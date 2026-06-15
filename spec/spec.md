# Especificaciones del Sistema — Frecuencímetro ASIC
**Proyecto:** Frecuencímetro mixto-señal  
**PDK:** sky130A · Tensión nominal: 1.8 V (núcleo digital) / 3.3 V (pads analógicos)  
**Wrapper:** user_project_wrapper de Caravel (efabless)  
**Estado:** Fase 1 — Especificación

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
| Amplitud mínima útil | > 200 mV (pico a pico) | Determinada por el hysteresis del Schmitt trigger |

## 3. Arquitectura del sistema

El sistema implementa **dos caminos de señal en paralelo**:

### Camino A — Medición de frecuencia (conteo directo)
```
Señal analógica → Schmitt trigger → freq_counter.v → result_latch.v → Wishbone
```
- Latencia de primer resultado: T_gate + 1 ciclo de captura
- Actualización de resultado: cada T_gate segundos
- Sin interrupción de la señal de entrada durante la lectura del resultado

### Camino B — Análisis de amplitud y forma de onda
```
Señal analógica → ADC SAR 12b → adc_ctrl.v → registro ADC_DATA → Wishbone
```
- Tasa de muestreo: limitada por el tiempo de conversión del ADC SAR
- Resolución: 12 bits (4096 niveles, SNR teórico ≈ 74 dB)
- Uso: análisis de amplitud, detección de distorsión, posible FFT en software

### Camino de selftest (DAC interno)
```
CPU → wb_regs.v → dac_ctrl.v → DAC R-2R 8b → [lazo interno] → Schmitt → freq_counter.v
```
- Permite verificar el sistema completo sin señal externa
- Frecuencia de prueba: f_clk / (256 × selftest_rate)
- Con clk = 100 MHz y selftest_rate = 1: f_prueba ≈ 390.6 Hz

## 4. Parámetros del núcleo digital

| Módulo | Parámetro | Valor |
|---|---|---|
| freq_counter | Ancho del contador | 32 bits (cuenta hasta 4,294,967,295) |
| freq_counter | Fmax requerida | > 100 MHz (determinada por clk_user de Caravel) |
| gate_timer | Ancho del divisor | 27 bits (T_gate máximo = 1.34 s @ 100 MHz) |
| cdc_sync | Etapas de sincronización | 2 FF (estándar para MTBF > años en este proceso) |
| wb_regs | Registros implementados | 6 (ver module_list.md) |
| freq_top | Área estimada del núcleo digital | < 0.2 mm² en sky130 |

## 5. Consumo estimado

| Condición | Consumo estimado |
|---|---|
| Núcleo digital @ 100 MHz, 1.8 V, actividad 50% | ~1–2 mW |
| DAC R-2R (estático, salida media) | ~0.5 mW |
| ADC SAR 12b (conversión continua) | ~1–3 mW |
| **Total sistema** | **~3–7 mW** |

*Estimaciones basadas en P = α·C·V²·f para sky130. Verificar con simulaciones de Fase 5.*

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

| Fase | Criterio de éxito |
|---|---|
| Fase 2 (RTL) | Todos los módulos compilan sin errores en iverilog; testbenches unitarios pasan |
| Fase 3 (cocotb) | Error de medición ≤ ±1 Hz para fx en todo el rango con T_gate = 1 s |
| Fase 4 (Xschem) | Schmitt trigger dispara limpiamente con señales de amplitud > 200 mV |
| Fase 5 (ngspice) | ENOB del ADC ≥ 10 bits hasta 500 kHz; THD del DAC ≤ 1% |
| Fase 6 (LibreLane) | DRC: 0 violaciones; LVS: match; STA: slack positivo en todos los paths |
| Fase 7 (Caravel) | Firmware lee frecuencia correcta por UART; selftest pasa sin señal externa |
