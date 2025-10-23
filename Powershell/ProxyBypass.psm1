Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$esc = [char]27
$G = "$esc[32m"
$Y = "$esc[33m"
$B = "$esc[34m"
$R = "$esc[31m"
$RES = "$esc[0m"
$CurlCommand = if ($IsWindows) { "curl.exe" } else { "curl" }

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

    if (Test-Path -LiteralPath $RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $combined = Join-Path -Path $ScriptDirectory -ChildPath $RequestedPath
    if (Test-Path -LiteralPath $combined) {
        return (Resolve-Path -LiteralPath $combined).Path
    }

    return $null
}

function Get-ProxyUserAgents {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host ("{0}[ERROR]{1} File not found: {2}" -f $R, $RES, $Path)
        Write-Host ("{0}[INFO]{1} Check if user_agents.json is in the same directory as the script." -f $Y, $RES)
        Write-Host ("{0}[INFO]{1} you could also download from - https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json" -f $Y, $RES)
        throw "User agent file not found."
    }

    try {
        if ($Path.ToLower().EndsWith(".json")) {
            $content = Get-Content -LiteralPath $Path -Raw
            try {
                return $content | ConvertFrom-Json
            } catch {
                Write-Host ("{0}[ERROR]{1} Error decoding JSON file: {2}" -f $R, $RES, $Path)
                throw
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
        Write-Host ("{0}[ERROR]{1} Error reading file: {2}" -f $R, $RES, $Path)
        throw
    }
}

function Invoke-CurlRequest {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    try {
        $null = Get-Command $CurlCommand -ErrorAction Stop
    } catch {
        Write-Host ("{0}[ERROR]{1} curl is not available on this system." -f $R, $RES)
        throw
    }

    try {
        return (& $CurlCommand @Arguments 2>$null | Out-String)
    } catch {
        Write-Host ("{0}[ERROR]{1} Failed to execute curl. Ensure curl is installed and accessible." -f $R, $RES)
        throw
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

function Select-ProxyUserAgents {
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

    if ($Browser) {
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
            Write-Host ("{0}[INFO]{1} Output saved to {2}" -f $B, $RES, $OutputFile)
        } elseif ($Results.Count -gt 5) {
            while ($true) {
                $choice = Read-Host ("{0}[!]{1} The number of successful user agents exceeded 5. Would you like to save the output to a file? (yes/no)" -f $Y, $RES)
                $choice = $choice.ToLower()
                if ($choice -eq "yes" -or $choice -eq "no") {
                    break
                }
                Write-Host ""
                Write-Host ("{0}[!]{1} Please enter 'yes' or 'no'." -f $Y, $RES)
            }

            if ($choice -eq "yes") {
                $defaultFilename = "output.txt"
                $filename = Read-Host ("{0}[!]{1} Enter the filename (default: {2})" -f $Y, $RES, $defaultFilename)
                if ([string]::IsNullOrWhiteSpace($filename)) {
                    $filename = $defaultFilename
                }
                Set-Content -LiteralPath $filename -Value ($Results -join [Environment]::NewLine)
                Write-Host ("{0}[INFO]{1} Output saved to {2}" -f $B, $RES, $filename)
            } else {
                Write-Host ""
                Write-Host ("{0}[+]{1} Successful user agents:" -f $G, $RES)
                foreach ($ua in $Results) {
                    Write-Host ("{0}->{1} {2}" -f $B, $RES, $ua)
                }
            }
        } else {
            foreach ($ua in $Results) {
                Write-Host ("{0}->{1} {2}" -f $B, $RES, $ua)
            }
        }
    } catch {
        Write-Host ""
        Write-Host ("{0}[ERROR]{1} Program interrupted by user during output handling." -f $R, $RES)
        throw
    }
}

function Test-ProxyBypassArguments {
    param(
        [string[]]$UsedOptions,
        [switch]$List,
        [string]$Output,
        [string[]]$Browser,
        [string]$Platform,
        [string]$SpecificIds,
        [string]$UserAgent,
        [string]$UserAgentFile,
        [switch]$Uniq,
        [Nullable[int]]$Rate,
        [int]$TimeInterval,
        [string]$ProxyDetails,
        [string]$Target,
        [switch]$VerboseFlag
    )

    if ($List) {
        $allowed = @("List", "Output")
        foreach ($opt in $UsedOptions) {
            if ($allowed -notcontains $opt) {
                return [pscustomobject]@{
                    IsValid = $false
                    Message = ("{0}[INFO]{1} Option '-l' can only be combined with the '-O' option followed by a filename or used standalone." -f $B, $RES)
                }
            }
        }
    }

    if ($UserAgent) {
        $rateProvided = $UsedOptions -contains "Rate"
        $timeIntervalProvided = $UsedOptions -contains "TimeInterval"
        $proxyChanged = $UsedOptions -contains "ProxyDetails"
        $targetChanged = $UsedOptions -contains "Target"

        if (($UsedOptions -contains "Browser") -or (($UsedOptions -contains "Platform") -and $Platform -ne "all") -or ($UsedOptions -contains "SpecificIds") -or $List -or ($rateProvided -and $VerboseFlag) -or ($timeIntervalProvided -and $VerboseFlag) -or ($proxyChanged -and $VerboseFlag) -or ($targetChanged -and $VerboseFlag)) {
            return [pscustomobject]@{
                IsValid = $false
                Message = ("{0}[INFO]{1} The '-ua' option can only be used standalone." -f $B, $RES)
            }
        }
    }

    $secondaryOptionCount = 0
    if ($UsedOptions -contains "Browser") { $secondaryOptionCount++ }
    if (($UsedOptions -contains "Platform") -and $Platform -ne "all") { $secondaryOptionCount++ }
    if ($UsedOptions -contains "SpecificIds") { $secondaryOptionCount++ }
    if ($UsedOptions -contains "UserAgentFile") { $secondaryOptionCount++ }
    if ($Uniq) { $secondaryOptionCount++ }

    if ($secondaryOptionCount -gt 1) {
        return [pscustomobject]@{
            IsValid = $false
            Message = ("{0}[INFO]{1} You can't combine -P, -s, -B, -uq and -uf options together." -f $B, $RES)
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

function Invoke-ProxyBypass {
    [CmdletBinding()]
    param(
        [switch]$VerboseOutput,
        [Nullable[int]]$Rate,
        [int]$TimeInterval = 2,
        [string]$ProxyDetails = "127.0.0.1:8080",
        [string]$Target = "www.google.com",
        [string]$Output,
        [string[]]$Browser,
        [ValidateSet("mobile", "general", "all")]
        [string]$Platform = "all",
        [string]$SpecificIds,
        [string]$UserAgent,
        [string]$UserAgentFile,
        [switch]$List,
        [switch]$Uniq,
        [switch]$Help,
        [Parameter(DontShow = $true)]
        [string]$WorkingDirectory
    )

    if ($Help) {
        Show-Help
        return
    }

    if (-not $Browser) {
        $Browser = @()
    }

    $usedOptions = @($PSBoundParameters.Keys | ForEach-Object { $_.ToString() })

    $scriptDirectory = if ($WorkingDirectory) {
        $WorkingDirectory
    } elseif ($PSScriptRoot) {
        $PSScriptRoot
    } else {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }

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
        Write-Host ("{0}[INFO]{1} Check if user_agents.json is in the same directory as the script." -f $Y, $RES)
        Write-Host ("{0}[INFO]{1} you could also download from - https://github.com/Add3r/UserAgent-Fuzz-lib/blob/main/user_agents.json" -f $Y, $RES)
        throw "User agent file not found."
    }

    $validationResult = Test-ProxyBypassArguments -UsedOptions $usedOptions -List:$List -Output $Output -Browser $Browser -Platform $Platform -SpecificIds $SpecificIds -UserAgent $UserAgent -UserAgentFile $UserAgentFile -Uniq:$Uniq -Rate $Rate -TimeInterval $TimeInterval -ProxyDetails $ProxyDetails -Target $Target -VerboseFlag:$VerboseOutput

    if (-not $validationResult.IsValid) {
        Write-Host ("{0}[ERROR]{1} Invalid combination of options." -f $R, $RES)
        Write-Host $validationResult.Message
        throw "Invalid arguments."
    }

    $userAgents = Get-ProxyUserAgents -Path $userAgentPath
    $availableBrowserGroups = ($userAgents | ForEach-Object { Get-PropertyValue -Object $_ -PropertyName 'group' } | Where-Object { $_ } | Sort-Object -Unique)

    if ($Browser.Count -gt 0) {
        foreach ($browserName in $Browser) {
            if ($availableBrowserGroups -notcontains $browserName) {
                Write-Host ("{0}[ERROR]{1} Given browser group doesn't exist." -f $R, $RES)
                Write-Host ("{0}[INFO]{1} try proxy_bypass.ps1 -List and use one of the browsers." -f $B, $RES)
                throw "Invalid browser group."
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
            Write-Host ("{0}[INFO]{1} Output saved to {2} (Only successful results are saved)" -f $B, $RES, $Output)
        } else {
            Write-Host ("{0}Available Browser Groups:{1}" -f $B, $RES)
            foreach ($group in $browserGroups) {
                Write-Host ("{0}-{1} {2}" -f $B, $RES, $group)
            }
        }
        return
    }

    $script:SuccessCount = 0
    $script:DeniedCount = 0
    $script:SuccessfulUserAgents = [System.Collections.Generic.List[string]]::new()

    $cancelSubscription = $null
    try {
        Unregister-Event -SourceIdentifier ConsoleCancel -ErrorAction SilentlyContinue
        $cancelSubscription = Register-EngineEvent -SourceIdentifier ConsoleCancel -SupportEvent -Action {
            Write-Host ""
            Write-Host ("{0}[ERROR]{1} Program interrupted by user." -f $using:R, $using:RES)
            Stop-Event -SourceIdentifier ConsoleCancel
            exit 1
        }
    } catch {
        $cancelSubscription = $null
    }

    try {
        if ($UserAgent) {
            Test-SpecificUserAgent -Proxy $ProxyDetails -UserAgent $UserAgent -Target $Target
        } else {
            $filteredUserAgents = Select-ProxyUserAgents -UserAgents $userAgents -Browser $Browser -Platform $Platform -SpecificIds $SpecificIds -Uniq:$Uniq
            Test-UserAgentsBatch -UserAgents $filteredUserAgents -Proxy $ProxyDetails -VerboseOutput:$VerboseOutput -Target $Target -Rate $Rate -TimeInterval $TimeInterval
        }
    } finally {
        if ($cancelSubscription) {
            Unregister-Event -SubscriptionId $cancelSubscription.Id -ErrorAction SilentlyContinue
            Get-Event -SourceIdentifier ConsoleCancel -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
        }
    }

    if (-not $UserAgent) {
        $successful = @($userAgents | Where-Object {
            $uaString = Get-PropertyValue -Object $_ -PropertyName 'user-agent'
            $script:SuccessfulUserAgents -contains $uaString
        } | ForEach-Object { Get-PropertyValue -Object $_ -PropertyName 'user-agent' })

        Save-Results -Results $successful -OutputFile $Output
    }
}

Export-ModuleMember -Function Invoke-ProxyBypass
