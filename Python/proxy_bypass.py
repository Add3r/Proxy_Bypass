#!/usr/bin/env python3

import json
import subprocess
import argparse
import sys
import time
from collections import Counter

# Color Codes for Printing
G = "\033[32m"
Y = "\033[33m"
B = "\033[34m"
R = "\033[31m"
RES = "\033[0m"

class UserAgentTester:
    def __init__(self, user_agents_file):
        self.user_agents = self.load_user_agents(user_agents_file)
        self.success_count = 0
        self.denied_count = 0
        self.successful_user_agents = []

    def load_user_agents(self, file_path):
        try:
            if file_path.endswith('.json'):
                with open(file_path) as f:
                    return json.load(f)
            else:  # Assuming plain text file with user agents
                with open(file_path) as f:
                    return [{"user-agent": line.strip(), "id": "N/A", "group": "N/A"} for line in f if line.strip()]
        except FileNotFoundError:
            print(f"{R}[ERROR]{RES} File not found: {file_path}")
            print(f"{Y}[INFO]{RES} Check if user_agents.json is in the same directory as the script.")
            print(f"{Y}[INFO]{RES} you could also download from - https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json")
            sys.exit(1)
        except json.JSONDecodeError:
            print(f"{R}[ERROR]{RES} Error decoding JSON file: {file_path}")
            sys.exit(1)

    def test_user_agent(self, proxy, user_agent, verbose=False, target="www.google.com"):
        ua = user_agent["user-agent"]
        cmd = f"curl -s -A '{ua}' {target} -I --proxy 'http://{proxy}'"
        output = subprocess.getoutput(cmd)
        
        if "200 OK" in output:
            self.success_count += 1
            self.successful_user_agents.append(ua)
            if verbose:
                print(f"\n{B}ID: {RES}{user_agent.get('id', 'N/A')}\n{B}group: {RES}{user_agent.get('group', 'N/A')}\n{B}user-agent: {RES}{ua}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{G}[+] Success{RES}\n")
        else:
            self.denied_count += 1
            if verbose:
                print(f"\n{B}ID: {RES}{user_agent.get('id', 'N/A')}\n{B}group: {RES}{user_agent.get('group', 'N/A')}\n{B}user-agent: {RES}{ua}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{R}[x] Denied{RES}\n")

    def test_specific_user_agent(self, proxy, user_agent, target="www.google.com"):
        cmd = f"curl -s -A '{user_agent}' {target} -I --proxy 'http://{proxy}'"
        output = subprocess.getoutput(cmd)

        if "200 OK" in output:
            self.success_count += 1
            print(f"\n{B}ID: {RES}'N/A'\n{B}group: {RES}'N/A'\n{B}user-agent: {RES}{user_agent}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{G}[+] Success{RES}\n")
        else:
            print(f"\n{B}ID: {RES}'N/A'\n{B}group: {RES}'N/A'\n{B}user-agent: {RES}{user_agent}\n{B}proxy: {RES}{proxy}\n{B}target: {RES}{target}\n{R}[x] Denied{RES}\n")

    def test_user_agents(self, args):
        user_agents_to_test = self.user_agents

        if args.Platform != 'all':
            user_agents_to_test = [ua for ua in user_agents_to_test if ua["platform"].lower() == args.Platform]
        if args.Browser:
            user_agents_to_test = [ua for ua in user_agents_to_test if ua["group"] in args.Browser]
        if args.specific_ids:
            ids = args.specific_ids.split(',')
            user_agents_to_test = [ua for ua in user_agents_to_test if ua["id"] in ids]
        if args.uniq:
            group_counts = Counter(ua["group"] for ua in user_agents_to_test)
            uniq_groups = {group for group, count in group_counts.items() if count == 1}
            user_agents_to_test = [ua for ua in user_agents_to_test if ua["group"] in uniq_groups]
        
        total_agents = len(user_agents_to_test)
        if args.rate:
            for i in range(0, total_agents, args.rate):  # step by rate
                batch = user_agents_to_test[i:i+args.rate]
                for idx, ua in enumerate(batch, 1 + i):
                    self.test_user_agent(args.proxy_details, ua, args.verbose, args.target)
                    
                    eta = (total_agents - idx) * args.time_interval / 60
                    
                    if args.verbose:
                        print(f"Attempted {Y}{min(idx, total_agents)}/{total_agents}{RES} user agents | Successful: {G}{self.success_count}{RES} | Denied: {R}{self.denied_count}{RES} | ETA: {B}{eta:.2f}{RES} minutes")
                    else:
                        sys.stdout.write(f"\rAttempting {Y}{min(idx + args.rate, total_agents)}/{total_agents}{RES} user agents | Successful: {G}{self.success_count}{RES} | Denied: {R}{self.denied_count}{RES} | ETA: {B}{eta:.2f}{RES} minutes")
                        sys.stdout.flush()

                time.sleep(args.time_interval)
        else:
            for idx, ua in enumerate(user_agents_to_test, 1):
                self.test_user_agent(args.proxy_details, ua, args.verbose, args.target)
                
                eta = (total_agents - idx) * args.time_interval / 60
                
                if args.verbose:
                    print(f"Attempted {Y}{idx}/{total_agents}{RES} user agents | Successful: {G}{self.success_count}{RES} | Denied: {R}{self.denied_count}{RES} | ETA: {B}{eta:.2f}{RES} minutes")
                else:
                    sys.stdout.write(f"\rAttempting {Y}{idx}/{total_agents}{RES} user agents | Successful: {G}{self.success_count}{RES} | Denied: {R}{self.denied_count}{RES} | ETA: {B}{eta:.2f}{RES} minutes")
                    sys.stdout.flush()

        if not args.verbose:
            sys.stdout.write("\n")

    def save_to_file_or_print(self, successful_user_agents, output_filename=None):
        try:
            if output_filename:
                with open(output_filename, 'w') as f:
                    for ua in successful_user_agents:
                        f.write(f"{ua}\n")
                print(f"{B}[INFO]{RES}Output saved to {output_filename}")
            elif len(successful_user_agents) > 5:
                while True:
                    choice = input(f"\n{Y}[!]{RES} The number of successful user agents exceeded 5. Would you like to save the output to a file? (yes/no): ").lower()
                    if choice in ['yes', 'no']:
                        break
                    print(f"\n{Y}[!]{RES} Please enter 'yes' or 'no'.")

                if choice == 'yes':
                    default_filename = "output.txt"
                    filename = input(f"{Y}[!]{RES} Enter the filename (default: {default_filename}): ").strip() or default_filename
                    with open(filename, 'w') as f:
                        for ua in successful_user_agents:
                            f.write(f"{ua}\n")
                    print(f"{B}[INFO]{RES} Output saved to {filename}")
                else:
                    print(f"\n{G}[+]{RES} Successful user agents:")
                    for ua in successful_user_agents:
                        print(f"{B}->{RES} {ua}")
            else:
                #print("\n{G}[+]{RES} Successful user agents:")
                for ua in successful_user_agents:
                    print(f"{B}->{RES} {ua}")
        except KeyboardInterrupt:
            print(f"\n{R}[ERROR]{RES} Program interrupted by user during output handling.")
            sys.exit(1)

def validate_args(args):   
    if args.list:
        # Check the number of arguments provided to ensure only `-l` and `-O` are used
        provided_args = sys.argv[1:]
        
        # If only '-l' is provided
        if provided_args == ['-l']:
            return True, ""
        
        # If '-l' is combined with '-O' and a filename
        if len(provided_args) == 3 and '-l' in provided_args and '-O' in provided_args and args.output:
            return True, ""
        
        return False, f"{B}[INFO]{RES} Option '-l' can only be combined with the '-O' option followed by a filename or used standalone."

    # Check for special option (-ua) combinations
    if args.useragent:
        if args.Browser or args.Platform != "all" or args.specific_ids or args.list or (args.rate != None and args.verbose) or (args.time_interval != None and args.verbose) or (args.proxy_details != "127.0.0.1:8080" and args.verbose) or (args.target != "www.google.com" and args.verbose):
            return False, f"{B}[INFO]{RES} The '-ua' option can only be used standalone."
        return True, ""

    secondary_option_count = sum([bool(args.Browser), args.Platform != "all", bool(args.specific_ids), bool(args.useragent_file), args.uniq])
    # Check if more than one secondary option is provided
    if secondary_option_count > 1:
        return False, f"{B}[INFO]{RES} You can't combine -P, -s, -B, -uq and -uf options together."
   
    return True, ""

class CustomArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        if "invalid choice:" or "expected one argument" or "expected at least one argument" or "unrecognized arguments" in message:
            print(f"{R}[ERROR]{RES} Unregistered option(s) provided. or Missing argument(s).")
            print(f"{B}[INFO]{RES} re-run with -h/--help option for information on accepted input formats")
            sys.exit(2)
        else:
            super().error(message)

class CustomHelpFormatter(argparse.RawDescriptionHelpFormatter):
    def format_help(self):
        logo = """
                   
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
        """
        author = f"{B}Author: {RES}Karthick Siva\n"
        version = f"{B}Version: {RES}1.0\n"
        desc = f"{B}Description: {RES}Command-line tool to identify useragents that bypasses proxy restrictions\n"
        issues = f"{B}Report issues at: {RES}https://github.com/Add3r/Proxy_Bypass/issues\n"
        original_help = super().format_help()
        return logo + "\n" + version + desc + issues + author +"\n" + original_help

def main():
        parser = CustomArgumentParser(description=f"{B}Examples: {RES}\n\t$ python3 proxy_bypass.py\n\t$ python3 proxy_bypass.py -B Firefox Chrome\n\t$ python3 proxy_bypass.py -P mobile", formatter_class=CustomHelpFormatter)
        
        # Normal options
        parser.add_argument("-v", "--verbose", action="store_true", help="print verbose output")
        parser.add_argument("-r", "--rate", type=int, default=None, help="number of user agents to be processed in each batch")
        parser.add_argument("-t", "--time-interval", type=int, default=2, help="time interval (in seconds) for each batch to be processed")
        parser.add_argument("-p", "--proxy-details", default="127.0.0.1:8080", help="proxy server details (default: 127.0.0.1:8080)")
        parser.add_argument("-T", "--target", default="www.google.com", help="target domain to test user agents (default: www.google.com)")
        parser.add_argument("-O", "--output", help="output file to write results, -O output.txt")
        
        # Special options
        special_group = parser.add_argument_group(f"{B}Special Options{RES}")
        special_group.add_argument("-l", "--list", action="store_true", help="list available browser groups, proxy_bypass.py -l")
        special_group.add_argument("-B", "--Browser", nargs="+", help="select user agent browser groups")
        special_group.add_argument("-P", "--Platform", choices=["mobile", "general", "all"], default="all", help="select user agent platform (mobile/general/all)")
        special_group.add_argument("-s", "--specific-ids", help="run specific user agents by ID (comma-separated) by using ua-id from json file. -ua 'ua-30','ua-31'")
        special_group.add_argument("-ua", "--useragent", help="specific user agent string for testing")
        special_group.add_argument("-uf", "--useragent-file", help="file containing user agents to be tested")
        special_group.add_argument("-uq", "--uniq", action="store_true", help="test user agents of unique browser groups")

        args = parser.parse_args()

        is_valid, error_message = validate_args(args)
        if not is_valid:
            print(f"{R}[ERROR]{RES} Invalid combination of options. \n{error_message}")
            sys.exit(1)

        tester = UserAgentTester(args.useragent_file if args.useragent_file else "user_agents.json")

        available_browser_groups = set(ua["group"] for ua in tester.user_agents)
        # Check if -B value is valid
        if args.Browser:
            for browser in args.Browser:
                if browser not in available_browser_groups:
                    print(f"{R}[ERROR]{RES} Given browser group doesn't exist.")
                    print(f"{B}[INFO]{RES} try python3 proxy_bypass -l and use one of the browsers.")
                    sys.exit(1)

        if args.list:
            browser_groups = set(ua["group"] for ua in tester.user_agents)
            if args.output:  # Check if `-O` option is provided
                with open(args.output, 'w') as f:
                    f.write("{B}Available Browser Groups:{RES}\n")
                    for group in sorted(browser_groups):
                        f.write(f"- {group}\n")
                print(f"{B}[INFO]{RES} Output saved to {args.output}")
                sys.exit(0)
            else:
                print(f"{B}Available Browser Groups:{RES}\n")
                for group in sorted(browser_groups):
                    print(f"{B}-{RES} {group}")
                sys.exit(0)

        elif args.useragent:
            tester.test_specific_user_agent(args.proxy_details, args.useragent, args.target)
        else:
            try:
                tester.test_user_agents(args)
            except KeyboardInterrupt:
                print(f"\n{R}[ERROR]{RES} Program interrupted by user.")
                sys.exit(1)

        if not args.useragent and not args.list:
            successful_user_agents = [ua["user-agent"] for ua in tester.user_agents if ua["user-agent"] in tester.successful_user_agents]
            tester.save_to_file_or_print(successful_user_agents, args.output)

if __name__ == "__main__":
    main()
