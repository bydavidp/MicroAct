<#
.SYNOPSIS
    MicroAct - launcher mejorado para Microsoft Activation Scripts
.DESCRIPTION
    Descarga, verifica y ejecuta MAS desde GitHub.
    Diseñado para usarse con: irm <url> | iex
.PARAMETER Action
    Accion a ejecutar (status, activate, kms38, online, dryrun)
.PARAMETER LogPath
    Ruta para guardar log
.PARAMETER SkipHashCheck
    Omitir verificacion de hash (no recomendado)
#>

param(
    [ValidateSet('status', 'activate', 'kms38', 'online', 'help', 'dryrun')]
    [string]$Action = '',

    [string]$LogPath = "$env:TEMP\MicroAct_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",

    [switch]$SkipHashCheck
)

$troubleshoot = 'https://massgrave.dev/troubleshoot'

# --- Si no se paso -Action explicitamente, mostrar menu ----------
$hasExplicitAction = $PSBoundParameters.ContainsKey('Action')

# Detectar si stdin es pipe (curl ... | powershell -c -)
$isPiped = try { [Console]::IsInputRedirected } catch { $false }



# --- Logging ------------------------------------------------------
try { Start-Transcript -Path $LogPath -Force | Out-Null } catch {}

# --- Verificaciones de seguridad ----------------------------------
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

# --- Detectar antivirus de terceros -------------------------------
function Check-3rdPartyAV {
    $cmd = if ($psv -ge 3) { 'Get-CimInstance' } else { 'Get-WmiObject' }
    try {
        $avList = & $cmd -Namespace 'root\SecurityCenter2' -Class 'AntiVirusProduct' |
            Where-Object { $_.displayName -notlike '*windows*' } |
            Select-Object -ExpandProperty displayName -ErrorAction SilentlyContinue
        if ($avList) {
            Write-Host "[!] Antivirus de terceros detectado:" -NoNewline -ForegroundColor White -BackgroundColor Blue
            Write-Host " $($avList -join ', ')" -ForegroundColor DarkRed -BackgroundColor White
        }
    } catch {}
}
Check-3rdPartyAV

# --- Auto-elevacion -----------------------------------------------
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')

if (-not $isAdmin) {
    Write-Host "[!] No se ejecuta como administrador. Reintentando con elevacion..." -ForegroundColor Yellow
    $selfContent = Get-Content $PSCommandPath -Raw -ErrorAction Stop
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $selfContent } -Action '$Action' $(if ($SkipHashCheck) { '-SkipHashCheck' })`""
    $proc = Start-Process -FilePath powershell.exe -ArgumentList $argList -Verb RunAs -PassThru -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "[X] No se pudo elevar. Ejecuta manualmente como administrador." -ForegroundColor Red
        Stop-Transcript -ErrorAction SilentlyContinue; return
    }
    Write-Host "[OK] Elevado. PID: $($proc.Id)" -ForegroundColor Green
    if ($Action -eq 'dryrun') { $proc.WaitForExit() }
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

# --- Funcion: descargar MAS ---------------------------------------
function Download-MAS {
    $URLs = @(
        'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/refs/heads/master/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
        'https://dev.azure.com/massgrave/Microsoft-Activation-Scripts/_apis/git/repositories/Microsoft-Activation-Scripts/items?path=/MAS/All-In-One-Version-KL/MAS_AIO.cmd',
        'https://git.activated.win/Microsoft-Activation-Scripts/plain/MAS/All-In-One-Version-KL/MAS_AIO.cmd'
    )
    $expectedHash = 'D94B1ABCBA24D26C5FBE114A15B53A558684D74A1ACCFF79BBB2407BE7102A89'

    Write-Progress -Activity "Descargando MAS..." -Status "Conectando..."
    $response = $null; $errors = @()

    foreach ($URL in ($URLs | Sort-Object { Get-Random })) {
        try {
            Write-Progress -Activity "Descargando MAS..." -Status "Intentando: $URL"
            # Metodo 1: Invoke-RestMethod
            try {
                $response = Invoke-RestMethod -Uri $URL -TimeoutSec 30 -ErrorAction Stop
            } catch {
                # Metodo 2: curl.exe (fallback)
                $tmpFile = "$env:TEMP\MAS_$(Get-Random).cmd"
                $proc = Start-Process -FilePath curl.exe -ArgumentList "-sL `"$URL`" -o `"$tmpFile`"" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($proc.ExitCode -eq 0 -and (Test-Path $tmpFile)) {
                    $response = Get-Content $tmpFile -Raw
                    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                } else {
                    throw "curl.exe fallo con codigo $($proc.ExitCode)"
                }
            }
            Write-Progress -Activity "Descargando MAS..." -Completed
            break
        } catch {
            $errors += $_
            Start-Sleep -Seconds 1
        }
    }
    Write-Progress -Activity "Descargando MAS..." -Completed

    if (-not $response) {
        Write-Host "[X] No se pudo descargar MAS." -ForegroundColor Red
        foreach ($err in $errors) { Write-Host "   $($err.Exception.Message)" -ForegroundColor DarkRed }
        return $null
    }

    # Forzar ASCII
    $response = [Text.Encoding]::ASCII.GetString([Text.Encoding]::ASCII.GetBytes($response))

    # Verificar hash
    $hashBytes = [Text.Encoding]::UTF8.GetBytes($response)
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($hashBytes)) -replace '-'

    if (-not $SkipHashCheck -and $hash -ne $expectedHash) {
        Write-Host "[X] HASH MISMATCH" -ForegroundColor Red
        Write-Host "   Esperado: $expectedHash" -ForegroundColor DarkRed
        Write-Host "   Obtenido:  $hash" -ForegroundColor DarkRed
        if ($SkipHashCheck) { Write-Host "   Usa -SkipHashCheck si confias en el script." -ForegroundColor Yellow }
        return $null
    }

    Write-Host "[OK] Hash verificado" -ForegroundColor Green
    return $response
}

# --- Funcion: ejecutar MAS ----------------------------------------
function Invoke-MAS {
    param([string]$MASContent, [string]$Flags)

    if (-not $MASContent) {
        Write-Host "[X] No hay contenido MAS para ejecutar." -ForegroundColor Red
        return
    }

    # Verificar AutoRun
    foreach ($path in @("HKCU:\SOFTWARE\Microsoft\Command Processor",
                        "HKLM:\SOFTWARE\Microsoft\Command Processor")) {
        try {
            if (Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue) {
                Write-Warning "AutoRun detectado en $path"
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
        Write-Host "[X] No se pudo crear archivo temporal." -ForegroundColor Red
        return
    }

    Write-Host "[>] Ejecutando cmd.exe como administrador..." -ForegroundColor Green
    $escapedPath = $filePath -replace '"', '""'

    try {
        $p = Start-Process -FilePath "$env:SystemRoot\system32\cmd.exe" `
            -ArgumentList "/c """"$escapedPath"" $Flags""" `
            -Verb RunAs -Wait -PassThru -ErrorAction Stop
        if ($p.ExitCode -ne 0) {
            Write-Host "[!] cmd.exe termino con codigo: $($p.ExitCode)" -ForegroundColor Yellow
        } else {
            Write-Host "[OK] Ejecucion completada" -ForegroundColor Green
        }
    } catch {
        Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    try { Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue } catch {}
}

# --- Menu interactivo --------------------------------------------
function Show-Menu {
    $art = @"

  __  __ _            _____   _       _
 |  \/  (_)          / ____| (_)     | |
 | \  / |_  ___ ___ | |     ___  ___ | |_
 | |\/| | |/ __/ _ \| |    | \ \/ / | __|
 | |  | | | (_| (_) | |____| |>  <| | |_
 |_|  |_|_|\___\___/ \_____|_/_/\_\_|\__|

"@
    Write-Host $art -ForegroundColor Cyan
    Write-Host "  bydavidp/MicroAct" -ForegroundColor DarkGray
    Write-Host "  =======================================" -ForegroundColor Cyan
    Write-Host "  1. Activar Windows (HWID)" -ForegroundColor White
    Write-Host "  2. Activar con KMS38 (hasta 2038)" -ForegroundColor White
    Write-Host "  3. Activar con Online KMS (180 dias)" -ForegroundColor White
    Write-Host "  4. Solo ver estado de activacion" -ForegroundColor White
    Write-Host "  5. Dry run (simular, no ejecuta nada)" -ForegroundColor White
    Write-Host "  0. Salir" -ForegroundColor Gray
    Write-Host "  =======================================" -ForegroundColor Cyan
    try { $choice = Read-Host "  Selecciona una opcion" } catch { return '0' }
    if ([string]::IsNullOrEmpty($choice)) { return '0' }
    return $choice
}

# --- Mostrar ayuda -----------------------------------------------
function Show-Help {
    @"
  MicroAct - MAS Custom Launcher
  ===============================
  USO:

    # Desde internet (muestra menu interactivo)
    irm https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | iex

    # Local (con parametros)
    .\launcher.ps1 -Action activate
    .\launcher.ps1 -Action kms38
    .\launcher.ps1 -Action online
    .\launcher.ps1 -Action dryrun
    .\launcher.ps1 -Action help

  ACCIONES:
    activate   Activar Windows (HWID) - permanente
    kms38      Activar hasta el 2038
    online     Activar por 180 dias
    status     Mostrar estado de activacion
    dryrun     Simular sin ejecutar nada
    help       Esta ayuda

  OPCIONES:
    -SkipHashCheck   Omitir verificacion SHA256
    -LogPath <ruta>  Ruta del archivo de log

"@
}

# ============ FLUJO PRINCIPAL ============

# Si pidio ayuda
if ($Action -eq 'help') {
    Show-Help
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

# Si no se paso -Action, decidir entre menu o modo automatico
if (-not $hasExplicitAction) {
    if ($isPiped) {
        Write-Host "[>] Modo automatico (pipe detectado). Ejecutando activate..." -ForegroundColor Cyan
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
                '4' { $Action = 'status'; break }
                '5' { $Action = 'dryrun'; break }
                '0' { Write-Host "[OK] Saliendo." -ForegroundColor Green; Stop-Transcript -ErrorAction SilentlyContinue; return }
                default {
                    Write-Host "[!] Opcion invalida." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1; continue
                }
            }
        } while ($choice -notin @('1','2','3','4','5','0'))
        if ($Action -ne 'dryrun') {
            $masContent = Download-MAS
            if (-not $masContent) { Stop-Transcript -ErrorAction SilentlyContinue; return }
        }
    }
} else {
    # Ejecucion directa con -Action
    if ($Action -ne 'dryrun') {
        $masContent = Download-MAS
        if (-not $masContent) {
            Stop-Transcript -ErrorAction SilentlyContinue; return
        }
    }
}

# Mapear accion a flags de MAS
$flagsMap = @{
    'activate' = '-el'
    'kms38'    = '-k'
    'online'   = '-o'
    'status'   = ''
}
$masFlags = $flagsMap[$Action]

# Dry run
if ($Action -eq 'dryrun') {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  DRY RUN - Modo simulacion" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host "  Se ejecutaria:" -ForegroundColor White
    if ($masContent) { Write-Host "  * MAS_AIO.cmd ($($masContent.Length) bytes)" -ForegroundColor Gray }
    Write-Host "  * Flags: $masFlags" -ForegroundColor Gray
    Write-Host "  * Lanzado como administrador via cmd.exe" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  No se ejecuto nada." -ForegroundColor Green
    Stop-Transcript -ErrorAction SilentlyContinue; return
}

# Confirmacion
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  MicroAct" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Accion:  $Action (flags: $masFlags)" -ForegroundColor White
Write-Host "  Admin:   $(if ($isAdmin) { 'Si' } else { 'No' })" -ForegroundColor White
Write-Host "  Hash:    $(if ($SkipHashCheck) { 'Omitido' } else { 'Verificado' })" -ForegroundColor White
Write-Host "  Log:     $LogPath" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona ENTER para continuar o Ctrl+C para cancelar..." -ForegroundColor Yellow
$null = Read-Host

# Ejecutar
Invoke-MAS -MASContent $masContent -Flags $masFlags

Write-Host "Log guardado en: $LogPath" -ForegroundColor Gray
Stop-Transcript -ErrorAction SilentlyContinue
