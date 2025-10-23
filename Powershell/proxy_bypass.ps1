Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$esc = [char]27
$G = "$esc[32m"
$Y = "$esc[33m"
$B = "$esc[34m"
$R = "$esc[31m"
$RES = "$esc[0m"
$curlCommand = if ($IsWindows) { "curl.exe" } else { "curl" }

function Show-Help {
    $logoLines = @(
"                   ",
"                                                 @@@@@@@@@@@                   ",
"                               @@@@@@@@@@@@@@@@@        @@@                    ",
"                            @@@@@@@@@@@@@@@@@@@@@      @@@@                    ",
"                          @@@@@@@@@@       @@@          @@                     ",
"                        @@@@@@@@                   @@@@                        ",
"                       @@@@@@@@                 @@@@@@@@                       ",
"                       @@@@@@@@@@@@@@@@@@@@      @@@@@@@                       ",
"                       @@@@@@@@@@@@@@@@@@@@@     @@@@@@@                       ",
"                       @@@@@@@@@@@@@@@@@@        @@@@@@@                       ",
"                        @@@@@@@                @@@@@@@@                        ",
"                         @@@@@@              @@@@@@@@@                         ",
"                         @@@@@@     @@@@@@@@@@@@@@@@                           ",
"                         @@@@@@     @@@@@@@@@@@@@                              ",
"                         @@@@@@     @@@@@@@                                     ",
"",
"                         PROXY BYPASS with USERAGENTS"
    )
    $logo = [string]::Join([Environment]::NewLine, $logoLines)
    Write-Host $logo
    Write-Host ("{0}Version: {1}1.0" -f $B, $RES)
    Write-Host ("{0}Description: {1}Command-line tool to identify useragents that bypass proxy restrictions" -f $B, $RES)
    Write-Host ("{0}Report issues at: {1}https://github.com/Add3r/Proxy_Bypass/issues" -f $B, $RES)
    Write-Host ("{0}Author: {1}Karthick Siva" -f $B, $RES)
    Write-Host ""
    Write-Host "usage: proxy_bypass.py [-h] [-v] [-r RATE] [-t TIME_INTERVAL]"
    Write-Host "                       [-p PROXY_DETAILS] [-T TARGET] [-O OUTPUT] [-l]"
    Write-Host "                       [-B BROWSER [BROWSER ...]] [-P {mobile,general,all}]"
    Write-Host "                       [-s SPECIFIC_IDS] [-ua USERAGENT] [-uf USERAGENT_FILE]"
    Write-Host "                       [-uq]"
    Write-Host ""
    Write-Host ("{0}Examples: {1}" -f $B, $RES)
    Write-Host "`t$ python3 proxy_bypass.py"
    Write-Host "`t$ python3 proxy_bypass.py -B Firefox Chrome"
    Write-Host "`t$ python3 proxy_bypass.py -P mobile"
    Write-Host ""
    Write-Host "options:"
    Write-Host "  -h, --help            show this help message and exit"
    Write-Host "  -v, --verbose         print verbose output"
    Write-Host "  -r RATE, --rate RATE  number of user agents to be processed in each batch"
    Write-Host "  -t TIME_INTERVAL, --time-interval TIME_INTERVAL"
    Write-Host "                        time interval (in seconds) for each batch to be"
    Write-Host "                        processed"
    Write-Host "  -p PROXY_DETAILS, --proxy-details PROXY_DETAILS"
    Write-Host "                        proxy server details (default: 127.0.0.1:8080)"
    Write-Host "  -T TARGET, --target TARGET"
    Write-Host "                        target domain to test user agents (default:"
    Write-Host "                        www.google.com)"
    Write-Host "  -O OUTPUT, --output OUTPUT"
    Write-Host "                        output file to write SUCCESS results, -O output.txt"
    Write-Host ""
    Write-Host ("{0}Special Options{1}:" -f $B, $RES)
    Write-Host "  -l, --list            list available browser groups, proxy_bypass.py -l"
    Write-Host "  -B BROWSER [BROWSER ...], --Browser BROWSER [BROWSER ...]"
    Write-Host "                        select user agent browser groups"
    Write-Host "  -P {mobile,general,all}, --Platform {mobile,general,all}"
    Write-Host "                        select user agent platform (mobile/general/all)"
    Write-Host "  -s SPECIFIC_IDS, --specific-ids SPECIFIC_IDS"
    Write-Host "                        run specific user agents by ID (comma-separated) by"
    Write-Host "                        using ua-id from json file. -ua 'ua-30','ua-31'"
    Write-Host "  -ua USERAGENT, --useragent USERAGENT"
    Write-Host "                        specific user agent string for testing"
    Write-Host "  -uf USERAGENT_FILE, --useragent-file USERAGENT_FILE"
    Write-Host "                        file containing user agents to be tested"
    Write-Host "  -uq, --uniq           test user agents of unique browser groups"
}

function Parse-Arguments {
    param([string[]]$InputArgs)

    if (-not $PSBoundParameters.ContainsKey("InputArgs") -or @($InputArgs).Count -eq 0) {
        $InputArgs = [string[]]@($script:args)
    }

    $defaults = @{
        Verbose      = $false
        Rate         = $null
        TimeInterval = 2
        ProxyDetails = "127.0.0.1:8080"
        Target       = "www.google.com"
        Output       = $null
        List         = $false
        Browser      = @()
        Platform     = "all"
        SpecificIds  = $null
        UserAgent    = $null
        UserAgentFile= $null
        Uniq         = $false
        Help         = $false
    }

    $result = @{}
    foreach ($key in $defaults.Keys) {
        $result[$key] = $defaults[$key]
    }

    $used = New-Object System.Collections.Generic.List[string]
    $argsArray = [string[]]@($InputArgs)
    $count = @($argsArray).Count
    $i = 0

    $reportUnknown = {
        Write-Host "$R[ERROR]$RES Unregistered option(s) provided. or Missing argument(s)."
        Write-Host "$B[INFO]$RES re-run with -h/--help option for information on accepted input formats"
        exit 2
    }

    $reportMissing = {
        param($option)
        Write-Host ("{0}[ERROR]{1} Missing value for option '{2}'." -f $R, $RES, $option)
        Write-Host ("{0}[INFO]{1} re-run with -h/--help option for information on accepted input formats" -f $B, $RES)
        exit 2
    }

    $reportInt = {
        param($option)
        Write-Host ("{0}[ERROR]{1} Option '{2}' expects an integer value." -f $R, $RES, $option)
        exit 2
    }

    $reportPlatform = {
        param($option)
        Write-Host ("{0}[ERROR]{1} Option '{2}' expects one of: mobile, general, all." -f $R, $RES, $option)
        exit 2
    }

    while ($i -lt $count) {
        $arg = $argsArray[$i]
        if (-not $arg) {
            $i++
            continue
        }

        $handled = $false

        if ($arg.StartsWith("--") -and $arg.Contains("=")) {
            $name = $arg.Substring(0, $arg.IndexOf("=")).ToLowerInvariant()
            $value = $arg.Substring($arg.IndexOf("=") + 1)
            switch ($name) {
                "--rate" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--rate" }
                    $parsed = 0
                    if (-not [int]::TryParse($value, [ref]$parsed)) { & $reportInt "--rate" }
                    $result["Rate"] = $parsed
                    if (-not $used.Contains("Rate")) { [void]$used.Add("Rate") }
                    $handled = $true
                }
                "--time-interval" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--time-interval" }
                    $parsed = 0
                    if (-not [int]::TryParse($value, [ref]$parsed)) { & $reportInt "--time-interval" }
                    $result["TimeInterval"] = $parsed
                    if (-not $used.Contains("TimeInterval")) { [void]$used.Add("TimeInterval") }
                    $handled = $true
                }
                "--proxy-details" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--proxy-details" }
                    $result["ProxyDetails"] = $value
                    if (-not $used.Contains("ProxyDetails")) { [void]$used.Add("ProxyDetails") }
                    $handled = $true
                }
                "--target" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--target" }
                    $result["Target"] = $value
                    if (-not $used.Contains("Target")) { [void]$used.Add("Target") }
                    $handled = $true
                }
                "--output" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--output" }
                    $result["Output"] = $value
                    if (-not $used.Contains("Output")) { [void]$used.Add("Output") }
                    $handled = $true
                }
                "--platform" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--platform" }
                    $normalized = $value.ToLowerInvariant()
                    if (@("mobile", "general", "all") -notcontains $normalized) { & $reportPlatform "--platform" }
                    $result["Platform"] = $normalized
                    if (-not $used.Contains("Platform")) { [void]$used.Add("Platform") }
                    $handled = $true
                }
                "--specific-ids" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--specific-ids" }
                    $result["SpecificIds"] = $value
                    if (-not $used.Contains("SpecificIds")) { [void]$used.Add("SpecificIds") }
                    $handled = $true
                }
                "--useragent" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--useragent" }
                    $result["UserAgent"] = $value
                    if (-not $used.Contains("UserAgent")) { [void]$used.Add("UserAgent") }
                    $handled = $true
                }
                "--useragent-file" {
                    if ([string]::IsNullOrEmpty($value)) { & $reportMissing "--useragent-file" }
                    $result["UserAgentFile"] = $value
                    if (-not $used.Contains("UserAgentFile")) { [void]$used.Add("UserAgentFile") }
                    $handled = $true
                }
                "--browser" {
                    $items = @($value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    if ($items.Count -eq 0) { & $reportMissing "--browser" }
                    $result["Browser"] = @($items)
                    if (-not $used.Contains("Browser")) { [void]$used.Add("Browser") }
                    $handled = $true
                }
                default { }
            }

            if ($handled) {
                $i++
                continue
            } else {
                & $reportUnknown
            }
        }

                if ($arg -ceq "-h" -or $arg -ceq "-help" -or $arg.ToLowerInvariant() -eq "--help") {
            $result["Help"] = $true
            if (-not $used.Contains("Help")) { [void]$used.Add("Help") }
            $i++
            continue
        } elseif ($arg -ceq "-v" -or $arg.ToLowerInvariant() -eq "--verbose") {
            $result["Verbose"] = $true
            if (-not $used.Contains("Verbose")) { [void]$used.Add("Verbose") }
            $i++
            continue
        } elseif ($arg -ceq "-r" -or $arg.ToLowerInvariant() -eq "--rate") {
            $optionLabel = if ($arg -ceq "-r") { "-r" } else { "--rate" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $parsed = 0
            if (-not [int]::TryParse($value, [ref]$parsed)) { & $reportInt $optionLabel }
            $result["Rate"] = $parsed
            if (-not $used.Contains("Rate")) { [void]$used.Add("Rate") }
            $i++
            continue
        } elseif ($arg -ceq "-t" -or $arg.ToLowerInvariant() -eq "--time-interval") {
            $optionLabel = if ($arg -ceq "-t") { "-t" } else { "--time-interval" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $parsed = 0
            if (-not [int]::TryParse($value, [ref]$parsed)) { & $reportInt $optionLabel }
            $result["TimeInterval"] = $parsed
            if (-not $used.Contains("TimeInterval")) { [void]$used.Add("TimeInterval") }
            $i++
            continue
        } elseif ($arg -ceq "-p" -or $arg.ToLowerInvariant() -eq "--proxy-details") {
            $optionLabel = if ($arg -ceq "-p") { "-p" } else { "--proxy-details" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["ProxyDetails"] = $value
            if (-not $used.Contains("ProxyDetails")) { [void]$used.Add("ProxyDetails") }
            $i++
            continue
        } elseif ($arg -ceq "-T" -or $arg.ToLowerInvariant() -eq "--target") {
            $optionLabel = if ($arg -ceq "-T") { "-T" } else { "--target" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["Target"] = $value
            if (-not $used.Contains("Target")) { [void]$used.Add("Target") }
            $i++
            continue
        } elseif ($arg -ceq "-O" -or $arg -ceq "-o" -or $arg.ToLowerInvariant() -eq "--output") {
            $optionLabel = if ($arg.ToLowerInvariant() -eq "--output") { "--output" } else { "-O" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["Output"] = $value
            if (-not $used.Contains("Output")) { [void]$used.Add("Output") }
            $i++
            continue
        } elseif ($arg -ceq "-l" -or $arg.ToLowerInvariant() -eq "--list") {
            $result["List"] = $true
            if (-not $used.Contains("List")) { [void]$used.Add("List") }
            $i++
            continue
        } elseif ($arg -ceq "-B" -or $arg.ToLowerInvariant() -eq "--browser") {
            $optionLabel = if ($arg -ceq "-B") { "-B" } else { "--browser" }
            $values = New-Object System.Collections.Generic.List[string]
            while ($i + 1 -lt $count) {
                $peek = $argsArray[$i + 1]
                if ($peek.StartsWith("-")) { break }
                $i++
                $values.Add($peek)
            }
            if ($values.Count -eq 0) { & $reportMissing $optionLabel }
            $result["Browser"] = $values.ToArray()
            if (-not $used.Contains("Browser")) { [void]$used.Add("Browser") }
            $i++
            continue
        } elseif ($arg -ceq "-P" -or $arg.ToLowerInvariant() -eq "--platform") {
            $optionLabel = if ($arg -ceq "-P") { "-P" } else { "--platform" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $normalized = $value.ToLowerInvariant()
            if (@("mobile", "general", "all") -notcontains $normalized) { & $reportPlatform $optionLabel }
            $result["Platform"] = $normalized
            if (-not $used.Contains("Platform")) { [void]$used.Add("Platform") }
            $i++
            continue
        } elseif ($arg -ceq "-s" -or $arg.ToLowerInvariant() -eq "--specific-ids") {
            $optionLabel = if ($arg -ceq "-s") { "-s" } else { "--specific-ids" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["SpecificIds"] = $value
            if (-not $used.Contains("SpecificIds")) { [void]$used.Add("SpecificIds") }
            $i++
            continue
        } elseif ($arg -ceq "-ua" -or $arg.ToLowerInvariant() -eq "--useragent") {
            $optionLabel = if ($arg -ceq "-ua") { "-ua" } else { "--useragent" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["UserAgent"] = $value
            if (-not $used.Contains("UserAgent")) { [void]$used.Add("UserAgent") }
            $i++
            continue
        } elseif ($arg -ceq "-uf" -or $arg.ToLowerInvariant() -eq "--useragent-file") {
            $optionLabel = if ($arg -ceq "-uf") { "-uf" } else { "--useragent-file" }
            if ($i + 1 -ge $count) { & $reportMissing $optionLabel }
            $i++
            $value = $argsArray[$i]
            $result["UserAgentFile"] = $value
            if (-not $used.Contains("UserAgentFile")) { [void]$used.Add("UserAgentFile") }
            $i++
            continue
        } elseif ($arg -ceq "-uq" -or $arg.ToLowerInvariant() -eq "--uniq") {
            $result["Uniq"] = $true
            if (-not $used.Contains("Uniq")) { [void]$used.Add("Uniq") }
            $i++
            continue
        } else {
            & $reportUnknown
        }

    }

    $result["Browser"] = @($result["Browser"])
    $result["UsedOptions"] = $used.ToArray()
    return $result
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Object,
        [Parameter(Mandatory)]
        [string]$PropertyName,
        [string]$DefaultValue = "N/A"
    )

    $property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $PropertyName } | Select-Object -First 1
    if ($property) {
        return $property.Value
    }

    return $DefaultValue
}

function Resolve-UserAgentPath {
    param(
        [Parameter(Mandatory)]
        [string]$RequestedPath,
        [Parameter(Mandatory)]
        [string]$ScriptDirectory
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $null
    }

    $resolved = $null

    if (Test-Path -LiteralPath $RequestedPath) {
        $resolved = (Resolve-Path -LiteralPath $RequestedPath).Path
    } else {
        $combined = Join-Path -Path $ScriptDirectory -ChildPath $RequestedPath
        if (Test-Path -LiteralPath $combined) {
            $resolved = (Resolve-Path -LiteralPath $combined).Path
        }
    }

    return $resolved
}

function Load-UserAgents {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "$R[ERROR]$RES File not found: $Path"
        Write-Host "$Y[INFO]$RES Check if user_agents.json is in the same directory as the script."
        Write-Host "$Y[INFO]$RES you could also download from - https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json"
        exit 1
    }

    try {
        if ($Path.ToLower().EndsWith(".json")) {
            $content = Get-Content -LiteralPath $Path -Raw
            try {
                return $content | ConvertFrom-Json
            } catch {
                Write-Host "$R[ERROR]$RES Error decoding JSON file: $Path"
                exit 1
            }
        } else {
            $lines = Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            return $lines | ForEach-Object {
                [pscustomobject]@{
                    'user-agent' = $_.Trim()
                    id           = 'N/A'
                    group        = 'N/A'
                }
            }
        }
    } catch {
        Write-Host "$R[ERROR]$RES Error reading file: $Path"
        exit 1
    }
}

function Invoke-CurlRequest {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        $null = Get-Command $curlCommand -ErrorAction Stop
        return (& $curlCommand @Arguments 2>$null | Out-String)
    } catch {
        Write-Host "$R[ERROR]$RES Failed to execute curl. Ensure curl is installed and accessible."
        exit 1
    }
}

function Write-VerboseDetails {
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Group,
        [Parameter(Mandatory)]
        [string]$UserAgent,
        [Parameter(Mandatory)]
        [string]$Proxy,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [bool]$IsSuccess
    )

    $statusMessage = if ($IsSuccess) { "[+] Success" } else { "[x] Denied" }
    $statusColor = if ($IsSuccess) { $G } else { $R }

    $messages = @(
        "",
        ("{0}ID: {1}{2}" -f $B, $RES, $Id),
        ("{0}group: {1}{2}" -f $B, $RES, $Group),
        ("{0}user-agent: {1}{2}" -f $B, $RES, $UserAgent),
        ("{0}proxy: {1}{2}" -f $B, $RES, $Proxy),
        ("{0}target: {1}{2}" -f $B, $RES, $Target),
        ("{0}{1}{2}" -f $statusColor, $statusMessage, $RES),
        ""
    )

    foreach ($line in $messages) {
        Write-Host $line
    }
}

function Test-UserAgent {
    param(
        [Parameter(Mandatory)]
        [string]$Proxy,
        [Parameter(Mandatory)]
        [pscustomobject]$UserAgent,
        [switch]$VerboseOutput,
        [Parameter(Mandatory)]
        [string]$Target
    )

    $uaString = Get-PropertyValue -Object $UserAgent -PropertyName 'user-agent'
    $id = Get-PropertyValue -Object $UserAgent -PropertyName 'id'
    $group = Get-PropertyValue -Object $UserAgent -PropertyName 'group'
    $arguments = @("-s", "-A", $uaString, $Target, "-I", "--proxy", "http://$Proxy")
    $output = Invoke-CurlRequest -Arguments $arguments

    if ($output -match "200 OK") {
        $script:SuccessCount++
        [void]$script:SuccessfulUserAgents.Add($uaString)
        if ($VerboseOutput) {
            Write-VerboseDetails -Id $id -Group $group -UserAgent $uaString -Proxy $Proxy -Target $Target -IsSuccess $true
        }
        return $true
    } else {
        $script:DeniedCount++
        if ($VerboseOutput) {
            Write-VerboseDetails -Id $id -Group $group -UserAgent $uaString -Proxy $Proxy -Target $Target -IsSuccess $false
        }
        return $false
    }
}

function Test-SpecificUserAgent {
    param(
        [Parameter(Mandatory)]
        [string]$Proxy,
        [Parameter(Mandatory)]
        [string]$UserAgent,
        [Parameter(Mandatory)]
        [string]$Target
    )

    $arguments = @("-s", "-A", $UserAgent, $Target, "-I", "--proxy", "http://$Proxy")
    $output = Invoke-CurlRequest -Arguments $arguments

    if ($output -match "200 OK") {
        $script:SuccessCount++
        Write-VerboseDetails -Id "N/A" -Group "N/A" -UserAgent $UserAgent -Proxy $Proxy -Target $Target -IsSuccess $true
    } else {
        Write-VerboseDetails -Id "N/A" -Group "N/A" -UserAgent $UserAgent -Proxy $Proxy -Target $Target -IsSuccess $false
    }
}

function Filter-UserAgents {
    param(
        [Parameter(Mandatory)]
        [array]$UserAgents,
        [string[]]$Browser,
        [string]$Platform,
        [string]$SpecificIds,
        [switch]$Uniq
    )

    $filtered = $UserAgents

    if ($Platform -and $Platform.ToLower() -ne "all") {
        $filtered = $filtered | Where-Object {
            $platformValue = Get-PropertyValue -Object $_ -PropertyName 'platform'
            $platformValue -and $platformValue.ToString().ToLower() -eq $Platform.ToLower()
        }
    }

    if ($Browser -and $Browser.Count -gt 0) {
        $filtered = $filtered | Where-Object {
            $Browser -contains (Get-PropertyValue -Object $_ -PropertyName 'group')
        }
    }

    if ($SpecificIds) {
        $ids = $SpecificIds.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $filtered = $filtered | Where-Object {
            $ids -contains (Get-PropertyValue -Object $_ -PropertyName 'id')
        }
    }

    if ($Uniq) {
        $groupCounts = @{}
        foreach ($ua in $filtered) {
            $group = Get-PropertyValue -Object $ua -PropertyName 'group'
            if (-not $groupCounts.ContainsKey($group)) {
                $groupCounts[$group] = 0
            }
            $groupCounts[$group]++
        }

        $filtered = $filtered | Where-Object {
            $group = Get-PropertyValue -Object $_ -PropertyName 'group'
            $groupCounts[$group] -eq 1
        }
    }

    return @($filtered)
}

function Save-Results {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Results,
        [string]$OutputFile
    )

    try {
        if ($OutputFile) {
            Set-Content -LiteralPath $OutputFile -Value ($Results -join [Environment]::NewLine)
            Write-Host "$B[INFO]$RES Output saved to $OutputFile"
        } elseif ($Results.Count -gt 5) {
            while ($true) {
                $choice = Read-Host "$Y[!]$RES The number of successful user agents exceeded 5. Would you like to save the output to a file? (yes/no)"
                $choice = $choice.ToLower()
                if ($choice -eq "yes" -or $choice -eq "no") {
                    break
                }
                Write-Host ""
                Write-Host "$Y[!]$RES Please enter 'yes' or 'no'."
            }

            if ($choice -eq "yes") {
                $defaultFilename = "output.txt"
                $filename = Read-Host "$Y[!]$RES Enter the filename (default: $defaultFilename)"
                if ([string]::IsNullOrWhiteSpace($filename)) {
                    $filename = $defaultFilename
                }
                Set-Content -LiteralPath $filename -Value ($Results -join [Environment]::NewLine)
                Write-Host "$B[INFO]$RES Output saved to $filename"
            } else {
                Write-Host ""
                Write-Host "$G[+]$RES Successful user agents:"
                foreach ($ua in $Results) {
                    Write-Host "$B->$RES $ua"
                }
            }
        } else {
            foreach ($ua in $Results) {
                Write-Host "$B->$RES $ua"
            }
        }
    } catch {
        Write-Host ""
        Write-Host "$R[ERROR]$RES Program interrupted by user during output handling."
        exit 1
    }
}

function Validate-Arguments {
    param(
        [string[]]$UsedOptions,
        [bool]$List,
        [string]$Output,
        [string[]]$Browser,
        [string]$Platform,
        [string]$SpecificIds,
        [string]$UserAgent,
        [string]$UserAgentFile,
        [bool]$Uniq,
        [Nullable[int]]$Rate,
        [int]$TimeInterval,
        [string]$ProxyDetails,
        [string]$Target,
        [bool]$VerboseFlag
    )

    $usedSet = @{}
    if ($UsedOptions) {
        foreach ($option in $UsedOptions) {
            $usedSet[$option] = $true
        }
    }

    if ($List) {
        $allowed = @("List", "Output")
        foreach ($opt in $usedSet.Keys) {
            if ($allowed -notcontains $opt) {
                return [pscustomobject]@{
                    IsValid = $false
                    Message = "$B[INFO]$RES Option '-l' can only be combined with the '-O' option followed by a filename or used standalone."
                }
            }
        }
    }

    if ($UserAgent) {
        $rateProvided = $usedSet.ContainsKey("Rate")
        $timeIntervalProvided = $usedSet.ContainsKey("TimeInterval")
        $proxyChanged = $usedSet.ContainsKey("ProxyDetails")
        $targetChanged = $usedSet.ContainsKey("Target")

        if ($usedSet.ContainsKey("Browser") -or ($usedSet.ContainsKey("Platform") -and $Platform -ne "all") -or $usedSet.ContainsKey("SpecificIds") -or $List -or ($rateProvided -and $VerboseFlag) -or ($timeIntervalProvided -and $VerboseFlag) -or ($proxyChanged -and $VerboseFlag) -or ($targetChanged -and $VerboseFlag)) {
            return [pscustomobject]@{
                IsValid = $false
                Message = "$B[INFO]$RES The '-ua' option can only be used standalone."
            }
        }
    }

    $secondaryOptionCount = 0
    if ($usedSet.ContainsKey("Browser")) { $secondaryOptionCount++ }
    if ($usedSet.ContainsKey("Platform") -and $Platform -ne "all") { $secondaryOptionCount++ }
    if ($usedSet.ContainsKey("SpecificIds")) { $secondaryOptionCount++ }
    if ($usedSet.ContainsKey("UserAgentFile")) { $secondaryOptionCount++ }
    if ($Uniq) { $secondaryOptionCount++ }

    if ($secondaryOptionCount -gt 1) {
        return [pscustomobject]@{
            IsValid = $false
            Message = "$B[INFO]$RES You can't combine -P, -s, -B, -uq and -uf options together."
        }
    }

    return [pscustomobject]@{
        IsValid = $true
        Message = ""
    }
}

function Test-UserAgentsBatch {
    param(
        [Parameter(Mandatory)]
        [array]$UserAgents,
        [string]$Proxy,
        [switch]$VerboseOutput,
        [string]$Target,
        [Nullable[int]]$Rate,
        [int]$TimeInterval
    )

    $total = $UserAgents.Count
    if ($total -eq 0) {
        return
    }

    if ($Rate -and $Rate -gt 0) {
        for ($i = 0; $i -lt $total; $i += $Rate) {
            $batchEnd = [Math]::Min($i + $Rate, $total)
            for ($idx = $i; $idx -lt $batchEnd; $idx++) {
                $ua = $UserAgents[$idx]
                Test-UserAgent -Proxy $Proxy -UserAgent $ua -VerboseOutput:$VerboseOutput -Target $Target | Out-Null

                $eta = (($total - ($idx + 1)) * $TimeInterval) / 60.0
                $etaFormatted = "{0:N2}" -f $eta
                $attempted = $idx + 1
                $batchDisplay = [Math]::Min($idx + 1 + $Rate, $total)
                if ($VerboseOutput) {
                    Write-Host ("Attempted {0}{1}/{2}{3} user agents | Successful: {4}{5}{6} | Denied: {7}{8}{9} | ETA: {10}{11}{12} seconds" -f $Y, $attempted, $total, $RES, $G, $script:SuccessCount, $RES, $R, $script:DeniedCount, $RES, $B, $etaFormatted, $RES)
                } else {
                    Write-Host -NoNewline ("`rAttempting {0}{1}/{2}{3} user agents | Successful: {4}{5}{6} | Denied: {7}{8}{9} | ETA: {10}{11}{12} seconds" -f $Y, $batchDisplay, $total, $RES, $G, $script:SuccessCount, $RES, $R, $script:DeniedCount, $RES, $B, $etaFormatted, $RES)
                }
            }

            Start-Sleep -Seconds $TimeInterval
        }
    } else {
        for ($idx = 0; $idx -lt $total; $idx++) {
            $ua = $UserAgents[$idx]
            Test-UserAgent -Proxy $Proxy -UserAgent $ua -VerboseOutput:$VerboseOutput -Target $Target | Out-Null

            $eta = (($total - ($idx + 1)) * $TimeInterval) / 60.0
            $etaFormatted = "{0:N2}" -f $eta
            $attempted = $idx + 1
            if ($VerboseOutput) {
                Write-Host ("Attempted {0}{1}/{2}{3} user agents | Successful: {4}{5}{6} | Denied: {7}{8}{9} | ETA: {10}{11}{12} seconds" -f $Y, $attempted, $total, $RES, $G, $script:SuccessCount, $RES, $R, $script:DeniedCount, $RES, $B, $etaFormatted, $RES)
            } else {
                Write-Host -NoNewline ("`rAttempting {0}{1}/{2}{3} user agents | Successful: {4}{5}{6} | Denied: {7}{8}{9} | ETA: {10}{11}{12} seconds" -f $Y, $attempted, $total, $RES, $G, $script:SuccessCount, $RES, $R, $script:DeniedCount, $RES, $B, $etaFormatted, $RES)
            }
        }
    }

    if (-not $VerboseOutput) {
        Write-Host ""
    }
}



$parsed = Parse-Arguments
$Verbose = [bool]$parsed.Verbose
$Rate = $parsed.Rate
$TimeInterval = $parsed.TimeInterval
$ProxyDetails = $parsed.ProxyDetails
$Target = $parsed.Target
$Output = $parsed.Output
$List = [bool]$parsed.List
$Browser = @($parsed.Browser)
$Platform = $parsed.Platform
$SpecificIds = $parsed.SpecificIds
$UserAgent = $parsed.UserAgent
$UserAgentFile = $parsed.UserAgentFile
$Uniq = [bool]$parsed.Uniq
$HelpRequested = [bool]$parsed.Help
$UsedOptions = $parsed.UsedOptions

if ($HelpRequested) {
    Show-Help
    exit 0
}

$script:SuccessCount = 0
$script:DeniedCount = 0
$script:SuccessfulUserAgents = [System.Collections.Generic.List[string]]::new()

$scriptDirectory = Split-Path -Parent $PSCommandPath
$defaultUserAgentPath = Join-Path -Path $scriptDirectory -ChildPath "user_agents.json"
if (-not (Test-Path -LiteralPath $defaultUserAgentPath)) {
    $rootDirectory = Split-Path -Parent $scriptDirectory
    $alternatePath = Join-Path -Path $rootDirectory -ChildPath "Python/user_agents.json"
    if (Test-Path -LiteralPath $alternatePath) {
        $defaultUserAgentPath = $alternatePath
    }
}

$userAgentPath = if ($UserAgentFile) {
    Resolve-UserAgentPath -RequestedPath $UserAgentFile -ScriptDirectory $scriptDirectory
} else {
    Resolve-UserAgentPath -RequestedPath $defaultUserAgentPath -ScriptDirectory $scriptDirectory
}

if (-not $userAgentPath) {
    $missingFile = if ($UserAgentFile) { $UserAgentFile } else { "user_agents.json" }
    Write-Host ("{0}[ERROR]{1} File not found: {2}" -f $R, $RES, $missingFile)
    Write-Host "$Y[INFO]$RES Check if user_agents.json is in the same directory as the script."
    Write-Host "$Y[INFO]$RES you could also download from - https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json"
    exit 1
}

$validationResult = Validate-Arguments -UsedOptions $UsedOptions -List:$List -Output $Output -Browser $Browser -Platform $Platform -SpecificIds $SpecificIds -UserAgent $UserAgent -UserAgentFile $UserAgentFile -Uniq:$Uniq -Rate $Rate -TimeInterval $TimeInterval -ProxyDetails $ProxyDetails -Target $Target -VerboseFlag:$Verbose

if (-not $validationResult.IsValid) {
    Write-Host "$R[ERROR]$RES Invalid combination of options."
    Write-Host $validationResult.Message
    exit 1
}

$userAgents = Load-UserAgents -Path $userAgentPath
$availableBrowserGroups = ($userAgents | ForEach-Object { Get-PropertyValue -Object $_ -PropertyName 'group' } | Where-Object { $_ } | Sort-Object -Unique)

if ($Browser.Count -gt 0) {
    foreach ($browserName in $Browser) {
        if ($availableBrowserGroups -notcontains $browserName) {
            Write-Host "$R[ERROR]$RES Given browser group doesn't exist."
            Write-Host "$B[INFO]$RES try proxy_bypass.ps1 -List and use one of the browsers."
            exit 1
        }
    }
}

if ($List) {
    $browserGroups = ($userAgents | ForEach-Object { Get-PropertyValue -Object $_ -PropertyName 'group' } | Where-Object { $_ } | Sort-Object -Unique)
    if ($Output) {
        $content = @("{0}Available Browser Groups:{1}" -f $B, $RES)
        foreach ($group in $browserGroups) {
            $content += "- $group"
        }
        Set-Content -LiteralPath $Output -Value ($content -join [Environment]::NewLine)
        Write-Host "$B[INFO]$RES Output saved to $Output (Only successful results are saved)"
    } else {
        Write-Host ("{0}Available Browser Groups:{1}" -f $B, $RES)
        foreach ($group in $browserGroups) {
            Write-Host "$B-$RES $group"
        }
    }
    exit 0
}

$cancelHandler = [System.ConsoleCancelEventHandler]{
    param($sender, $eventArgs)
    $eventArgs.Cancel = $true
    Write-Host ""
    Write-Host "$R[ERROR]$RES Program interrupted by user."
    exit 1
}

$cancelSubscription = $false
try {
    [System.Console]::add_CancelKeyPress($cancelHandler)
    $cancelSubscription = $true
} catch {
    $cancelHandler = $null
}

try {
    if ($UserAgent) {
        Test-SpecificUserAgent -Proxy $ProxyDetails -UserAgent $UserAgent -Target $Target
    } else {
        $filteredUserAgents = Filter-UserAgents -UserAgents $userAgents -Browser $Browser -Platform $Platform -SpecificIds $SpecificIds -Uniq:$Uniq
        Test-UserAgentsBatch -UserAgents $filteredUserAgents -Proxy $ProxyDetails -VerboseOutput:$Verbose -Target $Target -Rate $Rate -TimeInterval $TimeInterval
    }
} catch {
    Write-Host ""
    Write-Host "$R[ERROR]$RES Program interrupted by user."
    exit 1
} finally {
    if ($cancelSubscription -and $cancelHandler) {
        [System.Console]::remove_CancelKeyPress($cancelHandler)
    }
}

if (-not $UserAgent) {
    $successful = @($userAgents | Where-Object {
        $uaString = Get-PropertyValue -Object $_ -PropertyName 'user-agent'
        $script:SuccessfulUserAgents -contains $uaString
    } | ForEach-Object { Get-PropertyValue -Object $_ -PropertyName 'user-agent' })

    Save-Results -Results $successful -OutputFile $Output
}
