#Requires -Version 7.3
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../Powershell/ProxyBypass.psm1" -Force
& (Get-Module ProxyBypass) {
    function Invoke-CurlRequest {
        param([string[]]$Arguments)
        $script:TestArguments = $Arguments
        return '204'
    }
    $script:TestArguments = $null
    $result = Invoke-UserAgentRequest -Proxy 'localhost:8080' -UserAgent '$(whoami); quoted' -Target 'example.test'
    if ($result -ne '204') { throw 'Expected status code' }
    $a = $script:TestArguments
    if ($a[0] -ne '-q' -or $a[-2] -ne '--url' -or $a[-1] -ne 'https://example.test') { throw 'Unsafe curl arguments' }
    if ($a[[Array]::IndexOf($a, '--noproxy') + 1] -ne '') { throw 'NO_PROXY must not bypass selected proxy' }
    $script:TestArguments = $null
    foreach ($ua in @("UA`r`nInjected: true", "UA$([char]0)")) {
        if ((Invoke-UserAgentRequest 'localhost:8080' $ua 'example.test') -ne '') { throw 'Unsafe header accepted' }
    }
    foreach ($target in @('--config=/tmp/test', 'file:///etc/passwd', "https://example.test/`n")) {
        if ((Invoke-UserAgentRequest 'localhost:8080' 'UA' $target) -ne '') { throw 'Unsafe URL accepted' }
    }
    if ($null -ne $script:TestArguments) { throw 'Invalid request reached curl' }
}
Write-Host 'PowerShell request validation passed.'
