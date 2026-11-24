# Shared helpers and GUID definitions for HP Victus Power Unlocker Suite

function Initialize-VictusConsoleEncoding {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        # Ignorar si el host actual no permite reasignar OutputEncoding
    }
}

function Assert-VictusAdministrator {
    param(
        [string]$ActionHint = 'ejecutar esta herramienta'
    )
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script requiere privilegios de Administrador para $ActionHint. Ejecuta DESBLOQUEAR_POTENCIA_VICTUS.bat o abre PowerShell como Administrador."
    }
}

function Write-VictusLog {
    param(
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    try {
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    } catch {
        # No abortar por bloqueo puntual de archivo de log
    }
}

function Get-ActivePowerSchemeGuid {
    $raw = (& powercfg /getactivescheme | Out-String)
    if ($raw -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        return $Matches[1].ToLowerInvariant()
    }
    throw "No se pudo determinar el GUID del plan de energia activo mediante 'powercfg /getactivescheme'."
}

function Get-PowerCfgSettingAcIndex {
    param(
        [Parameter(Mandatory = $true)][string]$SchemeGuid,
        [Parameter(Mandatory = $true)][string]$SubgroupGuid,
        [Parameter(Mandatory = $true)][string]$SettingGuid
    )
    try {
        $lines = & powercfg /qh $SchemeGuid $SubgroupGuid 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $lines) {
            return $null
        }
        $inTargetSetting = $false
        foreach ($line in $lines) {
            if ($line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
                $foundGuid = $Matches[1].ToLowerInvariant()
                if ($foundGuid -eq $SettingGuid.ToLowerInvariant()) {
                    $inTargetSetting = $true
                    continue
                }
                if ($inTargetSetting -and $line -match 'GUID') {
                    break
                }
            }
            if ($inTargetSetting -and ($line -match 'corriente alterna|AC Power Setting') -and ($line -match '0x([0-9a-fA-F]+)')) {
                return [Convert]::ToUInt32($Matches[1], 16)
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Get-HdaAudioPciNodes {
    $nodes = @()
    $pciParents = Get-ChildItem -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue
    foreach ($parent in $pciParents) {
        $children = Get-ChildItem -LiteralPath $parent.PSPath -ErrorAction SilentlyContinue
        foreach ($child in $children) {
            $svc = (Get-ItemProperty -LiteralPath $child.PSPath -Name 'Service' -ErrorAction SilentlyContinue).Service
            $desc = (Get-ItemProperty -LiteralPath $child.PSPath -Name 'DeviceDesc' -ErrorAction SilentlyContinue).DeviceDesc
            if ($svc -eq 'HDAudBus' -or ($desc -and $desc -match 'High Definition Audio') -or $child.PSChildName -eq '4&98c338a&0&0141') {
                $nodes += $child
            }
        }
    }
    return $nodes
}

function Get-TargetScheduledTasks {
    $tasks = @()
    $tasks += @(Get-ScheduledTask -TaskName 'NvDriverUpdateCheckDaily_*' -ErrorAction SilentlyContinue)
    $tasks += @(Get-ScheduledTask -TaskName 'NVIDIA App SelfUpdate_*' -ErrorAction SilentlyContinue)
    $tasks += @(Get-ScheduledTask -TaskPath '\Microsoft\Windows\Sustainability\' -TaskName 'SustainabilityTelemetry' -ErrorAction SilentlyContinue)
    $tasks += @(Get-ScheduledTask -TaskPath '\Microsoft\Windows\Sustainability\' -TaskName 'PowerGridForecastTask' -ErrorAction SilentlyContinue)
    return ($tasks | Where-Object { $_ -ne $null } | Sort-Object TaskPath, TaskName -Unique)
}

function Invoke-NativeToolChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait -PassThru -NoNewWindow
    Write-VictusLog -Level 'INFO' -Message "$Description finalizo con codigo de salida: $($proc.ExitCode)" -LogPath $LogPath
    return $proc.ExitCode
}

function Get-VictusPowerSettingsTable {
    # Fuente unica de verdad de GUIDs verificados en POWERCFG_AUDIT.md
    return @(
        [pscustomobject]@{ Name = 'CPMINCORES1 (Zen 4c Min Cores)'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '0cc5b647-c1df-4637-891a-dec35c318584'; UnlockValue = 100; UnlockHex = '0x64 (100%)';                    StockValue = 0;    StockHex = '0x0 (0%)' }
        [pscustomobject]@{ Name = 'CPMINCORES (Zen 4 Min Cores)';   Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '0cc5b647-c1df-4637-891a-dec35c318583'; UnlockValue = 100; UnlockHex = '0x64 (100%)';                    StockValue = 100;  StockHex = '0x64 (100%)' }
        [pscustomobject]@{ Name = 'SCHEDPOLICY (Hetero Policy)';    Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '93b8b6dc-0698-4d1c-9ee4-0644e900c85d'; UnlockValue = 2;   UnlockHex = '0x2 (Preferir mejor rendimiento)'; StockValue = 5;    StockHex = '0x5 (Automatico)' }
        [pscustomobject]@{ Name = 'SHORTSCHEDPOLICY (Short Runs)';  Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = 'bae08b81-2d5e-4688-ad6a-13243356654b'; UnlockValue = 2;   UnlockHex = '0x2 (Preferir mejor rendimiento)'; StockValue = 2;    StockHex = '0x2 (Preferir mejor rend.)' }
        [pscustomobject]@{ Name = 'PERFBOOSTMODE (Boost Mode)';     Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = 'be337238-0d82-4146-a960-4f3749d470c7'; UnlockValue = 2;   UnlockHex = '0x2 (Agresivo)';                   StockValue = 2;    StockHex = '0x2 (Agresiva)' }
        [pscustomobject]@{ Name = 'LATENCYHINTEPP';                 Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '4b70f900-cdd9-4e66-aa26-ae8417f98173'; UnlockValue = 0;   UnlockHex = '0x0 (0%)';                         StockValue = 100;  StockHex = '0x64 (100%)' }
        [pscustomobject]@{ Name = 'LATENCYHINTEPP1';                Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '4b70f900-cdd9-4e66-aa26-ae8417f98174'; UnlockValue = 0;   UnlockHex = '0x0 (0%)';                         StockValue = 100;  StockHex = '0x64 (100%)' }
        [pscustomobject]@{ Name = 'LATENCYHINTEPP2';                Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '4b70f900-cdd9-4e66-aa26-ae8417f98175'; UnlockValue = 0;   UnlockHex = '0x0 (0%)';                         StockValue = 100;  StockHex = '0x64 (100%)' }
        [pscustomobject]@{ Name = 'NVMEPRIMARYIDLETIMEOUT';         Subgroup = '0012ee47-9041-4b5d-9b77-535fba8b1442'; Setting = 'd639518a-e56d-4345-8af2-b9f32fb26109'; UnlockValue = 0;   UnlockHex = '0x0 (0 ms)';                       StockValue = 200;  StockHex = '0xc8 (200 ms)' }
        [pscustomobject]@{ Name = 'Secondary NVMe Idle Timeout';    Subgroup = '0012ee47-9041-4b5d-9b77-535fba8b1442'; Setting = 'd3d55efd-c1ff-424e-9dc3-441be7833010'; UnlockValue = 0;   UnlockHex = '0x0 (0 ms)';                       StockValue = 2000; StockHex = '0x7d0 (2000 ms)' }
        [pscustomobject]@{ Name = 'USB Selective Suspend';          Subgroup = '2a737441-1930-4402-8d77-b2bebba308a3'; Setting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'; UnlockValue = 0;   UnlockHex = '0x0 (Deshabilitado)';              StockValue = 1;    StockHex = '0x1 (Habilitado)' }
        [pscustomobject]@{ Name = 'USB 3 Link Power Management';    Subgroup = '2a737441-1930-4402-8d77-b2bebba308a3'; Setting = 'd4e98f31-5ffe-4ce1-be31-1b38b384c009'; UnlockValue = 0;   UnlockHex = '0x0 (Off)';                        StockValue = 2;    StockHex = '0x2 (Moderate savings)' }
        [pscustomobject]@{ Name = 'SUB_PCIEXPRESS ASPM';            Subgroup = '501a4d13-42af-4429-9fd1-a8218c268e20'; Setting = 'ee12f906-d277-404b-b6da-e5fa1a576df5'; UnlockValue = 0;   UnlockHex = '0x0 (Desactivado)';                StockValue = 0;    StockHex = '0x0 (Desactivar)' }
        [pscustomobject]@{ Name = 'Graficos Dinamicos Intercamb.';  Subgroup = 'e276e160-7cb0-43c6-b20b-73f5dce39954'; Setting = 'a1662ab2-9d34-4e53-ba8b-2639b9e20857'; UnlockValue = 3;   UnlockHex = '0x3 (Maximizar rendimiento)';      StockValue = 2;    StockHex = '0x2 (Optimizar rendimiento)' }
    )
}
