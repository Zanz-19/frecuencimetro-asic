// Módulo     : freq_top
// Archivo    : rtl/freq_top.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Top level del frecuencímetro. Instancia y conecta los 7
//              módulos digitales verificados en Fase 2 (cdc_sync, gate_timer,
//              freq_counter, result_latch, adc_ctrl, dac_ctrl, wb_regs), más
//              la FSM de secuenciación general del sistema. Es el único
//              módulo que conecta directamente con el bus Wishbone, el
//              Logic Analyzer y los pines de I/O de Caravel.
//
// Las dos IPs reales (sar_ctrl del ADC, r2r_dac_control del DAC) NO se
// instancian dentro de este módulo: freq_top.v expone los pines de control
// digital (adc_soc, adc_en, adc_swidth, dac_n_rst, etc.) hacia afuera, y es
// el user_project_wrapper (Fase 7) quien instancia las IPs y las conecta a
// estos pines. Esto mantiene freq_top.v como un macro 100% digital,
// sintetizable de forma independiente en Fase 6.
//
// FSM de secuenciación general:
//   RESET -> IDLE -> MEASURING (gate_en=1) -> CAPTURING (latch_en pulso)
//         -> RESETTING (cnt_reset pulso) -> IDLE (ciclo continuo)
//
// El ciclo de medición corre en loop continuo de forma automática; el CPU
// solo necesita leer FREQ_RESULT vía Wishbone cuando lo necesite. El primer
// ciclo de medición arranca automáticamente al salir de reset.
//
// Hallazgos críticos de Fase 2 aplicados en este módulo:
//   [1] dac_n_rst = rst_n SIN inversión (ver dac_ctrl.v y pin_map.md v4.0)
//   [2] adc_ctrl.adc_swidth_in conectado a wb_regs.adc_swidth (pendiente
//       que quedó abierto al cerrar adc_ctrl.v, resuelto aquí)
//   [3] eoc del ADC pasa por cdc_sync antes de llegar a adc_ctrl.eoc_sync

`default_nettype none
`timescale 1ns/1ps

module freq_top (
    input  wire        clk,           // clk_user de Caravel
    input  wire        rst_n,         // reset síncrono activo bajo

    // --- Bus Wishbone (subset relevante de Caravel) ---
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    // --- Señal de frecuencia externa (post-Schmitt, Fase 4) ---
    input  wire        fx_in,

    // --- Indicadores de estado hacia io_out ---
    output wire        data_ready_out,
    output wire        gate_active_out,
    output wire        adc_ready_out,

    // --- Interfaz digital hacia la IP del ADC (sar_ctrl, instanciado en el wrapper) ---
    output wire        adc_soc,
    output wire        adc_en,
    output wire [3:0]  adc_swidth,
    input  wire [11:0] adc_data_raw,   // sar_ctrl.data
    input  wire        adc_eoc,        // sar_ctrl.eoc (asíncrono, sin sincronizar aún)

    // --- Interfaz digital hacia la IP del DAC (r2r_dac_control, instanciado en el wrapper) ---
    output wire [7:0]  dac_data_out,
    output wire        dac_ext_data,
    output wire        dac_load_div,
    output wire        dac_n_rst       // SIN inversión respecto a rst_n (ver hallazgo crítico)
);

    // =====================================================================
    // Señales internas de interconexión
    // =====================================================================

    // --- gate_timer <-> freq_counter / result_latch ---
    wire        gate_en;
    wire        gate_done;

    // --- freq_counter <-> result_latch ---
    wire [31:0] count_out;
    wire        count_valid;   // no se usa directamente (latch_en usa gate_done)

    // --- result_latch -> wb_regs ---
    wire [31:0] freq_result;
    wire        data_ready;

    // --- cdc_sync: sincroniza eoc del ADC ---
    wire        eoc_sync;

    // --- Registro de captura inmediata del dato del ADC ---
    // HALLAZGO CRÍTICO DE FASE 2: sar_ctrl.data (adc_data_raw) solo es válido
    // durante el único ciclo en que sar_ctrl está en estado DONE; en el ciclo
    // siguiente vuelve a IDLE y pone result<=0. cdc_sync introduce 2 ciclos de
    // latencia en la notificación (eoc_sync), tiempo suficiente para que el
    // dato crudo ya haya decaído antes de que adc_ctrl pueda reaccionar a la
    // notificación sincronizada. La solución: capturar adc_data_raw en un
    // registro dedicado disparado DIRECTAMENTE por adc_eoc (sin sincronizar).
    // Esto es seguro porque es un registro de DATOS (12 bits estables durante
    // muchos ciclos una vez capturados), no una señal de CONTROL de 1 ciclo —
    // el riesgo de metaestabilidad en el flanco de captura es aceptable aquí
    // de la misma forma en que lo es en cualquier registro de datos cruzando
    // dominios, a diferencia de un pulso de control que cdc_sync sí protege.
    reg  [11:0] adc_data_latch;
    always @(posedge clk) begin
        if (!internal_rst_n) begin
            adc_data_latch <= 12'd0;
        end else if (adc_eoc) begin
            // Captura directa, sin esperar a eoc_sync. adc_eoc dura exactamente
            // 1 ciclo en sar_ctrl (estado DONE) y adc_data_raw es válido en
            // ese mismo ciclo.
            adc_data_latch <= adc_data_raw;
        end
    end

    // --- adc_ctrl <-> wb_regs ---
    wire [11:0] adc_result;
    wire        adc_ready;

    // --- wb_regs -> módulos de configuración ---
    wire [26:0] gate_cycles;
    wire [7:0]  dac_word;
    wire        dac_ext_data_cfg;
    wire        dac_load_div_cfg;
    wire [3:0]  adc_swidth_cfg;
    wire        continuous_adc;
    wire        soft_rst;
    wire        mode_sel;

    // --- Reset interno: combina rst_n externo con soft_rst del CPU ---
    // soft_rst es un pulso de 1 ciclo desde wb_regs; cuando está activo,
    // los módulos internos (no wb_regs en sí) se resetean por 1 ciclo.
    wire        internal_rst_n = rst_n & ~soft_rst;

    // =====================================================================
    // FSM de secuenciación general
    // =====================================================================
    localparam S_IDLE      = 2'b00;
    localparam S_MEASURING = 2'b01;
    localparam S_CAPTURING = 2'b10;
    localparam S_RESETTING = 2'b11;

    reg [1:0] fsm_state;
    reg       gate_start;   // pulso hacia gate_timer.start
    reg       latch_en;     // pulso hacia result_latch.latch_en
    reg       cnt_reset;    // pulso hacia freq_counter.cnt_reset

    always @(posedge clk) begin
        if (!internal_rst_n) begin
            fsm_state  <= S_IDLE;
            gate_start <= 1'b0;
            latch_en   <= 1'b0;
            cnt_reset  <= 1'b0;
        end else begin
            // Pulsos: por defecto bajan cada ciclo, se activan explícitamente
            gate_start <= 1'b0;
            latch_en   <= 1'b0;
            cnt_reset  <= 1'b0;

            case (fsm_state)
                S_IDLE: begin
                    // Arrancar automáticamente el siguiente ciclo de medición
                    gate_start <= 1'b1;
                    fsm_state  <= S_MEASURING;
                end

                S_MEASURING: begin
                    // Esperar a que gate_timer complete la ventana
                    if (gate_done) begin
                        fsm_state <= S_CAPTURING;
                    end
                end

                S_CAPTURING: begin
                    // Capturar el resultado en result_latch
                    latch_en  <= 1'b1;
                    fsm_state <= S_RESETTING;
                end

                S_RESETTING: begin
                    // Limpiar freq_counter antes del siguiente ciclo
                    cnt_reset <= 1'b1;
                    fsm_state <= S_IDLE;
                end

                default: begin
                    fsm_state <= S_IDLE;
                end
            endcase
        end
    end

    // =====================================================================
    // Instancias de los 7 módulos verificados
    // =====================================================================

    // --- 1. cdc_sync: sincroniza eoc del ADC (asíncrono) ---
    cdc_sync #(.STAGES(2)) u_cdc_sync (
        .clk      (clk),
        .rst_n    (internal_rst_n),
        .async_in (adc_eoc),
        .sync_out (eoc_sync)
    );

    // --- 2. gate_timer: genera la ventana de medición ---
    gate_timer u_gate_timer (
        .clk         (clk),
        .rst_n       (internal_rst_n),
        .start       (gate_start),
        .gate_cycles (gate_cycles),
        .gate_en     (gate_en),
        .gate_done   (gate_done)
    );

    // --- 3. freq_counter: cuenta flancos de fx_in durante gate_en ---
    freq_counter u_freq_counter (
        .clk         (clk),
        .rst_n       (internal_rst_n),
        .gate_en     (gate_en),
        .cnt_reset   (cnt_reset),
        .fx_in       (fx_in),
        .count_out   (count_out),
        .count_valid (count_valid)
    );

    // --- 4. result_latch: captura el resultado al final de cada ventana ---
    result_latch u_result_latch (
        .clk        (clk),
        .rst_n      (internal_rst_n),
        .latch_en   (latch_en),
        .data_in    (count_out),
        .data_out   (freq_result),
        .data_ready (data_ready)
    );

    // --- 5. adc_ctrl: orquesta el protocolo soc/eoc del ADC SAR ---
    adc_ctrl u_adc_ctrl (
        .clk            (clk),
        .rst_n          (internal_rst_n),
        .eoc_sync       (eoc_sync),
        .adc_data_raw   (adc_data_latch),  // dato ya capturado de forma inmediata
                                            // (ver hallazgo crítico arriba), no el
                                            // dato crudo directo de sar_ctrl
        .adc_soc        (adc_soc),
        .adc_en         (adc_en),
        .adc_swidth_out (adc_swidth),
        .adc_result     (adc_result),
        .adc_ready      (adc_ready),
        .continuous_en  (continuous_adc),
        .adc_trigger    (1'b0),          // disparo manual no usado en este nivel;
                                          // el modo continuo se controla via wb_regs
        .adc_swidth_in  (adc_swidth_cfg)
    );

    // --- 6. dac_ctrl: controla el DAC R-2R (modo externo / selftest) ---
    dac_ctrl u_dac_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),          // usa rst_n SIN soft_rst: el DAC no debe
                                           // resetearse por un soft_rst transitorio,
                                           // solo por el reset global del sistema
        .dac_word       (dac_word),
        .ext_data_en    (dac_ext_data_cfg),
        .load_div_pulse (dac_load_div_cfg),
        .dac_data_out   (dac_data_out),
        .dac_ext_data   (dac_ext_data),
        .dac_load_div   (dac_load_div),
        .dac_n_rst      (dac_n_rst)
    );

    // --- 7. wb_regs: decodifica el bus Wishbone y expone los registros ---
    wb_regs u_wb_regs (
        .clk            (clk),
        .rst_n          (rst_n),          // wb_regs se resetea solo con el reset
                                           // global, nunca con soft_rst (si no,
                                           // un soft_rst se autodestruiria)
        .wb_stb         (wbs_stb_i),
        .wb_cyc         (wbs_cyc_i),
        .wb_we          (wbs_we_i),
        .wb_sel         (wbs_sel_i),
        .wb_dat_i       (wbs_dat_i),
        .wb_adr         (wbs_adr_i),
        .wb_ack         (wbs_ack_o),
        .wb_dat_o       (wbs_dat_o),
        .freq_result    (freq_result),
        .data_ready     (data_ready),
        .adc_result     (adc_result),
        .adc_ready      (adc_ready),
        .gate_active    (gate_en),
        .gate_cycles    (gate_cycles),
        .dac_word       (dac_word),
        .dac_ext_data   (dac_ext_data_cfg),
        .dac_load_div   (dac_load_div_cfg),
        .adc_swidth     (adc_swidth_cfg),
        .continuous_adc (continuous_adc),
        .soft_rst       (soft_rst),
        .mode_sel       (mode_sel)
    );

    // =====================================================================
    // Salidas hacia io_out (indicadores de estado)
    // =====================================================================
    assign data_ready_out  = data_ready;
    assign gate_active_out = gate_en;
    assign adc_ready_out   = adc_ready;

endmodule

`default_nettype wire
