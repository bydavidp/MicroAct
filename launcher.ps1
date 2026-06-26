<#
.SYNOPSIS
    MAS Custom Launcher - portado y mejorado desde massgrave.dev
.DESCRIPTION
    Descarga, verifica y ejecuta MAS (Microsoft Activation Scripts)
    con multiples mejoras de seguridad y robustez.
.PARAMETER Action
    Accion a ejecutar (status, activate, help, dryrun)
.PARAMETER LogPath
    Ruta para guardar log (default: %%TEMP%%\MAS_launcher.log)
.PARAMETER SkipHashCheck
    Omitir verificacion de hash (no recomendado)
#>

param(
    [ValidateSet('status', 'activate', 'help', 'dryrun')]
    [string]$Action = 'help',

    [string]$LogPath = "$env:TEMP\MAS_Custom_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",

    [switch]$SkipHashCheck
)

# --- Ayuda rapida -------------------------------------------------
function Show-Help {
    @"

  MAS Custom Launcher
  ====================
  Uso: irm <url> | iex [-Action <accion>]

  Acciones:
    status     Muestra estado actual de activacion
    activate   Ejecuta activacion con HWID (Windows 10/11)
    help       Muestra esta ayuda
    dryrun     Simula sin ejecutar nada

  Ejemplos:
    irm https://raw.githubusercontent.com/tuuser/turepo/main/launcher.ps1 | iex
    irm https://raw.githubusercontent.com/tuuser/turepo/main/launcher.ps1 | iex -Action activate

"@
}
# ------------------------------------------------------------------

# --- Config logging -----------------------------------------------
try { Start-Transcript -Path $LogPath -Force | Out-Null } catch {}

# --- Detectar version de PowerShell -------------------------------
$psv = $PSVersionTable.PSVersion.Major
$troubleshoot = 'https://massgrave.dev/troubleshoot'

# --- Verificar Full Language Mode (robusto) -----------------------
try {
    if ((Get-Command Write-Host).Module.Name -ne 'Microsoft.PowerShell.Utility') {
        Write-Host "PowerShell no esta en Full Language Mode." -ForegroundColor Red
        Write-Host "Ayuda: https://massgrave.dev/fix_powershell" -ForegroundColor White -BackgroundColor Blue
        if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
        return
    }
} catch {
    Write-Host "No se pudo verificar Language Mode." -ForegroundColor Yellow
}

# --- Verificar .NET -----------------------------------------------
try {
    [void][System.AppDomain]::CurrentDomain.GetAssemblies()
    [void][System.Math]::Sqrt(144)
} catch {
    Write-Host "Error: .NET no disponible - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Ayuda: https://massgrave.dev/in-place_repair_upgrade" -ForegroundColor White -BackgroundColor Blue
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

# --- Forzar TLS 1.2 y validar certificados SSL --------------------
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Validar certificados SSL explicitamente
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {
        param($sender, $cert, $chain, $errors)
        if ($errors -eq [Net.Security.SslPolicyErrors]::None) { return $true }
        Write-Warning "SSL cert error: $errors"
        return $false
    }
} catch {
    Write-Warning "No se pudo forzar TLS 1.2: $_"
}

# --- Mostrar ayuda y salir ----------------------------------------
if ($Action -eq 'help') {
    Show-Help
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

# --- Detectar antivirus de terceros -------------------------------
function Check-3rdPartyAV {
    $cmd = if ($psv -ge 3) { 'Get-CimInstance' } else { 'Get-WmiObject' }
    try {
        $avList = & $cmd -Namespace 'root\SecurityCenter2' -Class 'AntiVirusProduct' |
            Where-Object { $_.displayName -notlike '*windows*' } |
            Select-Object -ExpandProperty displayName -ErrorAction SilentlyContinue
        if ($avList) {
            Write-Host '[!] Antivirus de terceros detectado:' -ForegroundColor White -BackgroundColor Blue -NoNewline
            Write-Host " $($avList -join ', ')" -ForegroundColor DarkRed -BackgroundColor White
            Write-Host '  Puede bloquear la ejecucion. Agrega una exclusion si es necesario.' -ForegroundColor Yellow
        }
    } catch {
        # No siempre se puede acceder a SecurityCenter2
    }
}
Check-3rdPartyAV

# --- Elevacion automatica si no es admin --------------------------
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')

if (-not $isAdmin) {
    Write-Host "[!] No se ejecuta como administrador. Reintentando con elevacion..." -ForegroundColor Yellow

    # Reconstruir comando con los mismos argumentos
    $selfContent = Get-Content $PSCommandPath -Raw -ErrorAction Stop
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $selfContent } -Action '$Action' $(if ($SkipHashCheck) { '-SkipHashCheck' })`""

    $proc = Start-Process -FilePath powershell.exe -ArgumentList $argList -Verb RunAs -PassThru -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "[X] No se pudo elevar. Ejecuta manualmente como administrador." -ForegroundColor Red
        Write-Host "   Boton derecho -> 'Ejecutar como administrador'" -ForegroundColor Yellow
        if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
        return
    }
    Write-Host "[OK] Elevado. PID: $($proc.Id)" -ForegroundColor Green
    if ($Action -eq 'dryrun') {
        Write-Host "   (dryrun - proceso lanzado, espera cierre)" -ForegroundColor Cyan
        $proc.WaitForExit()
    }
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

# --- URLs de descarga (original MAS) ------------------------------
$URLs = @(
    'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/refs/heads/master/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
    'https://dev.azure.com/massgrave/Microsoft-Activation-Scripts/_apis/git/repositories/Microsoft-Activation-Scripts/items?path=/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
    'https://git.activated.win/Microsoft-Activation-Scripts/plain/MAS/All-In-One-Version-KL/MAS_AIO.cmd'
)

# Hash SHA256 oficial de MAS_AIO.cmd
$expectedHash = 'D94B1ABCBA24D26C5FBE114A15B53A558684D74A1ACCFF79BBB2407BE7102A89'

# --- Descargar con timeout y reintentos ---------------------------
Write-Progress -Activity "Descargando MAS..." -Status "Conectando..."
$response = $null
$errors = @()

foreach ($URL in ($URLs | Sort-Object { Get-Random })) {
    try {
        Write-Progress -Activity "Descargando MAS..." -Status "Intentando: $URL"
        if ($psv -ge 3) {
            $response = Invoke-RestMethod -Uri $URL -TimeoutSec 30 -ErrorAction Stop
        } else {
            $wc = New-Object Net.WebClient
            $wc.Timeout = 30000
            $response = $wc.DownloadString($URL)
        }
        Write-Progress -Activity "Descargando MAS..." -Status "OK - Exito" -Completed
        break
    } catch {
        $errors += $_
        Write-Progress -Activity "Descargando MAS..." -Status "Falló: $URL"
        Start-Sleep -Seconds 1
    }
}
Write-Progress -Activity "Descargando MAS..." -Completed

if (-not $response) {
    Write-Host "[X] No se pudo descargar MAS desde ningun mirror." -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "   Error: $($err.Exception.Message)" -ForegroundColor DarkRed
    }
    Write-Host "   Ayuda: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

# --- Sanitizar encoding (forzar ASCII para cmd.exe) ---------------
$bytes = [Text.Encoding]::ASCII.GetBytes($response)
$responseAscii = [Text.Encoding]::ASCII.GetString($bytes)

# --- Verificar hash SHA256 -----------------------------------------
Write-Progress -Activity "Verificando integridad..."
$hashBytes = [Text.Encoding]::UTF8.GetBytes($response)
$hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($hashBytes)) -replace '-'

if (-not $SkipHashCheck -and $hash -ne $expectedHash) {
    Write-Host "[X] HASH MISMATCH" -ForegroundColor Red
    Write-Host "   Esperado: $expectedHash" -ForegroundColor DarkRed
    Write-Host "   Obtenido:  $hash" -ForegroundColor DarkRed
    Write-Host "   Reporta el problema en: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    Write-Host ""
    Write-Host "   Si confias en el script, usa: -SkipHashCheck" -ForegroundColor Yellow
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

if ($SkipHashCheck) {
    Write-Host "[!] Verificacion de hash omitida (flag -SkipHashCheck)" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Hash verificado correctamente" -ForegroundColor Green
}
Write-Progress -Activity "Verificando integridad..." -Completed

# --- Verificar AutoRun de CMD -------------------------------------
$autorunPaths = @(
    "HKCU:\SOFTWARE\Microsoft\Command Processor",
    "HKLM:\SOFTWARE\Microsoft\Command Processor"
)
foreach ($path in $autorunPaths) {
    try {
        $val = Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue
        if ($val) {
            Write-Warning "AutoRun detectado en $path - puede causar errores en CMD."
            Write-Host "   Solucion: Remove-ItemProperty -Path '$path' -Name 'Autorun'" -ForegroundColor Yellow
        }
    } catch {}
}

# --- Mostrar resumen y pedir confirmacion -------------------------
if ($Action -ne 'dryrun') {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  MAS Custom Launcher" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  Accion:     $Action" -ForegroundColor White
    Write-Host "  Admin:      $(if ($isAdmin) { 'OK - Si' } else { 'X - No' })" -ForegroundColor White
    Write-Host "  Hash:       $(if ($SkipHashCheck) { 'Omitido' } else { 'Verificado' })" -ForegroundColor White
    Write-Host "  Log:        $LogPath" -ForegroundColor White
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Presiona ENTER para continuar o Ctrl+C para cancelar..." -ForegroundColor Yellow
    $null = Read-Host
}

# --- Dry-run mode --------------------------------------------------
if ($Action -eq 'dryrun') {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  DRY RUN - Modo simulacion" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  Se ejecutaria:" -ForegroundColor White
    Write-Host "  * Descargar MAS_AIO.cmd ($($response.Length) bytes)" -ForegroundColor Gray
    Write-Host "  * Guardar en: %TEMP%\MAS_<guid>.cmd" -ForegroundColor Gray
    Write-Host "  * Lanzar cmd.exe con flags"
    Write-Host ""
    Write-Host "  No se ejecuto nada. Usa -Action activate para ejecutar." -ForegroundColor Green
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

# --- Preparar archivo temporal ------------------------------------
$rand = [Guid]::NewGuid().Guid
$filePath = "$env:SystemRoot\Temp\MAS_$rand.cmd"

try {
    Set-Content -Path $filePath -Value "@::: $rand`r`n$responseAscii" -Encoding ASCII -Force
} catch {
    # Fallback a USERPROFILE si no podemos escribir en SystemRoot
    $filePath = "$env:USERPROFILE\AppData\Local\Temp\MAS_$rand.cmd"
    Set-Content -Path $filePath -Value "@::: $rand`r`n$responseAscii" -Encoding ASCII -Force
}

if (-not (Test-Path $filePath)) {
    Check-3rdPartyAV
    Write-Host "[X] No se pudo crear el archivo temporal. Antivirus bloqueando?" -ForegroundColor Red
    Write-Host "   Ayuda: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
    if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
    return
}

Write-Host "[OK] Archivo temporal creado: $filePath" -ForegroundColor Green

# --- Definir flags segun accion -----------------------------------
$actionFlag = switch ($Action) {
    'activate'  { '-el' }
    'status'    { '' }
    default     { '' }
}

# --- Ejecutar como cmd.exe con privilegios ------------------------
Write-Host "[>] Ejecutando cmd.exe como administrador..." -ForegroundColor Green

# Sanitizar filePath (escapar comillas)
$escapedPath = $filePath -replace '"', '""'

try {
    if ($psv -lt 3) {
        $p = Start-Process -FilePath "$env:SystemRoot\system32\cmd.exe" `
            -ArgumentList "/c """"$escapedPath"" $actionFlag""" `
            -Verb RunAs -PassThru -Wait -ErrorAction Stop
    } else {
        $p = Start-Process -FilePath "$env:SystemRoot\system32\cmd.exe" `
            -ArgumentList "/c """"$escapedPath"" $actionFlag""" `
            -Verb RunAs -Wait -PassThru -ErrorAction Stop
    }

    if ($p.ExitCode -ne 0) {
        Write-Host "[!] cmd.exe termino con codigo: $($p.ExitCode)" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Ejecucion completada" -ForegroundColor Green
    }
} catch {
    Write-Host "[X] Error al ejecutar cmd.exe: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Ayuda: $troubleshoot" -ForegroundColor White -BackgroundColor Blue
}

# --- Limpiar -------------------------------------------------------
try {
    if (Test-Path $filePath) {
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Archivo temporal eliminado" -ForegroundColor Green
    }
} catch {
    Write-Host "[!] No se pudo eliminar el temporal: $_" -ForegroundColor Yellow
}

Write-Host "Log guardado en: $LogPath" -ForegroundColor Gray

if ($LogPath) { Stop-Transcript -ErrorAction SilentlyContinue }
