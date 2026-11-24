# Guía Técnica — HP Victus 15 Power Unlocker Suite (`8DD0` / Ryzen 7 7445HS + RTX 4050)

Esta guía documenta la arquitectura, operación segura, límites físicos y optimizaciones recomendadas para la suite de desbloqueo de potencia (`unlock_victus_power.ps1`, `victus_common.ps1`, `DESBLOQUEAR_POTENCIA_VICTUS.bat`).

---

## 1. Línea Base de Hardware Verificada

| Componente | Especificación Exacta Verificada |
| :--- | :--- |
| **Equipo / SKU** | `Victus by HP Gaming Laptop 15-fb3xxx` (`HP Victus C27MNLA#AC8`, Family `103C_5335M7`) |
| **Placa Base (`BaseBoard`)** | `HP 8DD0` (Versión `52.27`) |
| **BIOS** | `F.15` (Fecha `2026-04-26`) |
| **Procesador (APU)** | `AMD Ryzen 7 7445HS w/ Radeon 740M Graphics` (`6 núcleos / 12 hilos`, arquitectura híbrida Zen 4 + Zen 4c, reloj base `3201 MHz`) |
| **GPU Dedicada** | `NVIDIA GeForce RTX 4050 Laptop GPU` (`VBIOS 95.07.40.40.fa`, Driver `621.24` / `32.0.16.2124`, `CUDA 13.5`) |
| **Envolvente TGP GPU** | `40.00 W` base / `50.00 W` máximo con Dynamic Boost (`nvidia-smi`), VRAM GDDR6 hasta `8001 MHz` |
| **Memoria RAM Actual** | **1× 16 GB** `Micron Technology` `MTC8C1084S1SC56BD1 B` `DDR5-5600` (`5600 MT/s`) en `Bottom - Slot 1 (left)` (**Single-Channel**, Slot 2 vacío) |
| **Presupuesto AC** | Adaptador de **120 W** compartido entre CPU, GPU, pantalla, almacenamiento NVMe, VRM y periféricos |
| **Plan PowerCfg Auditado** | `8a6fba1a-bba9-4083-8074-3397a28ccccb` (`Máximo rendimiento`) |

---

## 2. Arquitectura de 4 Capas de Desbloqueo

Ejecutada mediante [`unlock_victus_power.ps1`](./unlock_victus_power.ps1) (apoyado por [`victus_common.ps1`](./victus_common.ps1)) con verificación de privilegios de Administrador y respaldo automático previo en `backup\`:

### Respaldo Automático Inicial (`[Backup]`)
Antes de aplicar cambios, la suite guarda la línea base original (sin sobrescribirla en ejecuciones posteriores):
- `backup\power_scheme_backup.pow`: exportación completa del plan de energía activo (`powercfg /export`).
- `backup\CustomProfiles_*.nip`: exportación previa de perfiles NVIDIA (`nvidiaProfileInspector.exe -exportCustomized`), movida limpiamente fuera de `bin\npi\`.
- `backup\backup_manifest.json`: registro del GUID activo, valores `powercfg` AC previos, estado `MSISupported` del controlador de audio PCI y estado original de tareas programadas.

### Capa 1 — Desbloqueo Profundo `powercfg` en AC (`SCHEME_CURRENT`)
Elimina políticas ocultas de ahorro en corriente alterna detectadas en [`POWERCFG_AUDIT.md`](./POWERCFG_AUDIT.md):
- **Núcleos sin parking en clases Zen 4 y Zen 4c**: `CPMINCORES` (`0cc5b647-...-83`) y `CPMINCORES1` (`0cc5b647-...-84`) = `0x64` (`100 %`).
- **Programador heterogéneo y boost agresivo**: `SCHEDPOLICY` (`93b8b6dc-...`) = `0x2` (`Preferir mejor rendimiento`), `SHORTSCHEDPOLICY` (`bae08b81-...`) = `0x2`, `PERFBOOSTMODE` (`be337238-...`) = `0x2` (`Agresivo`).
- **Latencia de respuesta inmediata (`Latency Hint EPP`)**: `LATENCYHINTEPP` / `1` / `2` (`4b70f900-...-73/74/75`) = `0x0` (`0 %`).
- **NVMe sin micro-suspensiones en AC**: `NVMEPRIMARYIDLETIMEOUT` (`d639518a-...`) y `Secondary NVMe Idle Timeout` (`d3d55efd-...`) = `0x0` (`0 ms`).
- **Periféricos USB y bus PCIe sin latencia de ahorro**: `USB Selective Suspend` (`48e6b7a6-...`) = `0x0`, `USB 3 Link Power Management` (`d4e98f31-...`) = `0x0`, `SUB_PCIEXPRESS ASPM` (`ee12f906-...`) = `0x0`.
- **Gráficos dinámicos intercambiables**: `e276e160-...` / `a1662ab2-...` = `0x3` (`Maximizar rendimiento`).
- Se confirma de inmediato con `powercfg /setactive SCHEME_CURRENT`.

### Capa 2 — Reducción de Ruido en Segundo Plano e Interrupciones MSI
- Deshabilita tareas programadas de telemetría/actualización en segundo plano: `NvDriverUpdateCheckDaily_*`, `NVIDIA App SelfUpdate_*`, `\Microsoft\Windows\Sustainability\SustainabilityTelemetry` y `\Microsoft\Windows\Sustainability\PowerGridForecastTask`.
- Activa **Message Signaled Interrupts (`MSISupported = 1`)** en el bus PCI `4&98c338a&0&0141` (`High Definition Audio Bus`, `VEN_1002&DEV_1640&SUBSYS_8DD0103C&REV_00`), reduciendo latencia DPC de audio tras el siguiente reinicio.

### Capa 3 — Perfil de Driver NVIDIA (`victus_max_perf.nip`)
Importa [`profiles/victus_max_perf.nip`](./profiles/victus_max_perf.nip) sobre `Base Profile` mediante `nvidiaProfileInspector.exe -silentImport -mergeImport` (preservando perfiles específicos por juego):

| `SettingID` (Decimal) | Parámetro | Valor Aplicado | Propósito |
|---:|---|---|---|
| `274197361` | Power Management - Mode | `1` (`Prefer maximum performance`) | Evita caídas agresivas de P-State bajo carga mixta |
| `269573257` / `269573260` | Battery Boost / App FPS Limit | `0` / `0` | Desactivado (sin techo artificial de FPS) |
| `269573258` / `269573259` | Whisper Mode / App FPS | `0` / `0` | Desactivado (sin limitación acústica oculta) |
| `269573261` | External Quiet Mode | `0` (`Off`) | Sin recorte térmico silencioso |
| `6600001` | Preferred Refreshrate | `1` (`Highest available`) | Máxima tasa de refresco disponible |
| `390467` | Ultra Low Latency - CPL State | `1` (`On`) | Menor latencia de cola sin penalizar juegos DX11 CPU-bound |
| `549528094` | Threaded Optimization | `1` (`On`) | Mejor reparto multihilo en driver |
| `11306135` | Shader Cache - Cache Size | `10240` (`10 GB`) | Reduce *stuttering* por recompilación de shaders |
| `1343646814` | CUDA - Force P2 State | `0` (`Off`) | Desbloquea VRAM a `8001 MHz` completos en CUDA / IA / Ollama |

### Capa 4 — Control SMU del Ryzen 7 7445HS (`RyzenAdj v0.19.0` Parcheado + PawnIO)
Ejecuta `bin\ryzenadj\ryzenadj.exe -i` **antes y después** para mostrar los límites reales del SMU (`STAPM`, `PPT Slow`, `PPT Fast`, `Tctl`):

> **Adaptación técnica específica para Ryzen 7 7445HS y Windows 11:**
> - El binario oficial `RyzenAdj v0.19.0` fallaba en este procesador con `Fam19h: unsupported model 124` (`0x7C`), y Windows Defender bloquea en cuarentena su controlador heredado `WinRing0x64.sys`.
> - El binario incluido en `bin\ryzenadj\ryzenadj.exe` fue recompilado desde `FlyGoat/RyzenAdj v0.19.0` con soporte para **Family `0x19` Model `124` (`FAM_HAWKPOINT`)** y backend directo sobre **PawnIO firmado (`PawnIOLib.dll` + `RyzenSMU.bin v0.2.11`)** sin depender de `WinRing0x64` ni `inpoutx64`.
> - Compatibilidad anti-cheat: Windows Defender y Secure Boot permiten PawnIO de forma nativa y Riot Vanguard suele tolerarlo; si algún anti-cheat estricto (p. ej. FACEIT AC) lo restringe temporalmente, detén el servicio antes de jugar con `sc stop PawnIO` y usa el Modo `[3]`. Si falla la inicialización SMU, la suite registra una advertencia sin abortar las Capas 1–3 ni el lanzamiento de `OmenCore` / `MSI Afterburner`.

| Opción del Menú / `-Mode` | Parámetros `RyzenAdj` | Caso de Uso Ideal |
|---|---|---|
| **`[1]` Gaming GPU-Max** | `--stapm-limit=38000 --slow-limit=42000 --fast-limit=48000 --tctl-temp=90` | **Gaming AAA / GPU-bound:** impide que el CPU acapare el presupuesto compartido de `120 W`, permitiendo que `nvpcf` sostenga los **`50 W` completos** en la RTX 4050 |
| **`[2]` Cómputo Bruto CPU** | `--stapm-limit=54000 --slow-limit=60000 --fast-limit=65000 --tctl-temp=93 --max-performance` | **Compilación (`cargo`/`rustc`), Docker, IA local en CPU, juegos competitivos CPU-bound:** libera `54 W` sostenidos y `65 W` turbo |
| **`[3]` Solo Windows + NVIDIA** | *(Omite `RyzenAdj`)* | Aplica únicamente Capas 1–3 sin tocar límites TDP del SMU |
| **`[4]` Suite Completa** | Aplica Modo `1` (`38W/48W`, o `-RyzenSubMode 2`) + `OmenCore --minimized` + MSI Afterburner | Sesión gaming completa con control térmico/ventiladores y curva Undervolt GPU |
| **`[5]` Rollback** | Ejecuta [`restaurar_potencia_stock.ps1`](./restaurar_potencia_stock.ps1) | Restaura `powercfg`, perfil NVIDIA, MSI Audio y tareas programadas |

> **Nota sobre persistencia SMU (`RyzenAdj`):** Windows (`amdpmf`) y el Embedded Controller (EC) de HP restablecen los registros volátiles de `RyzenAdj` al reiniciar, suspender o cambiar de energía AC/batería. Los Modos `1` y `2` surten efecto **de inmediato** en la sesión actual y pueden reaplicarse en un clic desde el acceso directo del Escritorio, o automatizarse en inicio de sesión AC ejecutando como Administrador:
> ```powershell
> .\unlock_victus_power.ps1 -Mode 1 -InstallStartupTask
> ```

---

## 3. Por qué NO Flashear una VBIOS de 75W en esta Placa `8DD0` (SKU 120W)

Aunque existen modelos de RTX 4050 Laptop con VBIOS de `75 W` o superiores en otros chasis, **flashear una VBIOS de 75W en el Victus `8DD0` con adaptador de 120W es peligroso y contraproducente**:

1. **Límite físico del adaptador AC de 120 W**: Con `50 W` en GPU + `38–54 W` en CPU + pantalla, NVMe, RAM y pérdidas de conversión (~15–20 W), el sistema ya trabaja cerca de `105–120 W` reales. Subir la GPU a `75 W` excede la capacidad del cargador, provocando descarga de batería durante el juego (*hybrid battery drain*), disparos de protección OCP (apagones súbitos) o recorte forzado del procesador.
2. **Diseño de VRM y disipación compartida del chasis `8DD0`**: Los MOSFETs de fase GPU y heatpipes compartidos están dimensionados para una envolvente de `40–50 W`. Sobrepasarlos dispara temperaturas de VRM y *thermal throttling* continuo que reduce los relojes por debajo de una curva bien optimizada a `50 W`.
3. **Corrupción de telemetría `nvpcf` y salidas de vídeo**: Las VBIOS de otros ensambladores o placas usan resistencias shunt y tablas de pines distintas; es frecuente perder la lectura real de consumo (quedando bloqueada en modos de seguridad de `25–30 W`), romper la salida HDMI/DisplayPort o inutilizar la GPU (*brick*).

---

## 4. Alternativa Segura y Eficaz: Undervolt + Curva en MSI Afterburner (`+10–15 %` FPS Reales)

A `50 W`, la RTX 4050 Laptop (arquitectura Ada Lovelace) está limitada principalmente por **potencia (`Power Limit`)**, no por capacidad del silicio. En estado de fábrica, el boost intenta usar voltajes innecesariamente altos (`~950–1025 mV`), agotando los `50 W` antes de alcanzar frecuencias altas estables.

Con la **curva de voltaje/frecuencia** y ajuste de VRAM en **MSI Afterburner** (incluido en Opción `[4]`):

1. **Abrir Editor de Curva**: Abre MSI Afterburner y pulsa **`Ctrl + F`** para abrir el *Voltage/Frequency Curve Editor*.
2. **Fijar techo eficiente (`875–900 mV @ ~2400 MHz`)**:
   - Localiza el punto correspondiente a **`875 mV`** (o **`900 mV`** si tu unidad requiere un poco más de margen) y súbelo hasta **`~2400 MHz`**.
   - Para aplanar todos los puntos a la derecha del punto elegido (de modo que la GPU nunca suba a voltajes altos que queman vatios): selecciona el rango a la derecha manteniendo **`Shift`**, arrástralos por debajo de `2400 MHz` y pulsa **`Apply` (✓)** — Afterburner alineará automáticamente una meseta plana a partir de `875–900 mV`.
3. **Ajustar memoria GDDR6 (`+400` a `+600 MHz`)**:
   - En el deslizador **Memory Clock**, aplica **`+400 MHz`** iniciales (subiendo hasta **`+600 MHz`** si resulta 100 % estable sin artefactos ni caída de puntuación en benchmark, ya que GDDR6 con corrección ECC pierde rendimiento si hay errores antes de crashear).
4. **Resultado esperado dentro de los mismos `50 W`**:
   - **+10–15 % de FPS sostenidos reales** y **`1% lows` mucho más estables**, con menor temperatura en GPU y menor saturación térmica del disipador compartido con el Ryzen 7 7445HS.
5. **Guardar perfil**: Haz clic en el icono de disquete (`Save`) en el perfil `1` y activa el icono de Windows (*Apply overclocking at system startup*) solo tras validar estabilidad en un juego exigente o 3DMark/OCCT.

---

## 5. Uso Seguro de OmenCore `v5.0.1` en Placa `8DD0`

El lanzador en Modo `[4]` inicia `bin\omencore\OmenCore.exe --minimized` en la bandeja del sistema para administrar modos térmicos HP WMI/EC y mitigar reducciones de potencia (`ApuPowerClampService`, `EdpThrottlingMitigationService`).

> **Precaución crítica en placa `8DD0`:**
> - **Evita hacer pruebas rápidas escalonadas con porcentajes manuales de ventilador (`%` por `%` en intervalos cortos).** En el EC de los HP Victus `8DD0`, envíos rápidos o cambios bruscos de PWM manual pueden congelar temporalmente la lectura RPM o dejar el ventilador anclado en un valor fijo hasta reiniciar el equipo / EC.
> - **Práctica segura:** utiliza los selectores limpios de modo (**Performance** / **Balanced**) o activa **Max Fan** cuando necesites disipación máxima sostenida en sesiones largas de gaming o renderizado.

---

## 6. Actualización de Hardware Recomendada: RAM Dual-Channel DDR5-5600

Actualmente el equipo opera con **un solo módulo** instalado en `Bottom - Slot 1 (left)`:
- **Módulo instalado:** `16 GB` `Micron Technology` `MTC8C1084S1SC56BD1 B` `DDR5-5600` (`5600 MT/s`, `1.1 V`, `CL46`).
- **Limitación actual:** al estar el **Slot 2 vacío**, el controlador de memoria del Ryzen 7 7445HS trabaja en **Single-Channel**, reduciendo a la mitad el ancho de banda teórico de RAM. Esto penaliza directamente los **`1% lows`** en juegos modernos, la iGPU Radeon 740M en escritorio/híbrido y cargas de compilación/contenedores.

### Compra Recomendada
- Instalar un **2.º módulo de `16 GB DDR5-5600 SO-DIMM` Micron o Crucial `CL46` a `1.1 V`** en el **Slot 2 vacío** (por ejemplo, el mismo número de parte `Micron MTC8C1084S1SC56BD1` o su equivalente `Crucial CT16G56C46S5`, `DDR5-5600 MT/s CL46 1.1V Non-ECC Unbuffered SO-DIMM`).
- Con ambos zócalos poblados obtendrás **32 GB en Dual-Channel simétrico a `5600 MT/s`**, maximizando la estabilidad de frametime y capacidad multitarea.

---

## 7. Reversión Completa (Rollback)

Para devolver el sistema a su estado original en cualquier momento:
1. Ejecuta [`DESBLOQUEAR_POTENCIA_VICTUS.bat`](./DESBLOQUEAR_POTENCIA_VICTUS.bat) y elige la opción **`[5] Restaurar Valores Originales (Rollback)`** (o ejecuta directamente [`restaurar_potencia_stock.ps1`](./restaurar_potencia_stock.ps1) como Administrador).
2. El rollback restaura el plan `powercfg` desde `backup\power_scheme_backup.pow` (o los valores stock auditados si faltase el archivo), devuelve el `Base Profile` de NVIDIA a `Power Management = 5 (Optimal)` / `CUDA P2 = 1` reimportando `backup\CustomProfiles_*.nip`, revierte `MSISupported = 0` en el audio PCI, reactiva las tareas programadas y elimina la tarea opcional `VictusPowerUnlock_AC_Startup` si existiese.
3. Reinicia Windows para que `MSISupported = 0` y los registros volátiles de `RyzenAdj` vuelvan al estado de fábrica de HP.
