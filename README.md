# MAS Custom Launcher

Launcher mejorado para Microsoft Activation Scripts.

## Uso directo (irm | iex)

```powershell
# Ayuda
irm https://raw.githubusercontent.com/TU_USER/TU_REPO/main/launcher.ps1 | iex

# Activar Windows
irm https://raw.githubusercontent.com/TU_USER/TU_REPO/main/launcher.ps1 | iex -Action activate

# Solo ver estado
irm https://raw.githubusercontent.com/TU_USER/TU_REPO/main/launcher.ps1 | iex -Action status

# Simulación sin ejecutar
irm https://raw.githubusercontent.com/TU_USER/TU_REPO/main/launcher.ps1 | iex -Action dryrun
```

## Uso local

```powershell
.\launcher.ps1
.\launcher.ps1 -Action activate
.\launcher.ps1 -Action dryrun
```

## Publicar en GitHub

1. Sube `launcher.ps1` a un repo público en GitHub
2. Obtén la URL raw: `https://raw.githubusercontent.com/USER/REPO/main/launcher.ps1`
3. Úsala con: `irm <URL> | iex`

## Actualizar hash

Si el script destino cambia:

```powershell
.\compute_hash.ps1 -Url https://raw.githubusercontent.com/massgravel/.../MAS_AIO.cmd
```

Copia el hash resultante en `launcher.ps1`, línea `$expectedHash`.

## Mejoras incluidas

- [x] Validación SSL de certificados
- [x] Verificación SHA256 post-descarga
- [x] Auto-elevación (UAC) si no es admin
- [x] Detección de PowerShell version + Language Mode
- [x] Forzar encoding ASCII para cmd.exe
- [x] Timeout de 30s por descarga
- [x] 3 mirrors con reintento aleatorio
- [x] Detección de antivirus de terceros
- [x] Detección de AutoRun en CMD
- [x] Confirmación previa a la ejecución
- [x] Modo dry-run
- [x] Logging con Start-Transcript
- [x] Argumentos sanitizados
- [x] Flags: -Action, -SkipHashCheck, -LogPath
- [x] Limpieza de archivo temporal
