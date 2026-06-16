# Mapa de Pines — Frecuencímetro ASIC en Caravel
**Versión:** 2.0 — Actualizada con pines reales verificados desde código fuente  
**Estado:** Fase 1 completada · Verificado contra `src/project.v`, `verilog/rtl/r2r_dac_control.v`, `verilog/sar_ctrl.v`, `verilog/sky130_ef_ip__adc3v_12bit.v`

---

## HALLAZGOS IMPORTANTES (diferencias respecto a v1.0)

| # | Supuesto original | Realidad confirmada | Impacto |
|---|---|---|---|
| 1 | DAC tiene reset activo bajo `rst_n` | DAC usa reset activo **alto** `n_rst` (invierte la lógica) | `dac_ctrl.v` debe invertir la señal de reset al conectar |
| 2 | `dac_ctrl.v` debe implementar la rampa de selftest | La rampa ya existe dentro de `r2r_dac_control` — se activa con `ext_data=0` | `dac_ctrl.v` se simplifica: solo controla `ext_data` y `ui_in[7:0]` |
| 3 | El ADC expone pines `start`, `data[11:0]`, `eoc` directamente | El ADC tiene DOS capas: `sar_ctrl.v` (lógica) + `sky130_ef_ip__adc3v_12bit.v` (analógico). Los pines de interfaz digital son los de `sar_ctrl.v` | `adc_ctrl.v` se conecta a `sar_ctrl`, no al bloque analógico directamente |
| 4 | `sar_ctrl` tiene SIZE=12 bits fijo | `sar_ctrl` tiene `parameter SIZE=8` por defecto — verificar si el wrapper del ADC instancia con SIZE=12 | Revisar `verilog/sky130_ef_ip__adc3v_12bit.v` completo antes de Fase 2 |
| 5 | ADC tiene pin `start` | ADC SAR usa pin `soc` (Start Of Conversion) | Renombrar en `adc_ctrl.v` |
| 6 | `load_divider` no anticipado en el DAC | Pin `load_divider` en `r2r_dac_control` carga el valor del divisor de la rampa interna | Controlable desde `dac_ctrl.v` para ajustar velocidad de la rampa selftest |

---

## 1. Pines de las IPs — Verificados desde código fuente

### DAC R-2R (tt_um_mattvenn_r2r_dac / r2r_dac_control)

Módulo top del DAC es `tt_um_mattvenn_r2r_dac`. El control digital interno es `r2r_dac_control`.

| Pin (módulo top) | Tipo | Conectado a en freq_top | Notas |
|---|---|---|---|
| `ui_in[7:0]` | Digital entrada | `dac_ctrl.v → dac_word[7:0]` | Dato de 8 bits. Activo cuando `ext_data=1` |
| `uio_in[0]` | Digital entrada | `dac_ctrl.v → dac_ext_data` | **`ext_data`**: 1=modo externo (lee ui_in), 0=rampa interna |
| `uio_in[1]` | Digital entrada | `dac_ctrl.v → dac_load_div` | **`load_divider`**: pulso para cargar divisor de velocidad de rampa |
| `clk` | Digital entrada | `clk_user` de Caravel | El repo indica esperar 10 MHz — verificar si 100 MHz es compatible |
| `rst_n` | Digital entrada | `~rst_n_global` ⚠️ | **Reset activo ALTO en la IP** — invertir antes de conectar |
| `ena` | Digital entrada | `1'b1` (siempre habilitado) | Enable del módulo TinyTapeout |
| `ua[0]` | Analógico salida | `user_analog[1]` | Salida analógica Vout de la escalera R-2R |
| `VPWR` / `VGND` | Alimentación | `VCCD1` / `VSSD1` | |

> ⚠️ **Nota crítica de reloj:** El comentario en `r2r_dac_control.v` dice "expect a 10M clock". Usar el PLL de Caravel a 10 MHz para esta IP, o verificar que 100 MHz no rompe la lógica del divisor interno.

### ADC SAR 12b — Capa de control digital (`sar_ctrl`)

La interfaz que conecta `adc_ctrl.v` es `sar_ctrl`, no el bloque analógico directamente.

| Pin (`sar_ctrl`) | Tipo | Conectado a en freq_top | Notas |
|---|---|---|---|
| `clk` | Digital entrada | `clk_user` de Caravel | |
| `rst_n` | Digital entrada | `rst_n_global` | Reset activo bajo — consistente con nuestro diseño |
| `soc` | Digital entrada | `adc_ctrl.v → adc_soc` | Start Of Conversion — pulso de 1 ciclo |
| `cmp` | Digital entrada | Bloque analógico `adc0_comp_out` | Salida del comparador analógico interno |
| `en` | Digital entrada | `adc_ctrl.v → adc_en` | Habilitación del SAR |
| `swidth[3:0]` | Digital entrada | `wb_regs.v → adc_swidth` | Tiempo de muestreo en ciclos de clk |
| `sample_n` | Digital salida | Bloque analógico `adc0_hold` | Control de hold del S&H analógico (`sample_n = !sample`) |
| `data[SIZE-1:0]` | Digital salida | `adc_ctrl.v → adc_data_raw` | Resultado de la conversión |
| `eoc` | Digital salida | `cdc_sync.v → async_in` | End Of Conversion — sincronizar antes de usar |
| `dac_rst` | Digital salida | Bloque analógico `adc0_reset` | Reset del CDAC interno |

> ⚠️ **Nota crítica SIZE:** `sar_ctrl` tiene `parameter SIZE = 8` por defecto. El ADC es de 12 bits — verificar que el wrapper `sky130_ef_ip__adc3v_12bit` instancia `sar_ctrl` con `SIZE=12`. Confirmar antes de escribir `adc_ctrl.v`.

### ADC SAR 12b — Capa analógica (`sky130_ef_ip__adc3v_12bit`)

Esta capa es interna al macro — no se conecta directamente desde `freq_top`. Se documenta para referencia de las simulaciones Xschem (Fase 4).

| Pin | Tipo | Conectado internamente a |
|---|---|---|
| `adc0` | Analógico entrada | `user_analog[0]` (señal externa) |
| `adc0_ena` | Digital entrada | `sar_ctrl → en` (interno) |
| `adc0_reset` | Digital entrada | `sar_ctrl → dac_rst` (interno) |
| `adc0_hold` | Digital entrada | `sar_ctrl → sample_n` invertido (interno) |
| `adc0_dac_val_0[11:0]` | Digital entrada | `sar_ctrl → data` durante conversión (interno) |
| `adc0_comp_out` | Digital salida | `sar_ctrl → cmp` (interno) |
| `adc_vrefH` / `adc_vrefL` | Analógico entrada | Referencias de tensión externas |
| `adc_vCM` | Analógico entrada | Tensión de modo común |
| `adc_trim` | Analógico entrada | Calibración de offset del comparador |

---

## 2. Pines digitales io_in / io_out del wrapper Caravel

| Pin Caravel | Dirección | Señal interna | Módulo | Descripción |
|---|---|---|---|---|
| `io_in[0]` | entrada | `fx_in` | `freq_counter.v` | Señal de frecuencia externa (post-Schmitt trigger) |
| `io_in[1]` | entrada | `ext_rst_n` | `freq_top.v` | Reset externo activo bajo (opcional) |
| `io_in[2]` | entrada | `mode_sel_pin` | `wb_regs.v` | Modo: 0=conteo directo, 1=recíproco |
| `io_out[0]` | salida | `data_ready` | `result_latch.v` | '1' cuando hay resultado válido |
| `io_out[1]` | salida | `gate_active` | `gate_timer.v` | '1' durante ventana de medición activa |
| `io_out[2]` | salida | `adc_ready` | `adc_ctrl.v` | '1' cuando hay dato nuevo del ADC |
| `io_oeb[0:2]` | — | `1'b1` | — | io_in[0:2] siempre como entradas |
| `io_oeb[3:5]` | — | `1'b0` | — | io_out[0:2] siempre como salidas |

---

## 3. Bus Wishbone (sin cambios respecto a v1.0)

Dirección base Caravel: `0x3000_0000`

| Offset | Registro | R/W | Descripción | Cambios v2.0 |
|---|---|---|---|---|
| `0x00` | `FREQ_RESULT` | R | Conteos en T_gate | Sin cambio |
| `0x04` | `GATE_CFG` | R/W | gate_cycles[26:0] | Sin cambio |
| `0x08` | `ADC_DATA` | R | Dato ADC [11:0 o 7:0 — ver nota SIZE] | ⚠️ Verificar ancho |
| `0x0C` | `DAC_WORD` | R/W | Dato al DAC [7:0] (activo cuando ext_data=1) | Sin cambio |
| `0x10` | `STATUS` | R | {gate_active, adc_ready, data_ready, eoc_sync} | Sin cambio |
| `0x14` | `CTRL` | W | {adc_swidth[3:0], dac_ext_data, dac_load_div, soft_rst} | ⚠️ Actualizado: selftest ahora es dac_ext_data=0 |

---

## 4. Logic Analyzer (sin cambios respecto a v1.0)

| Bits LA | Dirección | Señal | Descripción |
|---|---|---|---|
| `la_data_out[0]` | CPU→diseño | `la_gate_force` | Fuerza GATE=1 (debug) |
| `la_data_out[1]` | CPU→diseño | `la_rst_counter` | Reset manual del contador |
| `la_data_out[2]` | CPU→diseño | `la_dac_ext_data` | Fuerza ext_data=1 en el DAC (debug) |
| `la_data_in[0]` | diseño→CPU | `gate_active` | Estado de la ventana |
| `la_data_in[1]` | diseño→CPU | `data_ready` | Resultado disponible |
| `la_data_in[2]` | diseño→CPU | `eoc_sync` | EOC sincronizado |
| `la_data_in[31:3]` | diseño→CPU | `count_live[28:0]` | Contador en tiempo real |

---

## 5. Alimentación (sin cambios respecto a v1.0)

| Dominio | Tensión | Módulos |
|---|---|---|
| `VCCD1` / `VSSD1` | 1.8 V | freq_top, celdas digitales |
| `VDDA1` / `VSSA1` | 3.3 V | Pads analógicos, DAC, ADC |

---

## Pendientes antes de Fase 2

- [ ] Confirmar que `sky130_ef_ip__adc3v_12bit` instancia `sar_ctrl` con `SIZE=12` (leer el wrapper completo del ADC)
- [ ] Confirmar frecuencia máxima de operación del DAC (comentario dice 10 MHz — ¿soporta 100 MHz?)
- [ ] Definir qué referencia de tensión (`adc_vrefH`, `adc_vrefL`) se conecta a los pads analógicos de Caravel

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial basada en suposiciones |
| 2.0 | Junio 2025 | Actualización con pines reales verificados desde código fuente |
