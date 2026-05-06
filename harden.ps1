#Requires -RunAsAdministrator
<#
.SYNOPSIS
  bastion-script — Windows Server VPS hardening, in one PowerShell file.

.DESCRIPTION
  Battle-tested hardening for fresh Windows Server VPS deployments. Encodes
  the safety-net pattern (verify before tightening) so you don't lock
  yourself out. Tested on Windows Server 2016/2019/2022/2025.

.LINK
  https://github.com/kastlevps/bastion-script
  https://kastlevps.com

.NOTES
  Run this in an ELEVATED PowerShell session on a fresh Windows Server VPS.
  Take a provider snapshot BEFORE running on a server you care about.
#>

# ============================================================================
#  bastion-script
#  Windows Server hardening — version 1.0.0
#  https://github.com/kastlevps/bastion-script
# ============================================================================

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

# ----- Console helpers ------------------------------------------------------

function Write-Banner {
  Clear-Host
  Write-Host ""
  Write-Host "  ============================================================" -ForegroundColor Cyan
  Write-Host "    bastion-script — Windows Server VPS hardening (v1.0.0)" -ForegroundColor Cyan
  Write-Host "    https://github.com/kastlevps/bastion-script" -ForegroundColor DarkCyan
  Write-Host "  ============================================================" -ForegroundColor Cyan
  Write-Host ""
}

function Write-Section($title) {
  Write-Host ""
  Write-Host "── $title " -NoNewline -ForegroundColor Yellow
  Write-Host ('─' * (60 - $title.Length)) -ForegroundColor DarkGray
}

function Write-Step($msg)    { Write-Host "  → $msg" -ForegroundColor White }
function Write-OK($msg)      { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-ErrMsg($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info($msg)    { Write-Host "    $msg" -ForegroundColor DarkGray }

function Confirm-Action($prompt) {
  Write-Host ""
  $resp = Read-Host "  $prompt [y/N]"
  return ($resp -eq 'y' -or $resp -eq 'Y' -or $resp -eq 'yes')
}

# ----- Pre-flight checks ----------------------------------------------------

function Test-PreFlight {
  Write-Section "Pre-flight checks"

  # Admin check
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    Write-ErrMsg "Not running as Administrator. Re-launch PowerShell as Admin."
    return $false
  }
  Write-OK "Running as Administrator"

  # OS check
  $os = Get-CimInstance Win32_OperatingSystem
  Write-OK "OS: $($os.Caption)"
  if ($os.Caption -notmatch 'Windows Server') {
    Write-Warn "This script is tuned for Windows Server. Some sections will be skipped on desktop SKUs."
  }

  # Network check
  try {
    $null = Test-NetConnection -ComputerName "1.1.1.1" -Port 53 -InformationLevel Quiet -ErrorAction Stop
    Write-OK "Network connectivity confirmed"
  } catch {
    Write-Warn "Could not verify outbound connectivity. Some downloads may fail."
  }

  return $true
}

# ----- Configuration prompts ------------------------------------------------

function Get-Configuration {
  Write-Section "Configuration"

  $config = @{}

  # 1. Public IP
  Write-Step "Auto-detecting your public IP via ifconfig.me..."
  $detectedIp = $null
  try {
    $detectedIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    Write-Info "Detected: $detectedIp"
  } catch {
    Write-Warn "Auto-detection failed. You'll need to enter it manually."
  }

  $ipPrompt = if ($detectedIp) { "Your public IP [$detectedIp]" } else { "Your public IP (e.g., 203.0.113.45)" }
  $myIp = Read-Host "  $ipPrompt"
  if ([string]::IsNullOrWhiteSpace($myIp)) { $myIp = $detectedIp }
  if ([string]::IsNullOrWhiteSpace($myIp) -or $myIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    Write-ErrMsg "Invalid IP. Aborting."
    return $null
  }
  $config.MyIP = $myIp

  # 2. New admin username
  $defaultAdmin = "vpsadmin"
  $adminName = Read-Host "  New admin username [$defaultAdmin]"
  if ([string]::IsNullOrWhiteSpace($adminName)) { $adminName = $defaultAdmin }
  if ($adminName -ieq "Administrator") {
    Write-ErrMsg "Refusing to use 'Administrator' as the new admin name (most-attacked username globally)."
    return $null
  }
  $config.AdminName = $adminName

  # 3. RDP port
  $defaultPort = Get-Random -Minimum 49152 -Maximum 65535
  $portStr = Read-Host "  New RDP port [$defaultPort]"
  if ([string]::IsNullOrWhiteSpace($portStr)) { $port = $defaultPort } else { $port = [int]$portStr }
  if ($port -lt 1024 -or $port -gt 65535) {
    Write-ErrMsg "Port out of valid range (1024-65535)."
    return $null
  }
  $config.RDPPort = $port

  # 4. Workload type
  Write-Host ""
  Write-Host "  Workload profile:"
  Write-Host "    1) trading   — Defender exclusions for MT4/MT5, NinjaTrader, etc."
  Write-Host "    2) web       — Allow HTTP/HTTPS inbound"
  Write-Host "    3) general   — Generic VPS, no special exclusions"
  $workChoice = Read-Host "  Choose [1-3, default 3]"
  $config.Workload = switch ($workChoice) { "1" {"trading"} "2" {"web"} default {"general"} }

  # Summary
  Write-Host ""
  Write-Host "  Configuration summary:" -ForegroundColor Cyan
  Write-Host "    Public IP:      $($config.MyIP)" -ForegroundColor White
  Write-Host "    New admin:      $($config.AdminName)" -ForegroundColor White
  Write-Host "    RDP port:       $($config.RDPPort)" -ForegroundColor White
  Write-Host "    Workload:       $($config.Workload)" -ForegroundColor White

  if (-not (Confirm-Action "Proceed with hardening?")) {
    Write-Warn "Aborted by user."
    return $null
  }

  return $config
}

# ----- Account hygiene ------------------------------------------------------

function Set-AccountHygiene($config) {
  Write-Section "Account hygiene"

  $adminName = $config.AdminName

  # Create new admin if doesn't exist
  $exists = (net user 2>$null | Out-String) -match "\b$adminName\b"
  if ($exists) {
    Write-Warn "Account '$adminName' already exists — skipping creation."
  } else {
    Write-Step "Creating account '$adminName'..."
    Write-Info "You'll be prompted for a password TWICE. Use 14+ chars, mix of cases/digits/symbols."
    Write-Info "Save the password in your password manager BEFORE typing it here."
    Write-Host ""
    $result = net user $adminName * /add /fullname:"VPS Admin" /passwordchg:no 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-ErrMsg "Account creation failed. Password likely didn't meet policy. Check password requirements and re-run."
      Write-Info ($result | Out-String)
      return $false
    }
    net localgroup Administrators $adminName /add 2>&1 | Out-Null
    Write-OK "Account '$adminName' created and added to Administrators"

    # Set "password never expires" via ADSI (cross-version compatible)
    try {
      $user = [ADSI]"WinNT://./$adminName,user"
      $user.UserFlags.value = $user.UserFlags.value -bor 0x10000
      $user.SetInfo()
      Write-OK "Password set to never expire"
    } catch {
      Write-Warn "Could not set password-never-expires via ADSI. Set manually in Computer Management."
    }
  }

  # Disable built-in unused accounts (but NOT Administrator yet — gated below)
  $accountsToDisable = @("Guest", "DefaultAccount")
  foreach ($acct in $accountsToDisable) {
    if ((net user 2>$null | Out-String) -match "\b$acct\b") {
      net user $acct /active:no 2>&1 | Out-Null
      Write-OK "Disabled built-in account: $acct"
    }
  }

  # Cloud-provider provisioning accounts (Cloudbase-Init etc.)
  $cloudAccounts = @("cloudbase-admin", "cloudbase-init")
  foreach ($acct in $cloudAccounts) {
    if ((net user 2>$null | Out-String) -match "\b$acct\b") {
      if (Confirm-Action "Disable cloud provisioning account '$acct'? (Safe — only used at first boot)") {
        net user $acct /active:no 2>&1 | Out-Null
        Write-OK "Disabled: $acct"
      }
    }
  }

  return $true
}

function Set-PasswordPolicy {
  Write-Section "Password & lockout policy"

  Write-Step "5 failed logons → 30 min lockout, min password 14 chars, max age 90 days"
  net accounts /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:30 2>&1 | Out-Null
  net accounts /minpwlen:14 /maxpwage:90 2>&1 | Out-Null
  Write-OK "Policies applied"
}

# ----- RDP hardening --------------------------------------------------------

function Set-RDPHardening($config) {
  Write-Section "RDP hardening"

  $myIp = $config.MyIP
  $newPort = $config.RDPPort

  # 1. Add allow rule for new port BEFORE doing anything else (safety net)
  Write-Step "Adding allow rule for $myIp on new port $newPort (safety net)..."
  Get-NetFirewallRule -DisplayName "bastion-RDP-$newPort" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName "bastion-RDP-$newPort" -Direction Inbound -Protocol TCP -LocalPort $newPort -RemoteAddress $myIp -Action Allow -Profile Any | Out-Null
  Write-OK "Allow rule added: TCP/$newPort from $myIp"

  # 2. Restrict default RDP rules to user's IP only (DON'T disable yet)
  Write-Step "Restricting default RDP rules (port 3389) to $myIp..."
  Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue |
    Get-NetFirewallAddressFilter |
    Set-NetFirewallAddressFilter -RemoteAddress $myIp
  Write-OK "Default RDP rules now restricted to your IP"

  # 3. Move RDP port in registry
  Write-Step "Setting RDP port to $newPort in registry..."
  Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name PortNumber -Value $newPort
  Write-OK "Registry updated"

  # 4. Force TermService to Automatic (default Manual causes lockouts after reboot)
  Write-Step "Setting TermService startup to Automatic..."
  Set-Service TermService -StartupType Automatic
  Write-OK "TermService = Automatic"

  # 5. Verify NLA enabled
  Write-Step "Verifying Network Level Authentication..."
  try {
    $nla = Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'"
    if ($nla.UserAuthenticationRequired -ne 1) {
      $nla.SetUserAuthenticationRequired(1) | Out-Null
      Write-OK "NLA enabled"
    } else {
      Write-OK "NLA already enabled"
    }
  } catch {
    Write-Warn "Could not verify NLA. Check Remote Desktop settings manually."
  }

  Write-Host ""
  Write-Warn "⚠ Reboot required for new RDP port to take effect."
  Write-Warn "⚠ AFTER reboot, RDP to: <server-ip>:$newPort as $($config.AdminName)"
  Write-Warn "⚠ Old port 3389 still works from your IP as fallback until you confirm new port works."
}

# ----- Defender tuning ------------------------------------------------------

function Set-DefenderTuning($config) {
  Write-Section "Defender tuning"

  Write-Step "Performance tuning..."
  Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
  Set-MpPreference -DisableRemovableDriveScanning $true -ErrorAction SilentlyContinue
  Set-MpPreference -EnableLowCpuPriority $true -ErrorAction SilentlyContinue
  Set-MpPreference -ScanAvgCPULoadFactor 25 -ErrorAction SilentlyContinue
  Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
  Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
  Set-MpPreference -ScanScheduleDay 0 -ScanScheduleTime 04:00:00 -ErrorAction SilentlyContinue
  Write-OK "Tuned for low-CPU operation; full scan scheduled 4 AM daily"

  # Workload-specific exclusions
  $exclusionPaths = @()
  $exclusionProcs = @()

  switch ($config.Workload) {
    "trading" {
      $exclusionPaths = @(
        "C:\Program Files\MetaTrader 5",
        "C:\Program Files (x86)\MetaTrader 4",
        "C:\Program Files\NinjaTrader 8",
        "C:\MT5",
        "C:\MT4",
        "C:\Users\$($config.AdminName)\AppData\Roaming\MetaQuotes",
        "C:\ProgramData\MetaQuotes"
      )
      $exclusionProcs = @("terminal64.exe", "metaeditor64.exe", "terminal.exe", "metaeditor.exe", "NinjaTrader.exe")
      Write-Step "Adding trading-platform exclusions..."
    }
    "web" {
      $exclusionPaths = @("C:\inetpub\wwwroot")
      Write-Step "Adding web-server exclusions..."
    }
    default {
      Write-Step "No workload-specific exclusions (general profile)"
    }
  }

  foreach ($p in $exclusionPaths) { Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue }
  foreach ($p in $exclusionProcs) { Add-MpPreference -ExclusionProcess $p -ErrorAction SilentlyContinue }
  if ($exclusionPaths.Count -gt 0) { Write-OK "$($exclusionPaths.Count) path exclusions applied" }
  if ($exclusionProcs.Count -gt 0) { Write-OK "$($exclusionProcs.Count) process exclusions applied" }
}

# ----- Service trim ---------------------------------------------------------

function Disable-UnneededServices {
  Write-Section "Service trim"

  $standardDisable = @(
    "XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc",  # Xbox (yes, on Server)
    "DiagTrack",                                                       # Connected User Experiences and Telemetry
    "MapsBroker",                                                      # Maps
    "WSearch",                                                         # Windows Search indexer
    "Fax", "PrintNotify",                                              # Print/Fax
    "TabletInputService",                                              # Tablet PC
    "WerSvc",                                                          # Windows Error Reporting
    "WMPNetworkSvc",                                                   # WMP Network Sharing
    "RetailDemo",                                                      # Retail demo
    "PcaSvc",                                                          # Program Compatibility Assistant
    "SysMain"                                                          # SuperFetch (useless on SSD/server)
  )

  $disabled = 0
  foreach ($svc in $standardDisable) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
      Stop-Service $svc -Force -ErrorAction SilentlyContinue
      Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
      $disabled++
    }
  }
  Write-OK "Disabled $disabled unneeded services"
}

# ----- Firewall lockdown ----------------------------------------------------

function Set-FirewallLockdown {
  Write-Section "Firewall lockdown — disable unneeded inbound rules"

  $patterns = @(
    @{Name="OpenSSH";              Match="OpenSSH"},
    @{Name="WinRM";                Match="Windows Remote Management|WinRM"},
    @{Name="Delivery Optimization"; Match="Delivery Optimization"},
    @{Name="Cast to Device";       Match="Cast to Device|Wireless Display|Microsoft Media Foundation"},
    @{Name="mDNS";                 Match="mDNS"},
    @{Name="AllJoyn";              Match="AllJoyn"},
    @{Name="Microsoft Edge";       Match="Microsoft Edge"}
  )

  foreach ($p in $patterns) {
    $matched = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $p.Match }
    if ($matched) {
      $matched | Disable-NetFirewallRule -ErrorAction SilentlyContinue
      Write-OK "Disabled rules matching: $($p.Name)"
    }
  }

  # Also disable WinRM service since we're locking down its firewall
  Stop-Service WinRM -ErrorAction SilentlyContinue
  Set-Service WinRM -StartupType Disabled -ErrorAction SilentlyContinue

  # SSH service if present
  if (Get-Service sshd -ErrorAction SilentlyContinue) {
    Stop-Service sshd -ErrorAction SilentlyContinue
    Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue
    Write-OK "Disabled OpenSSH service"
  }
}

# ----- Block known-bad IPs --------------------------------------------------

function Block-KnownBadIPs {
  Write-Section "Block known brute-force source IPs"

  # Subset of IPs observed actively brute-forcing during the original incident
  $badIps = @(
    "3.65.40.162",
    "45.133.195.186",
    "216.24.213.226",
    "158.173.154.150",
    "181.215.65.0/24",   # known botnet range
    "45.131.194.160"
  )

  Get-NetFirewallRule -DisplayName "bastion-Block-Known-Attackers" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName "bastion-Block-Known-Attackers" -Direction Inbound -Action Block -RemoteAddress $badIps -ErrorAction SilentlyContinue | Out-Null
  Write-OK "Blocked $($badIps.Count) known attacker IPs/ranges"
  Write-Info "(These are seed IPs — install IPBan for ongoing dynamic blocking)"
}

# ----- IPBan installation prompt --------------------------------------------

function Install-IPBan {
  Write-Section "IPBan (defense in depth)"

  if (Get-Service IPBAN -ErrorAction SilentlyContinue) {
    Write-OK "IPBan already installed"
    return
  }

  if (-not (Confirm-Action "Install IPBan? (Auto-bans IPs after 5 failed login attempts)")) {
    Write-Info "Skipped — install later from https://github.com/DigitalRuby/IPBan/releases"
    return
  }

  $url = "https://github.com/DigitalRuby/IPBan/releases/latest/download/IPBan-Windows-x64.zip"
  $zip = "$env:TEMP\IPBan.zip"
  $dst = "C:\IPBan"

  try {
    Write-Step "Downloading IPBan..."
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if (-not (Test-Path $dst)) { New-Item -Path $dst -ItemType Directory -Force | Out-Null }
    Expand-Archive -Path $zip -DestinationPath $dst -Force
    Remove-Item $zip -Force

    $exe = Get-ChildItem -Path $dst -Recurse -Filter "DigitalRuby.IPBan.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
      Write-ErrMsg "IPBan binary not found after extract — check $dst manually"
      return
    }

    Write-Step "Installing as Windows service..."
    & sc.exe create IPBAN type= own start= auto binPath= "`"$($exe.FullName)`"" DisplayName= "IPBan Service" | Out-Null
    & sc.exe description IPBAN "Auto-bans IPs after failed login attempts" | Out-Null
    & sc.exe failure IPBAN reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
    Start-Service IPBAN
    Write-OK "IPBan installed and running"
  } catch {
    Write-ErrMsg "IPBan install failed: $($_.Exception.Message)"
    Write-Info "Install manually from $url"
  }
}

# ----- Tailscale install (with the critical --unattended flag) --------------

function Install-Tailscale {
  Write-Section "Tailscale mesh network (optional)"

  Write-Info "Tailscale lets you reach this server via a private 100.x.x.x IP,"
  Write-Info "removing public RDP entirely once verified working after reboot."

  if (Get-Service Tailscale -ErrorAction SilentlyContinue) {
    Write-OK "Tailscale already installed"
  } else {
    if (-not (Confirm-Action "Install Tailscale?")) {
      Write-Info "Skipped"
      return
    }
    Write-Step "Downloading and installing Tailscale..."
    try {
      $msi = "$env:TEMP\tailscale.msi"
      Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.msi" -OutFile $msi -UseBasicParsing
      Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait
      Remove-Item $msi -Force
      Write-OK "Tailscale installed"
    } catch {
      Write-ErrMsg "Install failed: $($_.Exception.Message)"
      return
    }
  }

  Write-Host ""
  Write-Warn "CRITICAL: Tailscale must be brought up with --unattended flag,"
  Write-Warn "or it WON'T auto-reconnect after reboot (causing lockout)."
  Write-Host ""
  Write-Step "Run this command after the script finishes:"
  Write-Host ""
  Write-Host "    & ""C:\Program Files\Tailscale\tailscale.exe"" up --unattended" -ForegroundColor Cyan
  Write-Host ""
  Write-Step "Then verify: 'tailscale status' should show your VPS connected."
  Write-Step "Verify 'WantRunning: true' in 'tailscale debug prefs'."
  Write-Step "Then REBOOT and confirm Tailscale RDP still works before disabling public RDP."
}

# ----- Final summary --------------------------------------------------------

function Write-Summary($config) {
  Write-Section "Hardening complete"

  Write-Host ""
  Write-Host "  Next steps (in this order):" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  1. " -NoNewline
  Write-Host "Take a snapshot of this VPS via your provider panel" -ForegroundColor White
  Write-Host "     Name it: clean-hardened-$(Get-Date -Format 'yyyy-MM-dd')"
  Write-Host ""
  Write-Host "  2. " -NoNewline
  Write-Host "Restart-Computer -Force" -ForegroundColor Yellow
  Write-Host "     Then RDP back in via:"
  Write-Host "       <server-ip>:$($config.RDPPort) as $($config.AdminName)" -ForegroundColor White
  Write-Host "       (or via Tailscale 100.x.x.x:$($config.RDPPort) if installed)"
  Write-Host ""
  Write-Host "  3. " -NoNewline
  Write-Host "ONLY AFTER successful login as new admin, disable Administrator:" -ForegroundColor White
  Write-Host "       net user Administrator /active:no" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  4. " -NoNewline
  Write-Host "If you installed Tailscale, run:" -ForegroundColor White
  Write-Host "       & ""C:\Program Files\Tailscale\tailscale.exe"" up --unattended" -ForegroundColor Yellow
  Write-Host "     and verify reboot survives BEFORE disabling public RDP."
  Write-Host ""
  Write-Host "  Recovery if locked out:" -ForegroundColor Cyan
  Write-Host "    - Provider VNC console (Contabo, Hetzner, AWS Console Connect, etc.)"
  Write-Host "    - Public RDP from $($config.MyIP) on port $($config.RDPPort) is your fallback"
  Write-Host ""
  Write-Host "  Want this all automated with weekly audits + alerts?" -ForegroundColor DarkCyan
  Write-Host "    → https://kastlevps.com" -ForegroundColor DarkCyan
  Write-Host ""
}

# ============================================================================
#  MAIN
# ============================================================================

Write-Banner

if (-not (Test-PreFlight)) { exit 1 }

$config = Get-Configuration
if (-not $config) { exit 1 }

Set-AccountHygiene  $config | Out-Null
Set-PasswordPolicy
Set-RDPHardening    $config
Set-DefenderTuning  $config
Disable-UnneededServices
Set-FirewallLockdown
Block-KnownBadIPs
Install-IPBan
Install-Tailscale

Write-Summary $config
