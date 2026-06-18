// Módulo     : tb_adc_ctrl
// Archivo    : tb/tb_adc_ctrl.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de adc_ctrl, integrado con una instancia real de
//              sar_ctrl (IP del ADC SAR, chipfoundry/sky130_ef_ip__adc3v_12bit)
//              para verificar el protocolo completo soc->eoc->captura con
//              el comportamiento real de la IP, no un mock.
//
// Modelo de cmp utilizado: se modela un comparador ideal que compara un
// valor objetivo (target_value) contra el registro interno de sar_ctrl
// durante su búsqueda binaria. Esto permite verificar que adc_ctrl captura
// exactamente el valor esperado al finalizar la conversión SAR completa.
//
// Nota de estilo: todo cambio de señal de entrada inmediatamente después de
// un @(posedge clk) usa #1 de margen antes de leer salidas del DUT.
//
// Uso:
//   make sim MODULE=adc_ctrl

`default_nettype none
`timescale 1ns/1ps

module tb_adc_ctrl;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz
    parameter ADC_SIZE   = 12;

    reg         clk;
    reg         rst_n;
    reg         eoc_sync;
    reg  [11:0] adc_data_raw;
    wire        adc_soc;
    wire        adc_en;
    wire [11:0] adc_result;
    wire        adc_ready;
    reg         continuous_en;
    reg         adc_trigger;

    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------
    // Instancia del DUT (adc_ctrl)
    // -------------------------------------------------------------------
    adc_ctrl dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .eoc_sync      (eoc_sync),
        .adc_data_raw  (adc_data_raw),
        .adc_soc       (adc_soc),
        .adc_en        (adc_en),
        .adc_result    (adc_result),
        .adc_ready     (adc_ready),
        .continuous_en (continuous_en),
        .adc_trigger   (adc_trigger)
    );

    // -------------------------------------------------------------------
    // Instancia de sar_ctrl REAL (IP del ADC) para integración genuina
    // -------------------------------------------------------------------
    reg  sar_cmp;
    wire sar_sample_n;
    wire [ADC_SIZE-1:0] sar_data;
    wire sar_eoc;
    wire sar_dac_rst;

    sar_ctrl #(.SIZE(ADC_SIZE)) sar (
        .clk       (clk),
        .rst_n     (rst_n),
        .soc       (adc_soc),
        .cmp       (sar_cmp),
        .en        (adc_en),
        .swidth    (4'd0),       // swidth=0 -> 15 ciclos soc->eoc (verificado)
        .sample_n  (sar_sample_n),
        .data      (sar_data),
        .eoc       (sar_eoc),
        .dac_rst   (sar_dac_rst)
    );

    // En este testbench, adc_ctrl ve directamente las señales reales de sar_ctrl
    // (eoc_sync y adc_data_raw aquí NO pasan por cdc_sync, ya que ese módulo
    // se verificó por separado en Fase 2; aquí asumimos sincronización ideal
    // para aislar el comportamiento de adc_ctrl + sar_ctrl)
    always @(*) begin
        eoc_sync     = sar_eoc;
        adc_data_raw = sar_data;
    end

    // -------------------------------------------------------------------
    // Modelo de comparador para la búsqueda binaria SAR
    // -------------------------------------------------------------------
    // sar_ctrl arma 'result' progresivamente: en cada ciclo de CONV,
    // current = (cmp==0) ? ~shift : todo_unos. El comparador real compara
    // la tensión del CDAC (proporcional a 'result' probado) contra la
    // entrada analógica. Aquí lo modelamos digitalmente: cmp=1 si el
    // 'result' probado (vía la jerarquía de sar) es <= target_value,
    // replicando la lógica de aproximaciones sucesivas hacia ese objetivo.
    reg [11:0] target_value;

    always @(*) begin
        // Modelo de comparador verificado contra sar_ctrl.v real:
        // el valor que se compara en cada ciclo es (result acumulado | shift
        // del bit actual que se esta probando), no result solo. cmp=1
        // mantiene el bit probado si el valor resultante es <= target.
        sar_cmp = ((sar.result | sar.shift) <= target_value) ? 1'b1 : 1'b0;
    end

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

    // Tarea: dispara una conversión single-shot con un target_value dado,
    // espera a que termine, y devuelve el resultado capturado.
    // IMPORTANTE: adc_ready persiste en 1 tras la primera conversión exitosa
    // (no es un pulso), por lo que no sirve para detectar el fin de
    // conversiones POSTERIORES. En su lugar, esperamos a que la FSM
    // regrese a S_IDLE (dut.state == 2'b00), lo cual ocurre exactamente
    // 1 ciclo despues de la captura.
    task run_single_shot;
        input  [11:0] target;
        output [11:0] result;
        integer safety_counter;
        begin
            target_value = target;
            adc_trigger  = 1;
            @(posedge clk);
            #1;
            adc_trigger  = 0;

            // Esperar a que la FSM salga de IDLE (inicio de la conversion)
            safety_counter = 0;
            while (dut.state === 2'b00 && safety_counter < 100) begin
                @(posedge clk);
                #1;
                safety_counter = safety_counter + 1;
            end

            // Esperar a que la FSM vuelva a IDLE (fin de la conversion)
            safety_counter = 0;
            while (dut.state !== 2'b00 && safety_counter < 100) begin
                @(posedge clk);
                #1;
                safety_counter = safety_counter + 1;
            end

            result = adc_result;
        end
    endtask

    // -------------------------------------------------------------------
    // Bloque principal de pruebas
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_adc_ctrl.vcd");
        $dumpvars(0, tb_adc_ctrl);

        pass_count = 0;
        fail_count = 0;

        rst_n         = 0;
        adc_trigger   = 0;
        continuous_en = 0;
        target_value  = 12'd0;

        $display("");
        $display("=== TEST: adc_ctrl (integrado con sar_ctrl real, SIZE=%0d) ===", ADC_SIZE);
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        wait_clk(3);
        rst_n = 1;
        wait_clk(2);

        // ------------------------------------------------------------
        // CASO 1: Reset
        // ------------------------------------------------------------
        $display("\n[CASO 1] Reset inicial");
        check(adc_ready === 1'b0 && adc_result === 12'd0 && adc_soc === 1'b0,
              "reset_inicial - adc_ready=0, adc_result=0, adc_soc=0");

        // ------------------------------------------------------------
        // CASO 2: Conversion single-shot, valor medio (0x800 = 2048)
        // ------------------------------------------------------------
        $display("\n[CASO 2] Single-shot, target=0x800 (2048)");
        begin : caso2
            reg [11:0] res;
            run_single_shot(12'h800, res);
            $display("       resultado capturado = 0x%03h (esperado ~0x800)", res);
            check(adc_ready === 1'b1, "adc_ready_sube - tras single-shot");
            // La busqueda SAR converge exactamente al target si es representable
            check(res === 12'h800, "resultado_exacto - 0x800 capturado correctamente");
        end

        wait_clk(5);

        // ------------------------------------------------------------
        // CASO 3: Conversion single-shot, valor minimo (0x000)
        // ------------------------------------------------------------
        $display("\n[CASO 3] Single-shot, target=0x000 (minimo)");
        begin : caso3
            reg [11:0] res;
            run_single_shot(12'h000, res);
            $display("       resultado capturado = 0x%03h (esperado 0x000)", res);
            check(res === 12'h000, "resultado_minimo - 0x000 capturado correctamente");
        end

        wait_clk(5);

        // ------------------------------------------------------------
        // CASO 4: Conversion single-shot, valor maximo (0xFFF)
        // ------------------------------------------------------------
        $display("\n[CASO 4] Single-shot, target=0xFFF (maximo)");
        begin : caso4
            reg [11:0] res;
            run_single_shot(12'hFFF, res);
            $display("       resultado capturado = 0x%03h (esperado 0xFFF)", res);
            check(res === 12'hFFF, "resultado_maximo - 0xFFF capturado correctamente");
        end

        wait_clk(5);

        // ------------------------------------------------------------
        // CASO 5: Conversion single-shot, valor arbitrario (0x3E7 = 999)
        // ------------------------------------------------------------
        $display("\n[CASO 5] Single-shot, target=0x3E7 (999)");
        begin : caso5
            reg [11:0] res;
            run_single_shot(12'h3E7, res);
            $display("       resultado capturado = 0x%03h (esperado 0x3E7)", res);
            check(res === 12'h3E7, "resultado_arbitrario - 0x3E7 capturado correctamente");
        end

        wait_clk(5);

        // ------------------------------------------------------------
        // CASO 6: adc_soc es pulso de exactamente 1 ciclo
        // ------------------------------------------------------------
        $display("\n[CASO 6] adc_soc es pulso de 1 ciclo");
        begin : caso6
            integer soc_high_cycles;
            target_value = 12'h200;
            soc_high_cycles = 0;

            adc_trigger = 1;
            @(posedge clk);
            #1;
            adc_trigger = 0;

            // Contar cuantos ciclos adc_soc permanece en alto
            while (!(adc_soc === 1'b0 && soc_high_cycles > 0) && soc_high_cycles < 50) begin
                if (adc_soc === 1'b1) soc_high_cycles = soc_high_cycles + 1;
                @(posedge clk);
                #1;
                if (adc_soc === 1'b0 && soc_high_cycles > 0) begin
                    // ya bajo, salir
                end
            end
            $display("       adc_soc estuvo en alto durante %0d ciclo(s)", soc_high_cycles);
            check(soc_high_cycles === 1, "adc_soc_pulso_unico - exactamente 1 ciclo en alto");

            // Esperar a que termine la conversion en curso antes de seguir
            // (esperar a S_IDLE, ya que adc_ready persiste en 1 desde
            // conversiones previas y no sirve como señal de "recien termino")
            while (dut.state !== 2'b00) @(posedge clk);
            #1;
        end

        wait_clk(5);

        // ------------------------------------------------------------
        // CASO 7: Modo single-shot no encadena conversiones automaticamente
        // ------------------------------------------------------------
        $display("\n[CASO 7] Single-shot no se repite sin nuevo trigger");
        begin : caso7
            reg [11:0] res_before;
            integer k;
            target_value = 12'hAAA;
            res_before = adc_result;

            // Sin nuevo adc_trigger, esperar varios ciclos
            for (k = 0; k < 30; k = k + 1) @(posedge clk);
            #1;
            check(adc_result === res_before,
                  "sin_repeticion - adc_result no cambia sin nuevo trigger");
            check(adc_soc === 1'b0,
                  "sin_nuevo_soc - adc_soc permanece en 0 sin trigger");
        end

        // ------------------------------------------------------------
        // CASO 8: Modo continuo encadena conversiones automaticamente
        // ------------------------------------------------------------
        $display("\n[CASO 8] Modo continuo encadena conversiones");
        begin : caso8
            integer conversions_seen;
            integer k;
            reg prev_ready;

            target_value  = 12'h555;
            continuous_en = 1;
            conversions_seen = 0;
            prev_ready = adc_ready;

            // Disparar la primera conversion en modo continuo
            // (en S_IDLE, continuous_en=1 ya dispara sin necesidad de adc_trigger)
            for (k = 0; k < 200; k = k + 1) begin
                @(posedge clk);
                #1;
                if (adc_soc === 1'b1) begin
                    conversions_seen = conversions_seen + 1;
                end
            end

            $display("       conversiones (pulsos adc_soc) vistas en 200 ciclos: %0d",
                       conversions_seen);
            // Con 15 ciclos por conversion, en 200 ciclos esperamos >= 2 conversiones
            check(conversions_seen >= 2,
                  "modo_continuo_encadena - al menos 2 conversiones sin intervencion");

            continuous_en = 0;
            // Esperar a que termine la conversion en curso
            wait_clk(20);
        end

        // ------------------------------------------------------------
        // CASO 9: adc_en se activa tras el reset y permanece activo
        // ------------------------------------------------------------
        $display("\n[CASO 9] adc_en permanece activo tras reset");
        check(adc_en === 1'b1, "adc_en_activo - permanece en 1 tras salir de reset");

        // ------------------------------------------------------------
        // CASO 10: Reset durante una conversion en curso
        // ------------------------------------------------------------
        $display("\n[CASO 10] Reset durante conversion en curso");
        begin : caso10
            target_value = 12'h333;
            adc_trigger  = 1;
            @(posedge clk);
            #1;
            adc_trigger = 0;

            wait_clk(5); // a mitad de la conversion (dura 15+ ciclos)
            check(adc_soc === 1'b0 && dut.state != 2'b00,
                  "conversion_en_curso - FSM ocupada antes del reset");

            rst_n = 0;
            @(posedge clk);
            #1;
            check(adc_ready === 1'b0 && adc_soc === 1'b0,
                  "reset_corta_conversion - adc_ready=0, adc_soc=0");

            rst_n = 1;
            wait_clk(2);
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

    // Timeout de seguridad
    initial begin
        #100000;
        $display("  TIMEOUT - testbench no termino a tiempo");
        $finish;
    end

endmodule

`default_nettype wire
