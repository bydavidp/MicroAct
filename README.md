# MicroAct

Launcher mejorado para Microsoft Activation Scripts (MAS).

## Uso

### Desde internet (menú interactivo)

```powershell
irm https://raw.githubusercontent.com/bydavidp/MicroAct/master/launcher.ps1 | iex
```

Muestra un menú para elegir: HWID, KMS38, Online KMS, Status, Dry Run.

### Local (con parámetros directos)

```powershell
.\launcher.ps1 -Action activate
.\launcher.ps1 -Action kms38
.\launcher.ps1 -Action online
.\launcher.ps1 -Action status
.\launcher.ps1 -Action dryrun
.\launcher.ps1 -Action help
```

### Opciones adicionales

```powershell
.\launcher.ps1 -Action activate -SkipHashCheck
.\launcher.ps1 -Action activate -LogPath C:\logs\microact.log
```

## Mejoras incluidas

- [x] Menú interactivo al usar `irm | iex`
- [x] 3 mirrors de descarga con reintento aleatorio
- [x] Verificación SHA256 post-descarga
- [x] Validación SSL de certificados
- [x] Auto-elevación (UAC) si no es admin
- [x] Forzar encoding ASCII para cmd.exe
- [x] Timeout de 30s por descarga
- [x] Detección de antivirus de terceros
- [x] Detección de AutoRun en CMD
- [x] Modo dry-run
- [x] Logging con Start-Transcript
- [x] Limpieza de archivo temporal
- [x] Flags: -Action, -SkipHashCheck, -LogPath

## Actualizar hash

Si el MAS original cambia:

```powershell
.\compute_hash.ps1 -Url https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/refs/heads/master/MAS/All-In-One-Version-KL/MAS_AIO.cmd
```

Copia el hash en `launcher.ps1`, línea `$expectedHash`.
