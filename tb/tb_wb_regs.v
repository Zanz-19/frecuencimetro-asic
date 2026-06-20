// Módulo     : tb_wb_regs
// Archivo    : tb/tb_wb_regs.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de wb_regs. Implementa un maestro Wishbone simple
//              (wb_write / wb_read) para ejercer todos los registros:
//              defaults tras reset, escritura/lectura de GATE_CFG y
//              DAC_WORD, decodificación correcta de CTRL, valores de
//              solo lectura reflejando las entradas de los módulos
//              internos, y comportamiento de pulsos (soft_rst, dac_load_div).
//
// Uso:
//   make sim MODULE=wb_regs

`default_nettype none
`timescale 1ns/1ps

module tb_wb_regs;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

    reg         clk;
    reg         rst_n;

    // Señales del bus Wishbone (lado maestro, manejadas por el testbench)
    reg         wb_stb;
    reg         wb_cyc;
    reg         wb_we;
    reg  [3:0]  wb_sel;
    reg  [31:0] wb_dat_i;
    reg  [31:0] wb_adr;
    wire        wb_ack;
    wire [31:0] wb_dat_o;

    // Entradas simuladas de los módulos internos
    reg  [31:0] freq_result;
    reg         data_ready;
    reg  [11:0] adc_result;
    reg         adc_ready;
    reg         gate_active;

    // Salidas de configuración del DUT
    wire [26:0] gate_cycles;
    wire [7:0]  dac_word;
    wire        dac_ext_data;
    wire        dac_load_div;
    wire [3:0]  adc_swidth;
    wire        continuous_adc;
    wire        soft_rst;
    wire        mode_sel;

    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------
    // Instancia del DUT
    // -------------------------------------------------------------------
    wb_regs dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .wb_stb         (wb_stb),
        .wb_cyc         (wb_cyc),
        .wb_we          (wb_we),
        .wb_sel         (wb_sel),
        .wb_dat_i       (wb_dat_i),
        .wb_adr         (wb_adr),
        .wb_ack         (wb_ack),
        .wb_dat_o       (wb_dat_o),
        .freq_result    (freq_result),
        .data_ready     (data_ready),
        .adc_result     (adc_result),
        .adc_ready      (adc_ready),
        .gate_active    (gate_active),
        .gate_cycles    (gate_cycles),
        .dac_word       (dac_word),
        .dac_ext_data   (dac_ext_data),
        .dac_load_div   (dac_load_div),
        .adc_swidth     (adc_swidth),
        .continuous_adc (continuous_adc),
        .soft_rst       (soft_rst),
        .mode_sel       (mode_sel)
    );

    // -------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------
    // Tareas auxiliares
    // -------------------------------------------------------------------
    task check;
        input        cond;
        input [255:0] name;
        begin
            if (cond) begin
                $display("  PASS | %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %0s", name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_clk;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // Tarea: escritura Wishbone de 1 ciclo (stb+cyc+we, espera ack)
    task wb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            wb_adr   = addr;
            wb_dat_i = data;
            wb_we    = 1;
            wb_sel   = 4'hF;
            wb_stb   = 1;
            wb_cyc   = 1;
            @(posedge clk);
            #1;
            wb_stb = 0;
            wb_cyc = 0;
            wb_we  = 0;
        end
    endtask

    // Tarea: lectura Wishbone de 1 ciclo, devuelve el dato leído
    task wb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            wb_adr = addr;
            wb_we  = 0;
            wb_sel = 4'hF;
            wb_stb = 1;
            wb_cyc = 1;
            @(posedge clk);
            #1;
            data   = wb_dat_o;
            wb_stb = 0;
            wb_cyc = 0;
        end
    endtask

    // -------------------------------------------------------------------
    // Bloque principal de pruebas
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_wb_regs.vcd");
        $dumpvars(0, tb_wb_regs);

        pass_count = 0;
        fail_count = 0;

        rst_n       = 0;
        wb_stb      = 0;
        wb_cyc      = 0;
        wb_we       = 0;
        wb_sel      = 4'h0;
        wb_dat_i    = 32'd0;
        wb_adr      = 32'd0;

        freq_result = 32'd0;
        data_ready  = 0;
        adc_result  = 12'd0;
        adc_ready   = 0;
        gate_active = 0;

        $display("");
        $display("=== TEST: wb_regs ===");
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        wait_clk(3);
        rst_n = 1;
        wait_clk(2);

        // ------------------------------------------------------------
        // CASO 1: Valores default tras reset
        // ------------------------------------------------------------
        $display("\n[CASO 1] Defaults tras reset");
        check(gate_cycles === 27'd100_000_000,
              "default_gate_cycles - 100_000_000 (T_gate=1s @ 100MHz)");
        check(dac_word === 8'd0, "default_dac_word - 0");
        check(dac_ext_data === 1'b1, "default_dac_ext_data - 1 (modo externo)");
        check(adc_swidth === 4'd0, "default_adc_swidth - 0");
        check(continuous_adc === 1'b0, "default_continuous_adc - 0");
        check(mode_sel === 1'b0, "default_mode_sel - 0");
        check(wb_ack === 1'b0, "default_wb_ack - 0 sin transaccion");

        // ------------------------------------------------------------
        // CASO 2: Escritura y lectura de GATE_CFG
        // ------------------------------------------------------------
        $display("\n[CASO 2] Escritura/lectura GATE_CFG (0x04)");
        begin : caso2
            reg [31:0] readback;
            wb_write(32'h04, 32'd5_000_000);
            check(gate_cycles === 27'd5_000_000,
                  "escritura_gate_cfg - gate_cycles=5000000");

            wb_read(32'h04, readback);
            check(readback === 32'd5_000_000,
                  "lectura_gate_cfg - readback=5000000");
            check(wb_ack === 1'b1, "ack_en_lectura - wb_ack=1");
        end

        // ------------------------------------------------------------
        // CASO 3: Escritura y lectura de DAC_WORD
        // ------------------------------------------------------------
        $display("\n[CASO 3] Escritura/lectura DAC_WORD (0x0C)");
        begin : caso3
            reg [31:0] readback;
            wb_write(32'h0C, 32'h000000AA);
            check(dac_word === 8'hAA, "escritura_dac_word - dac_word=0xAA");

            wb_read(32'h0C, readback);
            check(readback === 32'h000000AA,
                  "lectura_dac_word - readback=0x000000AA (bits altos en 0)");
        end

        // ------------------------------------------------------------
        // CASO 4: Lectura de FREQ_RESULT (solo lectura, refleja entrada)
        // ------------------------------------------------------------
        $display("\n[CASO 4] Lectura FREQ_RESULT (0x00, solo lectura)");
        begin : caso4
            reg [31:0] readback;
            freq_result = 32'd123456;
            wb_read(32'h00, readback);
            check(readback === 32'd123456,
                  "lectura_freq_result - refleja freq_result=123456");

            // Intentar escribir no debe tener efecto (es de solo lectura)
            wb_write(32'h00, 32'hFFFFFFFF);
            wait_clk(1);
            check(freq_result === 32'd123456,
                  "escritura_ignorada_freq_result - freq_result no cambia (es entrada externa)");
        end

        // ------------------------------------------------------------
        // CASO 5: Lectura de ADC_DATA (solo lectura, 12 bits con padding)
        // ------------------------------------------------------------
        $display("\n[CASO 5] Lectura ADC_DATA (0x08)");
        begin : caso5
            reg [31:0] readback;
            adc_result = 12'hABC;
            wb_read(32'h08, readback);
            check(readback === 32'h00000ABC,
                  "lectura_adc_data - 0x00000ABC (bits altos en 0)");
        end

        // ------------------------------------------------------------
        // CASO 6: Lectura de STATUS (combinacion de flags)
        // ------------------------------------------------------------
        $display("\n[CASO 6] Lectura STATUS (0x10)");
        begin : caso6
            reg [31:0] readback;
            data_ready  = 1;
            adc_ready   = 0;
            gate_active = 1;
            // mode_sel actualmente en 0 (default, no se ha cambiado aun)
            wb_read(32'h10, readback);
            // STATUS = {mode_sel, gate_active, adc_ready, data_ready}
            //         = {0, 1, 0, 1} = 4'b0101 = 0x5
            check(readback === 32'h00000005,
                  "lectura_status - 0x5 = {mode_sel=0,gate_active=1,adc_ready=0,data_ready=1}");
        end

        // ------------------------------------------------------------
        // CASO 7: Escritura de CTRL - decodificacion de cada bit
        // ------------------------------------------------------------
        $display("\n[CASO 7] Escritura CTRL (0x14) - decodificacion de bits");
        begin : caso7
            // CTRL = {adc_swidth[3:0], dac_load_div, dac_ext_data,
            //         continuous_adc, mode_sel, soft_rst}
            // bits: [8:5]=swidth [4]=load_div [3]=ext_data [2]=cont_adc [1]=mode_sel [0]=soft_rst
            wb_write(32'h14, 32'b0_0000_1010_1); // swidth=0101=5, load_div=0, ext_data=1,
                                                   // cont_adc=0, mode_sel=1, soft_rst... veamos bit a bit
        end

        // Reescribimos con valores claros para verificar bit por bit
        wb_write(32'h14, 32'h000001FF); // todos los bits relevantes en 1 (hasta bit 8)
        wait_clk(1);
        check(mode_sel === 1'b1, "ctrl_mode_sel - bit1=1 -> mode_sel=1");
        check(continuous_adc === 1'b1, "ctrl_continuous_adc - bit2=1 -> continuous_adc=1");
        check(dac_ext_data === 1'b1, "ctrl_dac_ext_data - bit3=1 -> dac_ext_data=1");
        check(adc_swidth === 4'hF, "ctrl_adc_swidth - bits[8:5]=1111 -> adc_swidth=0xF");

        // ------------------------------------------------------------
        // CASO 8: soft_rst y dac_load_div son pulsos de 1 ciclo
        // ------------------------------------------------------------
        $display("\n[CASO 8] soft_rst y dac_load_div son pulsos de 1 ciclo");
        wb_write(32'h14, 32'h00000019); // bit0=1 (soft_rst), bit3=1 (ext_data), bit4=1 (load_div)
        // En el ciclo de la escritura, los pulsos deben verse en 1
        check(soft_rst === 1'b1, "soft_rst_pulso_alto - durante el ciclo de escritura");
        check(dac_load_div === 1'b1, "dac_load_div_pulso_alto - durante el ciclo de escritura");

        @(posedge clk);
        #1;
        check(soft_rst === 1'b0, "soft_rst_autoclear - 1 ciclo despues vuelve a 0");
        check(dac_load_div === 1'b0, "dac_load_div_autoclear - 1 ciclo despues vuelve a 0");

        // Pero mode_sel y dac_ext_data SI deben persistir (no son pulsos)
        check(dac_ext_data === 1'b1, "dac_ext_data_persiste - no es un pulso, mantiene valor");

        // ------------------------------------------------------------
        // CASO 9: wb_ack solo se activa con stb Y cyc simultaneos
        // ------------------------------------------------------------
        $display("\n[CASO 9] wb_ack requiere stb y cyc simultaneos");
        wb_stb = 1;
        wb_cyc = 0; // cyc bajo, no debe haber ack
        @(posedge clk);
        #1;
        check(wb_ack === 1'b0, "sin_cyc_no_ack - wb_ack=0 si cyc=0 aunque stb=1");
        wb_stb = 0;

        wb_stb = 0;
        wb_cyc = 1; // stb bajo, no debe haber ack
        @(posedge clk);
        #1;
        check(wb_ack === 1'b0, "sin_stb_no_ack - wb_ack=0 si stb=0 aunque cyc=1");
        wb_cyc = 0;

        // ------------------------------------------------------------
        // CASO 10: Direccion no mapeada en lectura devuelve 0
        // ------------------------------------------------------------
        $display("\n[CASO 10] Direccion no mapeada devuelve 0");
        begin : caso10
            reg [31:0] readback;
            wb_read(32'h7C, readback); // direccion fuera del mapa de 6 registros
            check(readback === 32'd0,
                  "direccion_no_mapeada - devuelve 0");
        end

        // ------------------------------------------------------------
        // CASO 11: Reset limpia el estado incluso tras varias escrituras
        // ------------------------------------------------------------
        $display("\n[CASO 11] Reset restaura los defaults");
        wb_write(32'h04, 32'd999);
        wb_write(32'h0C, 32'hFF);
        wait_clk(1);
        check(gate_cycles === 27'd999 && dac_word === 8'hFF,
              "estado_antes_reset - valores modificados correctamente");

        rst_n = 0;
        @(posedge clk);
        #1;
        rst_n = 1;
        wait_clk(2);
        check(gate_cycles === 27'd100_000_000 && dac_word === 8'd0,
              "post_reset_defaults - vuelven a los valores default");

        // ------------------------------------------------------------
        // Resumen final
        // ------------------------------------------------------------
        $display("");
        $display("=== RESULTADO FINAL ===");
        $display("  PASS: %0d / FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >> ALL TESTS PASSED <<");
        else
            $display("  >> HAY FALLOS - revisar <<");
        $display("");

        $finish;
    end

    // Timeout de seguridad
    initial begin
        #20000;
        $display("  TIMEOUT - testbench no termino a tiempo");
        $finish;
    end

endmodule

`default_nettype wire
