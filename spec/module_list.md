# Contratos de Interfaz de Módulos — Frecuencímetro ASIC
**Versión:** 2.0 — Actualizada con pines reales de las IPs  
**Estado:** Fase 1 completada · Listo para Fase 2  
**Regla:** Ningún módulo se modifica sin actualizar este documento primero.

---

## Cambios respecto a v1.0

| Módulo | Cambio |
|---|---|
| `dac_ctrl.v` | Simplificado: selftest ya existe en la IP (`ext_data=0`). Solo controla `ext_data`, `load_divider` y `ui_in[7:0]`. Reset debe invertirse (`n_rst = ~rst_n`). |
| `adc_ctrl.v` | Renombrado `start` → `soc`. Añadido pin `swidth[3:0]` para tiempo de muestreo. Añadido `dac_rst` como salida (va al bloque analógico). |
| `wb_regs.v` | Registro `CTRL` actualizado: `selftest_en` reemplazado por `dac_ext_data` + `dac_load_div`. Añadido `adc_swidth[3:0]`. |
| `freq_top.v` | Añadida inversión de reset para el DAC. Conexión `sar_ctrl` como intermediario del ADC. |

---

## Orden de desarrollo (sin cambio)

```
1. cdc_sync.v       → sin dependencias
2. gate_timer.v     → sin dependencias
3. freq_counter.v   → usa: gate_en de gate_timer
4. result_latch.v   → usa: count_out de freq_counter, gate_done de gate_timer
5. adc_ctrl.v       → usa: eoc_sync de cdc_sync
6. dac_ctrl.v       → sin dependencias de módulos nuevos
7. wb_regs.v        → usa: salidas de todos los anteriores
8. freq_top.v       → instancia y conecta todo
```

---

## 1. `cdc_sync.v` — Sincronizador de dominio de reloj

**Sin cambios respecto a v1.0.**

**Propósito:** Sincronizar `eoc` del `sar_ctrl` (asíncrono respecto a `clk_user`) al dominio del diseño digital. El `eoc` de `sar_ctrl` dura exactamente 1 ciclo del reloj del ADC — si ese reloj difiere de `clk_user`, hay riesgo de metaestabilidad.

**Archivo:** `rtl/cdc_sync.v`  
**Testbench:** `tb/tb_cdc_sync.v`

```verilog
module cdc_sync #(
    parameter STAGES = 2
)(
    input  wire clk,        // clk_user de Caravel
    input  wire rst_n,      // reset síncrono activo bajo
    input  wire async_in,   // eoc de sar_ctrl (asíncrono)
    output wire sync_out    // eoc sincronizado al dominio clk_user
);
```

**Restricción de síntesis obligatoria:** Los FFs de sincronización deben tener atributo
`(* dont_touch = "true" *)` para que Yosys/LibreLane no los optimice ni reordene.

**Casos de prueba:**
- Flanco en fase con clk → captura en ciclo siguiente
- Flanco en zona metaestable (±0.5 ns del flanco de clk) → sin propagación indefinida
- Pulso corto (1 ciclo del dominio fuente) → debe capturarse correctamente

---

## 2. `gate_timer.v` — Generador de ventana T_gate

**Sin cambios respecto a v1.0.**

**Propósito:** Generar `gate_en` con duración exacta de `gate_cycles` ciclos de `clk_user`. Configurable en tiempo de ejecución desde Wishbone.

**Archivo:** `rtl/gate_timer.v`  
**Testbench:** `tb/tb_gate_timer.v`

```verilog
module gate_timer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,       // pulso de inicio (de la FSM en freq_top)
    input  wire [26:0] gate_cycles, // T_gate = gate_cycles / f_clk
    output reg         gate_en,     // '1' durante ventana activa
    output reg         gate_done    // pulso de 1 ciclo al finalizar
);
```

**Tabla de referencia:**

| gate_cycles | T_gate | Resolución |
|---|---|---|
| 100_000 | 1 ms | 1 kHz |
| 1_000_000 | 10 ms | 100 Hz |
| 10_000_000 | 100 ms | 10 Hz |
| 100_000_000 | 1 s | 1 Hz |

**Casos de prueba:**
- T_gate 1 ms, 100 ms, 1 s → duración exacta de `gate_en`
- `start` durante `gate_en` activo → ignorado
- Reset durante gate activo → `gate_en` baja en 1 ciclo

---

## 3. `freq_counter.v` — Contador de pulsos de 32 bits

**Sin cambios respecto a v1.0.**

**Propósito:** Contar flancos de subida de `fx_in` durante `gate_en = 1`.

**Archivo:** `rtl/freq_counter.v`  
**Testbench:** `tb/tb_freq_counter.v`

```verilog
module freq_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        gate_en,     // '1': contar; '0': detener
    input  wire        cnt_reset,   // borra el contador (1 ciclo)
    input  wire        fx_in,       // señal digitalizada post-Schmitt
    output reg  [31:0] count_out,
    output reg         count_valid  // sube 1 ciclo tras bajar gate_en
);
```

**Nota de implementación:** `fx_in` no está sincronizada con `clk`. La detección
de flanco usa dos registros internos (`fx_d1`, `fx_d2`) para detectar la transición
`0→1` de forma robusta sin necesidad de sincronizar la señal completa.

**Casos de prueba:**
- fx = 1 kHz, T_gate = 1 s → `count_out` = 1000 ± 1
- fx = 100 kHz, T_gate = 100 ms → `count_out` = 10000 ± 1
- `gate_en` baja a la mitad de un ciclo de `fx` → no cuenta flanco parcial
- `cnt_reset` → `count_out` vuelve a 0 en 1 ciclo

---

## 4. `result_latch.v` — Registro de captura del resultado

**Sin cambios respecto a v1.0.**

**Propósito:** Capturar `count_out` en el momento exacto de `gate_done` y mantenerlo estable para lectura asíncrona desde Wishbone.

**Archivo:** `rtl/result_latch.v`

```verilog
module result_latch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        latch_en,    // = gate_done de gate_timer
    input  wire [31:0] data_in,     // count_out de freq_counter
    output reg  [31:0] data_out,    // resultado estable
    output reg         data_ready   // '1' desde primera captura
);
```

---

## 5. `adc_ctrl.v` — Controlador del ADC SAR ⚠️ ACTUALIZADO

**Propósito:** Orquestar el protocolo del `sar_ctrl` de la IP del ADC.
Interfaz real confirmada desde `verilog/sar_ctrl.v`.

**Archivo:** `rtl/adc_ctrl.v`

```verilog
module adc_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    // Interfaz con cdc_sync (eoc ya sincronizado)
    input  wire        eoc_sync,
    // Interfaz con sar_ctrl de la IP ADC
    input  wire [11:0] adc_data_raw,  // data[SIZE-1:0] de sar_ctrl
                                       // ⚠️ verificar SIZE=12 en el wrapper del ADC
    output reg         adc_soc,        // soc: Start Of Conversion (antes llamado 'start')
    output reg         adc_en,         // en: habilitación del SAR
    output reg  [3:0]  adc_swidth,     // swidth: tiempo de muestreo en ciclos
    // Interfaz con wb_regs
    output reg  [11:0] adc_result,
    output reg         adc_ready,
    // Configuración
    input  wire        continuous_en,
    input  wire        adc_trigger,    // pulso externo para single-shot
    input  wire [3:0]  swidth_cfg      // valor de swidth desde Wishbone
);
```

**FSM de estados (sin cambio en lógica, actualizada en nombres de señales):**
```
IDLE → SOC_PULSE (adc_soc=1, 1 ciclo)
     → WAIT_EOC (espera eoc_sync)
     → CAPTURE (adc_result ← adc_data_raw)
     → IDLE
```
En `continuous_en=1`: CAPTURE → SOC_PULSE automáticamente.

**Nota sobre `sample_n` y `dac_rst`:** Estas señales de `sar_ctrl` van **directamente
al bloque analógico interno** del ADC macro. Son conexiones internas del macro — no
las maneja `adc_ctrl.v`. Solo se exponen aquí para documentación de referencia.

**Casos de prueba:**
- Single-shot: pulso `adc_trigger` → esperar `eoc_sync` → verificar `adc_result` válido
- Modo continuo: `continuous_en=1` → conversiones sin pausa entre ellas
- `eoc_sync` llega durante IDLE → ignorado sin efecto

---

## 6. `dac_ctrl.v` — Controlador del DAC R-2R ⚠️ ACTUALIZADO Y SIMPLIFICADO

**Propósito:** Controlar los pines digitales del DAC. El selftest (rampa interna)
ya existe dentro de `r2r_dac_control` — se activa simplemente poniendo `ext_data=0`.
`dac_ctrl.v` solo gestiona cuándo usar modo externo vs interno y qué dato enviar.

**Archivo:** `rtl/dac_ctrl.v`

```verilog
module dac_ctrl (
    input  wire       clk,
    input  wire       rst_n,         // activo bajo en nuestro diseño
    // Interfaz con wb_regs
    input  wire [7:0] dac_word_wb,   // dato de 8 bits del CPU
    input  wire       dac_ext_data,  // 1=modo externo (usa dac_word_wb)
                                     // 0=rampa interna de la IP (selftest)
    input  wire       dac_load_div,  // pulso para cargar divisor de velocidad de rampa
    // Salidas a la IP del DAC
    output reg  [7:0] dac_ui_in,     // → ui_in[7:0] del DAC
    output reg        dac_ext_data_o,// → uio_in[0] del DAC (ext_data)
    output reg        dac_load_div_o,// → uio_in[1] del DAC (load_divider)
    output wire       dac_n_rst      // → rst_n del DAC ⚠️ INVERTIDO
);
    // Reset: nuestro diseño usa activo bajo, la IP usa activo ALTO
    assign dac_n_rst = ~rst_n;
```

**Comportamiento:**
- `dac_ext_data=1`: DAC en modo externo → `dac_ui_in = dac_word_wb` (dato estático del CPU)
- `dac_ext_data=0`: DAC en modo selftest → rampa interna de la IP, `dac_ui_in` ignorado
- `dac_load_div=1` (pulso): carga el valor actual de `dac_word_wb` como divisor de velocidad de rampa

**Tabla de frecuencias de rampa selftest** (modo `ext_data=0`, clk=10 MHz recomendado):

| Divisor cargado | f_sawtooth |
|---|---|
| 0 | ~39 kHz (máxima) |
| 1 | ~19.5 kHz |
| 10 | ~3.8 kHz |
| 100 | ~390 Hz |
| 255 | ~153 Hz |

> ⚠️ **Nota de reloj del DAC:** El código fuente indica "expect a 10M clock". Conectar
> el DAC a una salida dividida del PLL de Caravel (÷10 si clk_user=100 MHz) o verificar
> que la lógica del divisor interno funciona correctamente a 100 MHz antes de Fase 3.

**Casos de prueba:**
- `dac_ext_data=1`, escribir 0x80 → `dac_ui_in` = 0x80 estable
- `dac_ext_data=0` → `dac_ui_in` puede tomar cualquier valor (lo controla la IP)
- Reset → `dac_n_rst` sube (activo alto en la IP)

---

## 7. `wb_regs.v` — Mapa de registros Wishbone ⚠️ ACTUALIZADO

**Propósito:** Decodificar el bus Wishbone y enrutar a los módulos internos.

**Archivo:** `rtl/wb_regs.v`

```verilog
module wb_regs (
    input  wire        clk,
    input  wire        rst_n,
    // Bus Wishbone
    input  wire        wb_stb,
    input  wire        wb_cyc,
    input  wire        wb_we,
    input  wire [3:0]  wb_sel,
    input  wire [31:0] wb_dat_i,
    input  wire [31:0] wb_adr,
    output reg         wb_ack,
    output reg  [31:0] wb_dat_o,
    // Entradas de módulos (para lectura por CPU)
    input  wire [31:0] freq_result,
    input  wire        data_ready,
    input  wire [11:0] adc_result,
    input  wire        adc_ready,
    input  wire        gate_active,
    input  wire        eoc_sync,
    // Salidas de configuración (escritas por CPU)
    output reg  [26:0] gate_cycles,     // → gate_timer
    output reg  [7:0]  dac_word,        // → dac_ctrl (dato al DAC)
    output reg         dac_ext_data,    // → dac_ctrl (0=selftest, 1=externo)
    output reg         dac_load_div,    // → dac_ctrl (pulso carga divisor)
    output reg  [3:0]  adc_swidth,      // → adc_ctrl (tiempo de muestreo)
    output reg         continuous_adc,  // → adc_ctrl
    output reg         soft_rst,        // reset de módulos internos
    output reg         mode_sel         // modo de medición
);
```

**Mapa de registros actualizado:**

| Offset | Nombre | Bits relevantes | R/W | Descripción |
|---|---|---|---|---|
| `0x00` | `FREQ_RESULT` | [31:0] | R | Conteos en T_gate |
| `0x04` | `GATE_CFG` | [26:0] | R/W | Ciclos de T_gate. Default: 100_000_000 |
| `0x08` | `ADC_DATA` | [11:0] | R | Último valor del ADC |
| `0x0C` | `DAC_WORD` | [7:0] | R/W | Dato al DAC (activo en modo ext_data=1) |
| `0x10` | `STATUS` | [3:0] | R | {gate_active, adc_ready, data_ready, eoc_sync} |
| `0x14` | `CTRL` | ver abajo | W | Control del sistema |

**Detalle del registro CTRL [0x14]:**

| Bits | Campo | Descripción |
|---|---|---|
| [0] | `soft_rst` | Reset de módulos internos (auto-clear tras 1 ciclo) |
| [1] | `mode_sel` | 0=conteo directo, 1=recíproco |
| [2] | `continuous_adc` | 1=muestreo continuo del ADC |
| [3] | `dac_ext_data` | 1=DAC usa dato de DAC_WORD; 0=rampa interna (selftest) |
| [4] | `dac_load_div` | Pulso: carga DAC_WORD[7:0] como divisor de velocidad de rampa |
| [8:5] | `adc_swidth[3:0]` | Tiempo de muestreo del ADC en ciclos de clk |

---

## 8. `freq_top.v` — Top level ⚠️ ACTUALIZADO

**Propósito:** Instanciar y conectar todos los módulos. Único punto de contacto
con `user_project_wrapper` de Caravel. Implementa la FSM de secuenciación.

**Archivo:** `rtl/freq_top.v`

```verilog
module freq_top (
    input  wire        clk,
    input  wire        rst_n,
    // Wishbone
    input  wire        wbs_stb_i, wbs_cyc_i, wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i, wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,
    // Logic Analyzer
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oenb,
    // IO digitales
    input  wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    // Pines hacia IPs (digital)
    // -- DAC --
    output wire [7:0]  dac_ui_in,      // → ui_in[7:0] del DAC
    output wire        dac_uio_in_0,   // → uio_in[0] (ext_data)
    output wire        dac_uio_in_1,   // → uio_in[1] (load_divider)
    output wire        dac_clk,        // → clk del DAC (puede ser clk dividido)
    output wire        dac_n_rst,      // → rst_n del DAC (INVERTIDO)
    // -- ADC SAR ctrl --
    output wire        adc_soc,        // → soc de sar_ctrl
    output wire        adc_en,         // → en de sar_ctrl
    output wire [3:0]  adc_swidth,     // → swidth de sar_ctrl
    input  wire [11:0] adc_data,       // ← data de sar_ctrl
    input  wire        adc_eoc,        // ← eoc de sar_ctrl (asíncrono)
    // Alimentación
    input  wire        vccd1, vssd1,
    input  wire        vdda1, vssa1
);
```

**Conexión del reset del DAC dentro de freq_top:**
```verilog
// El DAC usa reset activo ALTO — invertir nuestra señal rst_n
assign dac_n_rst = ~rst_n;
```

**FSM de secuenciación (sin cambio en lógica):**
```
RESET → IDLE → MEASURING (gate_en=1) → CAPTURING (latch_en pulso)
      → RESETTING (cnt_reset pulso) → IDLE
```

---

## Diagrama de conexiones actualizado

```
                    ┌──────────────────────────────────────────────┐
                    │                freq_top.v                     │
                    │                                               │
  ADC eoc ────────→ │ cdc_sync ──→ adc_ctrl ──→ wb_regs           │
  (sar_ctrl.eoc)    │   (sync)      (soc,en,       │               │
                    │               swidth)         │               │
  fx_in ──────────→ │ freq_counter ──→ result_latch─┤              │
  (io_in[0])        │      ↑                        │              │
                    │ gate_timer ───────────────────→ wb_regs      │
                    │                                │              │
  CPU Wishbone ───→ │ wb_regs ──→ dac_ctrl ─────────┤             │
                    │               │ (ext_data,     │             │
                    │               │  load_div,     │             │
                    │               │  ui_in,        │             │
                    │               │  ~rst_n)       │             │
                    │               ↓                ↓             │
                    │           DAC IP           Bus WB            │
                    └──────────────────────────────────────────────┘
```

---

## Convenciones de codificación (sin cambio)

- Reset: síncrono, activo bajo (`rst_n`) en todos nuestros módulos
- Excepción: `dac_n_rst` se invierte en `freq_top.v` antes de salir al DAC
- Sin latches inferidos
- Comentario de cabecera obligatorio en cada archivo:

```verilog
// Módulo   : nombre_modulo
// Archivo  : rtl/nombre_modulo.v
// Proyecto : Frecuencímetro ASIC sky130A
// Autor    : Jose (Zanz-19)
// Fecha    : [fecha de creación]
// Descripción: [una línea]
```

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial |
| 2.0 | Junio 2025 | Pines reales verificados; DAC simplificado; ADC pines corregidos (soc, swidth, dac_rst) |
