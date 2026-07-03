param(
    [int]$Port = 8001
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force

$matches = Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -and
        ($_.CommandLine -like "*windows_mcp*" -or $_.CommandLine -like "*windows-mcp*") -and
        $_.CommandLine -like "*serve*" -and
        $_.CommandLine -like "*--port*" -and
        $_.CommandLine -like "*$Port*"
    }

foreach ($process in $matches) {
    Stop-Process -Id $process.ProcessId -Force
}

Write-Host "Stopped ngrok and Windows-MCP demo process on port $Port if they were running."
