<#
.SYNOPSIS
    Calcula el SHA256 de un archivo para usarlo en launcher.ps1
.EXAMPLE
    .\compute_hash.ps1 -Url https://raw.githubusercontent.com/.../MAS_AIO.cmd
    .\compute_hash.ps1 -FilePath .\mi_script.cmd
#>

param(
    [string]$Url,
    [string]$FilePath
)

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

if ($Url) {
    Write-Host "Descargando: $Url" -ForegroundColor Cyan
    $content = Invoke-RestMethod $Url -TimeoutSec 30
} elseif ($FilePath) {
    Write-Host "Leyendo: $FilePath" -ForegroundColor Cyan
    $content = Get-Content $FilePath -Raw -ErrorAction Stop
} else {
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  .\compute_hash.ps1 -Url    <url>" -ForegroundColor White
    Write-Host "  .\compute_hash.ps1 -File   <path>" -ForegroundColor White
    return
}

$hashBytes = [Text.Encoding]::UTF8.GetBytes($content)
$hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($hashBytes)) -replace '-'

Write-Host ""
Write-Host "Hash SHA256:" -ForegroundColor Green
Write-Host $hash -ForegroundColor White
Write-Host ""
Write-Host "Línea para launcher.ps1:" -ForegroundColor Cyan
Write-Host "`$expectedHash = '$hash'" -ForegroundColor Yellow
