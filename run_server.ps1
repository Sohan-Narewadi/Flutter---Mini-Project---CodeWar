<#
.SYNOPSIS
  Starts the CodeWar backend and (optionally) a public tunnel so friends can join your rooms.

.DESCRIPTION
  1. Creates backend\.venv and installs requirements on first run.
  2. Starts the API on 0.0.0.0:<Port>.
  3. Starts a free tunnel with cloudflared (preferred) or ngrok and prints the public URL.
  Friends enter that URL in the app (onboarding > Advanced, or Settings) and then join your
  room with its 6-character code. Press Ctrl+C to stop everything.

.PARAMETER Port      Port for the API (default 8000).
.PARAMETER NoTunnel  Skip the tunnel (same Wi-Fi / local play only).

.EXAMPLE
  .\run_server.ps1
  .\run_server.ps1 -NoTunnel
#>
param(
  [int]$Port = 8000,
  [switch]$NoTunnel,
  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path $root 'backend'
$py = Join-Path $backend '.venv\Scripts\python.exe'
$logDir = Join-Path ([System.IO.Path]::GetTempPath()) 'codewar-run'
New-Item -ItemType Directory -Force $logDir | Out-Null

if (-not (Test-Path $py)) {
  Write-Host 'Creating virtual environment and installing dependencies (first run)...'
  & python -m venv (Join-Path $backend '.venv')
  & $py -m pip install --quiet -r (Join-Path $backend 'requirements.txt')
}

if (-not $env:ANTHROPIC_API_KEY) {
  Write-Host 'Note: ANTHROPIC_API_KEY is not set, so new problems come from the built-in generator only.'
}

$procs = @()
try {
  $api = Start-Process -FilePath $py -PassThru -WindowStyle Hidden -WorkingDirectory $backend `
    -ArgumentList @('-m', 'uvicorn', 'app.main:app', '--host', '0.0.0.0', '--port', $Port, '--log-level', 'warning') `
    -RedirectStandardError (Join-Path $logDir 'api.err.log') -RedirectStandardOutput (Join-Path $logDir 'api.out.log')
  $procs += $api

  $healthy = $false
  for ($i = 0; $i -lt 40; $i++) {
    try {
      Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
      $healthy = $true
      break
    } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $healthy) {
    Write-Host "The API did not start. See $logDir\api.err.log" -ForegroundColor Red
    exit 1
  }
  Write-Host ''
  Write-Host "CodeWar running:  http://127.0.0.1:$Port   (web app + API)" -ForegroundColor Green
  if (-not (Test-Path (Join-Path $root 'frontend/codewar/build/web/index.html'))) {
    Write-Host '  (web app not built yet: run  flutter build web  inside frontend\codewar, then restart this script)' -ForegroundColor Yellow
  }
  Write-Host '  Android emulator: http://10.0.2.2:' -NoNewline; Write-Host $Port
  $lan = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress
  foreach ($ip in $lan) { Write-Host "  Same Wi-Fi:       http://${ip}:$Port" }

  if (-not $NoOpen) { Start-Process "http://127.0.0.1:$Port" }

  $publicUrl = $null
  if (-not $NoTunnel) {
    $cf = Get-Command cloudflared -ErrorAction SilentlyContinue
    $ng = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($cf) {
      $errLog = Join-Path $logDir 'tunnel.err.log'
      Remove-Item $errLog -ErrorAction SilentlyContinue
      $t = Start-Process -FilePath $cf.Source -PassThru -WindowStyle Hidden `
        -ArgumentList @('tunnel', '--url', "http://localhost:$Port") `
        -RedirectStandardError $errLog -RedirectStandardOutput (Join-Path $logDir 'tunnel.out.log')
      $procs += $t
      for ($i = 0; $i -lt 60 -and -not $publicUrl; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Path $errLog) {
          $m = Select-String -Path $errLog -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue | Select-Object -First 1
          if ($m) { $publicUrl = $m.Matches[0].Value }
        }
      }
    } elseif ($ng) {
      $t = Start-Process -FilePath $ng.Source -PassThru -WindowStyle Hidden -ArgumentList @('http', $Port) `
        -RedirectStandardOutput (Join-Path $logDir 'ngrok.out.log') -RedirectStandardError (Join-Path $logDir 'ngrok.err.log')
      $procs += $t
      for ($i = 0; $i -lt 40 -and -not $publicUrl; $i++) {
        Start-Sleep -Milliseconds 500
        try {
          $tunnels = Invoke-RestMethod 'http://127.0.0.1:4040/api/tunnels' -TimeoutSec 2
          $publicUrl = ($tunnels.tunnels | Where-Object { $_.public_url -like 'https://*' } | Select-Object -First 1).public_url
        } catch { }
      }
    } else {
      Write-Host ''
      Write-Host 'No tunnel tool found. Install one of these, then run this script again:' -ForegroundColor Yellow
      Write-Host '  winget install Cloudflare.cloudflared      (free, no account needed)'
      Write-Host '  winget install ngrok.ngrok                 (free account + authtoken needed)'
      Write-Host 'Or use -NoTunnel for same-Wi-Fi play with the addresses above.'
    }
  }

  if ($publicUrl) {
    Write-Host ''
    Write-Host "PUBLIC URL (share with friends): $publicUrl" -ForegroundColor Cyan
    Write-Host 'In the app: onboarding > Advanced > Server URL (or Settings), paste it, then join your room code.'
    Set-Clipboard -Value $publicUrl -ErrorAction SilentlyContinue
    Write-Host '(copied to clipboard)'
  } elseif (-not $NoTunnel) {
    Write-Host 'Tunnel did not report a URL. Check the logs in' $logDir -ForegroundColor Yellow
  }

  Write-Host ''
  Write-Host 'Press Ctrl+C to stop.'
  while ($true) {
    if ($api.HasExited) { Write-Host 'The API stopped unexpectedly.' -ForegroundColor Red; break }
    Start-Sleep -Seconds 2
  }
}
finally {
  foreach ($p in $procs) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  }
}
