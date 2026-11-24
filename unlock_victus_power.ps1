[CmdletBinding()]
param(
    [ValidateSet('1', '2', '3', '4', 'BackupOnly')]
    [string]$Mode = '1',

    [ValidateSet('1', '2')]
    [string]$RyzenSubMode = '1',

    [switch]$LaunchOmenCore,
    [switch]$InstallAfterburner,
    [switch]$InstallStartupTask,
    [switch]$OnlyOnAC
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'victus_common.ps1')

Initialize-VictusConsoleEncoding
Assert-VictusAdministrator -ActionHint 'desbloquear energia, perfiles NVIDIA y registros SMU'

$backupDir = Join-Path $scriptDir 'backup'
$snapshotsDir = Join-Path $backupDir 'snapshots'
$logPath = Join-Path $backupDir 'victus_unlock.log'
$manifestPath = Join-Path $backupDir 'backup_manifest.json'
$powBackupPath = Join-Path $backupDir 'power_scheme_backup.pow'

$npiExe = Join-Path $scriptDir 'bin\npi\nvidiaProfileInspector.exe'
$npiDir = Split-Path -Parent $npiExe
$nipPath = Join-Path $scriptDir 'profiles\victus_max_perf.nip'
$ryzenAdjExe = Join-Path $scriptDir 'bin\ryzenadj\ryzenadj.exe'
$omenExe = Join-Path $scriptDir 'bin\omencore\OmenCore.exe'
$afterburnerExe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
$startupTaskName = 'VictusPowerUnlock_AC_Startup'

if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

function Test-IsOnACPower {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        return ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online)
    } catch {
        $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if (-not $batteries) {
            return $true
        }
        return (@($batteries | Where-Object { $_.BatteryStatus -in @(2, 6, 7, 8, 9) }).Count -gt 0)
    }
}

if ($OnlyOnAC -and -not (Test-IsOnACPower)) {
    Write-VictusLog -Level 'INFO' -Message 'Equipo en bateria y -OnlyOnAC activo; se omite el desbloqueo hasta conectar cargador AC.' -LogPath $logPath
    exit 0
}

$powerCfgSettings = Get-VictusPowerSettingsTable

Write-VictusLog -Level 'STEP' -Message "=== HP Victus Power Unlocker Suite | Modo=$Mode ===" -LogPath $logPath

# ==============================================================================
# [Backup] Respaldo inicial de PowerCfg, NPI DRS y PCI Audio MSI
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[Backup] Generando / verificando respaldos previos...' -LogPath $logPath
$activeGuid = Get-ActivePowerSchemeGuid
Write-VictusLog -Level 'INFO' -Message "Plan de energia activo detectado: $activeGuid" -LogPath $logPath

$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$hasBaselinePow = Test-Path -LiteralPath $powBackupPath
$hasBaselineManifest = Test-Path -LiteralPath $manifestPath

if (-not $hasBaselinePow) {
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powercfg /export $powBackupPath $activeGuid | Out-Null
    $exportRc = $LASTEXITCODE
    $ErrorActionPreference = $prevPref
    if ($exportRc -ne 0 -or -not (Test-Path -LiteralPath $powBackupPath)) {
        throw "Fallo al exportar el plan de energia actual a '$powBackupPath' (exit code $exportRc)."
    }
    Write-VictusLog -Level 'OK' -Message "Respaldo de plan PowerCfg guardado en: $powBackupPath" -LogPath $logPath
} else {
    if (-not (Test-Path -LiteralPath $snapshotsDir)) {
        New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
    }
    $snapPow = Join-Path $snapshotsDir "power_scheme_$stamp.pow"
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powercfg /export $snapPow $activeGuid | Out-Null
    $ErrorActionPreference = $prevPref
    Write-VictusLog -Level 'INFO' -Message "Respaldo original PowerCfg preservado; snapshot pre-ejecucion guardado en: $snapPow" -LogPath $logPath
}

$exportedNpiBaselineName = $null
if (Test-Path -LiteralPath $npiExe) {
    $preExistingNips = @(Get-ChildItem -LiteralPath $npiDir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $npiExportRc = Invoke-NativeToolChecked -FilePath $npiExe -ArgumentList @('-exportCustomized') -WorkingDirectory $npiDir -Description 'nvidiaProfileInspector -exportCustomized' -LogPath $logPath

    $postNips = @(Get-ChildItem -LiteralPath $npiDir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue | Where-Object { $preExistingNips -notcontains $_.FullName })
    if (-not $postNips) {
        $postNips = @(Get-ChildItem -LiteralPath $npiDir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    }

    if ($postNips -and $postNips.Count -gt 0) {
        $existingBackupNips = @(Get-ChildItem -LiteralPath $backupDir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue)
        foreach ($nipFile in $postNips) {
            if ($existingBackupNips.Count -eq 0 -and -not $exportedNpiBaselineName) {
                $destPath = Join-Path $backupDir $nipFile.Name
                Move-Item -LiteralPath $nipFile.FullName -Destination $destPath -Force
                $exportedNpiBaselineName = $nipFile.Name
                Write-VictusLog -Level 'OK' -Message "Respaldo inicial de perfiles NVIDIA movido a: $destPath" -LogPath $logPath
            } else {
                if (-not (Test-Path -LiteralPath $snapshotsDir)) {
                    New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
                }
                $snapNip = Join-Path $snapshotsDir $nipFile.Name
                Move-Item -LiteralPath $nipFile.FullName -Destination $snapNip -Force
                Write-VictusLog -Level 'INFO' -Message "Respaldo original NPI preservado; snapshot movido a: $snapNip" -LogPath $logPath
            }
        }
    } elseif ($npiExportRc -eq 0) {
        Write-VictusLog -Level 'INFO' -Message 'nvidiaProfileInspector -exportCustomized no genero archivo nuevo (sin perfiles personalizados previos).' -LogPath $logPath
    } else {
        Write-VictusLog -Level 'WARN' -Message "nvidiaProfileInspector -exportCustomized devolvio codigo $npiExportRc." -LogPath $logPath
    }
} else {
    Write-VictusLog -Level 'WARN' -Message "No se encontro nvidiaProfileInspector.exe en '$npiExe'; se omite respaldo DRS." -LogPath $logPath
}

$hdaNodes = @(Get-HdaAudioPciNodes)
$hdaStates = @()
foreach ($node in $hdaNodes) {
    $msiSubKey = Join-Path $node.PSPath 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
    $currentMsi = $null
    if (Test-Path -LiteralPath $msiSubKey) {
        $prop = Get-ItemProperty -LiteralPath $msiSubKey -Name 'MSISupported' -ErrorAction SilentlyContinue
        if ($null -ne $prop) {
            $currentMsi = $prop.MSISupported
        }
    }
    $hdaStates += [pscustomobject]@{
        DevicePath         = $node.PSPath
        MsiKeyPath         = $msiSubKey
        OriginalMSISupport = $currentMsi
    }
    Write-VictusLog -Level 'INFO' -Message "Estado actual High Def Audio Bus ($($node.PSChildName)) MSISupported = $(if ($null -eq $currentMsi) { '<no definido>' } else { $currentMsi })" -LogPath $logPath
}

if (-not $hasBaselineManifest) {
    $powerBaselineValues = @()
    foreach ($item in $powerCfgSettings) {
        $acVal = Get-PowerCfgSettingAcIndex -SchemeGuid $activeGuid -SubgroupGuid $item.Subgroup -SettingGuid $item.Setting
        $powerBaselineValues += [pscustomobject]@{
            Name     = $item.Name
            Subgroup = $item.Subgroup
            Setting  = $item.Setting
            AcValue  = $acVal
        }
    }

    $taskStates = @()
    foreach ($t in (Get-TargetScheduledTasks)) {
        $taskStates += [pscustomobject]@{
            TaskPath = $t.TaskPath
            TaskName = $t.TaskName
            State    = "$($t.State)"
        }
    }

    $manifestObj = [pscustomobject]@{
        CreatedAtUtc     = (Get-Date).ToUniversalTime().ToString('o')
        ActiveSchemeGuid = $activeGuid
        PowerBackupFile  = 'power_scheme_backup.pow'
        NpiBackupFile    = $exportedNpiBaselineName
        PowerCfgBaseline = $powerBaselineValues
        HdaMsiBaseline   = $hdaStates
        ScheduledTasks   = $taskStates
    }
    $manifestObj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-VictusLog -Level 'OK' -Message "Manifiesto de respaldo inicial guardado en: $manifestPath" -LogPath $logPath
}

if ($Mode -eq 'BackupOnly') {
    Write-VictusLog -Level 'OK' -Message 'Modo BackupOnly completado sin aplicar modificaciones.' -LogPath $logPath
    if (Test-Path -LiteralPath $ryzenAdjExe) {
        Write-VictusLog -Level 'INFO' -Message 'Lectura informativa actual RyzenAdj (-i):' -LogPath $logPath
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $ryzenAdjExe -i
        $ErrorActionPreference = $prevPref
    }
    exit 0
}

# ==============================================================================
# [Layer 1] Desbloqueo profundo de PowerCfg en AC (SCHEME_CURRENT)
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[Layer 1] Aplicando desbloqueo profundo PowerCfg en AC (SCHEME_CURRENT)...' -LogPath $logPath
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
foreach ($item in $powerCfgSettings) {
    & powercfg /setacvalueindex SCHEME_CURRENT $item.Subgroup $item.Setting $item.UnlockValue | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-VictusLog -Level 'OK' -Message "  $($item.Name) -> AC = $($item.UnlockHex)" -LogPath $logPath
    } else {
        Write-VictusLog -Level 'WARN' -Message "  No se pudo ajustar $($item.Name) (exit code $LASTEXITCODE)" -LogPath $logPath
    }
}
& powercfg /setactive SCHEME_CURRENT | Out-Null
$setActiveRc = $LASTEXITCODE
$ErrorActionPreference = $prevPref

if ($setActiveRc -eq 0) {
    Write-VictusLog -Level 'OK' -Message "Plan activo SCHEME_CURRENT confirmado con 'powercfg /setactive SCHEME_CURRENT'." -LogPath $logPath
} else {
    Write-VictusLog -Level 'WARN' -Message "'powercfg /setactive SCHEME_CURRENT' devolvio codigo $setActiveRc." -LogPath $logPath
}

# ==============================================================================
# [Layer 2] Deshabilitar telemetria NVIDIA/Windows + activar MSI en Audio HD Bus
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[Layer 2] Deshabilitando tareas de telemetria y activando MSI en High Definition Audio Bus...' -LogPath $logPath
$tasksToDisable = @(Get-TargetScheduledTasks)
if ($tasksToDisable.Count -eq 0) {
    Write-VictusLog -Level 'INFO' -Message 'No se encontraron tareas programadas de telemetria activas/coincidentes.' -LogPath $logPath
} else {
    foreach ($task in $tasksToDisable) {
        try {
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
            Write-VictusLog -Level 'OK' -Message "  Tarea deshabilitada: $($task.TaskPath)$($task.TaskName)" -LogPath $logPath
        } catch {
            Write-VictusLog -Level 'WARN' -Message "  No se pudo deshabilitar $($task.TaskPath)$($task.TaskName): $($_.Exception.Message)" -LogPath $logPath
        }
    }
}

if ($hdaNodes.Count -eq 0) {
    Write-VictusLog -Level 'WARN' -Message "No se encontro dispositivo PCI '*\4&98c338a&0&0141' (High Definition Audio Bus)." -LogPath $logPath
} else {
    foreach ($node in $hdaNodes) {
        $msiKey = Join-Path $node.PSPath 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
        if (-not (Test-Path -LiteralPath $msiKey)) {
            New-Item -Path $msiKey -Force | Out-Null
            Write-VictusLog -Level 'INFO' -Message "  Subclave creada: $msiKey" -LogPath $logPath
        }
        Set-ItemProperty -LiteralPath $msiKey -Name 'MSISupported' -Value 1 -Type DWord
        Write-VictusLog -Level 'OK' -Message "  MSISupported = 1 (DWord) aplicado en $($node.PSChildName) (efectivo tras reiniciar)." -LogPath $logPath
    }
}

# ==============================================================================
# [Layer 3] Importar perfil NVIDIA Profile Inspector (Base Profile)
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message "[Layer 3] Importando perfil NVIDIA 'victus_max_perf.nip'..." -LogPath $logPath
if (-not (Test-Path -LiteralPath $npiExe)) {
    throw "No se encontro '$npiExe'."
}
if (-not (Test-Path -LiteralPath $nipPath)) {
    throw "No se encontro el perfil '$nipPath'."
}

$npiImportRc = Invoke-NativeToolChecked -FilePath $npiExe -ArgumentList @('-silentImport', '-mergeImport', "`"$nipPath`"") -WorkingDirectory $npiDir -Description 'nvidiaProfileInspector -silentImport -mergeImport' -LogPath $logPath
if ($npiImportRc -ne 0) {
    throw "nvidiaProfileInspector.exe fallo al importar '$nipPath' (exit code $npiImportRc)."
}
Write-VictusLog -Level 'OK' -Message 'Perfil NVIDIA Base Profile importado correctamente (Power Management = 1, CUDA P2 = Off, Shader Cache = 10GB, ULL = On).' -LogPath $logPath

# ==============================================================================
# [Layer 4] RyzenAdj SMU Power Unlock + OmenCore + MSI Afterburner
# ==============================================================================
$effectiveRyzenMode = if ($Mode -eq '4') { $RyzenSubMode } else { $Mode }

if ($Mode -eq '3') {
    Write-VictusLog -Level 'STEP' -Message '[Layer 4] Modo 3 seleccionado: se omite RyzenAdj (solo Windows PowerCfg + Driver NVIDIA).' -LogPath $logPath
} else {
    Write-VictusLog -Level 'STEP' -Message "[Layer 4] Aplicando desbloqueo SMU via RyzenAdj (PawnIO + RyzenSMU, Perfil $effectiveRyzenMode)..." -LogPath $logPath
    if (-not (Test-Path -LiteralPath $ryzenAdjExe)) {
        Write-VictusLog -Level 'WARN' -Message "No se encontro '$ryzenAdjExe'; se omite ajuste SMU en esta ejecucion." -LogPath $logPath
    } else {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        Write-VictusLog -Level 'INFO' -Message '--- Estado SMU ANTES de RyzenAdj (ryzenadj.exe -i) ---' -LogPath $logPath
        & $ryzenAdjExe -i
        if ($LASTEXITCODE -ne 0) {
            Write-VictusLog -Level 'WARN' -Message "ryzenadj.exe -i previo devolvio codigo $LASTEXITCODE." -LogPath $logPath
        }

        if ($effectiveRyzenMode -eq '1') {
            Write-VictusLog -Level 'INFO' -Message 'Perfil Gaming GPU-Priority: 38W STAPM / 42W Slow / 48W Fast / 90 C.' -LogPath $logPath
            Write-VictusLog -Level 'INFO' -Message 'Razon: evita que el Ryzen 7 7445HS acapare el presupuesto compartido de 120W para que nvpcf sostenga los 50W completos en la RTX 4050.' -LogPath $logPath
            $ryzenArgs = @('--stapm-limit=38000', '--slow-limit=42000', '--fast-limit=48000', '--tctl-temp=90')
        } else {
            Write-VictusLog -Level 'INFO' -Message 'Perfil Computo Bruto CPU Unleashed: 54W STAPM / 60W Slow / 65W Fast / 93 C / --max-performance.' -LogPath $logPath
            Write-VictusLog -Level 'INFO' -Message 'Razon: libera maxima potencia sostenida de CPU para compilacion, IA/Docker y cargas intensivas de procesador.' -LogPath $logPath
            $ryzenArgs = @('--stapm-limit=54000', '--slow-limit=60000', '--fast-limit=65000', '--tctl-temp=93', '--max-performance')
        }

        & $ryzenAdjExe @ryzenArgs
        $ryzenSetRc = $LASTEXITCODE
        if ($ryzenSetRc -ne 0) {
            Write-VictusLog -Level 'WARN' -Message "ryzenadj.exe devolvio codigo $ryzenSetRc al aplicar limites SMU; verifica que el servicio PawnIO este activo (sc query PawnIO), RyzenSMU.bin junto a ryzenadj.exe y que no haya bloqueo de HVCI/anti-cheat. Las Capas 1-3 permanecen activas (alternativa manual: OmenCore / UXTU v26.3.1 con .NET 10)." -LogPath $logPath
        } else {
            Write-VictusLog -Level 'OK' -Message 'Parametros RyzenAdj aplicados correctamente.' -LogPath $logPath

            Write-VictusLog -Level 'INFO' -Message '--- Estado SMU DESPUES de RyzenAdj (ryzenadj.exe -i) ---' -LogPath $logPath
            & $ryzenAdjExe -i
            if ($LASTEXITCODE -ne 0) {
                Write-VictusLog -Level 'WARN' -Message "ryzenadj.exe -i posterior devolvio codigo $LASTEXITCODE." -LogPath $logPath
            }
        }
        $ErrorActionPreference = $prevPref
    }
}

# Lanzar OmenCore minimizado si corresponde
if ($Mode -eq '4' -or $LaunchOmenCore) {
    Write-VictusLog -Level 'STEP' -Message '[OmenCore] Verificando OmenCore v5.0.1...' -LogPath $logPath
    if (Test-Path -LiteralPath $omenExe) {
        $runningOmen = Get-Process -Name 'OmenCore' -ErrorAction SilentlyContinue
        if ($runningOmen) {
            Write-VictusLog -Level 'INFO' -Message 'OmenCore.exe ya se encuentra ejecutandose en segundo plano.' -LogPath $logPath
        } else {
            Start-Process -FilePath $omenExe -ArgumentList '--minimized' -WorkingDirectory (Split-Path -Parent $omenExe)
            Write-VictusLog -Level 'OK' -Message 'OmenCore.exe iniciado minimizado en la bandeja del sistema (--minimized).' -LogPath $logPath
        }
    } else {
        Write-VictusLog -Level 'WARN' -Message "No se encontro OmenCore.exe en '$omenExe'." -LogPath $logPath
    }
}

# Verificar / instalar / abrir MSI Afterburner si corresponde
if ($Mode -eq '4' -or $InstallAfterburner) {
    Write-VictusLog -Level 'STEP' -Message '[MSI Afterburner] Verificando instalacion...' -LogPath $logPath
    $hasAfterburner = Test-Path -LiteralPath $afterburnerExe

    if (-not $hasAfterburner) {
        $shouldInstall = $InstallAfterburner.IsPresent
        if (-not $shouldInstall -and $Mode -eq '4') {
            $answer = Read-Host 'MSI Afterburner no esta instalado. Instalarlo via winget ahora? [S/n]'
            $shouldInstall = ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToUpperInvariant().StartsWith('S') -or $answer.Trim().ToUpperInvariant().StartsWith('Y'))
        }

        if ($shouldInstall) {
            $wingetCmd = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
            if (-not $wingetCmd) {
                Write-VictusLog -Level 'WARN' -Message 'No se encontro winget.exe en el sistema para instalar MSI Afterburner.' -LogPath $logPath
            } else {
                Write-VictusLog -Level 'INFO' -Message 'Instalando Guru3D.Afterburner via winget...' -LogPath $logPath
                $prevPref = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                & winget.exe install --id Guru3D.Afterburner --accept-package-agreements --accept-source-agreements
                $wingetRc = $LASTEXITCODE
                $ErrorActionPreference = $prevPref
                if ($wingetRc -eq 0 -and (Test-Path -LiteralPath $afterburnerExe)) {
                    $hasAfterburner = $true
                    Write-VictusLog -Level 'OK' -Message 'MSI Afterburner instalado correctamente.' -LogPath $logPath
                } else {
                    Write-VictusLog -Level 'WARN' -Message "winget finalizo con codigo $wingetRc; verifica manualmente si requiere confirmacion." -LogPath $logPath
                }
            }
        } else {
            Write-VictusLog -Level 'INFO' -Message 'Instalacion de MSI Afterburner omitida por el usuario.' -LogPath $logPath
        }
    }

    if ($hasAfterburner) {
        Write-VictusLog -Level 'OK' -Message "MSI Afterburner detectado en '$afterburnerExe'." -LogPath $logPath
        if ($Mode -eq '4') {
            $runningAb = Get-Process -Name 'MSIAfterburner' -ErrorAction SilentlyContinue
            if (-not $runningAb) {
                Start-Process -FilePath $afterburnerExe -WorkingDirectory (Split-Path -Parent $afterburnerExe)
                Write-VictusLog -Level 'OK' -Message 'MSI Afterburner iniciado para aplicar curva Undervolt (875-900 mV @ ~2400 MHz + VRAM +400..+600 MHz).' -LogPath $logPath
            } else {
                Write-VictusLog -Level 'INFO' -Message 'MSI Afterburner ya se encuentra abierto.' -LogPath $logPath
            }
        }
    }
}

# Tarea programada opcional en inicio de sesion AC
if ($InstallStartupTask) {
    $taskMode = if ($Mode -eq '4') { $RyzenSubMode } else { $Mode }
    if ($taskMode -eq '3') {
        Write-VictusLog -Level 'INFO' -Message 'Modo 3 es persistente por si mismo (Windows PowerCfg + NVIDIA DRS); no necesita tarea de reaplicacion SMU.' -LogPath $logPath
    } else {
        Write-VictusLog -Level 'STEP' -Message "[Startup Task] Registrando tarea programada '$startupTaskName' para reaplicar Modo $taskMode en inicio de sesion (solo AC)..." -LogPath $logPath
        $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Mode $taskMode -OnlyOnAC"
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $psArgs -WorkingDirectory $scriptDir
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$false -DontStopIfGoingOnBatteries:$false -StartWhenAvailable
        Register-ScheduledTask -TaskName $startupTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Write-VictusLog -Level 'OK' -Message "Tarea '$startupTaskName' registrada correctamente." -LogPath $logPath
    }
}

Write-VictusLog -Level 'STEP' -Message '=== Desbloqueo completado ===' -LogPath $logPath
Write-VictusLog -Level 'INFO' -Message 'NOTA IMPORTANTE: Windows (amdpmf) y el EC de HP restablecen los limites SMU de RyzenAdj tras suspender o reiniciar.' -LogPath $logPath
Write-VictusLog -Level 'INFO' -Message 'Los Modos 1 y 2 surten efecto inmediato y pueden reaplicarse en 1 clic desde DESBLOQUEAR_POTENCIA_VICTUS.bat (o automatizarse en inicio AC con -InstallStartupTask).' -LogPath $logPath
