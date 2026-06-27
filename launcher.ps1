<#
.SYNOPSIS
    MicroAct - launcher mejorado para Microsoft Activation Scripts
.DESCRIPTION
    Descarga, verifica y ejecuta MAS desde GitHub.
    Diseñado para usarse con: irm <url> | iex
.PARAMETER Action
    Accion: activate, kms38, online, office, all, status, info, check, schedule, help, dryrun
.PARAMETER Silent
    Sin prompts ni confirmaciones (para scripts automatizados)
.PARAMETER Language
    Idioma: ES (español) o EN (ingles)
.PARAMETER LogPath
    Ruta para guardar log
.PARAMETER SkipHashCheck
    Omitir verificacion de hash (no recomendado)
#>

param(
    [ValidateSet('activate', 'kms38', 'online', 'office', 'all', 'status', 'info', 'check', 'schedule', 'help', 'dryrun')]
    [string]$Action = '',
    [switch]$Silent,
    [ValidateSet('ES', 'EN')]
    [string]$Language = 'ES',
    [string]$LogPath = "$env:TEMP\MicroAct_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [switch]$SkipHashCheck
)

# ============ IDIOMAS ============
$L = @{
    'title'           = @{ EN = 'MicroAct - MAS Custom Launcher'; ES = 'MicroAct - MAS Custom Launcher' }
    'usage'           = @{ EN = 'USAGE'; ES = 'USO' }
    'activate_win'    = @{ EN = 'Activate Windows (HWID - permanent)'; ES = 'Activar Windows (HWID - permanente)' }
    'kms38_win'       = @{ EN = 'Activate with KMS38 (until 2038)'; ES = 'Activar con KMS38 (hasta 2038)' }
    'online_win'      = @{ EN = 'Activate with Online KMS (180 days)'; ES = 'Activar con Online KMS (180 dias)' }
    'activate_off'    = @{ EN = 'Activate Office (Online KMS)'; ES = 'Activar Office (Online KMS)' }
    'activate_all'    = @{ EN = 'Activate Windows + Office'; ES = 'Activar Windows + Office' }
    'check_status'    = @{ EN = 'Check activation status'; ES = 'Ver estado de activacion' }
    'show_info'       = @{ EN = 'Show system info'; ES = 'Informacion del sistema' }
    'schedule_task'   = @{ EN = 'Create scheduled task (reactivate every 180 days)'; ES = 'Crear tarea programada (reactivar c/180 dias)' }
    'dry_run'         = @{ EN = 'Dry run (simulate)'; ES = 'Dry run (simular)' }
    'exit_opt'        = @{ EN = 'Exit'; ES = 'Salir' }
    'select'          = @{ EN = 'Select an option'; ES = 'Selecciona una opcion' }
    'invalid_opt'     = @{ EN = 'Invalid option'; ES = 'Opcion invalida' }
    'exiting'         = @{ EN = 'Exiting'; ES = 'Saliendo' }
    'auto_mode'       = @{ EN = 'Auto mode (pipe detected). Running'; ES = 'Modo automatico (pipe detectado). Ejecutando' }
    'no_admin'        = @{ EN = 'Not running as admin. Retrying with elevation...'; ES = 'No se ejecuta como administrador. Reintentando con elevacion...' }
    'elev_fail'       = @{ EN = 'Could not elevate. Run manually as administrator.'; ES = 'No se pudo elevar. Ejecuta manualmente como administrador.' }
    'elev_ok'         = @{ EN = 'Elevated. PID'; ES = 'Elevado. PID' }
    'av_detected'     = @{ EN = '3rd party antivirus detected'; ES = 'Antivirus de terceros detectado' }
    'av_info'         = @{ EN = 'May block execution. Add exclusion if needed.'; ES = 'Puede bloquear la ejecucion. Agrega una exclusion si es necesario.' }
    'downloading'     = @{ EN = 'Downloading MAS...'; ES = 'Descargando MAS...' }
    'trying'          = @{ EN = 'Trying'; ES = 'Intentando' }
    'success'         = @{ EN = 'Success'; ES = 'Exito' }
    'failed'          = @{ EN = 'Failed'; ES = 'Fallo' }
    'dl_failed'       = @{ EN = 'Could not download MAS from any mirror.'; ES = 'No se pudo descargar MAS desde ningun mirror.' }
    'hash_mismatch'   = @{ EN = 'HASH MISMATCH'; ES = 'HASH MISMATCH' }
    'hash_expected'   = @{ EN = 'Expected'; ES = 'Esperado' }
    'hash_got'        = @{ EN = 'Got'; ES = 'Obtenido' }
    'hash_skip'       = @{ EN = 'Use -SkipHashCheck if you trust the script.'; ES = 'Usa -SkipHashCheck si confias en el script.' }
    'hash_ok'         = @{ EN = 'Hash verified'; ES = 'Hash verificado' }
    'hash_skipped'    = @{ EN = 'Hash check skipped (-SkipHashCheck)'; ES = 'Verificacion de hash omitida (-SkipHashCheck)' }
    'no_content'      = @{ EN = 'No MAS content to execute.'; ES = 'No hay contenido MAS para ejecutar.' }
    'temp_fail'       = @{ EN = 'Could not create temp file. Antivirus blocking?'; ES = 'No se pudo crear archivo temporal. Antivirus bloqueando?' }
    'temp_ok'         = @{ EN = 'Temp file created'; ES = 'Archivo temporal creado' }
    'running_cmd'     = @{ EN = 'Running cmd.exe as administrator...'; ES = 'Ejecutando cmd.exe como administrador...' }
    'exit_code'       = @{ EN = 'cmd.exe exited with code'; ES = 'cmd.exe termino con codigo' }
    'done'            = @{ EN = 'Execution completed'; ES = 'Ejecucion completada' }
    'cmd_error'       = @{ EN = 'Error running cmd.exe'; ES = 'Error al ejecutar cmd.exe' }
    'temp_deleted'    = @{ EN = 'Temp file deleted'; ES = 'Archivo temporal eliminado' }
    'log_at'          = @{ EN = 'Log saved at'; ES = 'Log guardado en' }
    'press_enter'     = @{ EN = 'Press ENTER to continue or Ctrl+C to cancel...'; ES = 'Presiona ENTER para continuar o Ctrl+C para cancelar...' }
    'dryrun_title'    = @{ EN = 'DRY RUN - Simulation mode'; ES = 'DRY RUN - Modo simulacion' }
    'dryrun_what'     = @{ EN = 'Would execute'; ES = 'Se ejecutaria' }
    'dryrun_none'     = @{ EN = 'Nothing was executed.'; ES = 'No se ejecuto nada.' }
    'confirm_title'   = @{ EN = 'Confirmation'; ES = 'Confirmacion' }
    'confirm_action'  = @{ EN = 'Action'; ES = 'Accion' }
    'confirm_admin'   = @{ EN = 'Admin'; ES = 'Admin' }
    'confirm_hash'    = @{ EN = 'Hash'; ES = 'Hash' }
    'confirm_log'     = @{ EN = 'Log'; ES = 'Log' }
    'yes'             = @{ EN = 'Yes'; ES = 'Si' }
    'no'              = @{ EN = 'No'; ES = 'No' }
    'omitted'         = @{ EN = 'Omitted'; ES = 'Omitido' }
    'verified'        = @{ EN = 'Verified'; ES = 'Verificado' }
    'autorun_warn'    = @{ EN = 'AutoRun detected in registry - may cause CMD errors.'; ES = 'AutoRun detectado en registro - puede causar errores en CMD.' }
    'autorun_fix'     = @{ EN = 'Fix'; ES = 'Solucion' }
    'win_version'     = @{ EN = 'Windows Version'; ES = 'Version de Windows' }
    'win_edition'     = @{ EN = 'Edition'; ES = 'Edicion' }
    'win_activation'  = @{ EN = 'Activation Status'; ES = 'Estado de Activacion' }
    'win_license'     = @{ EN = 'License Status'; ES = 'Estado de Licencia' }
    'win_partial'     = @{ EN = 'Partial Product Key'; ES = 'Clave Parcial' }
    'rec_activated'   = @{ EN = 'Windows is already activated.'; ES = 'Windows ya esta activado.' }
    'rec_not_act'     = @{ EN = 'Windows is NOT activated. Recommended'; ES = 'Windows NO esta activado. Recomendado' }
    'rec_expired'     = @{ EN = 'Activation expired. Recommended'; ES = 'Activacion expirada. Recomendado' }
    'rec_unknown'     = @{ EN = 'Could not determine activation status.'; ES = 'No se pudo determinar el estado de activacion.' }
    'sch_created'     = @{ EN = 'Scheduled task created. Reactivates every 180 days.'; ES = 'Tarea programada creada. Reactiva cada 180 dias.' }
    'sch_exists'      = @{ EN = 'Scheduled task already exists.'; ES = 'La tarea programada ya existe.' }
    'sch_removed'     = @{ EN = 'Scheduled task removed.'; ES = 'Tarea programada eliminada.' }
    'office_note'     = @{ EN = 'Note: Office activation requires Microsoft 365 / Office 2016+ installed'; ES = 'Nota: Office activacion requiere Microsoft 365 / Office 2016+ instalado' }
    'all_note'        = @{ EN = 'Activating Windows (HWID) + Office (Online KMS)'; ES = 'Activando Windows (HWID) + Office (Online KMS)' }
}

function T {
    param([string]$Key)
    if ($L.ContainsKey($Key) -and $L[$Key].ContainsKey($Language)) {
        return $L[$Key][$Language]
    }
    return $Key
}

# ============ INICIO ============
$troubleshoot = 'https://massgrave.dev/troubleshoot'
$hasExplicitAction = $PSBoundParameters.ContainsKey('Action')
$isPiped = try { [Console]::IsInputRedirected } catch { $false }

try { Start-Transcript -Path $LogPath -Force | Out-Null } catch {}

# --- Verificaciones de seguridad ---
try {
    $psv = $PSVersionTable.PSVersion.Major
} catch { $psv = 5 }

try {
    if ((Get-Command Write-Host).Module.Name -ne 'Microsoft.PowerShell.Utility') {
        Write-Host "PowerShell no esta en Full Language Mode." -ForegroundColor Red
        Write-Host "Ayuda: https://massgrave.dev/fix_powershell" -ForegroundColor White -BackgroundColor Blue
        Stop-Transcript -ErrorAction SilentlyContinue; return
    }
} catch {}

try {
    [void][System.AppDomain]::CurrentDomain.GetAssemblies()
} catch {
    Write-Host "Error: .NET no disponible - $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} catch {}

# --- Detectar antivirus ---
function Check-3rdPartyAV {
    $cmd = if ($psv -ge 3) { 'Get-CimInstance' } else { 'Get-WmiObject' }
    try {
        $avList = & $cmd -Namespace 'root\SecurityCenter2' -Class 'AntiVirusProduct' |
            Where-Object { $_.displayName -notlike '*windows*' } |
            Select-Object -ExpandProperty displayName -ErrorAction SilentlyContinue
        if ($avList) {
            Write-Host "[!] $(T 'av_detected'):" -NoNewline -ForegroundColor White -BackgroundColor Blue
            Write-Host " $($avList -join ', ')" -ForegroundColor DarkRed -BackgroundColor White
        }
    } catch {}
}

# --- Auto-elevacion ---
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')

if (-not $isAdmin) {
    Write-Host "[!] $(T 'no_admin')" -ForegroundColor Yellow
    $selfContent = Get-Content $PSCommandPath -Raw -ErrorAction Stop
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $selfContent } -Action '$Action' $(if ($Silent) { '-Silent' }) $(if ($Language -ne 'ES') { "-Language '$Language'" }) $(if ($SkipHashCheck) { '-SkipHashCheck' })`""
    $proc = Start-Process -FilePath powershell.exe -ArgumentList $argList -Verb RunAs -PassThru -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "[X] $(T 'elev_fail')" -ForegroundColor Red
        Stop-Transcript -ErrorAction SilentlyContinue; return
    }
    Write-Host "[OK] $(T 'elev_ok'): $($proc.Id)" -ForegroundColor Green
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

Check-3rdPartyAV

# ============ FUNCIONES ============

# --- Mostrar info del sistema ---
function Show-SystemInfo {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  $(T 'show_info')" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Host "  $(T 'win_version'): $($os.Caption)" -ForegroundColor White
        Write-Host "  $(T 'win_edition'): $($os.OperatingSystemSKU)" -ForegroundColor White
    } catch {
        Write-Host "  $(T 'win_version'): $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName)" -ForegroundColor White
    }

    try {
        $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
        if ($license) {
            $status = switch ($license.LicenseStatus) {
                0 { 'Unlicensed' }
                1 { 'Licensed' }
                2 { 'Out-Of-Box-Grace' }
                3 { 'Out-Of-Tolerance-Grace' }
                4 { 'Non-Genuine-Grace' }
                5 { 'Notification' }
                6 { 'Extended-Grace' }
                default { "Unknown ($($license.LicenseStatus))" }
            }
            Write-Host "  $(T 'win_activation'): $status" -ForegroundColor $(if ($license.LicenseStatus -eq 1) { 'Green' } else { 'Yellow' })
            Write-Host "  $(T 'win_partial'): $($license.PartialProductKey)" -ForegroundColor Gray
        } else {
            Write-Host "  $(T 'win_activation'): $(T 'rec_unknown')" -ForegroundColor Yellow
        }
    } catch {
        try {
            $slmgr = & "$env:SystemRoot\system32\cscript.exe" "$env:SystemRoot\system32\slmgr.vbs" /dli 2>&1 | Out-String
            Write-Host "  $(T 'win_activation'): $slmgr" -ForegroundColor Gray
        } catch {
            Write-Host "  $(T 'win_activation'): $(T 'rec_unknown')" -ForegroundColor Yellow
        }
    }

    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
}

# --- Check + recomendacion ---
function Show-Check {
    Show-SystemInfo

    try {
        $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
        if (-not $license) {
            Write-Host "[!] $(T 'rec_unknown')" -ForegroundColor Yellow
            Write-Host "  -> -Action activate"
            return
        }

        switch ($license.LicenseStatus) {
            1 {
                Write-Host "[OK] $(T 'rec_activated')" -ForegroundColor Green
                Write-Host "  -> -Action status"
            }
            0 {
                Write-Host "[X] $(T 'rec_not_act'): -Action activate (HWID)" -ForegroundColor Yellow
            }
            6 {
                Write-Host "[!] $(T 'rec_expired'): -Action online" -ForegroundColor Yellow
            }
            default {
                Write-Host "[!] $(T 'rec_not_act'): -Action activate (HWID)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[!] $(T 'rec_unknown')" -ForegroundColor Yellow
        Write-Host "  -> -Action activate"
    }
}

# --- Crear tarea programada ---
function New-ScheduleTask {
    $taskName = "MicroAct_Reactivation"
    $scriptPath = "$env:SystemRoot\Temp\MicroAct_Launcher.ps1"
    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($taskExists) {
        Write-Host "[!] $(T 'sch_exists')" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[OK] $(T 'sch_removed')" -ForegroundColor Green
    }

    # Descargar script y guardarlo localmente
    Write-Host "[>] $(T 'downloading')" -ForegroundColor Cyan
    $url = 'https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1'
    try {
        curl.exe -sL $url -o $scriptPath
    } catch {
        Invoke-WebRequest $url -OutFile $scriptPath -ErrorAction Stop
    }

    if (-not (Test-Path $scriptPath)) {
        Write-Host "[X] $(T 'dl_failed')" -ForegroundColor Red
        return
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Action online -Silent -Language $Language"
    $trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 180 -At "10:00"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        Write-Host "[OK] $(T 'sch_created')" -ForegroundColor Green
    } catch {
        Write-Host "[X] Error creating task: $_" -ForegroundColor Red
    }
}

# --- Descargar MAS ---
function Download-MAS {
    $URLs = @(
        'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/refs/heads/master/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
        'https://dev.azure.com/massgrave/Microsoft-Activation-Scripts/_apis/git/repositories/Microsoft-Activation-Scripts/items?path=/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
        'https://git.activated.win/Microsoft-Activation-Scripts/plain/MAS/All-In-One-Version-KL/MAS_AIO.cmd'
    )
    $expectedHash = 'D94B1ABCBA24D26C5FBE114A15B53A558684D74A1ACCFF79BBB2407BE7102A89'

    Write-Progress -Activity "$(T 'downloading')" -Status "$(T 'trying')..."
    $response = $null; $errors = @()

    foreach ($URL in ($URLs | Sort-Object { Get-Random })) {
        try {
            Write-Progress -Activity "$(T 'downloading')" -Status "$(T 'trying'): $URL"
            try {
                $response = Invoke-RestMethod -Uri $URL -TimeoutSec 30 -ErrorAction Stop
            } catch {
                $tmpFile = "$env:TEMP\MAS_$(Get-Random).cmd"
                $proc = Start-Process -FilePath curl.exe -ArgumentList "-sL `"$URL`" -o `"$tmpFile`"" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($proc.ExitCode -eq 0 -and (Test-Path $tmpFile)) {
                    $response = Get-Content $tmpFile -Raw
                    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                } else {
                    throw "curl.exe fallo con codigo $($proc.ExitCode)"
                }
            }
            Write-Progress -Activity "$(T 'downloading')" -Completed
            break
        } catch {
            $errors += $_
            Start-Sleep -Seconds 1
        }
    }
    Write-Progress -Activity "$(T 'downloading')" -Completed

    if (-not $response) {
        Write-Host "[X] $(T 'dl_failed')" -ForegroundColor Red
        foreach ($err in $errors) { Write-Host "   $($err.Exception.Message)" -ForegroundColor DarkRed }
        return $null
    }

    $response = [Text.Encoding]::ASCII.GetString([Text.Encoding]::ASCII.GetBytes($response))

    $hashBytes = [Text.Encoding]::UTF8.GetBytes($response)
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($hashBytes)) -replace '-'

    if (-not $SkipHashCheck -and $hash -ne $expectedHash) {
        Write-Host "[X] $(T 'hash_mismatch')" -ForegroundColor Red
        Write-Host "   $(T 'hash_expected'): $expectedHash" -ForegroundColor DarkRed
        Write-Host "   $(T 'hash_got'):  $hash" -ForegroundColor DarkRed
        Write-Host "   $(T 'hash_skip')" -ForegroundColor Yellow
        return $null
    }

    if ($SkipHashCheck) {
        Write-Host "[!] $(T 'hash_skipped')" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] $(T 'hash_ok')" -ForegroundColor Green
    }
    return $response
}

# --- Ejecutar MAS ---
function Invoke-MAS {
    param([string]$MASContent, [string]$Flags)

    if (-not $MASContent) {
        Write-Host "[X] $(T 'no_content')" -ForegroundColor Red
        return
    }

    foreach ($path in @("HKCU:\SOFTWARE\Microsoft\Command Processor",
                        "HKLM:\SOFTWARE\Microsoft\Command Processor")) {
        try {
            if (Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue) {
                Write-Warning "$(T 'autorun_warn')"
                Write-Host "   $(T 'autorun_fix'): Remove-ItemProperty -Path '$path' -Name 'Autorun'" -ForegroundColor Yellow
            }
        } catch {}
    }

    $rand = [Guid]::NewGuid().Guid
    $filePath = "$env:SystemRoot\Temp\MicroAct_$rand.cmd"

    try {
        Set-Content -Path $filePath -Value "@::: $rand`r`n$MASContent" -Encoding ASCII -Force
    } catch {
        $filePath = "$env:USERPROFILE\AppData\Local\Temp\MicroAct_$rand.cmd"
        Set-Content -Path $filePath -Value "@::: $rand`r`n$MASContent" -Encoding ASCII -Force
    }

    if (-not (Test-Path $filePath)) {
        Write-Host "[X] $(T 'temp_fail')" -ForegroundColor Red
        return
    }

    Write-Host "[>] $(T 'temp_ok'): $filePath" -ForegroundColor Green
    Write-Host "[>] $(T 'running_cmd')" -ForegroundColor Green
    $escapedPath = $filePath -replace '"', '""'

    try {
        $p = Start-Process -FilePath "$env:SystemRoot\system32\cmd.exe" `
            -ArgumentList "/c """"$escapedPath"" $Flags""" `
            -Verb RunAs -Wait -PassThru -ErrorAction Stop
        if ($p.ExitCode -ne 0) {
            Write-Host "[!] $(T 'exit_code'): $($p.ExitCode)" -ForegroundColor Yellow
        } else {
            Write-Host "[OK] $(T 'done')" -ForegroundColor Green
        }
    } catch {
        Write-Host "[X] $(T 'cmd_error'): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Ayuda: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    }

    try { Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue } catch {}
}

# --- Ejecutar MAS varias veces (para -All) ---
function Invoke-MAS-Multiple {
    param([array]$Runs)

    foreach ($run in $Runs) {
        $masContent = $run.Content
        $flags = $run.Flags
        $label = $run.Label

        Write-Host "[>] $label" -ForegroundColor Cyan
        Invoke-MAS -MASContent $masContent -Flags $flags
        Write-Host ""
    }
}

# --- Menu ---
function Show-Menu {
    Write-Host @"

  __  __ _            _____   _       _
 |  \/  (_)          / ____| (_)     | |
 | \  / |_  ___ ___ | |     ___  ___ | |_
 | |\/| | |/ __/ _ \| |    | \ \/ / | __|
 | |  | | | (_| (_) | |____| |>  <| | |_
 |_|  |_|_|\___\___/ \_____|_/_/\_\_|\__|

"@ -ForegroundColor Cyan
    Write-Host "  bydavidp/MicroAct | -Language $Language" -ForegroundColor DarkGray
    Write-Host "  =======================================" -ForegroundColor Cyan
    Write-Host "  1. $(T 'activate_win')" -ForegroundColor White
    Write-Host "  2. $(T 'kms38_win')" -ForegroundColor White
    Write-Host "  3. $(T 'online_win')" -ForegroundColor White
    Write-Host "  4. $(T 'activate_off')" -ForegroundColor White
    Write-Host "  5. $(T 'activate_all')" -ForegroundColor White
    Write-Host "  6. $(T 'show_info')" -ForegroundColor White
    Write-Host "  7. $(T 'check_status')" -ForegroundColor White
    Write-Host "  8. $(T 'schedule_task')" -ForegroundColor White
    Write-Host "  9. $(T 'dry_run')" -ForegroundColor White
    Write-Host "  0. $(T 'exit_opt')" -ForegroundColor Gray
    Write-Host "  =======================================" -ForegroundColor Cyan
    try { $choice = Read-Host "  $(T 'select')" } catch { return '0' }
    if ([string]::IsNullOrEmpty($choice)) { return '0' }
    return $choice
}

# --- Ayuda ---
function Show-Help {
    $langPrefix = if ($Language -eq 'EN') { @"
  MicroAct - MAS Custom Launcher
  ===============================
  USAGE:

    # From internet (interactive menu)
    irm https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | iex

    # From internet with curl (auto mode)
    curl.exe -sL https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | powershell -c -

    # Local (with parameters)
    .\launcher.ps1 -Action activate
    .\launcher.ps1 -Action office
    .\launcher.ps1 -Action all
    .\launcher.ps1 -Action info
    .\launcher.ps1 -Action check
    .\launcher.ps1 -Action schedule
    .\launcher.ps1 -Action help

  ACTIONS:
    activate   Activate Windows (HWID) - permanent
    kms38      Activate Windows until 2038
    online     Activate Windows for 180 days
    office     Activate Microsoft Office (KMS)
    all        Activate Windows + Office
    info       Show system info + activation status
    check      Diagnose + recommend action
    schedule   Create scheduled task (reactivate every 180 days)
    dryrun     Simulate without executing
    help       This help

  OPTIONS:
    -Silent           No prompts (for automation)
    -Language EN|ES   English / Spanish
    -SkipHashCheck    Skip SHA256 verification
    -LogPath <path>   Log file path

"@ } else { @"
  MicroAct - MAS Custom Launcher
  ===============================
  USO:

    # Desde internet (menu interactivo)
    irm https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | iex

    # Desde internet con curl (modo automatico)
    curl.exe -sL https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | powershell -c -

    # Local (con parametros)
    .\launcher.ps1 -Action activate
    .\launcher.ps1 -Action office
    .\launcher.ps1 -Action all
    .\launcher.ps1 -Action info
    .\launcher.ps1 -Action check
    .\launcher.ps1 -Action schedule
    .\launcher.ps1 -Action help

  ACCIONES:
    activate   Activar Windows (HWID) - permanente
    kms38      Activar Windows hasta 2038
    online     Activar Windows por 180 dias
    office     Activar Microsoft Office (KMS)
    all        Activar Windows + Office
    info       Info del sistema + estado activacion
    check      Diagnosticar + recomendar accion
    schedule   Crear tarea programada (reactivar c/180 dias)
    dryrun     Simular sin ejecutar
    help       Esta ayuda

  OPCIONES:
    -Silent           Sin prompts (automatizacion)
    -Language EN|ES   Ingles / Espanol
    -SkipHashCheck    Omitir verificacion SHA256
    -LogPath <ruta>   Ruta del log

"@ }
    Write-Host $langPrefix
}

# ============ FLUJO PRINCIPAL ============

if ($Action -eq 'help') {
    Show-Help
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

if ($Action -eq 'info') {
    Show-SystemInfo
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

if ($Action -eq 'check') {
    Show-Check
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

if ($Action -eq 'schedule') {
    New-ScheduleTask
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

# Menu o modo automatico
if (-not $hasExplicitAction) {
    if ($isPiped) {
        Write-Host "[>] $(T 'auto_mode') activate..." -ForegroundColor Cyan
        $Action = 'activate'
        $masContent = Download-MAS
        if (-not $masContent) { Stop-Transcript -ErrorAction SilentlyContinue; return }
    } else {
        $masContent = $null
        do {
            $choice = Show-Menu
            switch ($choice) {
                '1' { $Action = 'activate'; break }
                '2' { $Action = 'kms38'; break }
                '3' { $Action = 'online'; break }
                '4' { $Action = 'office'; break }
                '5' { $Action = 'all'; break }
                '6' { Write-Host ""; Show-SystemInfo; continue }
                '7' { Write-Host ""; Show-Check; continue }
                '8' { Write-Host ""; New-ScheduleTask; continue }
                '9' { $Action = 'dryrun'; break }
                '0' { Write-Host "[OK] $(T 'exiting')." -ForegroundColor Green; Stop-Transcript -ErrorAction SilentlyContinue; return }
                default { Write-Host "[!] $(T 'invalid_opt')." -ForegroundColor Yellow; Start-Sleep -Seconds 1; continue }
            }
        } while ($choice -notin @('1','2','3','4','5','9'))
    }
} else {
    # Accion directa
    if ($Action -ne 'dryrun' -and $Action -ne 'info' -and $Action -ne 'check' -and $Action -ne 'schedule') {
        $masContent = Download-MAS
        if (-not $masContent) { Stop-Transcript -ErrorAction SilentlyContinue; return }
    }
}

# --- Mapear accion a flags ---
$flagsMap = @{
    'activate' = '-el'
    'kms38'    = '-k'
    'online'   = '-o'
    'office'   = '-oh'
}
$masFlags = $flagsMap[$Action]

# --- Dry run ---
if ($Action -eq 'dryrun') {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  $(T 'dryrun_title')" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  $(T 'dryrun_what'):" -ForegroundColor White
    Write-Host "  * MAS_AIO.cmd ($($masContent.Length) bytes)" -ForegroundColor Gray
    Write-Host "  * Flags: $masFlags" -ForegroundColor Gray
    Write-Host "  * Lanzado como administrador via cmd.exe" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  $(T 'dryrun_none')" -ForegroundColor Green
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

# --- Confirmacion ---
if (-not $Silent -and $Action -ne 'all') {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  $(T 'confirm_title')" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  $(T 'confirm_action'): $Action (flags: $masFlags)" -ForegroundColor White
    Write-Host "  $(T 'confirm_admin'): $(if ($isAdmin) { "$(T 'yes')" } else { "$(T 'no')" })" -ForegroundColor White
    Write-Host "  $(T 'confirm_hash'): $(if ($SkipHashCheck) { "$(T 'omitted')" } else { "$(T 'verified')" })" -ForegroundColor White
    Write-Host "  $(T 'confirm_log'): $LogPath" -ForegroundColor White
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "$(T 'press_enter')" -ForegroundColor Yellow
    $null = Read-Host
}

# --- Office note ---
if ($Action -eq 'office') {
    Write-Host "[!] $(T 'office_note')" -ForegroundColor Yellow
    if (-not $Silent) {
        Write-Host "$(T 'press_enter')" -ForegroundColor Yellow
        $null = Read-Host
    }
}

# --- Ejecutar ---
if ($Action -eq 'all') {
    Write-Host "[>] $(T 'all_note')" -ForegroundColor Cyan
    # Descargar una vez, ejecutar dos veces con diferentes flags
    if (-not $masContent) {
        $masContent = Download-MAS
        if (-not $masContent) { Stop-Transcript -ErrorAction SilentlyContinue; return }
    }
    $runs = @(
        @{ Content = $masContent; Flags = '-el';  Label = "Windows (HWID)" },
        @{ Content = $masContent; Flags = '-oh'; Label = "Office (Online KMS)" }
    )
    Invoke-MAS-Multiple -Runs $runs
} else {
    Invoke-MAS -MASContent $masContent -Flags $masFlags
}

Write-Host "$(T 'log_at'): $LogPath" -ForegroundColor Gray
Stop-Transcript -ErrorAction SilentlyContinue
