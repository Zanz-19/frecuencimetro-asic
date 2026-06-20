// Módulo     : wb_regs
// Archivo    : rtl/wb_regs.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Decodifica el bus Wishbone de Caravel y enruta lecturas y
//              escrituras a los registros de configuración y resultado
//              del frecuencímetro. Es el único punto de contacto entre
//              el CPU PicoRV32 y la lógica interna del sistema.
//
// Mapa de registros (offset relativo a la base del periférico):
//   0x00  FREQ_RESULT  R    [31:0] resultado de medición (conteos en T_gate)
//   0x04  GATE_CFG     R/W  [26:0] duración de T_gate en ciclos de clk
//   0x08  ADC_DATA     R    [11:0] último valor capturado del ADC
//   0x0C  DAC_WORD     R/W  [7:0]  dato a escribir al DAC (modo externo)
//   0x10  STATUS       R    [3:0]  {mode_sel, gate_active, adc_ready, data_ready}
//   0x14  CTRL         W    ver detalle abajo
//
// Detalle de CTRL (offset 0x14, solo escritura):
//   bit 0     soft_rst        reset de módulos internos (auto-clear 1 ciclo)
//   bit 1     mode_sel        0=conteo directo, 1=recíproco
//   bit 2     continuous_adc  1=muestreo continuo del ADC
//   bit 3     dac_ext_data    1=DAC usa DAC_WORD; 0=rampa interna (selftest)
//   bit 4     dac_load_div    pulso: carga DAC_WORD[7:0] como divisor de rampa
//   bits 8:5  adc_swidth      tiempo de muestreo del ADC en ciclos
//
// Notas de diseño:
//   - Direccionamiento: se decodifican solo los bits bajos de wb_adr
//     (wb_adr[7:0]), suficiente para los 6 registros definidos. El offset
//     base completo dentro del mapa de Caravel lo resuelve el wrapper.
//   - Todas las transacciones responden con ACK en 1 ciclo (sin wait states).
//   - GATE_CFG y DAC_WORD son R/W: el valor escrito se retiene y también
//     se puede leer de vuelta para verificación desde firmware.
//   - soft_rst y dac_load_div son pulsos de 1 ciclo: se autolimpian
//     independientemente de si el CPU vuelve a escribir 0 explícitamente.
//   - mode_sel y adc_swidth SÍ son configuración persistente (no pulsos):
//     mantienen su valor hasta la siguiente escritura a CTRL.

`default_nettype none
`timescale 1ns/1ps

module wb_regs (
    input  wire        clk,
    input  wire        rst_n,

    // --- Bus Wishbone (subset de señales de Caravel) ---
    input  wire        wb_stb,
    input  wire        wb_cyc,
    input  wire        wb_we,
    input  wire [3:0]  wb_sel,
    input  wire [31:0] wb_dat_i,
    input  wire [31:0] wb_adr,
    output reg          wb_ack,
    output reg  [31:0] wb_dat_o,

    // --- Entradas de módulos internos (para lectura por el CPU) ---
    input  wire [31:0] freq_result,    // de result_latch
    input  wire        data_ready,     // de result_latch
    input  wire [11:0] adc_result,     // de adc_ctrl
    input  wire        adc_ready,      // de adc_ctrl
    input  wire        gate_active,    // de gate_timer

    // --- Salidas de configuración (escritas por el CPU) ---
    output reg  [26:0] gate_cycles,    // → gate_timer
    output reg  [7:0]  dac_word,       // → dac_ctrl
    output reg          dac_ext_data,   // → dac_ctrl
    output reg          dac_load_div,   // → dac_ctrl (pulso 1 ciclo)
    output reg  [3:0]  adc_swidth,     // → adc_ctrl
    output reg          continuous_adc, // → adc_ctrl
    output reg          soft_rst,       // → reset de módulos internos (pulso)
    output reg          mode_sel        // → selección de modo de medición
);

    // Offsets de registro (bits bajos de wb_adr, suficiente para 6 regs)
    localparam ADDR_FREQ_RESULT = 8'h00;
    localparam ADDR_GATE_CFG    = 8'h04;
    localparam ADDR_ADC_DATA    = 8'h08;
    localparam ADDR_DAC_WORD    = 8'h0C;
    localparam ADDR_STATUS      = 8'h10;
    localparam ADDR_CTRL        = 8'h14;

    wire [7:0] addr_low = wb_adr[7:0];
    wire       wb_access = wb_stb && wb_cyc;

    always @(posedge clk) begin
        if (!rst_n) begin
            wb_ack         <= 1'b0;
            wb_dat_o       <= 32'd0;
            gate_cycles    <= 27'd100_000_000; // default: T_gate = 1s @ 100MHz
            dac_word       <= 8'd0;
            dac_ext_data   <= 1'b1;             // modo externo por defecto
            dac_load_div   <= 1'b0;
            adc_swidth     <= 4'd0;
            continuous_adc <= 1'b0;
            soft_rst       <= 1'b0;
            mode_sel       <= 1'b0;
        end else begin
            // Pulsos: se autolimpian cada ciclo salvo que se reescriban
            dac_load_div <= 1'b0;
            soft_rst     <= 1'b0;

            // ACK por defecto en 0; se activa solo en ciclos de acceso válido
            wb_ack <= 1'b0;

            if (wb_access) begin
                wb_ack <= 1'b1;

                if (wb_we) begin
                    // ---------------- ESCRITURA ----------------
                    case (addr_low)
                        ADDR_GATE_CFG: begin
                            gate_cycles <= wb_dat_i[26:0];
                        end

                        ADDR_DAC_WORD: begin
                            dac_word <= wb_dat_i[7:0];
                        end

                        ADDR_CTRL: begin
                            soft_rst       <= wb_dat_i[0];
                            mode_sel       <= wb_dat_i[1];
                            continuous_adc <= wb_dat_i[2];
                            dac_ext_data   <= wb_dat_i[3];
                            dac_load_div   <= wb_dat_i[4];
                            adc_swidth     <= wb_dat_i[8:5];
                        end

                        // FREQ_RESULT, ADC_DATA y STATUS son de solo lectura;
                        // una escritura a esas direcciones se ACK-ea pero no
                        // tiene efecto (comportamiento estándar Wishbone).
                        default: begin
                            // no-op
                        end
                    endcase
                end else begin
                    // ---------------- LECTURA ----------------
                    case (addr_low)
                        ADDR_FREQ_RESULT: wb_dat_o <= freq_result;
                        ADDR_GATE_CFG:    wb_dat_o <= {5'd0, gate_cycles};
                        ADDR_ADC_DATA:    wb_dat_o <= {20'd0, adc_result};
                        ADDR_DAC_WORD:    wb_dat_o <= {24'd0, dac_word};
                        ADDR_STATUS:      wb_dat_o <= {28'd0, mode_sel, gate_active,
                                                        adc_ready, data_ready};
                        default:          wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule

`default_nettype wire
