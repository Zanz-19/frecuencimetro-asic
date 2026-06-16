# Mapa de Pines — Frecuencímetro ASIC en Caravel
**Versión:** 3.0 — Pines 100% verificados desde SPICE, Verilog y simulaciones  
**Estado:** Fase 1 CERRADA · Listo para Fase 2  
**Fuentes verificadas:**
- `ip/dac_r2r/src/project.v` + `verilog/rtl/r2r_dac_control.v` + `sim/mixed.cir`
- `ip/adc_sar/netlist/schematic/sky130_ef_ip__adc3v_12bit.spice` + `verilog/sar_ctrl.v`

---

## HALLAZGOS FINALES v3.0 (diferencias respecto a v2.0)

| # | Supuesto v2.0 | Realidad confirmada v3.0 | Impacto en Fase 2 |
|---|---|---|---|
| 1 | Pines ADC analógico: `adc0`, `adc0_ena`, `adc0_hold`... | Pines reales: `adc_in`, `adc_ena`, `adc_hold`, `adc_reset`, `adc_dac_val[11:0]`, `adc_comp_out` | Solo afecta Fase 4 (Xschem) — `adc_ctrl.v` se conecta a `sar_ctrl`, no a este bloque |
| 2 | SIZE=8 por defecto en sar_ctrl, dudábamos si era 12 | El esquemático Xschem muestra `adc_dac_val[11:0]` (12 líneas numeradas 0-11) → **SIZE=12 confirmado** | `adc_ctrl.v` usa `data[11:0]` — correcto como teníamos |
| 3 | Reset DAC activo alto a 1.8 V | `mixed.cir`: `PULSE 3 0` — reset en la simulación original usa **3 V** | En sky130, los pads HVL soportan 3.3 V. Conectar `dac_n_rst` desde pad 3.3 V o usar nivel shifter. Investigar en Fase 4. |
| 4 | Pines de cosimulación del DAC no confirmados | `mixed.cir` confirma exactamente: entradas `clk n_rst ext_data d[7:0] load_divider`, salidas `b[7:0]` | `dac_ctrl.v` conecta `b[7:0]` a la red R-2R, no `r2r_out` directamente |
| 5 | Ruta PDK en simulaciones de las IPs | `mixed.cir` tiene ruta hardcoded a máquina de Matt: `/home/matt/work/.../sky130.lib.spice` | En Fase 5: reemplazar con variable `$PDK_ROOT` o ruta local |
| 6 | ADC tiene sub-IPs `ccomp3v` y `cdac3v_12bit` | Confirmado: comparador es `sky130_ef_ip__scomp3v`, CDAC es `sky130_ef_ip__cdac3v_12bit` con 12 bits SELD[11:0] | No afecta Fase 2. Relevante para Fase 4 (Xschem) y Fase 5 (ngspice) |

---

## 1. Pines reales de las IPs — VERSIÓN FINAL

### DAC R-2R — Interfaz completa verificada

**Módulo top:** `tt_um_mattvenn_r2r_dac` (src/project.v)  
**Control digital:** `r2r_dac_control` (verilog/rtl/r2r_dac_control.v)  
**Cosimulación:** entradas/salidas confirmadas por sim/mixed.cir

| Pin | En módulo | Tipo | Conectado a en freq_top | Notas |
|---|---|---|---|---|
| `ui_in[7:0]` | top | Digital entrada | `dac_ctrl → dac_word[7:0]` | Dato 8b. Activo cuando `ext_data=1` |
| `uio_in[0]` | top | Digital entrada | `dac_ctrl → dac_ext_data` | 1=modo externo, 0=rampa interna |
| `uio_in[1]` | top | Digital entrada | `dac_ctrl → dac_load_div` | Pulso: carga divisor de velocidad |
| `clk` | top/ctrl | Digital entrada | `clk_dac` (ver nota ⚠️) | Comentario: "expect 10M clock" |
| `rst_n` | top | Digital entrada | `~rst_n_global` | ⚠️ Activo ALTO en la IP |
| `n_rst` | ctrl | Digital entrada | (interno al top) | Nombre interno del reset en r2r_dac_control |
| `ena` | top | Digital entrada | `1'b1` | Enable TinyTapeout, siempre activo |
| `ua[0]` | top | Analógico salida | `user_analog[1]` | Vout de la escalera R-2R |
| `VPWR`/`VGND` | top | Alimentación | `VCCD1`/`VSSD1` | 1.8 V digital |

**Señales internas del DAC (para referencia Fase 4/5):**

| Señal interna | De | A | Descripción |
|---|---|---|---|
| `r2r_out[7:0]` | `r2r_dac_control` | `r2r` (analógico) | 8 bits hacia la escalera |
| `b[7:0]` | `r2r` analógico | pines de la red | Salidas de la escalera (en cosim: `b7..b0`) |
| `out` | red R-2R | `ua[0]` | Tensión analógica de salida |

> ⚠️ **Nota de reloj DAC:** El archivo `mixed.cir` usa un oscilador a 1 MHz para el test.
> El comentario del RTL dice "expect a 10M clock". Opciones para Fase 6:
> - Dividir `clk_user` (100 MHz) entre 10 con un prescaler dentro de `dac_ctrl.v`
> - Usar una salida del PLL de Caravel configurada a 10 MHz
> - **Verificar en Fase 3** si la lógica del divisor interno funciona a 100 MHz

> ⚠️ **Nota de nivel de reset DAC:** `mixed.cir` usa `PULSE 3 0` (3 V).
> El pad digital de Caravel opera a 1.8 V. Opciones:
> - Usar pad HVL de Caravel (soporta 3.3 V) para la señal de reset del DAC
> - Verificar si 1.8 V es suficiente para activar el reset en el proceso sky130
> - Investigar en Fase 4 con simulación ngspice del nivel de umbral

---

### ADC SAR 12b — Interfaz completa verificada

**Bloque analógico:** `sky130_ef_ip__adc3v_12bit` (subcircuito SPICE)  
**Control SAR digital:** `sar_ctrl #(SIZE=12)` (verilog/sar_ctrl.v)  
**Sub-IPs internas:** `sky130_ef_ip__cdac3v_12bit` (CDAC) + `sky130_ef_ip__scomp3v` (comparador)

#### Interfaz del control SAR — lo que conecta `adc_ctrl.v`

| Pin (`sar_ctrl`) | Tipo | Conectado a en freq_top | Notas |
|---|---|---|---|
| `clk` | Digital entrada | `clk_user` de Caravel | |
| `rst_n` | Digital entrada | `rst_n_global` | Activo bajo — consistente ✅ |
| `soc` | Digital entrada | `adc_ctrl → adc_soc` | Start Of Conversion (pulso 1 ciclo) |
| `cmp` | Digital entrada | (interno: `adc_comp_out` del bloque analógico) | No sale al wrapper |
| `en` | Digital entrada | `adc_ctrl → adc_en` | Habilitación del SAR |
| `swidth[3:0]` | Digital entrada | `wb_regs → adc_swidth` | Tiempo de muestreo en ciclos |
| `sample_n` | Digital salida | (interno: `adc_hold` del bloque analógico) | No sale al wrapper |
| `data[11:0]` | Digital salida | `adc_ctrl → adc_data_raw[11:0]` | **SIZE=12 confirmado** ✅ |
| `eoc` | Digital salida | `cdc_sync → async_in` | Sincronizar antes de usar |
| `dac_rst` | Digital salida | (interno: `adc_reset` del bloque analógico) | No sale al wrapper |

#### Interfaz del bloque analógico — para Xschem/ngspice (Fases 4 y 5)

Pines reales del subcircuito SPICE (verificados desde `netlist/schematic/*.spice`):

| Pin | Tipo | Descripción |
|---|---|---|
| `adc_in` | Analógico entrada | Señal a convertir → `user_analog[0]` |
| `adc_ena` | Digital entrada | Habilitación → de `sar_ctrl.en` internamente |
| `adc_reset` | Digital entrada | Reset del CDAC → de `sar_ctrl.dac_rst` internamente |
| `adc_hold` | Digital entrada | Hold del S&H → de `sar_ctrl.sample_n` internamente |
| `adc_dac_val[11:0]` | Digital entrada | Valor del SAR → de `sar_ctrl.data[11:0]` internamente |
| `adc_comp_out` | Digital salida | Salida del comparador → a `sar_ctrl.cmp` internamente |
| `adc_vrefH` | Analógico | Referencia alta → pad analógico externo |
| `adc_vrefL` | Analógico | Referencia baja → pad analógico externo |
| `adc_vCM` | Analógico | Modo común → pad analógico externo |
| `adc_trim` | Analógico | Calibración comparador → pad analógico externo |
| `vdda`/`vssa` | Alimentación | 3.3 V analógico |
| `vccd`/`vssd` | Alimentación | 1.8 V digital |

> **Nota:** Todos los pines `cmp`, `sample_n`, `dac_rst` son conexiones **internas**
> al macro del ADC. `freq_top.v` solo ve los pines de `sar_ctrl` (soc, en, swidth,
> data, eoc). El bloque analógico es completamente opaco desde el exterior digital.

---

## 2. Pines digitales io_in / io_out del wrapper Caravel

| Pin Caravel | Dir | Señal interna | Módulo | Descripción |
|---|---|---|---|---|
| `io_in[0]` | entrada | `fx_in` | `freq_counter.v` | Señal de frecuencia externa post-Schmitt |
| `io_in[1]` | entrada | `ext_rst_n` | `freq_top.v` | Reset externo opcional activo bajo |
| `io_in[2]` | entrada | `mode_sel_pin` | `wb_regs.v` | 0=conteo directo, 1=recíproco |
| `io_out[0]` | salida | `data_ready` | `result_latch.v` | '1' cuando resultado válido |
| `io_out[1]` | salida | `gate_active` | `gate_timer.v` | '1' durante ventana de medición |
| `io_out[2]` | salida | `adc_ready` | `adc_ctrl.v` | '1' cuando dato ADC disponible |
| `io_oeb[0:2]` | — | `1'b1` | — | io_in[0:2] como entradas |
| `io_oeb[3:5]` | — | `1'b0` | — | io_out[0:2] como salidas |

---

## 3. Registros Wishbone — VERSIÓN FINAL

Base Caravel: `0x3000_0000`

| Offset | Registro | R/W | Bits | Descripción |
|---|---|---|---|---|
| `0x00` | `FREQ_RESULT` | R | [31:0] | Conteos en T_gate |
| `0x04` | `GATE_CFG` | R/W | [26:0] | Ciclos de T_gate. Default: 100_000_000 |
| `0x08` | `ADC_DATA` | R | [11:0] | Último valor del ADC (12 bits confirmados) |
| `0x0C` | `DAC_WORD` | R/W | [7:0] | Dato al DAC (activo en modo ext_data=1) |
| `0x10` | `STATUS` | R | [3:0] | {gate_active, adc_ready, data_ready, eoc_sync} |
| `0x14` | `CTRL` | W | [8:0] | Ver detalle abajo |

**Registro CTRL [0x14]:**

| Bits | Campo | Descripción |
|---|---|---|
| [0] | `soft_rst` | Reset interno (auto-clear 1 ciclo) |
| [1] | `mode_sel` | 0=conteo directo, 1=recíproco |
| [2] | `continuous_adc` | 1=muestreo continuo del ADC |
| [3] | `dac_ext_data` | 1=DAC usa DAC_WORD; 0=rampa interna de la IP |
| [4] | `dac_load_div` | Pulso: carga DAC_WORD como divisor de velocidad |
| [8:5] | `adc_swidth[3:0]` | Tiempo de muestreo ADC en ciclos de clk |

---

## 4. Logic Analyzer

| Bits | Dir | Señal | Descripción |
|---|---|---|---|
| `la_data_out[0]` | CPU→diseño | `la_gate_force` | Fuerza GATE=1 para debug |
| `la_data_out[1]` | CPU→diseño | `la_rst_counter` | Reset manual del contador |
| `la_data_out[2]` | CPU→diseño | `la_dac_ext_data` | Fuerza ext_data=1 en el DAC |
| `la_data_in[0]` | diseño→CPU | `gate_active` | Estado de la ventana |
| `la_data_in[1]` | diseño→CPU | `data_ready` | Resultado disponible |
| `la_data_in[2]` | diseño→CPU | `eoc_sync` | EOC sincronizado |
| `la_data_in[31:3]` | diseño→CPU | `count_live[28:0]` | Contador en tiempo real |

---

## 5. Pines analógicos user_analog

| Pin | Señal IP | IP | Descripción |
|---|---|---|---|
| `user_analog[0]` | `adc_in` | ADC SAR 12b | Entrada analógica al ADC |
| `user_analog[1]` | `ua[0]` | DAC R-2R 8b | Salida analógica del DAC |
| `user_analog[2]` | `adc_vrefH` | ADC SAR 12b | Referencia alta del ADC |
| `user_analog[3]` | `adc_vrefL` | ADC SAR 12b | Referencia baja del ADC |
| `user_analog[4]` | `adc_vCM` | ADC SAR 12b | Modo común del ADC |
| `user_analog[5..7]` | — | — | Reservados |

> **Actualización v3.0:** Las referencias `adc_vrefH`, `adc_vrefL` y `adc_vCM` necesitan
> pads analógicos propios — no estaban en v2.0. Se añaden `user_analog[2:4]`.

---

## 6. Alimentación

| Dominio | Tensión | Módulos |
|---|---|---|
| `VCCD1` / `VSSD1` | 1.8 V | freq_top, sar_ctrl, celdas digitales |
| `VDDA1` / `VSSA1` | 3.3 V | Pads analógicos, bloques analógicos ADC y DAC |

---

## Pendientes resueltos / abiertos

| # | Pendiente | Estado |
|---|---|---|
| ✅ | Confirmar SIZE=12 en sar_ctrl | Resuelto: adc_dac_val[11:0] confirma 12 bits |
| ✅ | Pines reales del bloque analógico ADC | Resuelto: adc_in, adc_ena, adc_hold, adc_reset, adc_dac_val[11:0], adc_comp_out |
| ✅ | Pines de cosimulación del DAC | Resuelto: clk, n_rst, ext_data, d[7:0], load_divider → b[7:0] |
| ⚠️ | Nivel de reset DAC (3V vs 1.8V) | Abierto — investigar en Fase 4 con ngspice |
| ⚠️ | Frecuencia máxima del DAC (10 MHz comentado) | Abierto — verificar en Fase 3 con cocotb |
| ⚠️ | Ruta PDK hardcoded en mixed.cir | Abierto — corregir en Fase 5 con $PDK_ROOT |
| ⚠️ | Referencias vrefH/vrefL/vCM del ADC | Abierto — definir fuente (bandgap externo o resistor divider) en Fase 6 |

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial basada en suposiciones |
| 2.0 | Junio 2025 | Pines digitales verificados desde Verilog |
| 3.0 | Junio 2025 | Pines analógicos verificados desde SPICE; SIZE=12 confirmado; reset DAC 3V identificado; referencias ADC añadidas |
