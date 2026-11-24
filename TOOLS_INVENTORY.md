# Portable Tools Inventory (`victus_power_unlock`)

All official open-source tuning archives were downloaded into `bin\_archives\`, verified, and extracted into `bin\`.
Verified on host hardware: **AMD Radeon 740M Graphics** + **NVIDIA GeForce RTX 4050 Laptop GPU** (Driver `32.0.16.2124`, `nvapi64.dll` present).

---

## 1. Download Archives & SHA256 Hashes

Download the upstream releases matching the hashes below and extract them under `bin\` (`bin\ryzenadj\`, `bin\npi\`, `bin\omencore\`):

| Archive / File | Source Release | Size (bytes) | SHA256 |
|---|---|---:|---|
| `bin\_archives\ryzenadj-win64.zip` | `FlyGoat/RyzenAdj` `v0.19.0` | `140566` | `871734A2322EA61A0D83EA8373162D3E1ECF0411BA4EB7E6AEC423F4B6B95B4F` |
| `bin\_archives\nvidiaProfileInspector.zip` | `Orbmu2k/nvidiaProfileInspector` `v3.0.2.1` | `433354` | `88DCF3514111E8DE630688467C03C36D8C2A8AD9EBC8073F27C069F82B75BB40` |
| `bin\_archives\OmenCore-5.0.1-win-x64.zip` | `theantipopau/omencore` `v5.0.1` | `113549882` | `29ADEC7E75BCCE4CA62814206367A0FC9F4A0EC2B9FCE913BF681E274EF18839` *(matched `.sha256` before extraction)* |
| `bin\_archives\OmenCore-5.0.1-win-x64.zip.sha256` | `theantipopau/omencore` `v5.0.1` | `92` | `0876DC960C1FE740A47F79FBEF630D9B6C1B1BBDFA0343CBA9ABCD7D4BFB4F5E` |

---

## 2. Extracted Executables & Manifest Elevation

| Tool | Exact Executable Path | Size (bytes) | SHA256 | Runtime / UAC Manifest |
|---|---|---:|---|---|
| RyzenAdj `v0.19.0` | `bin\ryzenadj\ryzenadj.exe` | `87552` | `F9E1EF49EE221EA2E2BD5468BCAC5D58054D5EAA4F5CC5092347A17B30722CC2` | Native x64 + `libryzenadj.dll` (`498DF2E9278C33BA7BA7BFB8BDCA93033941896D9E156C37AF382D31482EDCD5`), `WinRing0x64.sys`/`dll`, `inpoutx64.dll`; manifest `asInvoker` (Admin needed at runtime for SMU/kernel driver access; `--help` runs non-elevated) |
| NVIDIA Profile Inspector `v3.0.2.1` | `bin\npi\nvidiaProfileInspector.exe` | `1043456` | `1EBD8129B3C564BF226291FB3344819FD59668066F0C5E03334A69A04A62859E` | .NET Framework `v4.8` WPF; manifest **`requireAdministrator`** (`WinError 740` if launched non-elevated) |
| OmenCore `5.0.1` (GUI) | `bin\omencore\OmenCore.exe` | `86061312` | `7CD04FDA7C0A28E491B69EBB99E887FB8F48B3D27B8821B85F67D6B529E3E9A5` | .NET 8 single-file WPF app; manifest **`requireAdministrator`** |
| OmenCore `5.0.1` (Worker) | `bin\omencore\OmenCore.HardwareWorker.exe` | `72634113` | `B258322367F1A668125217718B5A0D6A7E12603F6D367B582145A3C5F86AF7C4` | .NET 8 single-file helper; manifest `asInvoker` |

### Complete Extracted File Lists
- **`bin\ryzenadj\`**: `ryzenadj.exe`, `libryzenadj.dll`, `WinRing0x64.dll`, `WinRing0x64.sys`, `inpoutx64.dll`, `readjustService.ps1`, `readjust.py`, `pmtable-example.py`, `RyzenAdjServiceTask.xml.template`, `installServiceTask.bat`, `uninstallServiceTask.bat`, `demo.bat`
- **`bin\npi\`**: `nvidiaProfileInspector.exe`, `nvidiaProfileInspector.exe.config`, `nvidiaProfileInspector.pdb`, `Reference.xml` (`873663` bytes, SHA256 `0EA7B055AEE5C543047243D2DD7ABDD1B8C6D96F5D2B7BB5FE17BE8130E005EF`)
- **`bin\omencore\`**: `OmenCore.exe`, `OmenCore.HardwareWorker.exe`, `OmenCore.pdb`, `OmenCore.Core.pdb`, `OmenCore.HardwareWorker.pdb`, `OmenCore.NvidiaPower.pdb`, `VERSION.txt` (`5.0.1`)

---

## 3. Verified `ryzenadj.exe` (`v0.19.0`) CLI Flags

Verified directly via `bin\ryzenadj\ryzenadj.exe --help` (exit code `0`):

### Info & Help
- `-h, --help` — show help message and exit
- `-i, --info` — show information and most important power metrics after adjustment
- `--dump-table` — show whole power metric table before and after adjustment

### Power, Current, Thermal & Clock Flags
Note exact hyphen vs underscore naming in `v0.19.0`:
- `-a, --stapm-limit=<u32>` — Sustained Power Limit - STAPM LIMIT (**mW**)
- `-b, --fast-limit=<u32>` — Actual Power Limit - PPT LIMIT FAST (**mW**)
- `-c, --slow-limit=<u32>` — Average Power Limit - PPT LIMIT SLOW (**mW**)
- `-d, --slow-time=<u32>` — Slow PPT Constant Time (**s**)
- `-e, --stapm-time=<u32>` — STAPM constant time (**s**)
- `-f, --tctl-temp=<u32>` — Tctl Temperature Limit (**degree C**)
- `-g, --vrm-current=<u32>` — VRM Current Limit - TDC LIMIT VDD (**mA**)
- `-j, --vrmsoc-current=<u32>` — VRM SoC Current Limit - TDC LIMIT SoC (**mA**)
- `--vrmgfx-current=<u32>` — VRM GFX Current Limit - TDC LIMIT GFX (**mA**)
- `--vrmcvip-current=<u32>` — VRM CVIP Current Limit - TDC LIMIT CVIP (**mA**)
- `-k, --vrmmax-current=<u32>` — VRM Maximum Current Limit - EDC LIMIT VDD (**mA**)
- `-l, --vrmsocmax-current=<u32>` — VRM SoC Maximum Current Limit - EDC LIMIT SoC (**mA**)
- `--vrmgfxmax_current=<u32>` — VRM GFX Maximum Current Limit - EDC LIMIT GFX (**mA**) *(underscore!)*
- `-m, --psi0-current=<u32>` — PSI0 VDD Current Limit (**mA**)
- `--psi3cpu_current=<u32>` — PSI3 CPU Current Limit (**mA**) *(underscore!)*
- `-n, --psi0soc-current=<u32>` — PSI0 SoC Current Limit (**mA**)
- `--psi3gfx_current=<u32>` — PSI3 GFX Current Limit (**mA**) *(underscore!)*
- `-o, --max-socclk-frequency=<u32>` / `-p, --min-socclk-frequency=<u32>` — SoC Clock (MHz)
- `-q, --max-fclk-frequency=<u32>` / `-r, --min-fclk-frequency=<u32>` — Transmission CPU-GPU Fabric Clock (MHz)
- `-s, --max-vcn=<u32>` / `-t, --min-vcn=<u32>` — Video Core Next Clock (MHz)
- `-u, --max-lclk=<u32>` / `-v, --min-lclk=<u32>` — Data Launch Clock (MHz)
- `-w, --max-gfxclk=<u32>` / `-x, --min-gfxclk=<u32>` — GFX Clock (MHz)
- `-y, --prochot-deassertion-ramp=<u32>` — Ramp Time After Prochot is Deasserted
- `--apu-skin-temp=<u32>` — APU Skin Temperature Limit - STT LIMIT APU (**degree C**)
- `--dgpu-skin-temp=<u32>` — dGPU Skin Temperature Limit - STT LIMIT dGPU (**degree C**)
- `--apu-slow-limit=<u32>` — APU PPT Slow Power limit for A+A dGPU platform - PPT LIMIT APU (**mW**)
- `--skin-temp-limit=<u32>` — Skin Temperature Power Limit (**mW**)
- `--gfx-clk=<u32>`, `--oc-clk=<u32>`, `--oc-volt=<u32>`, `--enable-oc`, `--disable-oc` (Renoir and up OC options)
- `--set-coall=<u32>`, `--set-coper=<u32>`, `--set-cogfx=<u32>` (Curve Optimizer)
- `--power-saving` — Hidden option for power efficiency
- `--max-performance` — Hidden option for performance

---

## 4. Verified `nvidiaProfileInspector.exe` (`v3.0.2.1`) CLI Flags & `.nip` Schema

Verified via .NET metadata & IL inspection of `nvidiaProfileInspector.App`, `DrsImportService`, `DrsSettingsServiceBase`, and `ImportExportUitl` (non-elevated launch stops at `WinError 740` due to `requireAdministrator` manifest).

### Supported CLI Flags (`App.ParseStartupOptions` / `App.ParseImportMode`)
- **There is NO `-help` / `/?` flag** — unrecognized switches without `.nip` arguments launch the WPF GUI.
- **`-silentImport`** (alias **`-silent`**): Suppresses MessageBox dialogs during `.nip` import and exits after completion (`RequiresSingleInstanceMutex == false`).
- **`-mergeImport`**: Merges imported `.nip` settings/executables into target profiles (`ProfileImportMode.Merge = 1`), preserving all other existing settings in the profile.
- **`-replaceImport`**: Replaces target profiles' apps and deletes settings not present in the `.nip` (`ProfileImportMode.Replace = 0`).
  > **CRITICAL TRAP:** In `App.ResolveForcedImportMode()`, passing `-silentImport` (or `-silent`) **without** `-mergeImport` defaults to `ProfileImportMode.Replace` (`0`)! Always pass **both** flags when patching the global profile:
  > ```bat
  > nvidiaProfileInspector.exe -silentImport -mergeImport "C:\path\to\profile.nip"
  > ```
- **`-exportCustomized`**: Headlessly exports all customized DRS profiles to `bin\npi\CustomProfiles_yyyy-MM-dd_HH-mm-ss.nip` and exits cleanly (requires compatible NVIDIA driver unless `-mock` is supplied).
- **`-createCSN`**: Writes embedded `CustomSettingNames.xml` to disk and exits cleanly (note: keeping an external `CustomSettingNames.xml` next to the `.exe` overrides the embedded definitions on GUI startup).
- **`-showOnlyCSN`**, **`-disableScan`**, **`-mock`**: GUI/testing startup flags.

### Verified `.nip` XML Schema (`XmlSerializer` over `nvidiaProfileInspector.Common.Import.Profiles`)
- Root element: `<ArrayOfProfile>` (`Profiles : List<Profile>`)
- Profile element: `<Profile>`
  - `<ProfileName>`: **`Base Profile`** targets the Global Driver Profile via `DRS_FindProfileByName` (verified in `DrsSettingsServiceBase.GetProfileHandle` and `DrsSettingsService.DeleteAllProfilesHard`; note `"GLOBAL DRIVER PROFILE"` is only a UI display alias and must NOT be used in `.nip` files!).
  - `<Executeables />` *(exact spelling with `Executeables`)* — empty for `Base Profile`.
  - `<Settings>` containing `<ProfileSetting>` items:
    - `<SettingNameInfo>...</SettingNameInfo>` *(optional descriptive string)*
    - **`<SettingID>`** *(note uppercase `ID`, via `[XmlElement(ElementName = "SettingID")]`; **decimal `uint32`**, NOT `0x...` hex!)*
    - **`<SettingValue>`** *(**decimal `uint32` string** for `ValueType = Dword`, parsed via `UInt32.Parse`; Base64 for `Binary`; string for `String`/`AnsiString`; decimal `uint64` for `Qword`)*
    - `<ValueType>Dword</ValueType>` *(enum: `Dword`, `AnsiString`, `String`, `Binary`, `Qword`)*

#### Minimal Verified `.nip` Example (Global Driver Profile)
```xml
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings>
      <ProfileSetting>
        <SettingNameInfo>Power Management - Mode</SettingNameInfo>
        <SettingID>274197361</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
```

### Verified Setting IDs & Values (from Embedded `CustomSettingNames.xml` and `bin\npi\Reference.xml`)

| Setting Name | Hex ID | Decimal `<SettingID>` | Source | Verified Values (Decimal `<SettingValue>` / Hex) |
|---|---|---:|---|---|
| Power Management - Mode | `0x1057EB71` | `274197361` | Embedded CSN | `0` = Adaptive, `1` = Prefer maximum performance, `5` = Optimal performance |
| Battery Boost | `0x10115C89` | `269573257` | `Reference.xml` | `0` = Disabled, `1` = Minimum, `1023` (`0x3FF`) = Maximum, `268435456` (`0x10000000`) = Enabled |
| Battery Boost - Application FPS Limit | `0x10115C8C` | `269573260` | `Reference.xml` | `0` = No override, `1` = Minimum limit, `1023` = Maximum limit |
| Whisper Mode | `0x10115C8A` | `269573258` | `Reference.xml` | `0` = Disabled, `1` = Minimum, `1023` = Maximum, `268435456` = Enabled |
| Whisper Mode Application FPS | `0x10115C8B` | `269573259` | `Reference.xml` | `0` = No override |
| Power Management - External Quiet Mode | `0x10115C8D` | `269573261` | `Reference.xml` | `0` = Off, `1` = On |
| Prefered Refreshrate | `0x0064B541` | `6600001` | Embedded CSN | `0` = Use 3D app setting, `1` = Highest available |
| Ultra Low Latency - CPL State | `0x0005F543` | `390467` | Embedded CSN | `0` = Off, `1` = On, `2` = Ultra |
| Ultra Low Latency - Enabled | `0x10835000` | `277041152` | Embedded CSN | `0` = Off, `1` = On |
| Threaded Optimization | `0x20C1221E` | `549528094` | Embedded CSN | `0` = Auto, `1` = On, `2` = Off |
| Shader Cache - Cache Size | `0x00AC8497` | `11306135` | Embedded CSN | `0` = Off, `10240` (`0x2800`) = 10GB, `4294967295` (`0xFFFFFFFF`) = Unlimited |
| Texture Filtering - Quality | `0x00CE2691` | `13510289` | Embedded CSN | `0` = Quality, `10` (`0xA`) = Performance, `20` (`0x14`) = High performance, `4294967286` (`0xFFFFFFF6`) = High quality |
| CUDA - Force P2 State | `0x50166C5E` | `1343646814` | Embedded CSN | `0` = Off, `1` = On *(default `1`)* |
| Vertical Sync | `0x00A879CF` | `11041231` | Embedded CSN | `138504007` (`0x08416747`) = Force off, `1620202130` (`0x60925292`) = App-controlled |
| Frame Rate Limiter V3 | `0x10835002` | `277041154` | Embedded CSN | `0` = Off, `20`..`1000` = FPS cap |

---

## 5. `OmenCore.exe` (`v5.0.1`) Notes

- `OmenCore-5.0.1-win-x64.zip` ships the WPF desktop application (`OmenCore.exe`, `requireAdministrator`) and hardware worker (`OmenCore.HardwareWorker.exe`, `asInvoker`); it does **not** bundle `omencore-cli.exe`.
- Verified startup flags in `OmenCore.dll`: `--minimized` / `/minimized` (start minimized to system tray) and `--headless` / `/headless` (tray-only, no main window).
- Provides HP WMI/EC performance modes, fan curve control, Victus thermal/TGP/Dynamic Boost handling (`OmenCore.Core` + `OmenCore.NvidiaPower`), and recovery services (`ApuPowerClampService`, `EdpThrottlingMitigationService`) via GUI/tray.
