# Auditoría `powercfg /qh SCHEME_CURRENT` — HP Victus 15 (Ryzen 7 7445HS + RTX 4050)

**Fecha de auditoría:** 2026-11-16  
**Plan de energía activo (`SCHEME_CURRENT`):** `8a6fba1a-bba9-4083-8074-3397a28ccccb` (`Máximo rendimiento`)  
**Otros planes detectados (`powercfg /list`):**
- `381b4222-f694-41f0-9685-ff5bb260df2e` (`Equilibrado`)
- `9506f0db-6629-4c9c-b7a8-2f77d12085cc` (`plan gamer`)
- `8a6fba1a-bba9-4083-8074-3397a28ccccb` (`Máximo rendimiento`) **[Activo]**

---

## 1. Subgrupo `SUB_PROCESSOR` (`54533251-82be-4824-96c1-47b60b740d00`)

### 1.1 Parámetros Clave Solicitados

| Alias | GUID de Configuración | Nombre Descriptivo | Rango / Opciones | AC Actual (Hex / Valor) | DC Actual (Hex / Valor) | Diagnóstico AC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `CPMINCORES` | `0cc5b647-c1df-4637-891a-dec35c318583` | Mínima detención de núcleos de rendimiento de procesador | `0x0`–`0x64` (`0–100 %`) | `0x00000064` (`100 %`) | `0x00000001` (`1 %`) | OK (Core Parking deshabilitado en clase 0) |
| `CPMINCORES1` | `0cc5b647-c1df-4637-891a-dec35c318584` | Núcleos mínimos de detención de núcleos de Eficiencia energética clase 1 | `0x0`–`0x64` (`0–100 %`) | `0x00000000` (`0 %`) | `0x00000000` (`0 %`) | **Oportunidad:** clase 1 (Zen 4c) aún permite parking al 0 % en AC |
| `PERFBOOSTMODE` | `be337238-0d82-4146-a960-4f3749d470c7` | Modo de mejora del rendimiento del procesador | `0`=Deshab., `1`=Hab., `2`=Agresiva, `3`=Efic. Hab., `4`=Efic. Agresiva, `5`=Estricto frec. garant., `6`=Efic.+Estricto | `0x00000002` (`Agresiva`) | `0x00000002` (`Agresiva`) | OK (Boost agresivo activo en AC y DC) |
| `PERFBOOSTPOL` | `45bcc044-d885-43e2-8605-ee0ec6e96b59` | Directiva de mejora del rendimiento del procesador | `0x0`–`0x64` (`0–100 %`) | `0x00000064` (`100 %`) | `0x00000028` (`40 %`) | OK en AC |
| `PERFEPP` | `36687f9e-e3a5-4dbf-b1dc-15eb381c6863` | Directiva de preferencia de rendimiento energético (EPP) | `0x0`–`0x64` (`0–100 %`) | `0x00000000` (`0 %`) | `0x0000003c` (`60 %`) | OK en AC (0 % = máx. rendimiento) |
| `PERFEPP1` | `36687f9e-e3a5-4dbf-b1dc-15eb381c6864` | Directiva de preferencia EPP clase 1 | `0x0`–`0x64` (`0–100 %`) | `0x00000000` (`0 %`) | `0x00000032` (`50 %`) | OK en AC |
| `PERFEPP2` | `36687f9e-e3a5-4dbf-b1dc-15eb381c6865` | Directiva de preferencia EPP clase 2 | `0x0`–`0x64` (`0–100 %`) | `0x00000000` (`0 %`) | `0x00000032` (`50 %`) | OK en AC |
| `SCHEDPOLICY` | `93b8b6dc-0698-4d1c-9ee4-0644e900c85d` | Directiva heterogénea de programación de subprocesos | `0`=Todos, `1`=Mejor rend., `2`=Preferir mejor rend., `3`=Eficientes, `4`=Preferir efic., `5`=Automático | `0x00000005` (`Automático`) | `0x00000005` (`Automático`) | **Oportunidad:** en Ryzen 7 7445HS (híbrido Zen 4 + Zen 4c), probar `0x2` (`Preferir mejor rendimiento`) o `0x0` (`Todos`) |
| `SHORTSCHEDPOLICY` | `bae08b81-2d5e-4688-ad6a-13243356654b` | Directiva heterogénea para subprocesos de ejecución breve | `0`–`5` (mismas opciones) | `0x00000002` (`Preferir procesadores con mejor rendimiento`) | `0x00000005` (`Automático`) | OK en AC (`0x2`) |
| `PROCFREQMAX` | `75b0ae3f-bce0-45a7-8c89-c9611c25e100` | Frecuencia máxima del procesador | `0x0`–`0xffffffff` (`MHz`, `0`=sin límite) | `0x00000000` (`0 MHz` / Sin límite) | `0x00000fa0` (`4000 MHz`) | OK en AC (sin límite); en DC tope de 4000 MHz |

### 1.2 Otros Parámetros Relevantes de `SUB_PROCESSOR` Observados en `powercfg /qh`

| Alias | GUID de Configuración | Descripción | AC Actual | DC Actual | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `PROCFREQMAX1` | `75b0ae3f-bce0-45a7-8c89-c9611c25e101` | Frecuencia máxima clase 1 | `0x00000000` (`0 MHz`) | `0x00000000` (`0 MHz`) | Sin tope |
| `PROCFREQMAX2` | `75b0ae3f-bce0-45a7-8c89-c9611c25e102` | Frecuencia máxima clase 2 | `0x00000000` (`0 MHz`) | `0x00000000` (`0 MHz`) | Sin tope |
| `PROCTHROTTLEMIN` | `893dee8e-2bef-41e0-89c6-b55d0929964c` | Estado mínimo del procesador | `0x00000064` (`100 %`) | `0x00000005` (`5 %`) | 100 % en AC |
| `PROCTHROTTLEMIN1` | `893dee8e-2bef-41e0-89c6-b55d0929964d` | Estado mínimo clase 1 | `0x00000064` (`100 %`) | `0x00000005` (`5 %`) | 100 % en AC |
| `PROCTHROTTLEMIN2` | `893dee8e-2bef-41e0-89c6-b55d0929964e` | Estado mínimo clase 2 | `0x00000064` (`100 %`) | `0x00000005` (`5 %`) | 100 % en AC |
| `PROCTHROTTLEMAX` / `1` / `2` | `bc5038f7-23e0-4960-96da-33abaf5935ec` / `ed` / `ee` | Estado máximo del procesador | `0x00000064` (`100 %`) | `0x00000064` (`100 %`) | 100 % en AC y DC |
| `CPMAXCORES` / `CPMAXCORES1` | `ea062031-0e34-4ff1-9b6d-eb1059334028` / `29` | Máxima detención de núcleos | `0x00000064` (`100 %`) | `0x00000064` (`100 %`) | Todos habilitados |
| `IDLEDISABLE` | `5d76a2ca-e8c0-402f-a133-2158492d58ad` | Inactividad de procesador deshabilitada (`0`=Hab., `1`=Deshab.) | `0x00000000` (`Habilitar inactividad`) | `0x00000000` | Mantener `0` en laptop para no bloquear turbo/térmicas |
| `PERFAUTONOMOUS` | `8baa4a8a-14c6-4451-8e8b-14bdbd197537` | Modo autónomo (CPPC) | `0x00000001` (`Habilitado`) | `0x00000001` | Necesario para `PERFEPP` hardware |
| `SYSCOOLPOL` | `94d3a615-a899-4ac5-ae2b-e4d8f634367f` | Directiva de refrigeración (`0`=Pasivo, `1`=Activo) | `0x00000001` (`Activo`) | `0x00000000` (`Pasivo`) | En AC ventiladores activos primero |
| `HETEROPOLICY` | `7f2f5cfa-f10c-4823-b5e1-e93ae85f46b5` | Directiva de heterogeneidad en vigor | `0x00000004` | `0x00000004` | Política 4 |
| `HETEROCONTAINMENTPOLICY` | `60fbe21b-efd9-49f2-b066-8674d8e9f423` | Política de contención hetero (`0`=Deshab., `1`=Hab.) | `0x00000001` (`Habilitado`) | `0x00000001` | Contención activa |
| `LATENCYHINTEPP` / `1` / `2` | `4b70f900-cdd9-4e66-aa26-ae8417f98173` / `74` / `75` | EPP de sugerencias de sensibilidad de latencia | `0x00000064` (`100 %`) | `0x00000064` (`100 %`) | **Oportunidad:** está al 100 % (ahorro) en vez de `0x0` (rendimiento) |
| `LATENCYHINTPERF` | `619b7505-003b-4e82-b7a6-4dd29c300971` | Rendimiento por sugerencia de latencia | `0x00000063` (`99 %`) | `0x00000063` (`99 %`) | `1`/`2` están en `0x32` (`50 %`) |
| `LATENCYHINTUNPARK` / `1` | `616cdaa5-695e-4545-97ad-97dc2d1bdd88` / `89` | Núcleos reactivos mínimos por latencia | `0x00000032` (`50 %`) / `0x0` (`0 %`) | `0x00000032` / `0x0` | Clase 1 en `0 %` |
| `SOFTPARKLATENCY` | `97cfac41-2217-47eb-992d-618b1977c907` | Latencia de detención temporal (us) | `0x00000000` (`0 us`) | `0x000003e8` (`1000 us`) | OK en AC |

---

## 2. Subgrupo `SUB_DISK` (`0012ee47-9041-4b5d-9b77-535fba8b1442` — Disco duro / NVMe)

| Alias | GUID de Configuración | Nombre Descriptivo | Rango / Opciones | AC Actual (Hex / Valor) | DC Actual (Hex / Valor) | Diagnóstico AC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| *(sin alias)* | `0b2d69d7-a2a1-449c-9680-f91c70521c60` | AHCI Link Power Management - HIPM/DIPM | `0`=Active, `1`=HIPM, `2`=HIPM+DIPM, `3`=DIPM, `4`=Lowest | `0x00000000` (`Active`) | `0x00000001` (`HIPM`) | OK en AC |
| `DISKMAXPOWER` | `51dea550-bb38-4bc4-991b-eacf37be5ec8` | Nivel de energía máximo | `0x0`–`0x64` (`0–100 %`) | `0x00000064` (`100 %`) | `0x00000064` (`100 %`) | OK |
| `DISKIDLE` | `6738e2c4-e8a5-4a42-b16a-e040e769756e` | Apagar el disco duro tras | `0x0`–`0xffffffff` (`Segundos`) | `0x00000000` (`0 s` / Nunca) | `0x00000000` (`0 s` / Nunca) | OK |
| `DISKBURSTIGNORE` | `80e3c60e-bb94-4ad8-bbe0-0d3195efc663` | Tiempo para omitir ráfaga de disco duro | `0x0`–`0xffffffff` (`Segundos`) | `0x00000000` (`0 s`) | `0x0000001e` (`30 s`) | OK en AC |
| *(sin alias)* | `d3d55efd-c1ff-424e-9dc3-441be7833010` | Secondary NVMe Idle Timeout | `0x0`–`0xea60` (`ms`) | `0x000007d0` (`2000 ms`) | `0x000003e8` (`1000 ms`) | **Oportunidad:** `0x0` o mayor en AC si hay 2do NVMe |
| `NVMEPRIMARYIDLETIMEOUT` | `d639518a-e56d-4345-8af2-b9f32fb26109` | Primary NVMe Idle Timeout | `0x0`–`0xea60` (`ms`) | `0x000000c8` (`200 ms`) | `0x0000001e` (`30 ms`) | **ALERTA:** Entra en inactividad a los `200 ms` incluso en AC (posible micro-latencia NVMe); candidato a `0x0` o `0xea60` en AC |
| *(sin alias)* | `dab60367-53fe-4fbc-825e-521d069d2456` | AHCI Link Power Management - Adaptive | `0x0`–`0x493e0` (`ms`) | `0x00000000` (`0 ms`) | `0x00000064` (`100 ms`) | OK en AC |
| *(sin alias)* | `dbc9e238-6de9-49e3-92cd-8c2b4946b472` | Secondary NVMe Power State Transition Latency Tolerance | `0x0`–`0xea60` (`ms`) | `0x00000000` (`0 ms`) | `0x00000064` (`100 ms`) | OK en AC |
| `DISKNVMENOPPME` | `fc7372b6-ab2d-43ee-8797-15e9841f2cca` | NVMe NOPPME | `0`=Desactivar, `1`=Activar | `0x00000001` (`Activar`) | `0x00000000` (`Desactivar`) | Activo en AC (deshabilita PME en estados profundos sin carga) |
| *(sin alias)* | `fc95af4d-40e7-4b6d-835a-56d131dbc80e` | Primary NVMe Power State Transition Latency Tolerance | `0x0`–`0xea60` (`ms`) | `0x00000000` (`0 ms`) | `0x00000032` (`50 ms`) | OK en AC (`0 ms` tolerancia) |

---

## 3. Subgrupo `SUB_PCIEXPRESS` (`501a4d13-42af-4429-9fd1-a8218c268e20`)

| Alias | GUID de Configuración | Nombre Descriptivo | Opciones | AC Actual (Hex / Valor) | DC Actual (Hex / Valor) | Diagnóstico AC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ASPM` | `ee12f906-d277-404b-b6da-e5fa1a576df5` | Administración de energía del estado de vínculos | `0`=Desactivar, `1`=Ahorro moderado, `2`=Máximo ahorro | `0x00000000` (`Desactivar`) | `0x00000002` (`Máximo ahorro de energía`) | OK en AC (`ASPM` desactivado para RTX 4050 y NVMe) |

---

## 4. Subgrupo Configuración de USB (`2a737441-1930-4402-8d77-b2bebba308a3`)

| Alias | GUID de Configuración | Nombre Descriptivo | Rango / Opciones | AC Actual (Hex / Valor) | DC Actual (Hex / Valor) | Diagnóstico AC |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| *(sin alias)* | `0853a681-27c8-4100-a2fd-82013e970683` | Hub Selective Suspend Timeout | `0x0`–`0x186a0` (`ms`) | `0x00000032` (`50 ms`) | `0x00000032` (`50 ms`) | Suspensión rápida a `50 ms` |
| *(sin alias)* | `48e6b7a6-50f5-4782-a5d4-53bb8f07e226` | Configuración de suspensión selectiva de USB | `0`=Deshabilitado, `1`=Habilitado | `0x00000001` (`Habilitado`) | `0x00000001` (`Habilitado`) | **ALERTA:** Suspensión selectiva USB habilitada incluso en AC (afecta mouse/teclado/dongles gaming) |
| *(sin alias)* | `498c044a-201b-4631-a522-5c744ed4e678` | Setting IOC on all TDs | `0`=Disabled, `1`=Enabled | `0x00000001` (`Enabled`) | `0x00000000` (`Disabled`) | Activo en AC |
| *(sin alias)* | `d4e98f31-5ffe-4ce1-be31-1b38b384c009` | USB 3 Link Power Mangement | `0`=Off, `1`=Minimum power savings, `2`=Moderate power savings, `3`=Maximum power savings | `0x00000002` (`Moderate power savings`) | `0x00000002` (`Moderate power savings`) | **ALERTA:** Ahorro moderado USB 3 activo en AC; candidato a `0x0` (`Off`) |

---

## 5. Subgrupos Adicionales OEM/GPU Detectados (Referencia para Subagent 3)

### 5.1 `AMD Power Slider` (`c763b4ec-0e50-4b6b-9bed-2b92a6ee884e`)
| GUID de Configuración | Nombre | AC Actual | DC Actual |
| :--- | :--- | :--- | :--- |
| `38cab4d5-db09-449f-9db5-1c91c909b6d4` | PMF Controller | `0x00000002` | `0x00000002` |
| `7ec1751b-60ed-4588-afb5-9819d3d77d90` | Overlay (`0`=Ahorro, `1`=Mejor bat., `2`=Mejor desemp., `3`=El mejor desempeño) | `0x00000003` (`El mejor desempeño`) | `0x00000002` (`Mejor desempeño`) |

### 5.2 `Gráficos dinámicos intercambiables` (`e276e160-7cb0-43c6-b20b-73f5dce39954`)
| GUID de Configuración | Nombre | Opciones | AC Actual | DC Actual |
| :--- | :--- | :--- | :--- | :--- |
| `a1662ab2-9d34-4e53-ba8b-2639b9e20857` | Configuración global | `0`=Forzar ahorro, `1`=Opt. ahorro, `2`=Optimizar rendimiento, `3`=Maximizar rendimiento | `0x00000002` (`Optimizar rendimiento`) | `0x00000001` (`Optimización del ahorro de energía`) |

---

## 6. Resumen de Cuellos de Botella en AC Detectados para Subagent 3

Aunque el plan activo es **Máximo rendimiento**, las siguientes configuraciones **en AC** mantienen políticas de ahorro o latencia conservadora:
1. **USB Selective Suspend (`48e6b7a6-50f5-4782-a5d4-53bb8f07e226`)**: AC = `0x00000001` (`Habilitado`) -> recomendado `0x0` (`Deshabilitado`) en AC.
2. **USB 3 Link Power Management (`d4e98f31-5ffe-4ce1-be31-1b38b384c009`)**: AC = `0x00000002` (`Moderate power savings`) -> recomendado `0x0` (`Off`) en AC.
3. **Primary NVMe Idle Timeout (`d639518a-e56d-4345-8af2-b9f32fb26109`)**: AC = `0x000000c8` (`200 ms`) (y Secondary NVMe `d3d55efd-...` = `0x000007d0` = `2000 ms`) -> recomendado `0x0` (o valor alto) en AC.
4. **`CPMINCORES1` (`0cc5b647-c1df-4637-891a-dec35c318584`)**: AC = `0x00000000` (`0 %`) -> permite aparcar núcleos de clase 1 (Zen 4c) incluso en AC; candidato a `0x64` (`100 %`).
5. **`SCHEDPOLICY` (`93b8b6dc-0698-4d1c-9ee4-0644e900c85d`)**: AC = `0x00000005` (`Automático`) -> candidato a `0x2` (`Preferir procesadores con mejor rendimiento`) o `0x0` (`Todos`) en AC.
6. **`LATENCYHINTEPP` / `1` / `2` (`4b70f900-cdd9-4e66-aa26-ae8417f98173/74/75`)**: AC = `0x00000064` (`100 %`) -> candidato a `0x0` (`0 %`) en AC.
7. **Gráficos dinámicos intercambiables (`e276e160...` -> `a1662ab2...`)**: AC = `0x00000002` (`Optimizar rendimiento`) -> candidato a `0x3` (`Maximizar rendimiento`) en AC.
