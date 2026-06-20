# Contratos de Interfaz de Módulos — Frecuencímetro ASIC
**Versión:** 3.0 — Fase 2 completada (7/8 módulos), interfaces confirmadas por simulación real
**Estado:** cdc_sync, gate_timer, freq_counter, result_latch, adc_ctrl, dac_ctrl, wb_regs ✅ verificados · freq_top pendiente

---

## Resumen de verificación

| Módulo | Tests | Resultado | IP externa integrada |
|---|---|---|---|
| `cdc_sync.v` | 12/12 | ✅ | — |
| `gate_timer.v` | 12/12 | ✅ | — |
| `freq_counter.v` | 9/9 | ✅ | — |
| `result_latch.v` | 14/14 | ✅ | — |
| `adc_ctrl.v` | 13/13 | ✅ | `sar_ctrl.v` real (chipfoundry) |
| `dac_ctrl.v` | 20/20 | ✅ | `r2r_dac_control.v` real (mattvenn) |
| `wb_regs.v` | 30/30 | ✅ | — |
| `freq_top.v` | — | 🔲 Pendiente | ambas IPs (integración completa) |

---

## Orden de desarrollo (confirmado, sin cambios respecto al plan original)

```
1. cdc_sync.v     → sin dependencias                         ✅
2. gate_timer.v   → sin dependencias                         ✅
3. freq_counter.v → depende de gate_en (de gate_timer)        ✅
4. result_latch.v → depende de count_out, gate_done            ✅
5. adc_ctrl.v     → depende de eoc_sync (de cdc_sync)          ✅
6. dac_ctrl.v     → sin dependencias de otros módulos nuevos   ✅
7. wb_regs.v      → depende de todos los anteriores            ✅
8. freq_top.v     → instancia y conecta todo                   🔲
```

---

## 1. `cdc_sync.v` — Sincronizador de dominio de reloj ✅

**Verificado:** 12/12 tests, cero warnings de compilación.

**Interfaz (sin cambios respecto al diseño original):**
```verilog
module cdc_sync #(parameter STAGES = 2) (
    input  wire clk, rst_n,
    input  wire async_in,
    output wire sync_out
);
```

**Cobertura de pruebas:** reset con señal en alto, latencia exacta de STAGES ciclos, 4 offsets de fase distintos respecto al flanco de clk, pulso más corto que un período (verifica estado siempre definido, sin X/Z), reset durante propagación activa.

**Lección aplicada en módulos posteriores:** ninguna corrección de bug en este módulo — fue el primero y sirvió como plantilla de estilo (atributo `(* keep *)` para evitar optimización por el sintetizador).

---

## 2. `gate_timer.v` — Generador de ventana T_gate ✅

**Verificado:** 12/12 tests, cero warnings.

**Interfaz (sin cambios):**
```verilog
module gate_timer (
    input  wire clk, rst_n, start,
    input  wire [26:0] gate_cycles,
    output reg  gate_en, gate_done
);
```

**Cobertura de pruebas:** reset, duración exacta para 10 y 1000 ciclos, pulso `gate_done` de exactamente 1 ciclo, `start` ignorado durante ventana activa (no reinicia el timer), reset corta una ventana activa, `gate_cycles=0` como configuración inválida (se ignora), dos ciclos de medición consecutivos.

**Bug encontrado y corregido (solo en testbench, no en RTL):** off-by-one en el cálculo manual de espera del Caso 4 — el testbench esperaba `gate_cycles` ciclos tras ver `start=0`, cuando la cantidad correcta es `gate_cycles - 1` (porque la FSM ya transicionó a RUNNING en el flanco donde se ve `start=0`, con `count` precargado en `gate_cycles - 1`). El RTL nunca tuvo el bug; confirmado con 4 trazas de depuración distintas.

---

## 3. `freq_counter.v` — Contador de pulsos de 32 bits ✅

**Verificado:** 9/9 tests, cero warnings.

**Interfaz (sin cambios):**
```verilog
module freq_counter (
    input  wire clk, rst_n, gate_en, cnt_reset, fx_in,
    output reg  [31:0] count_out,
    output reg  count_valid
);
```

**Cobertura de pruebas:** reset, medición básica a 10MHz con T_gate=100µs (~1000 conteos), conteo exacto manual de 7 flancos, pulso `count_valid` de 1 ciclo, flanco fuera de la ventana no se cuenta, `cnt_reset` con prioridad sobre conteo simultáneo, mediciones consecutivas independientes.

**Bug encontrado y corregido (solo en testbench, no en RTL):** carrera de simulación clásica — cada vez que el testbench ponía `cnt_reset=1` y luego hacía `@(posedge clk)` seguido inmediatamente de `cnt_reset=0` **sin un delay `#1` intermedio**, la lectura de `count_out` inmediatamente después podía capturar el valor *antes* de que el `always` del DUT aplicara el reset, dependiendo del orden de resolución de eventos del simulador en ese mismo instante. **Lección aplicada de aquí en adelante:** todo cambio de señal de control inmediatamente después de un `@(posedge clk)` debe ir seguido de `#1` antes de leer cualquier salida del DUT o cambiar otra entrada. Esta regla se aplicó preventivamente en todos los testbenches posteriores (`result_latch`, `adc_ctrl`, `dac_ctrl`, `wb_regs`), evitando que el mismo patrón de bug reapareciera.

---

## 4. `result_latch.v` — Registro de captura del resultado ✅

**Verificado:** 14/14 tests, cero warnings, **sin ningún bug** (ni en RTL ni en testbench) — primera verificación limpia a la primera, gracias a aplicar desde el inicio la lección del `#1` del módulo anterior.

**Interfaz (sin cambios):**
```verilog
module result_latch (
    input  wire clk, rst_n, latch_en,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg  data_ready
);
```

**Cobertura de pruebas:** reset, primera captura, estabilidad de `data_out` mientras `latch_en=0` (incluso si `data_in` cambia), segunda captura actualiza el valor, persistencia de `data_ready` (no es un pulso — comportamiento documentado y confirmado), valores de esquina (`0x00000000` y `0xFFFFFFFF`), reset tras varias capturas, `latch_en` sostenido por varios ciclos (no solo como pulso de 1 ciclo).

**Hallazgo de comportamiento (no bug):** `data_ready` sube en la primera captura y permanece en 1 indefinidamente — no se "rearma" en cada captura. Esto es intencional pero importante para el firmware de Fase 7: no se debe esperar un flanco de subida de `data_ready` para detectar una *nueva* medición; hay que comparar el valor de `data_out` o usar otro mecanismo (ver hallazgo equivalente en `adc_ctrl.v` abajo).

---

## 5. `adc_ctrl.v` — Controlador del ADC SAR ✅

**Verificado:** 13/13 tests, integrado con `sar_ctrl.v` **real** de la IP (chipfoundry/sky130_ef_ip__adc3v_12bit), no un mock.

**Interfaz actualizada (confirmada por simulación):**
```verilog
module adc_ctrl (
    input  wire        clk, rst_n,
    input  wire        eoc_sync,
    input  wire [11:0] adc_data_raw,
    output reg          adc_soc,
    output reg          adc_en,
    output reg  [11:0] adc_result,
    output reg          adc_ready,
    input  wire         continuous_en,
    input  wire         adc_trigger
);
```
*(Pendiente para `freq_top.v`: añadir entrada `swidth[3:0]` desde `wb_regs.adc_swidth` — en las pruebas unitarias se fijó `swidth=0` directamente en la instancia de `sar_ctrl` del testbench, no a través de `adc_ctrl.v`. Ver pin_map.md v4.0, sección de pendientes.)*

**Timing verificado empíricamente (no derivado de memoria):**
```
ciclos_soc_a_eoc = 15 + swidth   (con SIZE=12)
swidth=0  -> 15 ciclos  (medido)
swidth=5  -> 20 ciclos  (medido)
swidth=15 -> 30 ciclos  (medido)
```

**Cobertura de pruebas:** reset, conversión single-shot con valores mínimo/medio/máximo/arbitrario (0x000, 0x800, 0xFFF, 0x3E7) capturados exactamente, pulso `adc_soc` de 1 ciclo, modo single-shot no se repite sin nuevo trigger, modo continuo encadena conversiones automáticamente, `adc_en` permanece activo tras reset, reset durante una conversión en curso.

**Dos bugs encontrados y corregidos (ambos en testbench, no en RTL):**
1. Modelo de comparador SAR incorrecto: comparar `sar.result <= target` daba resultados erróneos en conversiones posteriores a la primera. La fórmula correcta, derivada de la lógica real de `sar_ctrl.v` (`current = cmp==0 ? ~shift : todo_unos`), es **`cmp = ((result | shift) <= target)`** — verificada exactamente contra 5 valores de prueba en aislamiento antes de aplicarla al testbench de integración.
2. Mismo patrón que en `freq_counter`: usar `adc_ready` (bandera persistente) para detectar "fin de una conversión posterior" fallaba, porque ya estaba en 1 desde la conversión anterior. Solución: esperar a que la FSM regrese a `S_IDLE` (`dut.state === 2'b00`) en lugar de esperar el flanco de `adc_ready`.

---

## 6. `dac_ctrl.v` — Controlador del DAC R-2R ✅

**Verificado:** 20/20 tests, integrado con `r2r_dac_control.v` **real** de la IP (mattvenn/tt06-analog-r2r-dac).

**Interfaz actualizada (confirmada por simulación):**
```verilog
module dac_ctrl (
    input  wire       clk, rst_n,
    input  wire [7:0] dac_word,
    input  wire        ext_data_en,
    input  wire        load_div_pulse,
    output reg  [7:0] dac_data_out,
    output reg          dac_ext_data,
    output reg          dac_load_div,
    output wire         dac_n_rst
);
```

**HALLAZGO CRÍTICO — corrección de polaridad de reset:**

```verilog
// CORRECTO (verificado, 20/20 tests):
assign dac_n_rst = rst_n;   // SIN inversión

// INCORRECTO (lo que se documentaba antes de Fase 2):
// assign dac_n_rst = ~rst_n;  // Esto deja la IP SIEMPRE en reset
```

Ver `pin_map.md` v4.0 para el análisis completo de por qué `n_rst` funciona como enable activo-alto y no como reset invertido convencional, a pesar de su nombre.

**Cobertura de pruebas:** conexión de reset (ambos sentidos: `rst_n=0→dac_n_rst=0`, `rst_n=1→dac_n_rst=1`), estado inicial tras reset (modo externo por defecto), modo externo con dato estático y su actualización, valores de esquina (0x00 y 0xFF), transición a modo selftest, carga del divisor de velocidad de rampa, verificación de que la rampa efectivamente incrementa en modo selftest con divisor=0, regreso a modo externo sin glitches, reset durante operación.

**Bug encontrado y corregido (en el RTL real, no solo en testbench):** el primer intento de `dac_ctrl.v` invertía el reset (`dac_n_rst = ~rst_n`), siguiendo la suposición documentada en `pin_map.md` v2.0/v3.0 de que `n_rst` era "activo alto, hay que invertir". Al simular contra la IP real, el DAC nunca generaba ninguna salida (`r2r_out` permanecía en 0 indefinidamente). El análisis de la lógica interna de `r2r_dac_control.v` reveló que la polaridad documentada estaba equivocada — la corrección se aplicó tanto al RTL (`dac_ctrl.v`) como al testbench, y quedó confirmada con 20/20 tests.

---

## 7. `wb_regs.v` — Mapa de registros Wishbone ✅

**Verificado:** 30/30 tests, cero warnings, sin bugs (ni en RTL ni en testbench) — verificación limpia a la primera.

**Interfaz (confirmada por simulación, coincide con el diseño original):**
```verilog
module wb_regs (
    input  wire        clk, rst_n,
    input  wire         wb_stb, wb_cyc, wb_we,
    input  wire [3:0]  wb_sel,
    input  wire [31:0] wb_dat_i, wb_adr,
    output reg          wb_ack,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] freq_result,
    input  wire         data_ready,
    input  wire [11:0] adc_result,
    input  wire         adc_ready,
    input  wire         gate_active,
    output reg  [26:0] gate_cycles,
    output reg  [7:0]  dac_word,
    output reg          dac_ext_data,
    output reg          dac_load_div,
    output reg  [3:0]  adc_swidth,
    output reg          continuous_adc,
    output reg          soft_rst,
    output reg          mode_sel
);
```

**Mapa de registros:** ver `pin_map.md` v4.0, sección 3 — verificado bit a bit, sin cambios respecto al diseño documentado en v2.0.

**Cobertura de pruebas:** defaults tras reset (incluyendo `gate_cycles=100_000_000`), escritura/lectura de `GATE_CFG` y `DAC_WORD`, lectura de los tres registros de solo lectura reflejando entradas externas, decodificación completa de los 9 bits de `CTRL`, comportamiento de pulso (`soft_rst`, `dac_load_div`) vs persistente (`mode_sel`, `dac_ext_data`, `adc_swidth`, `continuous_adc`), regla de `wb_ack` requiriendo `stb` Y `cyc` simultáneos, dirección no mapeada devuelve 0, reset restaura defaults incluso tras escrituras previas.

---

## 8. `freq_top.v` — Top level del frecuencímetro 🔲 PENDIENTE

**Propósito:** Instanciar y conectar los 7 módulos verificados arriba, más las dos IPs reales (`sar_ctrl` y `r2r_dac_control`), implementando la FSM de secuenciación general del sistema completo.

**Interfaz objetivo (sujeta a ajuste durante la implementación):**
```verilog
module freq_top (
    input  wire        clk, rst_n,
    input  wire         wbs_stb_i, wbs_cyc_i, wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i, wbs_adr_i,
    output wire         wbs_ack_o,
    output wire [31:0] wbs_dat_o,
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oenb,
    input  wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    inout  wire [7:0]  user_analog,
    input  wire         vccd1, vssd1, vdda1, vssa1
);
```

**Checklist de integración (basado en los hallazgos de Fase 2, a verificar durante la implementación):**

- [ ] Conectar `dac_n_rst = rst_n` **sin inversión** (hallazgo crítico v4.0)
- [ ] Conectar `wb_regs.adc_swidth` → `adc_ctrl.swidth` (pendiente identificado en pin_map.md v4.0; `adc_ctrl.v` necesita esta entrada agregada si no la tiene ya expuesta)
- [ ] Verificar si el reloj del DAC necesita un prescaler (comentario "10M clock" vs `clk_user`=100MHz) — pendiente abierto hasta Fase 3
- [ ] FSM de secuenciación general: `RESET → IDLE → MEASURING (gate_en=1) → CAPTURING (latch_en pulso) → RESETTING (cnt_reset pulso) → IDLE`
- [ ] Conectar `eoc` real de `sar_ctrl` (no el `eoc_sync` ya sincronizado del testbench aislado) a través de `cdc_sync` antes de llegar a `adc_ctrl.eoc_sync`
- [ ] Verificar el comportamiento de banderas persistentes (`data_ready`, `adc_ready`) en el contexto del sistema completo — el firmware (Fase 7) necesitará un mecanismo claro para detectar "nueva medición" distinto de simplemente leer el bit

**Plan de testbench para `freq_top.v` (a definir):** dado que este módulo integra ambas IPs reales simultáneamente, el testbench deberá combinar los enfoques ya usados en `adc_ctrl` (modelo de comparador SAR) y `dac_ctrl` (verificación de rampa), más un nuevo caso de prueba end-to-end: configurar el DAC en modo selftest, verificar que la señal generada se "mide" correctamente a través del camino completo hasta `FREQ_RESULT`.

---

## Convenciones de codificación (confirmadas tras 7 módulos)

- Reset: síncrono, activo bajo (`rst_n`) en todos nuestros módulos — consistente en los 7 módulos verificados
- Excepción documentada: `dac_n_rst` se conecta sin inversión hacia la IP del DAC (ver hallazgo crítico)
- Sin latches inferidos — confirmado en los 7 módulos (cero warnings de Yosys/iverilog relacionados)
- Banderas de tipo "ready" (`data_ready`, `adc_ready`) son persistentes por diseño, no pulsos — patrón usado consistentemente y ahora bien documentado
- Pulsos de control (`gate_done`, `dac_load_div`, `soft_rst`) duran exactamente 1 ciclo con auto-clear — patrón usado consistentemente

## Convenciones de testbench (confirmadas tras varios bugs de simulación)

- **Regla del `#1`:** todo cambio de señal de entrada inmediatamente después de un `@(posedge clk)` debe ir seguido de `#1` antes de leer cualquier salida del DUT. Evita carreras de simulación entre el testbench y el `always` del DUT en el mismo instante de tiempo.
- **Regla de "fin de operación":** nunca usar una bandera persistente (`*_ready`) para detectar el fin de una operación *posterior* a la primera — esperar a que la FSM regrese a su estado IDLE en su lugar.
- **Verificación contra IP real, no mocks:** cuando un módulo de control envuelve una IP externa (`adc_ctrl`↔`sar_ctrl`, `dac_ctrl`↔`r2r_dac_control`), el testbench debe instanciar la IP real, no un modelo simplificado — los dos bugs más importantes de Fase 2 (polaridad de reset del DAC, fórmula del comparador SAR) solo se manifestaron al integrar con el comportamiento real de la IP.

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial — Fase 1 |
| 2.0 | Junio 2025 | Pines reales verificados por inspección; DAC simplificado; ADC pines corregidos (soc, swidth, dac_rst) |
| 3.0 | Junio 2025 | **Fase 2 completada (7/8 módulos), verificado por simulación real con IPs reales.** Corrige polaridad de reset del DAC. Documenta timing real soc→eoc del ADC. Documenta comportamiento persistente de banderas ready. Añade checklist de integración para freq_top.v |
