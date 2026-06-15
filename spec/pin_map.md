# Mapa de Pines — Frecuencímetro ASIC en Caravel
**Estado:** Fase 1 — Borrador inicial (verificar contra GDS de las IPs antes de Fase 6)

---

## 1. Pines digitales io_in / io_out

| Pin Caravel | Dirección | Señal interna | Módulo | Descripción |
|---|---|---|---|---|
| `io_in[0]` | entrada | `fx_in` | `freq_counter.v` | Señal de frecuencia externa (post-Schmitt) |
| `io_in[1]` | entrada | `ext_rst_n` | `freq_top.v` | Reset externo activo bajo (opcional) |
| `io_in[2]` | entrada | `mode_sel` | `wb_regs.v` | Selección de modo: 0=conteo directo, 1=recíproco |
| `io_out[0]` | salida | `data_ready` | `result_latch.v` | '1' cuando hay resultado válido disponible |
| `io_out[1]` | salida | `gate_active` | `gate_timer.v` | '1' durante la ventana de medición activa |
| `io_out[2]` | salida | `adc_ready` | `adc_ctrl.v` | '1' cuando hay dato nuevo del ADC |
| `io_oeb[0]` | — | `1'b1` | — | io_in[0] siempre como entrada |
| `io_oeb[1]` | — | `1'b1` | — | io_in[1] siempre como entrada |
| `io_oeb[2]` | — | `1'b1` | — | io_in[2] siempre como entrada |
| `io_oeb[3..5]` | — | `1'b0` | — | io_out[0..2] siempre como salida |

> **Pines io_in[3:37] e io_out[3:37]:** Sin asignar en esta versión. Reservados para expansión futura o uso como bus de datos paralelo si la interfaz Wishbone no es suficiente.

---

## 2. Pines analógicos user_analog

| Pin Caravel | Señal IP | IP | Descripción |
|---|---|---|---|
| `user_analog[0]` | `ain` | ADC SAR 12b | Entrada analógica al ADC (señal a medir por Camino B) |
| `user_analog[1]` | `ua[0]` / `vout` | DAC R-2R 8b | Salida analógica del DAC (modo selftest o salida de síntesis) |
| `user_analog[2..7]` | — | — | Sin asignar. Reservados. |

> **Nota de layout:** Los pads user_analog están limitados a la zona periférica del wrapper con acceso al anillo analógico (VDDA1/VSSA1). El Schmitt trigger que procesa la señal de `user_analog[0]` para el Camino A debe estar físicamente cerca de este pad para minimizar la longitud de la net analógica.

---

## 3. Bus Wishbone (interfaz con el CPU PicoRV32 de Caravel)

El bus Wishbone llega al módulo `wb_regs.v` dentro de `freq_top`. Las señales son las estándar de Caravel:

| Señal Caravel | Dirección | Señal en freq_top | Descripción |
|---|---|---|---|
| `wbs_stb_i` | entrada | `wb_stb` | Strobe: transacción válida en el bus |
| `wbs_cyc_i` | entrada | `wb_cyc` | Cycle: bus ocupado |
| `wbs_we_i` | entrada | `wb_we` | Write enable: 1=escritura, 0=lectura |
| `wbs_sel_i[3:0]` | entrada | `wb_sel` | Byte select |
| `wbs_dat_i[31:0]` | entrada | `wb_dat_i` | Dato de escritura del CPU |
| `wbs_adr_i[31:0]` | entrada | `wb_adr` | Dirección del registro |
| `wbs_ack_o` | salida | `wb_ack` | Acknowledge: transacción completada |
| `wbs_dat_o[31:0]` | salida | `wb_dat_o` | Dato de lectura al CPU |

### Decodificación de dirección

El `user_project_wrapper` recibe direcciones Wishbone con base en `0x3000_0000`. El `wb_regs.v` decodifica los bits bajos:

| Dirección absoluta | Offset | Registro | R/W |
|---|---|---|---|
| `0x3000_0000` | `0x00` | `FREQ_RESULT` | R |
| `0x3000_0004` | `0x04` | `GATE_CFG` | R/W |
| `0x3000_0008` | `0x08` | `ADC_DATA` | R |
| `0x3000_000C` | `0x0C` | `DAC_OUT` | R/W |
| `0x3000_0010` | `0x10` | `STATUS` | R |
| `0x3000_0014` | `0x14` | `CTRL` | W |

---

## 4. Logic Analyzer (debug desde el CPU)

Caravel ofrece 128 bits de Logic Analyzer entre el CPU y el diseño de usuario. Se asignan los primeros 32 bits para observabilidad del frecuencímetro:

| Bit LA | Dirección | Señal | Descripción |
|---|---|---|---|
| `la_data_out[0]` | CPU→diseño | `la_gate_force` | Fuerza GATE=1 manualmente (debug) |
| `la_data_out[1]` | CPU→diseño | `la_rst_counter` | Resetea el contador manualmente |
| `la_data_out[2]` | CPU→diseño | `la_selftest_en` | Activa modo selftest (alternativo a CTRL vía Wishbone) |
| `la_data_in[0]` | diseño→CPU | `gate_active` | Estado actual de la ventana de medición |
| `la_data_in[1]` | diseño→CPU | `data_ready` | Resultado disponible |
| `la_data_in[2]` | diseño→CPU | `adc_eoc_sync` | EOC del ADC sincronizado |
| `la_data_in[31:3]` | diseño→CPU | `count_live[28:0]` | Valor del contador en tiempo real (29 bits) |

---

## 5. Alimentación y dominios de tensión

| Dominio | Tensión | Conectado a | Módulos |
|---|---|---|---|
| `VCCD1` / `VSSD1` | 1.8 V | Lógica digital | freq_top, celdas estándar |
| `VDDA1` / `VSSA1` | 3.3 V | Analógico | Pads analógicos, DAC, ADC |
| `VCCD2` / `VSSD2` | 1.8 V (reserva) | Sin usar | — |
| `VDDA2` / `VSSA2` | 3.3 V (reserva) | Sin usar | — |

> **Precaución de layout:** Los power straps de VCCD1 y VDDA1 deben estar físicamente separados en el floorplan para evitar acoplamiento de switching noise digital hacia las señales analógicas.

---

## 6. Pines de las IPs (referencia directa de repositorios)

### DAC R-2R 8b (mattvenn/tt06-analog-r2r-dac)

> ⚠️ Verificar nombres exactos contra el archivo `xschem/r2r_dac.sch` del repositorio antes de la Fase 6.

| Pin IP | Tipo | Conectado a en el wrapper |
|---|---|---|
| `ui_in[7:0]` | Digital entrada | `dac_ctrl.v` → `dac_out[7:0]` |
| `clk` | Digital entrada | `clk_user` de Caravel |
| `rst_n` | Digital entrada | `rst_n` global |
| `ua[0]` | Analógico salida | `user_analog[1]` (Vout externo) + lazo interno al Schmitt (selftest) |
| `vccd` | Alimentación | `VCCD1` (1.8 V) |
| `vssd` | GND | `VSSD1` |
| `vdda` | Alimentación analógica | `VDDA1` (3.3 V) |
| `vssa` | GND analógico | `VSSA1` |

### ADC SAR 12b (chipfoundry/sky130_ef_ip__adc3v_12bit)

> ⚠️ Verificar nombres exactos contra el archivo `verilog/sky130_ef_ip__adc3v_12bit.v` y `xschem/*.sch` del repositorio antes de la Fase 6.

| Pin IP | Tipo | Conectado a en el wrapper |
|---|---|---|
| `ain` | Analógico entrada | `user_analog[0]` (señal externa) |
| `clk` | Digital entrada | `clk_user` de Caravel |
| `rst_n` | Digital entrada | `rst_n` global |
| `ena` | Digital entrada | `adc_ctrl.v` → `adc_ena` |
| `start` | Digital entrada | `adc_ctrl.v` → `adc_start` (pulso) |
| `data[11:0]` | Digital salida | `adc_ctrl.v` → `adc_data_raw[11:0]` |
| `eoc` | Digital salida | `cdc_sync.v` → (sincronizado) → `adc_ctrl.v` |
| `vccd` | Alimentación | `VCCD1` (1.8 V) |
| `vssd` | GND | `VSSD1` |
| `vdda` | Alimentación analógica | `VDDA1` (3.3 V) |
| `vssa` | GND analógico | `VSSA1` |

---

## Historial de cambios

| Fecha | Cambio | Fase |
|---|---|---|
| Junio 2025 | Versión inicial | Fase 1 |
| — | Verificar pines exactos de IPs contra repositorios | Antes de Fase 6 |
