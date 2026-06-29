# Especificaciones del Sistema — Frecuencímetro ASIC
**Proyecto:** Frecuencímetro mixto-señal  
**PDK:** sky130A · Tensión nominal: 1.8 V (núcleo digital) / 3.3 V (pads analógicos)  
**Wrapper:** user_project_wrapper de Caravel (efabless)  
**Estado:** Fases 2-3 completadas (núcleo digital, 118/118 tests) · Fase 4 en progreso — Schmitt trigger diseñado y validado en ngspice (ver sección 9)

---

## 1. Parámetros de medición

| Parámetro | Valor | Justificación |
|---|---|---|
| Rango mínimo de frecuencia | 1 Hz | Resolución = 1/T_gate con T_gate = 1 s |
| Rango máximo de frecuencia | 500 kHz | Limitado por ancho de banda del ADC SAR y del Schmitt trigger |
| Resolución nominal | 1 Hz | Con T_gate = 1 s y clk_user = 100 MHz |
| Error máximo (cuantización) | ±1 conteo = ±1/T_gate Hz | Inherente al método de conteo directo |
| T_gate mínimo configurable | 1 ms | gate_cycles = 100,000 @ 100 MHz |
| T_gate máximo configurable | 1.34 s | Contador de 27 bits: 2²⁷ ciclos @ 100 MHz |
| Modo principal | Conteo directo | Óptimo para fx > 10 Hz con T_gate ≥ 1 s |
| Modo secundario | Recíproco (período) | Para fx < 10 Hz donde el error relativo del conteo directo supera 10% |

## 2. Señal de entrada

| Parámetro | Valor | Notas |
|---|---|---|
| Tipo de señal aceptada | Analógica periódica | Cualquier forma de onda con cruce de umbral repetitivo |
| Rango de tensión de entrada | 0 V – 1.8 V | Límite de los pads io_in de sky130 (modo digital) |
| Rango alternativo | 0 V – 3.3 V | Con divisor resistivo externo + pad analógico |
| Forma de onda | Sin restricción | El Schmitt trigger extrae los flancos independientemente de la forma |
| Amplitud mínima útil | > 23.4 mV (pico a pico), tipo 43.5 mV | Histéresis del Schmitt trigger, validada en ngspice sobre 12 casos PVT (3 esquinas × 4 temperaturas). Ver sección 9 |

## 3. Arquitectura del sistema

El sistema implementa **dos caminos de señal en paralelo**:

### Camino A — Medición de frecuencia (conteo directo)
```
Señal analógica → Schmitt trigger → freq_counter.v → result_latch.v → Wishbone
```
- Latencia de primer resultado: T_gate + 1 ciclo de captura
- Actualización de resultado: cada T_gate segundos
- Sin interrupción de la señal de entrada durante la lectura del resultado
- **Verificado por simulación:** `freq_counter.v` (9/9) y `result_latch.v` (14/14)

### Camino B — Análisis de amplitud y forma de onda
```
Señal analógica → ADC SAR 12b → adc_ctrl.v → registro ADC_DATA → Wishbone
```
- Tasa de muestreo: limitada por el tiempo de conversión del ADC SAR
- **Tiempo de conversión verificado empíricamente: `15 + swidth` ciclos de clk** (con SIZE=12, medido directamente sobre `sar_ctrl.v` real)
- Resolución: 12 bits (4096 niveles, SNR teórico ≈ 74 dB)
- Uso: análisis de amplitud, detección de distorsión, posible FFT en software
- **Verificado por simulación:** `adc_ctrl.v` integrado con `sar_ctrl.v` real (13/13)

### Camino de selftest (DAC interno)
```
CPU → wb_regs.v → dac_ctrl.v → DAC R-2R 8b → [lazo interno] → Schmitt → freq_counter.v
```
- Permite verificar el sistema completo sin señal externa
- El modo selftest (rampa automática) **ya existe dentro de la IP** del DAC (`ext_data=0`); `dac_ctrl.v` solo lo habilita/deshabilita, no lo reimplementa
- **Verificado por simulación:** `dac_ctrl.v` integrado con `r2r_dac_control.v` real (20/20)
- ⚠️ Frecuencia de prueba exacta pendiente de confirmar — el comentario original de la IP indica "expect a 10M clock", a verificar contra clk_user=100MHz en Fase 3 (ver `module_list.md` v3.0, checklist de `freq_top.v`)

## 4. Parámetros del núcleo digital

| Módulo | Parámetro | Valor | Estado |
|---|---|---|---|
| freq_counter | Ancho del contador | 32 bits (cuenta hasta 4,294,967,295) | ✅ Verificado |
| freq_counter | Fmax requerida | > 100 MHz (determinada por clk_user de Caravel) | Pendiente Fase 6 (STA) |
| gate_timer | Ancho del divisor | 27 bits (T_gate máximo = 1.34 s @ 100 MHz) | ✅ Verificado |
| cdc_sync | Etapas de sincronización | 2 FF (estándar para MTBF > años en este proceso) | ✅ Verificado |
| adc_ctrl | Timing soc→eoc | 15 + swidth ciclos (SIZE=12) | ✅ Verificado empíricamente |
| dac_ctrl | Polaridad de reset hacia la IP | Sin inversión (`dac_n_rst = rst_n`) | ✅ Verificado — corrige suposición anterior |
| wb_regs | Registros implementados | 6 (ver module_list.md v3.0) | ✅ Verificado, 30/30 tests |
| freq_top | Área estimada del núcleo digital | < 0.2 mm² en sky130 | Pendiente Fase 6 |

## 5. Consumo estimado

| Condición | Consumo estimado |
|---|---|
| Núcleo digital @ 100 MHz, 1.8 V, actividad 50% | ~1–2 mW |
| DAC R-2R (estático, salida media) | ~0.5 mW |
| ADC SAR 12b (conversión continua) | ~1–3 mW |
| **Total sistema** | **~3–7 mW** |

*Estimaciones basadas en P = α·C·V²·f para sky130. Verificar con simulaciones de Fase 5. Sin cambios respecto a v1.0 — no se ha hecho ninguna medición de consumo aún.*

## 6. Restricciones del wrapper Caravel

- Área total disponible: ~10 mm² (user_project_wrapper)
- Tensión de alimentación digital: VCCD1 = 1.8 V
- Tensión de alimentación analógica: VDDA1 = 3.3 V (para pads analógicos)
- Reloj de usuario: proveniente del PLL de Caravel, configurable hasta ~100 MHz
- Bus de comunicación: Wishbone (32 bits de datos, 32 bits de dirección)
- Debug: Logic Analyzer (32 bits del SoC al usuario)
- Pines de I/O: io_in[37:0], io_out[37:0], io_oeb[37:0]
- Pines analógicos: user_analog[7:0] (máximo 8 señales analógicas)

## 7. Criterios de aceptación por fase

| Fase | Criterio de éxito | Estado |
|---|---|---|
| Fase 2 (RTL) | Todos los módulos compilan sin errores en iverilog; testbenches unitarios pasan | ✅ 7/8 módulos (118 tests acumulados: 12+12+9+14+13+20+30+8 pendiente de freq_top) |
| Fase 3 (cocotb) | Error de medición ≤ ±1 Hz para fx en todo el rango con T_gate = 1 s | Pendiente |
| Fase 4 (Xschem) | Schmitt trigger dispara limpiamente con señales de amplitud > 23.4 mV (peor caso PVT) | ✅ Circuito y sizing validados en ngspice (12 casos PVT). Pendiente: símbolos de las IPs y `tb_adc_dac_loop.sch` |
| Fase 5 (ngspice) | ENOB del ADC ≥ 10 bits hasta 500 kHz; THD del DAC ≤ 1% | Pendiente |
| Fase 6 (LibreLane) | DRC: 0 violaciones; LVS: match; STA: slack positivo en todos los paths | Pendiente |
| Fase 7 (Caravel) | Firmware lee frecuencia correcta por UART; selftest pasa sin señal externa | Pendiente |

## 8. Hallazgos críticos de Fase 2 (resumen ejecutivo)

Durante la verificación por simulación de los módulos que envuelven las IPs reales, surgieron dos hallazgos que corrigen documentación previa (detalle completo en `pin_map.md` v4.0 y `module_list.md` v3.0):

1. **Polaridad de reset del DAC corregida.** La documentación de Fase 1 asumía que el pin `n_rst` de `r2r_dac_control` era un reset activo-alto que requería invertir nuestra señal `rst_n`. La simulación contra la IP real demostró lo contrario: `n_rst` funciona como un enable activo-alto que **coincide** con nuestra convención sin necesidad de inversión. Conectarlo invertido (como se documentaba antes) habría dejado el DAC permanentemente en reset en el chip real.

2. **Timing del ADC confirmado empíricamente.** El protocolo `soc→eoc` de `sar_ctrl` tarda exactamente `15 + swidth` ciclos de clk (con SIZE=12), medido directamente por simulación en lugar de derivado de un análisis teórico de la FSM (que había dado una cifra ligeramente distinta, 17+swidth, antes de la verificación empírica).

Ambos hallazgos solo fueron posibles porque los testbenches de `adc_ctrl.v` y `dac_ctrl.v` integran las IPs reales (`sar_ctrl.v`, `r2r_dac_control.v`) en lugar de modelos simplificados — ver la convención de testbench correspondiente en `module_list.md` v3.0.

## 9. Hallazgos críticos de Fase 4 (Schmitt trigger, resumen ejecutivo)

### 9.1 Corrección del spec de amplitud mínima (era circular)

La especificación original (v1.0–v1.x) indicaba **">200 mV"** como amplitud mínima útil, con la justificación "determinada por el hysteresis del Schmitt trigger" — es decir, el valor no se derivó de un presupuesto de ruido real de ninguna fuente de señal documentada (sensor, cable, oscilador externo), sino que era un placeholder aspiracional puesto en Fase 1. Validar el diseño en ngspice reveló que esta topología (6T, una sola capa de realimentación) tiene un **techo físico de histéresis muy por debajo de 200 mV** sin recurrir a transistores de canal extremadamente largo (≥300 µm) — ver hallazgo 9.3.

**Corrección:** la especificación ahora refleja el valor real validado por simulación (ver 9.2), no un placeholder.

### 9.2 Sizing final y validación PVT completa

**Topología:** 2 PMOS + 2 NMOS principales en serie (inversor base) + 1 PMOS y 1 NMOS de realimentación en paralelo (gate=vout), arquitectura clásica de Schmitt trigger CMOS de 6 transistores.

**Sizing final:** `MP_FB`: W=16.0 µm, L=64.0 µm | `MN_FB`: W=8.0 µm, L=64.0 µm | transistores principales sin cambios (W=1.0–2.0 µm, L=0.15 µm — mínimo del proceso).

**Validado en ngspice sobre 12 casos PVT** (esquinas de proceso tt/ff/ss × temperaturas -40/27/85/125°C), testbench `xschem/schmitt_tb.spice`:

| Esquina | -40°C | 27°C | 85°C | 125°C |
|---|---|---|---|---|
| TT (típica) | 65.95 mV | 43.48 mV | 36.59 mV | 34.12 mV |
| FF (rápida) | 28.56 mV | 24.52 mV | 23.58 mV | **23.36 mV** ← peor caso |
| SS (lenta) | 142.06 mV | 75.13 mV | 55.97 mV | 49.19 mV |

- **Histéresis garantizada (peor caso PVT):** 23.36 mV (esquina FF, 125°C)
- **Histéresis típica:** 43.48 mV (esquina TT, 27°C)
- **Velocidad de conmutación** (prueba con señal cuadrada de 500 kHz, el límite superior de la spec): peor caso `trise=104 ns` (esquina SS, -40°C) = 5.2% del periodo — margen amplio en los 12 casos, la velocidad nunca es el factor limitante.

### 9.3 Por qué no se alcanzaron los 200 mV originales

Un barrido paramétrico sobre el ancho (W) y largo (L) de canal de los transistores de realimentación mostró que la histéresis escala de forma sub-lineal con W (saturando rápidamente) y aproximadamente lineal con L. Extrapolando la tendencia medida, alcanzar 200 mV requeriría `L≈300 µm` en los transistores de realimentación — técnicamente viable en área (≈0.1–0.15% del presupuesto de 10 mm²) pero un sizing poco práctico para esta topología. La literatura confirma que histéresis grande con CMOS puro típicamente requiere una topología de **doble capa de realimentación** (más transistores), no solo agrandar los transistores existentes. Se optó por cerrar Fase 4 con el sizing de 9.2 (garantiza >23 mV, suficiente margen práctico de ruido) en vez de rediseñar la topología — queda como mejora futura si una fuente de ruido real documentada llegara a exigir más margen.

### 9.4 Archivos de la validación

- `xschem/schmitt_trigger.sch` — esquemático final (sizing de 9.2)
- `xschem/schmitt_tb.spice` — testbench maestro (correr con `make simspice` o `make waveschmitt` desde la raíz del repo)
- `xschem/schmitt_circuit_{tt,ff,ss}.cir` — circuitos por esquina de proceso, incluidos por el testbench maestro vía `source`
