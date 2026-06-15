# Contratos de Interfaz de Módulos — Frecuencímetro ASIC
**Estado:** Fase 1 — Documento de referencia para Fase 2 (RTL)  
**Regla:** Ningún módulo se modifica sin actualizar este documento primero.

---

## Orden de desarrollo (menor a mayor dependencia)

```
1. cdc_sync.v       → sin dependencias
2. gate_timer.v     → sin dependencias
3. freq_counter.v   → usa: gate_en de gate_timer
4. result_latch.v   → usa: count_out de freq_counter, gate_done de gate_timer
5. adc_ctrl.v       → usa: eoc_sync de cdc_sync
6. dac_ctrl.v       → sin dependencias de módulos nuevos
7. wb_regs.v        → usa: salidas de result_latch, adc_ctrl, dac_ctrl, gate_timer
8. freq_top.v       → instancia todos los anteriores
```

---

## 1. `cdc_sync.v` — Sincronizador de dominio de reloj

**Propósito:** Sincronizar la señal `eoc` del ADC SAR (asíncrona respecto a `clk_user`) al dominio de reloj del diseño digital. Previene metaestabilidad.

**Archivo:** `rtl/cdc_sync.v`  
**Testbench:** `tb/tb_cdc_sync.v`

```verilog
module cdc_sync #(
    parameter STAGES = 2        // número de etapas FF (mínimo 2)
)(
    input  wire clk,            // reloj destino (clk_user de Caravel)
    input  wire rst_n,          // reset síncrono activo bajo
    input  wire async_in,       // señal asíncrona de entrada (eoc del ADC)
    output wire sync_out        // señal sincronizada al dominio clk
);
```

**Comportamiento:**
- En reset: `sync_out = 0`
- En operación: la señal atraviesa STAGES flip-flops en cascada
- Restricción de síntesis: atributo `dont_touch` / `keep_hierarchy` en ambos FFs para que LibreLane no los fusione

**Casos de prueba obligatorios:**
- Flanco en fase con clk → captura en el próximo ciclo
- Flanco en zona metaestable (±1 ns del flanco de clk) → sin propagación de estado indefinido
- Pulso de reset mientras async_in=1 → sync_out vuelve a 0

---

## 2. `gate_timer.v` — Generador de ventana T_gate

**Propósito:** Generar la señal `gate_en` que define exactamente cuántos ciclos de reloj dura la ventana de medición. Configurable desde Wishbone en tiempo de ejecución.

**Archivo:** `rtl/gate_timer.v`  
**Testbench:** `tb/tb_gate_timer.v`

```verilog
module gate_timer (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        start,       // pulso de inicio de ciclo de medición
    input  wire [26:0] gate_cycles, // duración de T_gate en ciclos de clk
                                    // T_gate(s) = gate_cycles / f_clk
                                    // Ejemplo: 100_000_000 → 1 s @ 100 MHz
    output reg         gate_en,     // '1' durante la ventana activa
    output reg         gate_done    // pulso de 1 ciclo al finalizar la ventana
);
```

**Comportamiento:**
- En reset: `gate_en = 0`, `gate_done = 0`
- Al recibir `start`: inicia cuenta regresiva desde `gate_cycles`
- Durante cuenta: `gate_en = 1`
- Al llegar a 0: `gate_en = 0`, `gate_done = 1` (1 ciclo), luego `gate_done = 0`
- Tras `gate_done`: espera el siguiente pulso `start`

**Valores de referencia:**

| gate_cycles | T_gate | Resolución |
|---|---|---|
| 100_000 | 1 ms | 1 kHz |
| 1_000_000 | 10 ms | 100 Hz |
| 10_000_000 | 100 ms | 10 Hz |
| 100_000_000 | 1 s | 1 Hz |

**Casos de prueba obligatorios:**
- T_gate de 1 ms, 100 ms, 1 s → verificar duración exacta de gate_en
- `start` durante gate_en activo → debe ignorarse (no reiniciar el timer)
- Reset durante gate activo → gate_en baja inmediatamente

---

## 3. `freq_counter.v` — Contador de pulsos de 32 bits

**Propósito:** Contar el número de flancos de subida de `fx_in` mientras `gate_en = 1`. El valor al final de la ventana es N en la ecuación `fx = N / T_gate`.

**Archivo:** `rtl/freq_counter.v`  
**Testbench:** `tb/tb_freq_counter.v`

```verilog
module freq_counter (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        gate_en,     // '1': contar flancos; '0': detener
    input  wire        cnt_reset,   // reset del contador (de gate_timer vía FSM)
    input  wire        fx_in,       // señal de frecuencia digitalizada (post-Schmitt)
                                    // NO sincronizada con clk — solo se detectan flancos
    output reg  [31:0] count_out,   // valor actual del contador
    output reg         count_valid  // '1' cuando gate_en acaba de bajar (dato estable)
);
```

**Comportamiento:**
- Detección de flanco: registro interno `fx_prev` detecta transición 0→1 en `fx_in`
- Solo cuenta mientras `gate_en = 1`
- `count_valid` sube 1 ciclo después de que `gate_en` baja (dato estable para captura)
- `cnt_reset` borra el contador en 1 ciclo (preparación para siguiente ventana)

**Casos de prueba obligatorios:**
- fx = 1 kHz, T_gate = 1 s → count_out debe ser 1000 ± 1
- fx = 100 kHz, T_gate = 100 ms → count_out debe ser 10000 ± 1
- gate_en baja a la mitad de un ciclo de fx → no cuenta el flanco parcial
- cnt_reset durante gate_en inactivo → count_out vuelve a 0

---

## 4. `result_latch.v` — Registro de captura del resultado

**Propósito:** Capturar y mantener estable el valor del contador cuando termina la ventana de medición, independientemente del nuevo ciclo que comience inmediatamente después.

**Archivo:** `rtl/result_latch.v`

```verilog
module result_latch (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        latch_en,    // pulso de captura (= gate_done de gate_timer)
    input  wire [31:0] data_in,     // count_out de freq_counter
    output reg  [31:0] data_out,    // resultado estable para lectura Wishbone
    output reg         data_ready   // '1' desde la primera captura hasta nuevo reset
);
```

**Comportamiento:**
- En reset: `data_out = 0`, `data_ready = 0`
- En flanco de `latch_en`: `data_out ← data_in`, `data_ready ← 1`
- `data_out` permanece estable hasta el siguiente `latch_en`
- El CPU puede leer `data_out` en cualquier momento sin condición de carrera

---

## 5. `adc_ctrl.v` — Controlador del ADC SAR IP

**Propósito:** Orquestar el protocolo de conversión del ADC SAR (start → esperar EOC → capturar dato). Expone el resultado al bus Wishbone y permite muestreo continuo.

**Archivo:** `rtl/adc_ctrl.v`

```verilog
module adc_ctrl (
    input  wire        clk,             // clk_user de Caravel
    input  wire        rst_n,
    // Interfaz con cdc_sync
    input  wire        eoc_sync,        // EOC del ADC ya sincronizado
    // Interfaz directa con la IP del ADC
    input  wire [11:0] adc_data_raw,    // dato de 12 bits del ADC SAR
    output reg         adc_start,       // pulso de inicio de conversión (1 ciclo)
    output reg         adc_ena,         // habilitación del ADC
    // Interfaz con wb_regs
    output reg  [11:0] adc_result,      // último resultado capturado
    output reg         adc_ready,       // '1' tras primera conversión completa
    // Configuración
    input  wire        continuous_en,   // '1' = muestreo continuo; '0' = single-shot
    input  wire        adc_trigger      // pulso externo para iniciar una conversión
);
```

**FSM de estados:**
```
IDLE → START_CONV (pulso adc_start=1, 1 ciclo) → WAIT_EOC (espera eoc_sync) → CAPTURE (adc_result ← adc_data_raw) → IDLE
```
En modo continuous_en: desde CAPTURE vuelve automáticamente a START_CONV.

---

## 6. `dac_ctrl.v` — Controlador del DAC R-2R IP

**Propósito:** Mantener el valor de 8 bits enviado al DAC y, en modo selftest, generar una rampa periódica automática sin intervención del CPU.

**Archivo:** `rtl/dac_ctrl.v`

```verilog
module dac_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    // Interfaz con wb_regs
    input  wire [7:0] dac_word_wb,      // valor escrito por CPU vía Wishbone
    // Modo selftest
    input  wire       selftest_en,      // '1' = modo rampa automática
    input  wire [7:0] selftest_rate,    // ciclos entre incrementos de la rampa
                                        // f_sawtooth = f_clk / (256 × selftest_rate)
    // Salida a la IP del DAC
    output reg  [7:0] dac_out           // palabra de 8 bits hacia ui_in del DAC
);
```

**Cálculo de frecuencia en modo selftest:**

| selftest_rate | f_sawtooth @ 100 MHz |
|---|---|
| 1 | 390,625 Hz |
| 10 | 39,062 Hz |
| 100 | 3,906 Hz |
| 255 | 1,534 Hz |

**Comportamiento:**
- `selftest_en = 0`: `dac_out = dac_word_wb` (valor estático del CPU)
- `selftest_en = 1`: `dac_out` se incrementa en 1 cada `selftest_rate` ciclos, generando una rampa de 0 a 255 y vuelta a 0

---

## 7. `wb_regs.v` — Mapa de registros Wishbone

**Propósito:** Decodificar las transacciones del bus Wishbone de Caravel y enrutar lecturas y escrituras a los registros correctos del sistema.

**Archivo:** `rtl/wb_regs.v`

```verilog
module wb_regs (
    input  wire        clk,
    input  wire        rst_n,
    // Bus Wishbone (subset de señales de Caravel)
    input  wire        wb_stb,
    input  wire        wb_cyc,
    input  wire        wb_we,
    input  wire [3:0]  wb_sel,
    input  wire [31:0] wb_dat_i,
    input  wire [31:0] wb_adr,
    output reg         wb_ack,
    output reg  [31:0] wb_dat_o,
    // Conexiones con módulos internos
    input  wire [31:0] freq_result,     // de result_latch
    input  wire        data_ready,      // de result_latch
    input  wire [11:0] adc_result,      // de adc_ctrl
    input  wire        adc_ready,       // de adc_ctrl
    input  wire        gate_active,     // de gate_timer
    output reg  [26:0] gate_cycles,     // → gate_timer
    output reg  [7:0]  dac_word,        // → dac_ctrl
    output reg         selftest_en,     // → dac_ctrl
    output reg  [7:0]  selftest_rate,   // → dac_ctrl
    output reg         continuous_adc,  // → adc_ctrl
    output reg         soft_rst,        // reset de módulos internos
    output reg         mode_sel         // selección de modo de medición
);
```

**Mapa de registros:**

| Offset | Nombre | Bits | R/W | Descripción |
|---|---|---|---|---|
| `0x00` | `FREQ_RESULT` | [31:0] | R | Resultado de medición: N conteos en T_gate |
| `0x04` | `GATE_CFG` | [26:0] | R/W | Duración de T_gate en ciclos. Default: 100_000_000 (1 s) |
| `0x08` | `ADC_DATA` | [11:0] | R | Último valor del ADC. Bits [31:12] = 0 |
| `0x0C` | `DAC_OUT` | [7:0] | R/W | Valor a escribir al DAC. Bits [31:8] = 0 |
| `0x10` | `STATUS` | [3:0] | R | {mode_sel, gate_active, adc_ready, data_ready} |
| `0x14` | `CTRL` | [4:0] | W | {selftest_rate[7:0], selftest_en, continuous_adc, mode_sel, soft_rst} |

**Comportamiento de escritura:** ACK se genera en 1 ciclo (sin estados de espera).  
**Comportamiento de lectura:** ACK en 1 ciclo, dato disponible en el mismo ciclo.

---

## 8. `freq_top.v` — Top level del frecuencímetro

**Propósito:** Instanciar y conectar todos los módulos anteriores. Es el único módulo que ve el `user_project_wrapper` de Caravel. Implementa también la FSM de secuenciación (start → gate → latch → reset → start).

**Archivo:** `rtl/freq_top.v`

```verilog
module freq_top (
    // Reloj y reset
    input  wire        clk,
    input  wire        rst_n,
    // Bus Wishbone de Caravel
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,
    // Logic Analyzer
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oenb,
    // IO pins
    input  wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    // Analógico (hacia las IPs)
    inout  wire [7:0]  user_analog,
    // Alimentación
    input  wire        vccd1, vssd1,
    input  wire        vdda1, vssa1
);
```

**FSM de secuenciación interna:**
```
RESET → IDLE → MEASURING (gate_en=1) → CAPTURING (latch_en pulso) → RESETTING (cnt_reset pulso) → IDLE
```

El ciclo IDLE→MEASURING se dispara automáticamente: el sistema corre en loop continuo de mediciones. El CPU solo lee los resultados del registro `FREQ_RESULT` cuando lo necesita.

---

## Dependencias entre módulos (diagrama)

```
                    ┌─────────────────────────────────────────┐
                    │              freq_top.v                  │
                    │                                          │
  ADC eoc ──────→  │ cdc_sync ──→ adc_ctrl ──→ wb_regs       │
                    │                                          │
  fx_in ─────────→ │ freq_counter ──→ result_latch ──→ wb_regs│
                    │      ↑                                    │
                    │ gate_timer ──────────────────→ wb_regs   │
                    │                                          │
  CPU Wishbone ───→ │ wb_regs ──→ dac_ctrl ──→ DAC IP        │
                    │                                          │
                    └─────────────────────────────────────────┘
```

---

## Convenciones de codificación

- Reset: **síncrono**, activo bajo (`rst_n`)
- Todos los registros se inicializan a 0 en reset
- Sin latches inferidos: toda lógica combinacional cubre todos los casos
- Nombres de señales: `snake_case`; constantes: `UPPER_CASE`
- Comentario de cabecera en cada archivo:
  ```verilog
  // Módulo   : nombre_modulo
  // Archivo  : rtl/nombre_modulo.v
  // Proyecto : Frecuencímetro ASIC sky130A
  // Autor    : [nombre]
  // Fecha    : [fecha]
  // Descripción: [una línea]
  ```

---

## Historial de cambios

| Fecha | Módulo | Cambio | Motivo |
|---|---|---|---|
| Junio 2025 | Todos | Versión inicial | Fase 1 |
