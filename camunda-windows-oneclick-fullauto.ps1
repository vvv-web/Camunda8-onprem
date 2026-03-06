param(
  [string]$CamundaHost = "100.69.139.22",
  [int]$CamundaPort = 8088,
  [switch]$Elevated
)

$ErrorActionPreference = "Stop"

function Get-TailscaleExe {
  $candidates = @(
    (Join-Path $env:ProgramFiles "Tailscale IPN\tailscale.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Tailscale IPN\tailscale.exe"),
    "tailscale.exe"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -eq "tailscale.exe") {
      $cmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
      if ($cmd) { return $cmd.Source }
      continue
    }

    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  return $null
}

function Get-TailscaleMsiUrl {
  # Official package endpoint (latest stable).
  # Docs: https://tailscale.com/kb/1189/install-windows-msi
  $arch = $env:PROCESSOR_ARCHITECTURE
  if ($arch -eq "AMD64") { return "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi" }
  if ($arch -eq "ARM64") { return "https://pkgs.tailscale.com/stable/tailscale-setup-latest-x86.msi" }
  return "https://pkgs.tailscale.com/stable/tailscale-setup-latest-x86.msi"
}

function Ensure-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if ($isAdmin -or $Elevated) { return }

  Write-Host "[INFO] Requesting administrator rights..."
  $argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$PSCommandPath`"",
    "-CamundaHost", "`"$CamundaHost`"",
    "-CamundaPort", "$CamundaPort",
    "-Elevated"
  )
  $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru -WorkingDirectory (Split-Path -Parent $PSCommandPath)
  exit $proc.ExitCode
}

function Install-TailscaleIfNeeded {
  $tailscaleExe = Get-TailscaleExe
  if ($tailscaleExe) {
    Write-Host "[OK] Tailscale already installed: $tailscaleExe"
    return $tailscaleExe
  }

  Write-Host "[1/5] Download official Tailscale MSI"
  $msiUrl = Get-TailscaleMsiUrl
  $msiPath = Join-Path $env:TEMP "tailscale-setup-latest.msi"
  Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

  Write-Host "[2/5] Verify MSI digital signature"
  $sig = Get-AuthenticodeSignature -FilePath $msiPath
  if ($sig.Status -ne "Valid" -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch "Tailscale") {
    throw "Tailscale MSI signature check failed. Status=$($sig.Status), Subject=$($sig.SignerCertificate.Subject)"
  }
  Write-Host "[OK] Signature is valid: $($sig.SignerCertificate.Subject)"

  Write-Host "[3/5] Install Tailscale MSI (silent)"
  $msiLog = Join-Path $env:TEMP "tailscale-msi-install.log"
  $args = "/i `"$msiPath`" /qn /norestart /L*v `"$msiLog`""
  $installProc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru
  if ($installProc.ExitCode -ne 0 -and $installProc.ExitCode -ne 3010) {
    throw "MSI install failed with code $($installProc.ExitCode). Log: $msiLog"
  }
  if ($installProc.ExitCode -eq 3010) {
    Write-Host "[WARN] MSI requested reboot (3010). Continue without reboot."
  }

  Start-Sleep -Seconds 2
  $tailscaleExe = Get-TailscaleExe
  if (-not $tailscaleExe) {
    throw "Tailscale installed but CLI not found. Reboot Windows and rerun."
  }
  Write-Host "[OK] Tailscale installed: $tailscaleExe"
  return $tailscaleExe
}

function Wait-TailscaleOnline {
  param(
    [Parameter(Mandatory = $true)][string]$TailscaleExe,
    [int]$TimeoutSeconds = 180
  )

  $attempts = [math]::Ceiling($TimeoutSeconds / 2)
  for ($i = 0; $i -lt $attempts; $i++) {
    try {
      $json = & $TailscaleExe status --json 2>$null
      if ($LASTEXITCODE -eq 0 -and $json) {
        $status = $json | ConvertFrom-Json
        if ($status.Self.Online -eq $true) {
          return $true
        }
      }
    } catch {
      # transient
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

Write-Host "=== Camunda one-click AUTO-INSTALL SAFE (Windows) ==="
$tailscaleExe = Get-TailscaleExe
if (-not $tailscaleExe) {
  Write-Host "[INFO] Tailscale is not installed. Administrator rights are required for MSI install."
  Ensure-Admin
  # after elevated restart, execution continues in elevated process
  $tailscaleExe = Install-TailscaleIfNeeded
} else {
  Write-Host "[OK] Tailscale already installed: $tailscaleExe"
}

Write-Host "[4/5] Connect to tailnet (browser login may open)"
try {
  & $tailscaleExe up --accept-routes | Out-Host
} catch {
  Write-Host "[WARN] tailscale up returned non-zero. Continue to online check..."
}

if (-not (Wait-TailscaleOnline -TailscaleExe $tailscaleExe -TimeoutSeconds 180)) {
  throw "Tailscale is not online yet. Complete login and rerun script."
}
Write-Host "[OK] Tailscale is online"

Write-Host "[5/5] Check Camunda endpoint and open URLs"
$reachable = Test-NetConnection -ComputerName $CamundaHost -Port $CamundaPort -InformationLevel Quiet
if (-not $reachable) {
  throw "Cannot reach http://$CamundaHost`:$CamundaPort. Check ACL/routes/firewall."
}

Start-Process "http://$CamundaHost`:$CamundaPort/operate"
Start-Sleep -Milliseconds 600
Start-Process "http://$CamundaHost`:$CamundaPort/tasklist"

Write-Host ""
Write-Host "Done. Login in Camunda manually: demo / demo"
Write-Host "If redirected to 10.16.66.48 after login, change HOST on Camunda server to Tailscale address."
