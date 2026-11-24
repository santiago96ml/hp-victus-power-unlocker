# HP Victus 15 Power Unlocker Suite (`8DD0` / Ryzen 7 + RTX 4050)

4-layer Windows power, heterogeneous thread scheduler, NVIDIA driver P-State, PCI audio MSI interrupt, and SMU power-envelope unlocker for **HP Victus 15-fb3xxx (`8DD0` / AMD Ryzen 7 7445HS + NVIDIA RTX 4050 Laptop 50W)** — engineered with **automatic baseline backup and one-click stock rollback**.

> Detailed technical audit & hardware limits: see [GUIA_DESBLOQUEO_VICTUS.md](./GUIA_DESBLOQUEO_VICTUS.md) and [POWERCFG_AUDIT.md](./POWERCFG_AUDIT.md).

## What Each Layer Does

1. **Layer 1 — Deep AC `powercfg` Unlock (`victus_common.ps1`, `unlock_victus_power.ps1`)**:
   - Disables Zen 4 & Zen 4c core parking (`CPMINCORES`, `CPMINCORES1` = `100%`).
   - Tunes heterogeneous scheduling (`SCHEDPOLICY = 2`, `SHORTSCHEDPOLICY = 2`, `PERFBOOSTMODE = 2`) and zero latency-hint throttling (`LATENCYHINTEPP* = 0`).
   - Disables AC NVMe idle timeouts, USB Selective Suspend, USB 3 Link Power Management, and PCIe ASPM; forces Switchable Dynamic Graphics to `Maximize Performance`.
2. **Layer 2 — Telemetry Noise Reduction & PCI Audio MSI**:
   - Disables background update/telemetry scheduled tasks (`NvDriverUpdateCheckDaily_*`, `NVIDIA App SelfUpdate_*`, `SustainabilityTelemetry`, `PowerGridForecastTask`).
   - Enables `MSISupported = 1` on High Definition Audio Bus (`HDAudBus`) PCI nodes to reduce DPC audio latency.
3. **Layer 3 — Clean NVIDIA Base Profile (`profiles/victus_max_perf.nip`)**:
   - Sets `Power Management Mode = Prefer maximum performance`, disables Battery Boost / Whisper Mode / Quiet Mode caps, sets 10 GB Shader Cache, Ultra Low Latency = On, and disables `CUDA - Force P2 State` so GDDR6 VRAM runs at full clock under CUDA/AI workloads.
4. **Layer 4 — Volatile RyzenAdj SMU Tuning + OmenCore / Afterburner Launch**:
   - **Mode `[1]` Gaming GPU-Max (`38W STAPM / 42W Slow / 48W Fast`)**: prevents the CPU from starving the shared `120W` AC adapter so Dynamic Boost sustains full `50W` on the RTX 4050.
   - **Mode `[2]` CPU Compute Unleashed (`54W / 60W / 65W + --max-performance`)**: maximizes sustained multi-core CPU throughput for compilation, Docker, and CPU-bound tasks.

## Prerequisites (External Open-Source Tools)

Third-party binaries are **not** bundled in this repository. Before running Layer 3 or Layer 4, download the verified upstream releases listed in [TOOLS_INVENTORY.md](./TOOLS_INVENTORY.md) and extract them into:
- `bin\npi\nvidiaProfileInspector.exe` (`Orbmu2k/nvidiaProfileInspector`)
- `bin\ryzenadj\ryzenadj.exe` (`FlyGoat/RyzenAdj`, Model `124` / PawnIO build for Hawk Point)
- `bin\omencore\OmenCore.exe` *(optional, for Mode `[4]` tray/fan control)*

*(Mode `[3]` skips RyzenAdj if you only want Windows `powercfg` + NVIDIA profile adjustments.)*

## Usage & Rollback

1. Run **`DESBLOQUEAR_POTENCIA_VICTUS.bat`** (elevates via UAC automatically) and choose Mode `1`–`4`.
2. On first run, the suite exports your untouched baseline to `backup\power_scheme_backup.pow`, `backup\CustomProfiles_*.nip`, and `backup\backup_manifest.json`.
3. To revert everything cleanly, run **`DESBLOQUEAR_POTENCIA_VICTUS.bat`** option **`[5]`** (or execute `restaurar_potencia_stock.ps1` as Administrator).

## Safety Notes

- Never flash an incompatible higher-wattage (e.g. `75W`) VBIOS onto a `120W` AC Victus `8DD0` board — use Curve Editor undervolting (`875–900 mV` flat curve in MSI Afterburner) inside the `50W` budget instead.
- Use at your own risk; always keep the `backup\` folder intact before tweaking.

## License

MIT — see [LICENSE](./LICENSE).
