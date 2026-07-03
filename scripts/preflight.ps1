param(
    [string]$WindowsMcpPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$failed = $false

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = ""
    )

    if ($Ok) {
        Write-Host "[OK]   $Name $Detail"
    } else {
        Write-Host "[FAIL] $Name $Detail"
        $script:failed = $true
    }
}

function Resolve-Tool {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Resolve-Ngrok {
    $fromPath = Resolve-Tool -Name "ngrok"
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

    return $null
}

Push-Location $repoRoot
try {
    $uv = Resolve-Tool -Name "uv"
    Write-Check "uv installed" ([bool]$uv) $(if ($uv) { "($uv)" } else { "Install from https://docs.astral.sh/uv/" })

    $uvx = Resolve-Tool -Name "uvx"
    Write-Check "uvx installed" ([bool]$uvx) $(if ($uvx) { "($uvx)" } else { "uv should provide uvx on PATH" })

    $ngrok = Resolve-Ngrok
    Write-Check "ngrok installed" ([bool]$ngrok) $(if ($ngrok) { "($ngrok)" } else { "Install from https://ngrok.com/download" })

    $git = Resolve-Tool -Name "git"
    Write-Check "git installed" ([bool]$git) $(if ($git) { "($git)" } else { "Install Git for Windows" })

    if ($WindowsMcpPath) {
        Write-Check "Windows-MCP path exists" (Test-Path -LiteralPath $WindowsMcpPath) "($WindowsMcpPath)"
    } else {
        Write-Host "[INFO] Windows-MCP path not supplied; start-demo.ps1 will use uvx/PyPI."
    }

    if ($ngrok) {
        try {
            $version = & $ngrok version 2>$null
            Write-Host "[INFO] $version"
        } catch {
            Write-Host "[INFO] Could not read ngrok version."
        }
    }

    $tracked = @()
    if ($git) {
        $tracked = & git ls-files
    }
    if (-not $tracked -or $tracked.Count -eq 0) {
        $tracked = Get-ChildItem -Recurse -File |
            Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\.run\*" } |
            ForEach-Object { Resolve-Path -Relative $_.FullName }
    }

    $secretPatterns = @(
        "sk-[A-Za-z0-9_-]{20,}",
        "ghp_[A-Za-z0-9_]{20,}",
        "github_pat_[A-Za-z0-9_]{20,}",
        "xox[baprs]-[A-Za-z0-9-]{20,}",
        "AKIA[0-9A-Z]{16}",
        "(?i)(api[_-]?key|secret|password|passwd|token|authtoken)\s*[:=]\s*['""]?[A-Za-z0-9_./+=-]{20,}"
    )

    $findings = @()
    foreach ($file in $tracked) {
        if (-not (Test-Path -LiteralPath $file)) {
            continue
        }
        $content = Get-Content -Raw -LiteralPath $file -ErrorAction SilentlyContinue
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                $findings += "$file matches $pattern"
            }
        }
    }

    Write-Check "secret scan" ($findings.Count -eq 0) $(if ($findings.Count -eq 0) { "(tracked files only)" } else { "found $($findings.Count) possible issue(s)" })
    foreach ($finding in $findings) {
        Write-Host "       $finding"
    }

    if ($failed) {
        exit 1
    }

    Write-Host ""
    Write-Host "Preflight passed. Start with:"
    Write-Host ".\scripts\start-demo.ps1 -WindowsMcpPath ..\Windows-MCP"
} finally {
    Pop-Location
}
