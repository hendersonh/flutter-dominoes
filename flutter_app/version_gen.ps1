$timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$versionJson = '{"version": "' + $timestamp + '"}'
$versionJson | Out-File -FilePath "$PSScriptRoot/web/version.json" -Encoding utf8
Write-Output "Generated $PSScriptRoot/web/version.json with version: $timestamp"

