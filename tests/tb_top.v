// Módulo     : tb_top
// Archivo    : tests/tb_top.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Wrapper de integración para Fase 3 (cocotb). Instancia
//              freq_top.v junto con las dos IPs reales (sar_ctrl, 
//              r2r_dac_control), exactamente como lo hizo el testbench
//              Verilog de Fase 2, pero esta vez como punto de entrada
//              fijo para que cocotb maneje los estímulos desde Python.
//
// El modelo de comparador SAR (sar_cmp) y el modelo de Schmitt trigger
// (fx_modelo_schmitt) viven aquí en Verilog, igual que en Fase 2 — son
// piezas de testbench, no RTL del diseño real.

`default_nettype none
`timescale 1ns/1ps

module tb_top (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    input  wire        fx_in_external,
    input  wire        selftest_mode,
    input  wire [11:0] target_value,

    output wire        data_ready_out,
    output wire        gate_active_out,
    output wire        adc_ready_out,
    output wire [7:0]  dac_r2r_out_probe   // para observar la rampa del DAC desde Python
);

    parameter UMBRAL_SCHMITT = 8'd128;

    wire        adc_soc, adc_en;
    wire [3:0]  adc_swidth;
    wire [11:0] adc_data_raw;
    wire        adc_eoc;
    wire [7:0]  dac_data_out;
    wire        dac_ext_data, dac_load_div, dac_n_rst;

    wire        fx_modelo_schmitt = (dac_r2r_out_probe >= UMBRAL_SCHMITT);
    wire        fx_in_to_top = selftest_mode ? fx_modelo_schmitt : fx_in_external;

    freq_top u_freq_top (
        .clk             (clk),
        .rst_n           (rst_n),
        .wbs_stb_i       (wbs_stb_i),
        .wbs_cyc_i       (wbs_cyc_i),
        .wbs_we_i        (wbs_we_i),
        .wbs_sel_i       (wbs_sel_i),
        .wbs_dat_i       (wbs_dat_i),
        .wbs_adr_i       (wbs_adr_i),
        .wbs_ack_o       (wbs_ack_o),
        .wbs_dat_o       (wbs_dat_o),
        .fx_in           (fx_in_to_top),
        .data_ready_out  (data_ready_out),
        .gate_active_out (gate_active_out),
        .adc_ready_out   (adc_ready_out),
        .adc_soc         (adc_soc),
        .adc_en          (adc_en),
        .adc_swidth      (adc_swidth),
        .adc_data_raw    (adc_data_raw),
        .adc_eoc         (adc_eoc),
        .dac_data_out    (dac_data_out),
        .dac_ext_data    (dac_ext_data),
        .dac_load_div    (dac_load_div),
        .dac_n_rst       (dac_n_rst)
    );

    wire sar_cmp;
    sar_ctrl #(.SIZE(12)) u_sar_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .soc      (adc_soc),
        .cmp      (sar_cmp),
        .en       (adc_en),
        .swidth   (adc_swidth),
        .sample_n (),
        .data     (adc_data_raw),
        .eoc      (adc_eoc),
        .dac_rst  ()
    );

    // Modelo de comparador SAR verificado en Fase 2
    assign sar_cmp = ((u_sar_ctrl.result | u_sar_ctrl.shift) <= target_value) ? 1'b1 : 1'b0;

    r2r_dac_control u_dac_ip (
        .clk          (clk),
        .n_rst        (dac_n_rst),
        .ext_data     (dac_ext_data),
        .data         (dac_data_out),
        .load_divider (dac_load_div),
        .r2r_out      (dac_r2r_out_probe)
    );

endmodule

`default_nettype wire
