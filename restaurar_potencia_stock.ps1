[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'victus_common.ps1')

Initialize-VictusConsoleEncoding
Assert-VictusAdministrator -ActionHint 'restaurar configuraciones originales de energia, NVIDIA y registro'

$backupDir = Join-Path $scriptDir 'backup'
$logPath = Join-Path $backupDir 'victus_unlock.log'
$manifestPath = Join-Path $backupDir 'backup_manifest.json'
$powBackupPath = Join-Path $backupDir 'power_scheme_backup.pow'
$npiExe = Join-Path $scriptDir 'bin\npi\nvidiaProfileInspector.exe'
$npiDir = Split-Path -Parent $npiExe
$ryzenAdjExe = Join-Path $scriptDir 'bin\ryzenadj\ryzenadj.exe'
$startupTaskName = 'VictusPowerUnlock_AC_Startup'

if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

Write-VictusLog -Level 'STEP' -Message '=== HP Victus Power Unlocker - Rollback a Valores Originales ===' -LogPath $logPath

$manifest = $null
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-VictusLog -Level 'INFO' -Message "Manifiesto de respaldo cargado: $manifestPath" -LogPath $logPath
    } catch {
        Write-VictusLog -Level 'WARN' -Message "No se pudo leer '$manifestPath'; se usaran valores stock explicitos: $($_.Exception.Message)" -LogPath $logPath
    }
}

$stockPowerSettings = Get-VictusPowerSettingsTable

# ==============================================================================
# [1] Restaurar Plan PowerCfg
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[1/5] Restaurando configuracion de energia (PowerCfg)...' -LogPath $logPath
$restoredFromPow = $false
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

if (Test-Path -LiteralPath $powBackupPath) {
    $targetGuid = if ($manifest -and $manifest.ActiveSchemeGuid) { "$($manifest.ActiveSchemeGuid)".ToLowerInvariant() } else { Get-ActivePowerSchemeGuid }

    $tempImportRaw = (& powercfg /import $powBackupPath | Out-String)
    if ($LASTEXITCODE -eq 0 -and $tempImportRaw -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        $tempGuid = $Matches[1].ToLowerInvariant()
        & powercfg /setactive $tempGuid | Out-Null
        if ($LASTEXITCODE -eq 0) {
            if ($tempGuid -ne $targetGuid) {
                & powercfg /delete $targetGuid 2>$null | Out-Null
                & powercfg /import $powBackupPath $targetGuid | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    & powercfg /setactive $targetGuid | Out-Null
                    & powercfg /delete $tempGuid 2>$null | Out-Null
                    $restoredFromPow = $true
                    Write-VictusLog -Level 'OK' -Message "Plan original restaurado desde '$powBackupPath' en GUID '$targetGuid'." -LogPath $logPath
                } else {
                    Write-VictusLog -Level 'WARN' -Message "No se pudo reasignar GUID original '$targetGuid'; plan restaurado activo bajo GUID '$tempGuid'." -LogPath $logPath
                    $restoredFromPow = $true
                }
            } else {
                $restoredFromPow = $true
                Write-VictusLog -Level 'OK' -Message "Plan restaurado desde '$powBackupPath' (GUID '$tempGuid')." -LogPath $logPath
            }
        } else {
            & powercfg /delete $tempGuid 2>$null | Out-Null
        }
    }
}

if (-not $restoredFromPow) {
    Write-VictusLog -Level 'INFO' -Message 'Aplicando restauracion explicita de valores PowerCfg en SCHEME_CURRENT...' -LogPath $logPath
    foreach ($item in $stockPowerSettings) {
        $targetVal = $item.StockValue
        $label = $item.StockHex
        if ($manifest -and $manifest.PowerCfgBaseline) {
            $matchEntry = $manifest.PowerCfgBaseline | Where-Object { $_.Setting -eq $item.Setting } | Select-Object -First 1
            if ($matchEntry -and $null -ne $matchEntry.AcValue) {
                $targetVal = [uint32]$matchEntry.AcValue
                $label = "0x{0:x} ($targetVal) [desde manifiesto]" -f $targetVal
            }
        }
        & powercfg /setacvalueindex SCHEME_CURRENT $item.Subgroup $item.Setting $targetVal | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-VictusLog -Level 'OK' -Message "  $($item.Name) -> AC = $label" -LogPath $logPath
        } else {
            Write-VictusLog -Level 'WARN' -Message "  No se pudo restaurar $($item.Name) (exit code $LASTEXITCODE)" -LogPath $logPath
        }
    }
    & powercfg /setactive SCHEME_CURRENT | Out-Null
}
$ErrorActionPreference = $prevPref

# ==============================================================================
# [2] Restaurar Perfil NVIDIA DRS
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[2/5] Restaurando perfil NVIDIA (Base Profile)...' -LogPath $logPath
if (Test-Path -LiteralPath $npiExe) {
    $tempStockNip = Join-Path $env:TEMP ("victus_nvidia_stock_{0}.nip" -f ([guid]::NewGuid().ToString('N')))
    $stockNipXml = @'
<?xml version="1.0" encoding="utf-8"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings>
      <ProfileSetting>
        <SettingNameInfo>Power Management - Mode</SettingNameInfo>
        <SettingID>274197361</SettingID>
        <SettingValue>5</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Battery Boost</SettingNameInfo>
        <SettingID>269573257</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Battery Boost - Application FPS Limit</SettingNameInfo>
        <SettingID>269573260</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Whisper Mode</SettingNameInfo>
        <SettingID>269573258</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Whisper Mode Application FPS</SettingNameInfo>
        <SettingID>269573259</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Power Management - External Quiet Mode</SettingNameInfo>
        <SettingID>269573261</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred Refreshrate</SettingNameInfo>
        <SettingID>6600001</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Ultra Low Latency - CPL State</SettingNameInfo>
        <SettingID>390467</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Threaded Optimization</SettingNameInfo>
        <SettingID>549528094</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>CUDA - Force P2 State</SettingNameInfo>
        <SettingID>1343646814</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@

    try {
        [System.IO.File]::WriteAllText($tempStockNip, $stockNipXml, (New-Object System.Text.UTF8Encoding($false)))
        $resetRc = Invoke-NativeToolChecked -FilePath $npiExe -ArgumentList @('-silentImport', '-mergeImport', "`"$tempStockNip`"") -WorkingDirectory $npiDir -Description 'nvidiaProfileInspector (defaults NVIDIA)' -LogPath $logPath
        Write-VictusLog -Level 'OK' -Message "Base Profile NVIDIA restablecido a defaults de fabrica (Power Mode = 5 Optimal, CUDA P2 = 1). Exit code: $resetRc" -LogPath $logPath

        $backupNipPath = $null
        if ($manifest -and $manifest.NpiBackupFile) {
            $candidate = Join-Path $backupDir $manifest.NpiBackupFile
            if (Test-Path -LiteralPath $candidate) {
                $backupNipPath = $candidate
            }
        }
        if (-not $backupNipPath) {
            $foundBackupNip = Get-ChildItem -LiteralPath $backupDir -Filter 'CustomProfiles_*.nip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -First 1
            if ($foundBackupNip) {
                $backupNipPath = $foundBackupNip.FullName
            }
        }

        if ($backupNipPath) {
            $rawNip = Get-Content -LiteralPath $backupNipPath -Raw -ErrorAction SilentlyContinue
            if ($rawNip -and $rawNip -match '<Profile>') {
                $restoreRc = Invoke-NativeToolChecked -FilePath $npiExe -ArgumentList @('-silentImport', '-mergeImport', "`"$backupNipPath`"") -WorkingDirectory $npiDir -Description 'nvidiaProfileInspector (respaldo previo)' -LogPath $logPath
                Write-VictusLog -Level 'OK' -Message "Perfiles personalizados previos reimportados desde '$backupNipPath'. Exit code: $restoreRc" -LogPath $logPath
            } else {
                Write-VictusLog -Level 'INFO' -Message "El respaldo '$backupNipPath' no contenia overrides adicionales." -LogPath $logPath
            }
        }
    } finally {
        if (Test-Path -LiteralPath $tempStockNip) {
            Remove-Item -LiteralPath $tempStockNip -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-VictusLog -Level 'WARN' -Message "No se encontro '$npiExe'; se omite restauracion de perfil NVIDIA." -LogPath $logPath
}

# ==============================================================================
# [3] Restaurar High Definition Audio Bus MSI a 0 (o valor original)
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[3/5] Restaurando estado MSI en PCI High Definition Audio Bus...' -LogPath $logPath
$hdaNodes = @(Get-HdaAudioPciNodes)
if ($hdaNodes.Count -eq 0) {
    Write-VictusLog -Level 'WARN' -Message "No se encontro dispositivo PCI '*\4&98c338a&0&0141'." -LogPath $logPath
} else {
    foreach ($node in $hdaNodes) {
        $msiKey = Join-Path $node.PSPath 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
        $restoreMsiVal = 0
        if ($manifest -and $manifest.HdaMsiBaseline) {
            $entry = $manifest.HdaMsiBaseline | Where-Object { $_.DevicePath -eq $node.PSPath } | Select-Object -First 1
            if ($entry -and $null -ne $entry.OriginalMSISupport) {
                $restoreMsiVal = [int]$entry.OriginalMSISupport
            }
        }
        if (Test-Path -LiteralPath $msiKey) {
            Set-ItemProperty -LiteralPath $msiKey -Name 'MSISupported' -Value $restoreMsiVal -Type DWord
            Write-VictusLog -Level 'OK' -Message "  MSISupported = $restoreMsiVal (DWord) restaurado en $($node.PSChildName)." -LogPath $logPath
        }
    }
}

# ==============================================================================
# [4] Reactivar Tareas Programadas y limpiar tarea opcional de inicio
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[4/5] Reactivando tareas programadas de NVIDIA y Windows Sustainability...' -LogPath $logPath
$tasks = @(Get-TargetScheduledTasks)
foreach ($task in $tasks) {
    $shouldEnable = $true
    if ($manifest -and $manifest.ScheduledTasks) {
        $origTask = $manifest.ScheduledTasks | Where-Object { $_.TaskPath -eq $task.TaskPath -and $_.TaskName -eq $task.TaskName } | Select-Object -First 1
        if ($origTask -and $origTask.State -eq 'Disabled') {
            $shouldEnable = $false
        }
    }

    if ($shouldEnable) {
        try {
            Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
            Write-VictusLog -Level 'OK' -Message "  Tarea reactivada: $($task.TaskPath)$($task.TaskName)" -LogPath $logPath
        } catch {
            Write-VictusLog -Level 'WARN' -Message "  No se pudo reactivar $($task.TaskPath)$($task.TaskName): $($_.Exception.Message)" -LogPath $logPath
        }
    } else {
        Write-VictusLog -Level 'INFO' -Message "  Tarea mantenida deshabilitada segun estado original: $($task.TaskPath)$($task.TaskName)" -LogPath $logPath
    }
}

$existingStartup = Get-ScheduledTask -TaskName $startupTaskName -ErrorAction SilentlyContinue
if ($existingStartup) {
    Unregister-ScheduledTask -TaskName $startupTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-VictusLog -Level 'OK' -Message "Tarea opcional '$startupTaskName' eliminada." -LogPath $logPath
}

# ==============================================================================
# [5] Nota sobre RyzenAdj SMU
# ==============================================================================
Write-VictusLog -Level 'STEP' -Message '[5/5] Verificando estado SMU (RyzenAdj)...' -LogPath $logPath
Write-VictusLog -Level 'INFO' -Message 'Los limites SMU de RyzenAdj son volatiles y se restablecen automaticamente a valores HP/amdpmf tras reiniciar o suspender.' -LogPath $logPath
if (Test-Path -LiteralPath $ryzenAdjExe) {
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $ryzenAdjExe -i
    $ErrorActionPreference = $prevPref
}

Write-VictusLog -Level 'OK' -Message '=== Rollback completado. Reinicia el equipo para aplicar el cambio de MSI Audio y restablecer registros SMU por completo. ===' -LogPath $logPath
