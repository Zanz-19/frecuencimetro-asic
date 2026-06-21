// Módulo     : tb_freq_top
// Archivo    : tb/tb_freq_top.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de integración de freq_top.v con AMBAS IPs reales
//              simultáneamente (sar_ctrl del ADC, r2r_dac_control del DAC).
//              Verifica: arranque automático de la FSM general, lectura de
//              registros vía Wishbone, configuración de T_gate, medición de
//              una señal de frecuencia externa conocida, operación del ADC
//              en paralelo sin interferir con la medición de frecuencia, y
//              el camino de selftest completo (DAC -> modelo de Schmitt ->
//              freq_counter -> FREQ_RESULT).
//
// MODELO DE SCHMITT TRIGGER (no es RTL real, solo para cerrar el lazo digital
// de prueba del camino de selftest; el diseño analógico real es Fase 4):
//   fx_modelo = (dac_data_out >= UMBRAL) ? 1 : 0
// Con UMBRAL=128 (mitad de la rampa de 0-255), genera un pulso cuadrado cuya
// frecuencia coincide con la frecuencia de la rampa completa del DAC.
//
// Uso:
//   make sim MODULE=freq_top EXTRA_SRC="ip/adc_sar/verilog/sar_ctrl.v ip/dac_r2r/verilog/rtl/r2r_dac_control.v"

`default_nettype none
`timescale 1ns/1ps

module tb_freq_top;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz
    parameter UMBRAL_SCHMITT = 8'd128;

    reg         clk;
    reg         rst_n;

    // Bus Wishbone (lado maestro)
    reg         wbs_stb_i, wbs_cyc_i, wbs_we_i;
    reg  [3:0]  wbs_sel_i;
    reg  [31:0] wbs_dat_i, wbs_adr_i;
    wire        wbs_ack_o;
    wire [31:0] wbs_dat_o;

    // Señal de frecuencia externa
    reg         fx_in_external;

    // Indicadores de estado
    wire        data_ready_out, gate_active_out, adc_ready_out;

    // Interfaz hacia el ADC (sar_ctrl real)
    wire        adc_soc, adc_en;
    wire [3:0]  adc_swidth;
    wire [11:0] adc_data_raw;
    wire        adc_eoc;

    // Interfaz hacia el DAC (r2r_dac_control real)
    wire [7:0]  dac_data_out;
    wire        dac_ext_data, dac_load_div, dac_n_rst;
    wire [7:0]  dac_r2r_out;

    // Selección de fuente de fx_in: señal externa o modelo de Schmitt (selftest)
    reg         selftest_mode;
    wire        fx_modelo_schmitt = (dac_data_out >= UMBRAL_SCHMITT);
    wire        fx_in_to_top = selftest_mode ? fx_modelo_schmitt : fx_in_external;

    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------
    // Instancia del DUT (freq_top)
    // -------------------------------------------------------------------
    freq_top dut (
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

    // -------------------------------------------------------------------
    // Instancia REAL de sar_ctrl (IP del ADC)
    // -------------------------------------------------------------------
    reg  [11:0] target_value;
    wire        sar_cmp;
    wire        sar_sample_n, sar_dac_rst_unused;

    sar_ctrl #(.SIZE(12)) u_sar_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .soc      (adc_soc),
        .cmp      (sar_cmp),
        .en       (adc_en),
        .swidth   (adc_swidth),
        .sample_n (sar_sample_n),
        .data     (adc_data_raw),
        .eoc      (adc_eoc),
        .dac_rst  (sar_dac_rst_unused)
    );

    // Modelo de comparador SAR, formula verificada en Fase 2 (adc_ctrl.v):
    // cmp=1 mantiene el bit probado si (result | shift) <= target
    assign sar_cmp = ((u_sar_ctrl.result | u_sar_ctrl.shift) <= target_value) ? 1'b1 : 1'b0;

    // -------------------------------------------------------------------
    // Instancia REAL de r2r_dac_control (IP del DAC)
    // -------------------------------------------------------------------
    r2r_dac_control u_dac_ip (
        .clk          (clk),
        .n_rst        (dac_n_rst),
        .ext_data     (dac_ext_data),
        .data         (dac_data_out),
        .load_divider (dac_load_div),
        .r2r_out      (dac_r2r_out)
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

    task wb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            wbs_adr_i = addr;
            wbs_dat_i = data;
            wbs_we_i  = 1;
            wbs_sel_i = 4'hF;
            wbs_stb_i = 1;
            wbs_cyc_i = 1;
            @(posedge clk);
            #1;
            wbs_stb_i = 0;
            wbs_cyc_i = 0;
            wbs_we_i  = 0;
        end
    endtask

    task wb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            wbs_adr_i = addr;
            wbs_we_i  = 0;
            wbs_sel_i = 4'hF;
            wbs_stb_i = 1;
            wbs_cyc_i = 1;
            @(posedge clk);
            #1;
            data      = wbs_dat_o;
            wbs_stb_i = 0;
            wbs_cyc_i = 0;
        end
    endtask

    // Tarea: genera fx_in_external durante 'duration_ns' con medio periodo fx_half_ns
    task generate_fx_external;
        input real fx_half_ns;
        input real duration_ns;
        real elapsed;
        begin
            fx_in_external = 1'b0;
            elapsed = 0;
            while (elapsed < duration_ns) begin
                #(fx_half_ns);
                fx_in_external = ~fx_in_external;
                elapsed = elapsed + fx_half_ns;
            end
            fx_in_external = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------
    // Bloque principal de pruebas
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_freq_top.vcd");
        $dumpvars(0, tb_freq_top);

        pass_count = 0;
        fail_count = 0;

        rst_n          = 0;
        wbs_stb_i      = 0;
        wbs_cyc_i      = 0;
        wbs_we_i       = 0;
        wbs_sel_i      = 4'h0;
        wbs_dat_i      = 32'd0;
        wbs_adr_i      = 32'd0;
        fx_in_external = 0;
        selftest_mode  = 0;
        target_value   = 12'd0;

        $display("");
        $display("=== TEST: freq_top (integracion completa, ambas IPs reales) ===");
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        wait_clk(3);
        rst_n = 1;
        wait_clk(2);

        // ------------------------------------------------------------
        // CASO 1: Reset y defaults via Wishbone
        // ------------------------------------------------------------
        $display("\n[CASO 1] Reset y defaults leidos via Wishbone");
        begin : caso1
            reg [31:0] readback;
            wb_read(32'h04, readback); // GATE_CFG
            check(readback === 32'd100_000_000,
                  "default_gate_cfg_via_wishbone - 100_000_000 (T_gate=1s)");
        end

        // ------------------------------------------------------------
        // CASO 2: La FSM general arranca automaticamente (gate_active sube)
        // ------------------------------------------------------------
        $display("\n[CASO 2] FSM arranca automaticamente tras reset");
        begin : caso2
            integer timeout;
            timeout = 0;
            while (gate_active_out !== 1'b1 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            check(gate_active_out === 1'b1,
                  "fsm_arranca_sola - gate_active_out sube sin intervencion del CPU");
        end

        // ------------------------------------------------------------
        // CASO 3: Configurar T_gate corto para pruebas rapidas, medir
        // una señal externa de frecuencia conocida
        // ------------------------------------------------------------
        $display("\n[CASO 3] Medicion de frecuencia externa con T_gate corto");
        begin : caso3
            reg [31:0] readback;
            integer timeout;

            // IMPORTANTE: la FSM ya arranco con el T_gate default (100_000_000
            // ciclos = 1s), que es demasiado largo para simular en un caso de
            // prueba. Usamos soft_rst para forzar el reinicio de la FSM y de
            // gate_timer DESPUES de configurar el nuevo GATE_CFG, asi la
            // siguiente ventana ya usa el valor corto.

            // T_gate = 1000 ciclos = 10us @ 100MHz
            wb_write(32'h04, 32'd1000);

            // soft_rst (bit0 de CTRL) reinicia gate_timer/freq_counter/result_latch
            // por 1 ciclo, forzando que la FSM vuelva a S_IDLE y arranque de
            // nuevo, esta vez con gate_cycles=1000 ya cargado
            wb_write(32'h14, 32'h00000001);
            wait_clk(3);

            // Generar fx_in_external a 1MHz (periodo=1000ns, medio periodo=500ns)
            // durante mas que un T_gate completo (10us) para asegurar cobertura
            fork
                generate_fx_external(500.0, 15000.0); // 1MHz por 15us
                begin : wait_measurement
                    timeout = 0;
                    // Esperar a que ocurra un ciclo completo gate_active 1->0
                    wait(gate_active_out === 1'b1);
                    wait(gate_active_out === 1'b0);
                    wait_clk(2); // margen para que latch_en capture el resultado
                end
            join

            wb_read(32'h00, readback); // FREQ_RESULT
            // T_gate=1000 ciclos @ 100MHz = 10us. fx=1MHz -> periodo=1us.
            // En 10us esperamos ~10 flancos de subida.
            $display("       FREQ_RESULT = %0d (esperado ~10, T_gate=10us @ fx=1MHz)",
                       readback);
            check(readback >= 8 && readback <= 12,
                  "medicion_frecuencia_externa - ~10 conteos (1MHz, T_gate=10us)");
        end

        // ------------------------------------------------------------
        // CASO 4: Operacion del ADC en paralelo, sin interferir con freq
        // ------------------------------------------------------------
        $display("\n[CASO 4] ADC opera en paralelo a la medicion de frecuencia");
        begin : caso4
            reg [31:0] readback;
            integer timeout;

            target_value = 12'h555;

            // Disparar una conversion activando momentaneamente continuous_adc:
            // adc_ctrl ve continuous_en=1 en S_IDLE y arranca S_SOC_PULSE.
            // Apenas se detecta ese primer soc, desactivamos continuous_adc
            // para que la FSM complete ESTA conversion (S_WAIT_EOC->S_CAPTURE)
            // y regrese a S_IDLE sin encadenar una segunda. Esto emula un modo
            // "single-shot" usando los registros ya existentes, sin modificar
            // wb_regs.v (ya congelado con 30/30 tests).
            wb_write(32'h14, 32'h00000004); // continuous_adc=1

            timeout = 0;
            while (adc_soc !== 1'b1 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            check(timeout < 50, "adc_arranca - adc_soc sube tras activar continuous_adc");

            // Desactivar de inmediato para evitar el encadenamiento automatico
            wb_write(32'h14, 32'h00000000);

            // Esperar a que ESTA conversion termine (adc_ctrl vuelve a S_IDLE)
            timeout = 0;
            while (dut.u_adc_ctrl.state !== 2'b00 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            #1;  // Regla del #1 (Fase 2): evita leer adc_result en el mismo
                 // instante en que la asignacion no-bloqueante de S_CAPTURE
                 // todavia se esta resolviendo en este flanco.
            check(timeout < 50, "adc_termina_sin_encadenar - FSM vuelve a S_IDLE");

            check(adc_ready_out === 1'b1,
                  "adc_ready_tras_conversion - sube correctamente");

            wb_read(32'h08, readback); // ADC_DATA
            check(readback === 32'h00000555,
                  "adc_data_correcto - lee 0x555 a traves de wb_regs");

            // Verificar que gate_active sigue funcionando (no se detuvo por el ADC)
            timeout = 0;
            while (gate_active_out !== 1'b1 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            check(gate_active_out === 1'b1,
                  "freq_counter_no_interferido - gate_active sigue su ciclo normal");
        end

        // ------------------------------------------------------------
        // CASO 5: Camino de selftest completo (DAC -> Schmitt modelo -> freq)
        // ------------------------------------------------------------
        $display("\n[CASO 5] Selftest: DAC genera senal, freq_counter la mide");
        begin : caso5
            reg [31:0] readback;

            // Configurar T_gate adecuado para la frecuencia de rampa esperada
            // Modo selftest: dac_ext_data=0 (rampa interna), divisor=0 (rampa rapida)
            wb_write(32'h0C, 32'd0);          // DAC_WORD=0 (sera el divisor a cargar)
            wb_write(32'h14, 32'h00000010);   // bit4=dac_load_div=1 (pulso, carga divisor=0)
            wait_clk(2);
            wb_write(32'h14, 32'h00000000);   // bit3=dac_ext_data=0 -> modo selftest

            // Cambiar la fuente de fx_in del testbench a la salida del modelo Schmitt
            selftest_mode = 1;

            // T_gate suficientemente largo para capturar varios ciclos de rampa
            wb_write(32'h04, 32'd5000); // 50us @ 100MHz

            // Esperar un ciclo completo de medicion
            wait(gate_active_out === 1'b1);
            wait(gate_active_out === 1'b0);
            wait_clk(2);

            wb_read(32'h00, readback);
            $display("       FREQ_RESULT (selftest) = %0d", readback);
            // No verificamos un valor exacto (depende del divisor=0 y su velocidad
            // real), solo que el sistema reporto una medicion mayor a 0, confirmando
            // que el lazo completo DAC->Schmitt_modelo->freq_counter->wb_regs funciona
            check(readback > 0,
                  "selftest_lazo_completo - FREQ_RESULT > 0, el lazo DAC->freq funciona");

            selftest_mode = 0; // volver a fuente externa para casos siguientes
        end

        // ------------------------------------------------------------
        // CASO 6: dac_n_rst sigue rst_n correctamente (hallazgo critico Fase 2)
        // ------------------------------------------------------------
        $display("\n[CASO 6] dac_n_rst = rst_n sin inversion (verificacion en freq_top)");
        check(dac_n_rst === rst_n,
              "dac_n_rst_sin_inversion - coincide exactamente con rst_n");

        // ------------------------------------------------------------
        // CASO 7: Reset global detiene y reinicia todo el sistema
        // ------------------------------------------------------------
        $display("\n[CASO 7] Reset global reinicia el sistema completo");
        begin : caso7
            reg [31:0] readback;
            rst_n = 0;
            @(posedge clk);
            #1;
            check(gate_active_out === 1'b0 && data_ready_out === 1'b0,
                  "reset_global - gate_active=0, data_ready=0");

            rst_n = 1;
            wait_clk(3);

            wb_read(32'h04, readback);
            check(readback === 32'd100_000_000,
                  "post_reset_defaults - GATE_CFG vuelve a 100_000_000");
        end

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

    // Timeout de seguridad (mas largo, dado que hay esperas de T_gate reales)
    initial begin
        #500000; // 500 us
        $display("  TIMEOUT - testbench no termino a tiempo");
        $finish;
    end

endmodule

`default_nettype wire
