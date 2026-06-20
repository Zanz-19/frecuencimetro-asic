# Mapa de Pines — Frecuencímetro ASIC en Caravel
**Versión:** 4.0 — Incorpora hallazgos de Fase 2 verificados por simulación RTL real
**Estado:** Fase 2 completada (7/8 módulos) · Verificado contra simulación con IPs reales (`sar_ctrl.v`, `r2r_dac_control.v`)
**Fuentes verificadas en esta versión:**
- Simulación iverilog de `adc_ctrl.v` + `sar_ctrl.v` real (13/13 tests)
- Simulación iverilog de `dac_ctrl.v` + `r2r_dac_control.v` real (20/20 tests)
- Medición empírica de timing `soc→eoc` directamente sobre `sar_ctrl.v`

---

## ⚠️ CORRECCIÓN CRÍTICA v4.0 — Reset del DAC

**v3.0 indicaba (INCORRECTO, sin verificar por simulación):**
> `rst_n`... Activo ALTO en la IP. Conectado a: `~rst_n_global` (invertido)

**v4.0 corrige (VERIFICADO por simulación real, 20/20 tests):**

El pin real en `r2r_dac_control.v` se llama **`n_rst`**, y su lógica interna es:

```verilog
always @(posedge clk or posedge n_rst) begin
    if (n_rst)  rst <= 1'b0;   // n_rst=1 -> rst interno=0 -> IP OPERA
    else        rst <= 1'b1;   // n_rst=0 -> rst interno=1 -> IP RESETEA
end
```

`n_rst` se comporta como un **enable activo en alto**, no como un reset invertido convencional (el nombre del pin es engañoso). Esto **coincide exactamente** con la convención de `rst_n` que usamos en el resto del proyecto (activo bajo = en reset):

| Nuestra señal | Valor | Significado | `dac_n_rst` debe ser | Resultado en la IP |
|---|---|---|---|---|
| `rst_n` | 0 | En reset | 0 | IP resetea ✅ |
| `rst_n` | 1 | Operando | 1 | IP opera ✅ |

**Conexión correcta confirmada: `dac_n_rst = rst_n` — SIN inversión.**

> Si se conecta invertido (como sugería v3.0), el DAC quedaría permanentemente en reset en el chip real y nunca generaría ninguna salida. Este es el hallazgo más crítico de la Fase 2.

*Nota sobre el nivel de 3V mencionado en v3.0 (`mixed.cir: PULSE 3 0`): eso es independiente de esta corrección — se refiere al nivel de tensión analógico de la simulación SPICE original del autor, no a la polaridad lógica del pin. Sigue como pendiente abierto para Fase 4 (ver tabla de pendientes).*

---

## HALLAZGOS DE FASE 2 (verificados por simulación RTL, nuevos en v4.0)

| # | Hallazgo | Verificado en | Impacto |
|---|---|---|---|
| 1 | `dac_n_rst = rst_n` sin inversión (ver corrección arriba) | `tb_dac_ctrl.v`, 20/20 | Crítico — corrige v3.0 |
| 2 | Timing real `soc→eoc` de `sar_ctrl`: **`15 + swidth` ciclos** (con SIZE=12) | Medición directa sobre `sar_ctrl.v`, swidth=0→15, swidth=5→20, swidth=15→30 | Confirma diseño de `adc_ctrl.v`; útil para Fase 3 (cálculo de throughput) |
| 3 | Modelo de comparador SAR para testbenches: `cmp = ((result \| shift) <= target)` | Verificado contra 5 valores (0x000, 0x800, 0xFFF, 0x3E7) con coincidencia exacta | Solo relevante para testbenches futuros (Fase 3), no para el RTL en sí |
| 4 | `adc_ready` y `data_ready` son banderas persistentes, NO pulsos | Confirmado en `result_latch` y `adc_ctrl`; causó bugs de testbench en ambos módulos | Documentado aquí para que el firmware (Fase 7) no asuma que son pulsos — debe leer y, si necesita re-armar, usar `soft_rst` o esperar el siguiente ciclo de medición |
| 5 | El modo selftest del DAC ya existe dentro de la IP (`ext_data=0`) | Confirmado en `tb_dac_ctrl.v`, rampa interna incrementando automáticamente | `dac_ctrl.v` no reimplementa la rampa, solo la habilita/deshabilita |

---

## 1. Pines reales de las IPs — verificados por simulación

### DAC R-2R — Interfaz de control digital (`r2r_dac_control`)

**Módulo top:** `tt_um_mattvenn_r2r_dac` (src/project.v)
**Control digital:** `r2r_dac_control` (verilog/rtl/r2r_dac_control.v) — **este es el módulo que `dac_ctrl.v` instancia directamente**

| Pin | Tipo | Conectado desde `dac_ctrl.v` | Notas verificadas |
|---|---|---|---|
| `clk` | Digital entrada | `clk` (pasa transparente) | Comentario en IP: "expect a 10M clock" — pendiente verificar a 100MHz en Fase 3 |
| `n_rst` | Digital entrada | `dac_n_rst = rst_n` | ✅ **Sin inversión** (ver corrección crítica arriba) |
| `ext_data` | Digital entrada | `dac_ext_data` | 1=modo externo (usa `data`), 0=rampa interna (selftest) |
| `data[7:0]` | Digital entrada | `dac_data_out = dac_word` | Dato de 8 bits; en modo selftest la IP lo usa como divisor al recibir `load_divider` |
| `load_divider` | Digital entrada | `dac_load_div` | Pulso de 1 ciclo: carga `data[7:0]` como divisor de velocidad de rampa |
| `r2r_out[7:0]` | Digital salida | (hacia la escalera R-2R analógica, fuera del alcance de `dac_ctrl.v`) | Verificado: refleja `data` en modo externo; incrementa automáticamente en modo selftest |

**Tabla de velocidad de rampa (modo selftest, divisor cargado vía `load_divider`):**

| Divisor | Comportamiento verificado |
|---|---|
| 0 | Avanza ~1 paso cada pocos ciclos de clk (rampa rápida) — confirmado: incrementó de 8 a 13 en 10 ciclos de clk en simulación |
| N | Avanza 1 paso cada `(N << 8)` ciclos de clk, según fórmula del RTL: `counter >= (divider << 8)` |

### ADC SAR 12b — Interfaz de control digital (`sar_ctrl`)

**Control SAR digital:** `sar_ctrl #(.SIZE(12))` (verilog/sar_ctrl.v) — **este es el módulo que `adc_ctrl.v` instancia directamente**, confirmado con `SIZE(12)` en el testbench oficial de la IP (`adc_testbench.v`, línea de instanciación verificada).

| Pin (`sar_ctrl`) | Tipo | Conectado desde `adc_ctrl.v` | Notas verificadas |
|---|---|---|---|
| `clk` | Digital entrada | `clk` (pasa transparente) | |
| `rst_n` | Digital entrada | `rst_n` (pasa transparente) | Activo bajo — consistente con nuestra convención, sin inversión necesaria |
| `soc` | Digital entrada | `adc_soc` | Pulso de 1 ciclo, generado por la FSM de `adc_ctrl.v` |
| `cmp` | Digital entrada | (en freq_top: viene del bloque analógico vía `eoc_sync`/lazo interno; en testbench: modelo de comparador) | No conectado directamente por `adc_ctrl.v` |
| `en` | Digital entrada | `adc_en` | Habilitado permanentemente tras salir de reset (verificado) |
| `swidth[3:0]` | Digital entrada | (vía `wb_regs.adc_swidth`, no implementado aún en `adc_ctrl.v` v1 — usa swidth fijo en pruebas) | ⚠️ Pendiente conectar en `freq_top.v` |
| `data[11:0]` | Digital salida | `adc_data_raw[11:0]` → `adc_ctrl.adc_result` | **SIZE=12 confirmado por simulación**, no solo por inspección |
| `eoc` | Digital salida | (vía `cdc_sync` en el sistema completo; en el testbench de `adc_ctrl` se conecta directo para aislar el módulo) | Timing verificado: sube exactamente `15+swidth` ciclos después de `soc` |
| `dac_rst` | Digital salida | (interno, hacia el CDAC del bloque analógico) | No conectado por `adc_ctrl.v` |
| `sample_n` | Digital salida | (interno, hacia el S&H del bloque analógico) | No conectado por `adc_ctrl.v` |

> **Pendiente para `freq_top.v`:** la entrada `swidth[3:0]` de `adc_ctrl.v` debe conectarse a `wb_regs.adc_swidth` (ya existe esa salida en `wb_regs.v`, verificada en Fase 2). En las pruebas unitarias de `adc_ctrl.v` se usó `swidth=0` fijo para simplificar — confirmar en la integración que la señal fluye correctamente extremo a extremo.

### ADC SAR 12b — Bloque analógico (pendiente de re-verificación)

*Los pines de esta sección provienen de v3.0 (inspección de netlist SPICE), no fueron re-verificados por simulación en Fase 2 porque `adc_ctrl.v` no se conecta a este bloque directamente — esa conexión ocurre en Fase 4 (Xschem). Se mantienen aquí como referencia, marcados como pendientes de confirmación:*

| Pin | Tipo | Descripción | Estado |
|---|---|---|---|
| `adc_in` | Analógico entrada | Señal a convertir | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_ena` | Digital entrada | Habilitación (viene de `sar_ctrl.en`) | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_reset` | Digital entrada | Reset del CDAC (viene de `sar_ctrl.dac_rst`) | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_hold` | Digital entrada | Hold del S&H (viene de `sar_ctrl.sample_n`) | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_dac_val[11:0]` | Digital entrada | Valor del SAR (viene de `sar_ctrl.data`) | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_comp_out` | Digital salida | Salida del comparador (va a `sar_ctrl.cmp`) | ⚠️ Pendiente confirmar en Fase 4 |
| `adc_vrefH` / `adc_vrefL` / `adc_vCM` / `adc_trim` | Analógico | Referencias y calibración | ⚠️ Pendiente confirmar en Fase 4 |

---

## 2. Pines digitales io_in / io_out del wrapper Caravel

*(Sin cambios respecto a v3.0 — no se tocó en Fase 2)*

| Pin Caravel | Dir | Señal interna | Módulo | Descripción |
|---|---|---|---|---|
| `io_in[0]` | entrada | `fx_in` | `freq_counter.v` | Señal de frecuencia externa post-Schmitt |
| `io_in[1]` | entrada | `ext_rst_n` | `freq_top.v` | Reset externo opcional activo bajo |
| `io_in[2]` | entrada | `mode_sel_pin` | `wb_regs.v` | 0=conteo directo, 1=recíproco |
| `io_out[0]` | salida | `data_ready` | `result_latch.v` | '1' cuando resultado válido (persiste, no es pulso — ver hallazgo #4) |
| `io_out[1]` | salida | `gate_active` | `gate_timer.v` | '1' durante ventana de medición |
| `io_out[2]` | salida | `adc_ready` | `adc_ctrl.v` | '1' cuando dato ADC disponible (persiste, no es pulso — ver hallazgo #4) |
| `io_oeb[0:2]` | — | `1'b1` | — | io_in[0:2] como entradas |
| `io_oeb[3:5]` | — | `1'b0` | — | io_out[0:2] como salidas |

---

## 3. Registros Wishbone — verificado por simulación (30/30 tests en `wb_regs.v`)

Base Caravel: `0x3000_0000`

| Offset | Registro | R/W | Bits | Descripción | Verificado |
|---|---|---|---|---|---|
| `0x00` | `FREQ_RESULT` | R | [31:0] | Conteos en T_gate | ✅ Refleja entrada externa correctamente |
| `0x04` | `GATE_CFG` | R/W | [26:0] | Ciclos de T_gate. Default: 100_000_000 | ✅ R/W confirmado, default confirmado |
| `0x08` | `ADC_DATA` | R | [11:0] | Último valor del ADC | ✅ Padding de bits altos en 0 confirmado |
| `0x0C` | `DAC_WORD` | R/W | [7:0] | Dato al DAC (activo en modo ext_data=1) | ✅ R/W confirmado |
| `0x10` | `STATUS` | R | [3:0] | `{mode_sel, gate_active, adc_ready, data_ready}` | ✅ Combinación de 4 flags verificada bit a bit |
| `0x14` | `CTRL` | W | [8:0] | Ver detalle abajo | ✅ Decodificación de los 9 bits verificada individualmente |

**Registro CTRL [0x14] — verificado bit por bit:**

| Bits | Campo | Comportamiento verificado |
|---|---|---|
| [0] | `soft_rst` | Pulso de 1 ciclo, auto-clear confirmado |
| [1] | `mode_sel` | Persistente (no es pulso), confirmado |
| [2] | `continuous_adc` | Persistente, confirmado |
| [3] | `dac_ext_data` | Persistente, confirmado |
| [4] | `dac_load_div` | Pulso de 1 ciclo, auto-clear confirmado |
| [8:5] | `adc_swidth[3:0]` | Persistente, confirmado |

> **Nota de v3.0 corregida:** el `STATUS` en v3.0 listaba el orden `{gate_active, adc_ready, data_ready, eoc_sync}`. La implementación real verificada en `wb_regs.v` usa `{mode_sel, gate_active, adc_ready, data_ready}` (sin `eoc_sync`, que no es una señal que `wb_regs.v` reciba directamente). Ver `module_list.md` v3.0 para el detalle completo del módulo.

---

## 4. Logic Analyzer

*(Sin cambios respecto a v3.0 — no se tocó ni verificó en Fase 2)*

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

*(Sin cambios respecto a v3.0 — pendiente de confirmación en Fase 4, no tocado en Fase 2)*

| Pin | Señal IP | IP | Estado |
|---|---|---|---|
| `user_analog[0]` | `adc_in` | ADC SAR 12b | ⚠️ Pendiente Fase 4 |
| `user_analog[1]` | `ua[0]` | DAC R-2R 8b | ⚠️ Pendiente Fase 4 |
| `user_analog[2]` | `adc_vrefH` | ADC SAR 12b | ⚠️ Pendiente Fase 4 |
| `user_analog[3]` | `adc_vrefL` | ADC SAR 12b | ⚠️ Pendiente Fase 4 |
| `user_analog[4]` | `adc_vCM` | ADC SAR 12b | ⚠️ Pendiente Fase 4 |
| `user_analog[5..7]` | — | Reservados | — |

---

## 6. Alimentación

*(Sin cambios respecto a v3.0)*

| Dominio | Tensión | Módulos |
|---|---|---|
| `VCCD1` / `VSSD1` | 1.8 V | freq_top, sar_ctrl, celdas digitales |
| `VDDA1` / `VSSA1` | 3.3 V | Pads analógicos, bloques analógicos ADC y DAC |

---

## Pendientes actualizados tras Fase 2

| # | Pendiente | Estado | Fase objetivo |
|---|---|---|---|
| ✅ | Polaridad de reset del DAC | **Resuelto en Fase 2** — sin inversión, `dac_n_rst = rst_n` | — |
| ✅ | SIZE del ADC (8 vs 12) | **Resuelto en Fase 2** — 12 confirmado por simulación | — |
| ✅ | Timing soc→eoc del ADC | **Resuelto en Fase 2** — `15+swidth` ciclos medido | — |
| ⚠️ | Conectar `adc_swidth` desde `wb_regs` hasta `sar_ctrl` en la integración completa | Abierto | Fase 2 (freq_top.v) |
| ⚠️ | Nivel de tensión del reset DAC (3V en `mixed.cir` original) | Abierto — no es polaridad, es nivel de tensión analógica | Fase 4 |
| ⚠️ | Frecuencia máxima real del DAC a 100MHz (comentario dice 10MHz) | Abierto | Fase 3 (cocotb) |
| ⚠️ | Pines del bloque analógico del ADC (`adc_in`, `adc_ena`, etc.) | Abierto — no verificado por simulación, solo inspección | Fase 4 |
| ⚠️ | Ruta PDK hardcoded en `mixed.cir` | Abierto | Fase 5 |
| ⚠️ | Fuente de referencias `vrefH`/`vrefL`/`vCM` del ADC | Abierto | Fase 6 |

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial basada en suposiciones |
| 2.0 | Junio 2025 | Pines digitales verificados desde Verilog (inspección) |
| 3.0 | Junio 2025 | Pines analógicos verificados desde SPICE; SIZE=12 confirmado por inspección; reset DAC marcado como activo alto (sin verificar por simulación) |
| 4.0 | Junio 2025 | **Fase 2 completada (7/8 módulos) con verificación por simulación real.** Corrige la polaridad del reset del DAC (era incorrecta en v3.0). Confirma timing soc→eoc del ADC. Documenta comportamiento persistente de banderas ready. Separa claramente lo verificado por simulación de lo pendiente de Fase 4 |
