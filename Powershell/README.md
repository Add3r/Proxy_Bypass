# Proxy_Bypass → PowerShell Client

This directory ships the PowerShell implementation of **proxy_bypass**. It mirrors the Python feature set while providing both:

- A standalone script (`proxy_bypass.ps1`) that can be executed directly.
- A reusable module (`ProxyBypass.psm1`) exporting `Invoke-ProxyBypass` so the logic can be imported into other PowerShell sessions or tooling.

## What you get

- User-agent loading from `user_agents.json` (relative paths or explicit files).
- Filtering by browser group, platform, specific IDs, or unique groups.
- Batch execution with custom rate/interval and progress output.
- Optional verbose traces for each attempt and curl-backed proxy testing.
- Result persistence with the same prompts as the Python CLI.
- A smoke test script (`Test Scripts/PowerShell_test_commands.sh`) for the script variant and `PowerShell_module_test_commands.sh` for the module variant.

## Quickstart

### Prerequisites

- PowerShell 7+ (`pwsh`) on macOS, Linux, or Windows.
- `curl` available on `PATH` (macOS includes it; other platforms may need manual install).
- A `user_agents.json` file in this directory (copy the canonical file from `../Python/user_agents.json` if missing).

### Run as a script

```
# from repo root
pwsh -NoProfile -File Proxy_Bypass/Powershell/proxy_bypass.ps1 --help
```

Other examples:

```
pwsh -NoProfile -File Proxy_ByPass/Powershell/proxy_bypass.ps1 -Browser Chrome -Rate 5 -Time-Interval 1 -Target https://www.example.com
pwsh -NoProfile -File Proxy_ByPass/Powershell/proxy_bypass.ps1 -List
pwsh -NoProfile -File Proxy_ByPass/Powershell/proxy_bypass.ps1 -UserAgent "Mozilla/5.0 ..."
```

Running `Proxy_ByPass/Test Scripts/PowerShell_test_commands.sh` will execute a curated suite of script invocations for smoke testing.

### Use as a module

```
Set-Location Proxy_ByPass/Powershell
Import-Module (Resolve-Path ./ProxyBypass.psm1) -Force
Invoke-ProxyBypass -Help
```

Subsequent calls can reuse the imported function:

```
Invoke-ProxyBypass -Browser "ABrowse" -Rate 1 -TimeInterval 1 -Target "https://www.example.com"
Invoke-ProxyBypass -SpecificIds "ua-3916" -VerboseOutput -Output "output.txt"
Invoke-ProxyBypass -UserAgentFile "./input.txt"
```

Whenever you edit `ProxyBypass.psm1`, rerun `Import-Module ... -Force` (or `Remove-Module ProxyBypass; Import-Module ...`) to pick up changes in that PowerShell session. The companion smoke test `PowerShell_module_test_commands.sh` runs the same scenarios using the module API.

## Directory layout

```
Powershell/
├── proxy_bypass.ps1          # Entry-point script
├── ProxyBypass.psm1          # Importable module (Invoke-ProxyBypass)
├── user_agents.json          # Default UA library (copy of Python file)
├── input.txt                 # Sample UA list for -UserAgentFile tests
└── README.md                 # This document
```

## Troubleshooting

- **curl not found**: install it (Homebrew on macOS: `brew install curl`; Windows: winget/scoop/chocolatey) or ensure it’s on `PATH`.
- **Module not updating**: re-import with `Import-Module ... -Force` in the same session, or start a new PowerShell process.
- **Missing `user_agents.json`**: copy it from `Proxy_ByPass/Python/user_agents.json` or supply one via `-UserAgentFile`.

With the script or module available, you can script proxy bypass checks, integrate them into automation, or run the CLI interactively exactly as the original Python utility.
