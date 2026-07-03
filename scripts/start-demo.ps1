param(
    [int]$Port = 8002,
    [string]$HostName = "127.0.0.1",
    [string]$WindowsMcpPath = "",
    [string]$NgrokPath = "",
    [int]$ProxyPort = 0,
    [double]$ScreenshotScale = 0.5,
    [switch]$NoAcceptProxy,
    [switch]$SkipVerify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-Executable {
    param(
        [string]$Name,
        [string]$ExplicitPath
    )

    if ($ExplicitPath) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        return $resolved.Path
    }

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Resolve-Ngrok {
    if ($NgrokPath) {
        return (Resolve-Path -LiteralPath $NgrokPath -ErrorAction Stop).Path
    }

    $fromPath = Resolve-Executable -Name "ngrok" -ExplicitPath ""
    if ($fromPath) {
        return $fromPath
    }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $wingetRoot) {
        $candidate = Get-ChildItem $wingetRoot -Recurse -Filter ngrok.exe -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "ngrok.exe was not found. Install ngrok and run: ngrok config add-authtoken YOUR_TOKEN"
}

function Wait-For-Port {
    param(
        [int]$WaitPort,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $conn = Get-NetTCPConnection -LocalPort $WaitPort -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq "Listen" } |
            Select-Object -First 1
        if ($conn) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Wait-For-NgrokTunnel {
    param([int]$TimeoutSeconds = 30)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3
            $tunnel = $response.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
            if ($tunnel) {
                return $tunnel.public_url
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    throw "ngrok did not expose a tunnel. Check .run\ngrok.error.log and your ngrok authtoken."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $repoRoot ".run"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

if ($ProxyPort -eq 0) {
    $ProxyPort = $Port + 1
}

$existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq "Listen" } |
    Select-Object -First 1
if ($existing) {
    throw "Port $Port is already in use by process $($existing.OwningProcess). Run .\scripts\stop-demo.ps1 or choose another port."
}

if (-not $NoAcceptProxy) {
    $existingProxy = Get-NetTCPConnection -LocalPort $ProxyPort -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Listen" } |
        Select-Object -First 1
    if ($existingProxy) {
        throw "Proxy port $ProxyPort is already in use by process $($existingProxy.OwningProcess). Run .\scripts\stop-demo.ps1 or choose another proxy port."
    }
}

$noAuthConfig = Join-Path $runDir "windows-mcp-no-auth.toml"
@"
[server]
transport = "streamable-http"
host = "$HostName"
port = $Port
"@ | Set-Content -LiteralPath $noAuthConfig -Encoding UTF8

$env:WINDOWS_MCP_SCREENSHOT_SCALE = [string]$ScreenshotScale
$env:ANONYMIZED_TELEMETRY = "false"
Remove-Item Env:\WINDOWS_MCP_AUTH_KEY -ErrorAction SilentlyContinue

if ($WindowsMcpPath) {
    $resolvedWindowsMcpPath = (Resolve-Path -LiteralPath $WindowsMcpPath -ErrorAction Stop).Path
    $uv = Resolve-Executable -Name "uv" -ExplicitPath ""
    if (-not $uv) {
        throw "uv was not found on PATH."
    }
    $serverExe = $uv
    $serverArgs = @(
        "--directory", $resolvedWindowsMcpPath,
        "run", "--python", "3.13",
        "windows-mcp", "serve",
        "--config", $noAuthConfig,
        "--transport", "streamable-http",
        "--host", $HostName,
        "--port", [string]$Port
    )
} else {
    $uvx = Resolve-Executable -Name "uvx" -ExplicitPath ""
    if (-not $uvx) {
        throw "uvx was not found on PATH."
    }
    $serverExe = $uvx
    $serverArgs = @(
        "windows-mcp", "serve",
        "--config", $noAuthConfig,
        "--transport", "streamable-http",
        "--host", $HostName,
        "--port", [string]$Port
    )
}

$serverOut = Join-Path $runDir "windows-mcp.log"
$serverErr = Join-Path $runDir "windows-mcp.error.log"
$serverProcess = Start-Process -FilePath $serverExe -ArgumentList $serverArgs `
    -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr `
    -WindowStyle Hidden -PassThru

if (-not (Wait-For-Port -WaitPort $Port -TimeoutSeconds 45)) {
    throw "Windows-MCP did not start on port $Port. Check $serverErr"
}

$proxyProcess = $null
if (-not $NoAcceptProxy) {
    $uvForProxy = Resolve-Executable -Name "uv" -ExplicitPath ""
    if (-not $uvForProxy) {
        throw "uv was not found on PATH."
    }

    $proxyScript = Join-Path $PSScriptRoot "mcp_accept_proxy.py"
    $proxyOut = Join-Path $runDir "mcp-accept-proxy.log"
    $proxyErr = Join-Path $runDir "mcp-accept-proxy.error.log"
    $proxyArgs = @(
        "run", "--python", "3.13",
        "python", $proxyScript,
        "--listen-host", $HostName,
        "--listen-port", [string]$ProxyPort,
        "--target-host", $HostName,
        "--target-port", [string]$Port
    )
    $proxyProcess = Start-Process -FilePath $uvForProxy -ArgumentList $proxyArgs `
        -RedirectStandardOutput $proxyOut -RedirectStandardError $proxyErr `
        -WindowStyle Hidden -PassThru

    if (-not (Wait-For-Port -WaitPort $ProxyPort -TimeoutSeconds 30)) {
        throw "MCP accept proxy did not start on port $ProxyPort. Check $proxyErr"
    }
}

$ngrokExe = Resolve-Ngrok
$ngrokOut = Join-Path $runDir "ngrok.log"
$ngrokErr = Join-Path $runDir "ngrok.error.log"

Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$ngrokPort = if ($NoAcceptProxy) { $Port } else { $ProxyPort }
$upstream = "http://$HostName`:$ngrokPort"
$ngrokArgs = @(
    "http", $upstream,
    "--host-header=$HostName`:$ngrokPort",
    "--log=stdout"
)
$ngrokProcess = Start-Process -FilePath $ngrokExe -ArgumentList $ngrokArgs `
    -RedirectStandardOutput $ngrokOut -RedirectStandardError $ngrokErr `
    -WindowStyle Hidden -PassThru

$publicUrl = Wait-For-NgrokTunnel -TimeoutSeconds 45
$mcpUrl = "$publicUrl/mcp"

Write-Host ""
Write-Host "Windows-MCP process: $($serverProcess.Id)"
if ($proxyProcess) {
    Write-Host "Accept proxy process: $($proxyProcess.Id)"
}
Write-Host "ngrok process:       $($ngrokProcess.Id)"
Write-Host ""
Write-Host "ChatGPT MCP URL:"
Write-Host $mcpUrl
Write-Host ""
Write-Host "ChatGPT settings:"
Write-Host "Protocol: Streamable HTTP"
Write-Host "Authentication: No Authentication"
if ($proxyProcess) {
    Write-Host "Compatibility: Missing Accept headers are normalized before Windows-MCP"
}
Write-Host ""
Write-Host "Stop with:"
Write-Host ".\scripts\stop-demo.ps1 -Port $Port"
Write-Host ""

if (-not $SkipVerify) {
    try {
        $verifyScript = Join-Path $PSScriptRoot "verify_mcp.py"
        & uv run --with fastmcp python $verifyScript $mcpUrl
    } catch {
        Write-Warning "Verification failed. Try manually: uv run --with fastmcp python .\scripts\verify_mcp.py $mcpUrl"
    }
}
