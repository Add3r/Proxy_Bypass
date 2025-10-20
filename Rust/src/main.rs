use anyhow::{anyhow, Context, Result};
use clap::{Arg, ArgAction, ArgMatches, Command, ValueEnum};
use reqwest::blocking::{Client, ClientBuilder};
use reqwest::header::USER_AGENT;
use reqwest::Proxy;
use serde::Deserialize;
use std::env;
use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::path::Path;
use std::process;
use std::thread;
use std::time::Duration;

const DEFAULT_PROXY: &str = "127.0.0.1:8080";
const DEFAULT_TARGET: &str = "www.google.com";

const G: &str = "\x1b[32m";
const Y: &str = "\x1b[33m";
const B: &str = "\x1b[34m";
const R: &str = "\x1b[31m";
const RES: &str = "\x1b[0m";

#[derive(Debug, Clone, Deserialize)]
struct UserAgentRecord {
    #[serde(rename = "user-agent")]
    user_agent: String,
    #[serde(default)]
    id: Option<String>,
    #[serde(default)]
    group: Option<String>,
    #[serde(default)]
    platform: Option<String>,
}

#[derive(Clone, Debug, ValueEnum, PartialEq, Eq)]
enum PlatformChoice {
    Mobile,
    General,
    All,
}

impl Default for PlatformChoice {
    fn default() -> Self {
        PlatformChoice::All
    }
}

struct UserAgentTester {
    user_agents: Vec<UserAgentRecord>,
    success_count: usize,
    denied_count: usize,
    successful_user_agents: Vec<String>,
}

impl UserAgentTester {
    fn new(user_agent_path: Option<&str>) -> Result<Self> {
        let list = Self::load_user_agents(user_agent_path)?;
        Ok(Self {
            user_agents: list,
            success_count: 0,
            denied_count: 0,
            successful_user_agents: Vec::new(),
        })
    }

    fn load_user_agents(path: Option<&str>) -> Result<Vec<UserAgentRecord>> {
        let file_path = path.unwrap_or("user_agents.json");
        let p = Path::new(file_path);
        if !p.exists() {
            println!(
                "{R}[ERROR]{RES} File not found: {file_path}\n\
                 {Y}[INFO]{RES} Ensure the file resides alongside the binary or pass with --useragent-file.\n\
                 {Y}[INFO]{RES} You can download a sample library from https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json",
            );
            process::exit(1);
        }

        if file_path.ends_with(".json") {
            let file = File::open(p).with_context(|| format!("failed to open {}", file_path))?;
            let reader = BufReader::new(file);
            let mut entries: Vec<UserAgentRecord> =
                serde_json::from_reader(reader).with_context(|| "failed to parse JSON user agents")?;
            // Ensure blank groups/platforms come back as None for consistent filtering
            for entry in &mut entries {
                if entry.group.as_deref().map_or(false, |g| g.trim().is_empty()) {
                    entry.group = None;
                }
                if entry.platform.as_deref().map_or(false, |g| g.trim().is_empty()) {
                    entry.platform = None;
                }
            }
            Ok(entries)
        } else {
            let file = File::open(p).with_context(|| format!("failed to open {}", file_path))?;
            let reader = BufReader::new(file);
            let mut records = Vec::new();
            for line in reader.lines() {
                let ua = line?;
                let trimmed = ua.trim();
                if !trimmed.is_empty() {
                    records.push(UserAgentRecord {
                        user_agent: trimmed.to_string(),
                        id: None,
                        group: None,
                        platform: None,
                    });
                }
            }
            Ok(records)
        }
    }

    fn filter_user_agents<'a>(
        &'a self,
        args: &CliArgs,
    ) -> Vec<&'a UserAgentRecord> {
        let mut filtered: Vec<&UserAgentRecord> = self.user_agents.iter().collect();

        if args.platform != PlatformChoice::All {
            filtered.retain(|ua| {
                ua.platform
                    .as_deref()
                    .map(|p| p.eq_ignore_ascii_case(match args.platform {
                        PlatformChoice::Mobile => "mobile",
                        PlatformChoice::General => "general",
                        PlatformChoice::All => "all", // unreachable due to guard above
                    }))
                    .unwrap_or(false)
            });
        }

        if let Some(browsers) = &args.browser {
            let allowed: HashSet<String> = browsers.iter().cloned().collect();
            filtered.retain(|ua| {
                ua.group
                    .as_ref()
                    .map(|g| allowed.contains(g))
                    .unwrap_or(false)
            });
        }

        if let Some(ids) = &args.specific_ids {
            let id_set: HashSet<String> = ids.split(',').map(|s| s.trim().to_string()).collect();
            filtered.retain(|ua| ua.id.as_ref().map(|i| id_set.contains(i)).unwrap_or(false));
        }

        if args.uniq {
            let mut counts: HashMap<String, usize> = HashMap::new();
            for ua in &filtered {
                if let Some(group) = ua.group.as_ref() {
                    *counts.entry(group.clone()).or_insert(0) += 1;
                }
            }
            let unique_groups: HashSet<String> = counts
                .into_iter()
                .filter_map(|(group, count)| if count == 1 { Some(group) } else { None })
                .collect();
            filtered.retain(|ua| {
                ua.group
                    .as_ref()
                    .map(|g| unique_groups.contains(g))
                    .unwrap_or(false)
            });
        }

        filtered
    }

    fn test_user_agent(
        &mut self,
        client: &Client,
        proxy: &str,
        entry: &UserAgentRecord,
        verbose: bool,
        target: &str,
    ) {
        let result = client
            .head(target)
            .header(USER_AGENT, &entry.user_agent)
            .send();

        let success = match result {
            Ok(resp) => resp.status() == reqwest::StatusCode::OK,
            Err(_) => false,
        };

        if success {
            self.success_count += 1;
            self.successful_user_agents.push(entry.user_agent.clone());
            if verbose {
                println!(
                    "\n{B}ID: {RES}{}\n{B}group: {RES}{}\n{B}user-agent: {RES}{}\n{B}proxy: {RES}{}\n{B}target: {RES}{}\n{G}[+] Success{RES}\n",
                    entry.id.as_deref().unwrap_or("N/A"),
                    entry.group.as_deref().unwrap_or("N/A"),
                    entry.user_agent,
                    proxy,
                    target
                );
            }
        } else {
            self.denied_count += 1;
            if verbose {
                println!(
                    "\n{B}ID: {RES}{}\n{B}group: {RES}{}\n{B}user-agent: {RES}{}\n{B}proxy: {RES}{}\n{B}target: {RES}{}\n{R}[x] Denied{RES}\n",
                    entry.id.as_deref().unwrap_or("N/A"),
                    entry.group.as_deref().unwrap_or("N/A"),
                    entry.user_agent,
                    proxy,
                    target
                );
            }
        }
    }

    fn test_specific_user_agent(&mut self, proxy: &str, ua: &str, target: &str) -> Result<()> {
        let client = build_client(proxy)?;
        let result = client.head(target).header(USER_AGENT, ua).send();

        let success = match result {
            Ok(resp) => resp.status() == reqwest::StatusCode::OK,
            Err(_) => false,
        };

        if success {
            self.success_count += 1;
            println!(
                "\n{B}ID: {RES}'N/A'\n{B}group: {RES}'N/A'\n{B}user-agent: {RES}{ua}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{G}[+] Success{RES}\n"
            );
        } else {
            println!(
                "\n{B}ID: {RES}'N/A'\n{B}group: {RES}'N/A'\n{B}user-agent: {RES}{ua}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{R}[x] Denied{RES}\n"
            );
        }
        Ok(())
    }

    fn run_tests(&mut self, args: &CliArgs) -> Result<()> {
        let filtered = self.filter_user_agents(args);
        let filtered_cloned: Vec<UserAgentRecord> = filtered.into_iter().map(|ua| ua.clone()).collect();
        if filtered_cloned.is_empty() {
            println!("{Y}[INFO]{RES} No user agents matched the provided filters.");
            return Ok(());
        }

        let total = filtered_cloned.len();
        let target_url = normalize_target(&args.target);
        let client = build_client(&args.proxy_details)?;

        if let Some(rate) = args.rate {
            if rate == 0 {
                return Err(anyhow!("Rate must be greater than zero"));
            }
            let mut processed = 0;
            for chunk in filtered_cloned.chunks(rate) {
                for ua in chunk {
                    processed += 1;
                    self.test_user_agent(&client, &args.proxy_details, ua, args.verbose, &target_url);
                    let eta_minutes =
                        ((total - processed) as f64 * args.time_interval as f64) / 60.0;
                    if args.verbose {
                        println!(
                            "Attempted {Y}{}/{total}{RES} user agents | Successful: {G}{}{RES} | Denied: {R}{}{RES} | ETA: {B}{eta:.2}{RES} minutes",
                            processed,
                            self.success_count,
                            self.denied_count,
                            eta = eta_minutes
                        );
                    } else {
                        print!(
                            "\rAttempting {Y}{}/{total}{RES} user agents | Successful: {G}{}{RES} | Denied: {R}{}{RES} | ETA: {B}{eta:.2}{RES} minutes",
                            processed,
                            self.success_count,
                            self.denied_count,
                            eta = eta_minutes
                        );
                        io::stdout().flush().ok();
                    }
                }
                if processed < total {
                    thread::sleep(Duration::from_secs(args.time_interval.into()));
                }
            }
        } else {
            for (idx, ua) in filtered_cloned.iter().enumerate() {
                let current = idx + 1;
                self.test_user_agent(&client, &args.proxy_details, ua, args.verbose, &target_url);
                let eta_minutes =
                    ((total - current) as f64 * args.time_interval as f64) / 60.0;
                if args.verbose {
                    println!(
                        "Attempted {Y}{}/{total}{RES} user agents | Successful: {G}{}{RES} | Denied: {R}{}{RES} | ETA: {B}{eta:.2}{RES} minutes",
                        current,
                        self.success_count,
                        self.denied_count,
                        eta = eta_minutes
                    );
                } else {
                    print!(
                        "\rAttempting {Y}{}/{total}{RES} user agents | Successful: {G}{}{RES} | Denied: {R}{}{RES} | ETA: {B}{eta:.2}{RES} minutes",
                        current,
                        self.success_count,
                        self.denied_count,
                        eta = eta_minutes
                    );
                    io::stdout().flush().ok();
                }
            }
        }

        if !args.verbose {
            println!();
        }

        Ok(())
    }

    fn save_to_file_or_print(&self, successes: &[String], output: Option<&String>) -> Result<()> {
        if let Some(filename) = output {
            let mut file = File::create(filename)
                .with_context(|| format!("failed to create output file {}", filename))?;
            for ua in successes {
                writeln!(file, "{ua}")?;
            }
            println!("{B}[INFO]{RES} Output saved to {filename}");
            return Ok(());
        }

        if successes.len() > 5 {
            loop {
                print!(
                    "\n{Y}[!]{RES} The number of successful user agents exceeded 5. Save to file? (yes/no): "
                );
                io::stdout().flush().ok();
                let mut input = String::new();
                io::stdin().read_line(&mut input)?;
                match input.trim().to_lowercase().as_str() {
                    "yes" => {
                        let default = "output.txt";
                        print!(
                            "{Y}[!]{RES} Enter filename (default: {default}): "
                        );
                        io::stdout().flush().ok();
                        let mut fname = String::new();
                        io::stdin().read_line(&mut fname)?;
                        let fname = if fname.trim().is_empty() {
                            default.to_string()
                        } else {
                            fname.trim().to_string()
                        };
                        let mut file = File::create(&fname)
                            .with_context(|| format!("failed to create {fname}"))?;
                        for ua in successes {
                            writeln!(file, "{ua}")?;
                        }
                        println!("{B}[INFO]{RES} Output saved to {fname}");
                        break;
                    }
                    "no" => {
                        println!("\n{G}[+]{RES} Successful user agents:");
                        for ua in successes {
                            println!("{B}->{RES} {ua}");
                        }
                        break;
                    }
                    _ => {
                        println!("{Y}[!]{RES} Please enter 'yes' or 'no'.");
                    }
                }
            }
        } else {
            for ua in successes {
                println!("{B}->{RES} {ua}");
            }
        }
        Ok(())
    }
}

fn build_client(proxy_details: &str) -> Result<Client> {
    let proxy_url = format!("http://{proxy_details}");
    let proxy = Proxy::http(&proxy_url)
        .with_context(|| format!("failed to configure proxy {proxy_details}"))?;
    let client = ClientBuilder::new()
        .proxy(proxy)
        .timeout(Duration::from_secs(20))
        .build()
        .context("failed to build HTTP client")?;
    Ok(client)
}

fn normalize_target(target: &str) -> String {
    let lower = target.to_lowercase();
    if lower.starts_with("http://") || lower.starts_with("https://") {
        target.to_string()
    } else {
        format!("http://{target}")
    }
}

fn validate_args(args: &CliArgs) -> Result<()> {
    if args.list {
        let mut invalid = Vec::new();
        if args.browser.is_some() {
            invalid.push("-B/--Browser");
        }
        if args.platform != PlatformChoice::All {
            invalid.push("-P/--Platform");
        }
        if args.specific_ids.is_some() {
            invalid.push("-s/--specific-ids");
        }
        if args.useragent.is_some() {
            invalid.push("-u/--useragent");
        }
        if args.useragent_file.is_some() {
            invalid.push("--useragent-file");
        }
        if args.uniq {
            invalid.push("--uniq");
        }
        if args.rate.is_some()
            || args.verbose
            || args.proxy_details != DEFAULT_PROXY
            || args.target != DEFAULT_TARGET
        {
            invalid.push("other execution options");
        }
        if !invalid.is_empty() {
            return Err(anyhow!(
                "{B}[INFO]{RES} Option '-l' can only be combined with '-O <file>' or used standalone.\n\
                 Conflicting options: {}",
                invalid.join(", ")
            ));
        }
    }

    if let Some(_) = args.useragent {
        if args.browser.is_some()
            || args.platform != PlatformChoice::All
            || args.specific_ids.is_some()
            || args.list
            || args.useragent_file.is_some()
            || args.uniq
            || (args.rate.is_some() && args.verbose)
            || (args.time_interval != 2 && args.verbose)
            || (args.proxy_details != DEFAULT_PROXY && args.verbose)
            || (args.target != DEFAULT_TARGET && args.verbose)
        {
            return Err(anyhow!(
                "{B}[INFO]{RES} The '-u/--useragent' option must be used standalone."
            ));
        }
    }

    let mut secondary = 0;
    if args.browser.is_some() {
        secondary += 1;
    }
    if args.platform != PlatformChoice::All {
        secondary += 1;
    }
    if args.specific_ids.is_some() {
        secondary += 1;
    }
    if args.useragent_file.is_some() {
        secondary += 1;
    }
    if args.uniq {
        secondary += 1;
    }
    if secondary > 1 {
        return Err(anyhow!(
            "{B}[INFO]{RES} You can't combine -P, -s, -B, --uniq and --useragent-file options together."
        ));
    }

    Ok(())
}

#[derive(Debug)]
struct CliArgs {
    verbose: bool,
    rate: Option<usize>,
    time_interval: u64,
    proxy_details: String,
    target: String,
    output: Option<String>,
    list: bool,
    browser: Option<Vec<String>>,
    platform: PlatformChoice,
    specific_ids: Option<String>,
    useragent: Option<String>,
    useragent_file: Option<String>,
    uniq: bool,
}

fn build_cli() -> Command {
    Command::new("proxy_bypass")
        .version("1.0")
        .about("Command-line tool to identify user-agents that bypass proxy restrictions")
        .after_help(
            "
                                                  @@@@@@@@@@@                   
                                @@@@@@@@@@@@@@@@@        @@@                    
                             @@@@@@@@@@@@@@@@@@@@@      @@@@                    
                           @@@@@@@@@@       @@@          @@                     
                         @@@@@@@@                   @@@@                        
                        @@@@@@@@                 @@@@@@@@                       
                        @@@@@@@@@@@@@@@@@@@@      @@@@@@@                       
                        @@@@@@@@@@@@@@@@@@@@@     @@@@@@@                       
                        @@@@@@@@@@@@@@@@@@        @@@@@@@                       
                         @@@@@@@                @@@@@@@@                        
                          @@@@@@              @@@@@@@@@                         
                          @@@@@@     @@@@@@@@@@@@@@@@                           
                          @@@@@@     @@@@@@@@@@@@@                              
                          @@@@@@     @@@@@@@                                  

                          PROXY BYPASS with USERAGENTS

Examples:
  proxy_bypass
  proxy_bypass -B Firefox Chrome
  proxy_bypass -P mobile

Report issues: https://github.com/Add3r/Proxy_Bypass/issues
Author: Karthick Siva
",
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .help("print verbose output")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("rate")
                .short('r')
                .long("rate")
                .help("number of user agents to be processed in each batch")
                .value_parser(clap::value_parser!(usize)),
        )
        .arg(
            Arg::new("time_interval")
                .short('t')
                .long("time-interval")
                .default_value("2")
                .help("time interval (in seconds) for each batch to be processed")
                .value_parser(clap::value_parser!(u64)),
        )
        .arg(
            Arg::new("proxy_details")
                .short('p')
                .long("proxy-details")
                .default_value(DEFAULT_PROXY)
                .help("proxy server details (default: 127.0.0.1:8080)"),
        )
        .arg(
            Arg::new("target")
                .short('T')
                .long("target")
                .default_value(DEFAULT_TARGET)
                .help("target domain to test user agents (default: www.google.com)"),
        )
        .arg(
            Arg::new("output")
                .short('O')
                .long("output")
                .help("output file to write results"),
        )
        .arg(
            Arg::new("list")
                .short('l')
                .long("list")
                .help("list available browser groups")
                .action(ArgAction::SetTrue),
        )
        .arg(
            Arg::new("browser")
                .short('B')
                .long("Browser")
                .help("select user agent browser groups")
                .num_args(1..),
        )
        .arg(
            Arg::new("platform")
                .short('P')
                .long("Platform")
                .default_value("all")
                .value_parser(clap::builder::EnumValueParser::<PlatformChoice>::new())
                .help("select user agent platform (mobile/general/all)"),
        )
        .arg(
            Arg::new("specific_ids")
                .short('s')
                .long("specific-ids")
                .help("run specific user agents by ID (comma-separated)"),
        )
        .arg(
            Arg::new("useragent")
                .short('u')
                .long("useragent")
                .visible_alias("ua")
                .help("specific user agent string for testing"),
        )
        .arg(
            Arg::new("useragent_file")
                .long("useragent-file")
                .visible_alias("uf")
                .help("file containing user agents to be tested"),
        )
        .arg(
            Arg::new("uniq")
                .long("uniq")
                .visible_alias("uq")
                .help("test user agents of unique browser groups")
                .action(ArgAction::SetTrue),
        )
}

fn parse_args(matches: ArgMatches) -> CliArgs {
    CliArgs {
        verbose: matches.get_flag("verbose"),
        rate: matches.get_one::<usize>("rate").copied(),
        time_interval: matches
            .get_one::<u64>("time_interval")
            .copied()
            .unwrap_or(2),
        proxy_details: matches
            .get_one::<String>("proxy_details")
            .cloned()
            .unwrap_or_else(|| DEFAULT_PROXY.to_string()),
        target: matches
            .get_one::<String>("target")
            .cloned()
            .unwrap_or_else(|| DEFAULT_TARGET.to_string()),
        output: matches.get_one::<String>("output").cloned(),
        list: matches.get_flag("list"),
        browser: matches
            .get_many::<String>("browser")
            .map(|vals| vals.map(|s| s.to_string()).collect::<Vec<_>>()),
        platform: matches
            .get_one::<PlatformChoice>("platform")
            .cloned()
            .unwrap_or_default(),
        specific_ids: matches.get_one::<String>("specific_ids").cloned(),
        useragent: matches.get_one::<String>("useragent").cloned(),
        useragent_file: matches.get_one::<String>("useragent_file").cloned(),
        uniq: matches.get_flag("uniq"),
    }
}

fn main() -> Result<()> {
    ctrlc::set_handler(|| {
        println!("\n{R}[ERROR]{RES} Program interrupted by user.");
        process::exit(1);
    })
    .ok();

    let raw_args: Vec<String> = env::args().collect();
    let processed_args = preprocess_args(&raw_args);
    let matches = build_cli()
        .try_get_matches_from(processed_args)
        .unwrap_or_else(|e| e.exit());
    let args = parse_args(matches);

    if let Err(err) = validate_args(&args) {
        eprintln!("{R}[ERROR]{RES} Invalid combination of options.\n{err}");
        process::exit(1);
    }

    let mut tester = UserAgentTester::new(args.useragent_file.as_deref())?;

    if let Some(browsers) = &args.browser {
        let available: HashSet<String> = tester
            .user_agents
            .iter()
            .filter_map(|ua| ua.group.clone())
            .collect();
        for browser in browsers {
            if !available.contains(browser) {
                eprintln!(
                    "{R}[ERROR]{RES} Given browser group '{browser}' doesn't exist.\n\
                     {B}[INFO]{RES} Try running `proxy_bypass -l` to list available groups."
                );
                process::exit(1);
            }
        }
    }

    if args.list {
        let mut groups: Vec<String> = tester
            .user_agents
            .iter()
            .filter_map(|ua| ua.group.clone())
            .collect();
        groups.sort();
        groups.dedup();
        if let Some(filename) = args.output.as_ref() {
            let mut file = File::create(filename)
                .with_context(|| format!("failed to create {filename}"))?;
            writeln!(file, "Available Browser Groups:")?;
            for group in groups {
                writeln!(file, "- {group}")?;
            }
            println!("{B}[INFO]{RES} Output saved to {filename}");
        } else {
            println!("{B}Available Browser Groups:{RES}\n");
            for group in groups {
                println!("{B}-{RES} {group}");
            }
        }
        return Ok(());
    }

    if let Some(ua) = &args.useragent {
        let target_url = normalize_target(&args.target);
        tester.test_specific_user_agent(&args.proxy_details, ua, &target_url)?;
        return Ok(());
    }

    tester.run_tests(&args)?;

    if args.useragent.is_none() && !args.list {
        let success_set: HashSet<&String> = tester.successful_user_agents.iter().collect();
        let successes: Vec<String> = tester
            .user_agents
            .iter()
            .filter(|ua| success_set.contains(&ua.user_agent))
            .map(|ua| ua.user_agent.clone())
            .collect();
        tester.save_to_file_or_print(&successes, args.output.as_ref())?;
    }

    Ok(())
}

fn preprocess_args(raw: &[String]) -> Vec<String> {
    if raw.is_empty() {
        return Vec::new();
    }

    let mut result = Vec::with_capacity(raw.len());
    result.push(raw[0].clone());

    for arg in raw.iter().skip(1) {
        let arg_str = arg.as_str();

        if arg_str == "-uf" {
            result.push("--useragent-file".to_string());
        } else if let Some(rest) = arg_str.strip_prefix("-uf=") {
            result.push("--useragent-file".to_string());
            if !rest.is_empty() {
                result.push(rest.to_string());
            }
        } else if arg_str == "-ua" {
            result.push("--useragent".to_string());
        } else if let Some(rest) = arg_str.strip_prefix("-ua=") {
            result.push("--useragent".to_string());
            if !rest.is_empty() {
                result.push(rest.to_string());
            }
        } else if arg_str == "-uq" || arg_str == "-uq=true" {
            result.push("--uniq".to_string());
        } else {
            result.push(arg.clone());
        }
    }

    result
}
