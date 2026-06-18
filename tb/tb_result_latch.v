// Módulo     : tb_result_latch
// Archivo    : tb/tb_result_latch.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de result_latch. Verifica captura en latch_en,
//              estabilidad mientras latch_en=0, actualización en
//              capturas sucesivas, persistencia de data_ready, y reset.
//
// Nota de estilo: cada vez que se asigna una señal de entrada justo
// despues de un @(posedge clk), se inserta #1 antes de leer cualquier
// salida del DUT, para evitar carreras de simulacion entre el testbench
// y el always del DUT en el mismo flanco (lección aprendida en freq_counter).
//
// Uso:
//   make sim MODULE=result_latch

`default_nettype none
`timescale 1ns/1ps

module tb_result_latch;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

    reg         clk;
    reg         rst_n;
    reg         latch_en;
    reg  [31:0] data_in;
    wire [31:0] data_out;
    wire        data_ready;

    integer pass_count;
    integer fail_count;

    result_latch dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .latch_en   (latch_en),
        .data_in    (data_in),
        .data_out   (data_out),
        .data_ready (data_ready)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

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

    // Tarea: aplica un pulso de latch_en de 1 ciclo con data_in dado
    task pulse_latch;
        input [31:0] value;
        begin
            data_in  = value;
            latch_en = 1;
            @(posedge clk);
            #1;
            latch_en = 0;
        end
    endtask

    initial begin
        $dumpfile("tb_result_latch.vcd");
        $dumpvars(0, tb_result_latch);

        pass_count = 0;
        fail_count = 0;

        rst_n    = 0;
        latch_en = 0;
        data_in  = 32'd0;

        $display("");
        $display("=== TEST: result_latch ===");
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        // ------------------------------------------------------------
        // CASO 1: Reset
        // ------------------------------------------------------------
        $display("\n[CASO 1] Reset activo");
        wait_clk(3);
        check(data_out === 32'd0 && data_ready === 1'b0,
              "reset_inicial - data_out=0, data_ready=0");

        rst_n = 1;
        wait_clk(2);
        check(data_out === 32'd0 && data_ready === 1'b0,
              "post_reset_sin_latch - sigue en 0, data_ready sigue en 0");

        // ------------------------------------------------------------
        // CASO 2: Primera captura
        // ------------------------------------------------------------
        $display("\n[CASO 2] Primera captura con latch_en");
        pulse_latch(32'd1234);
        check(data_out === 32'd1234 && data_ready === 1'b1,
              "primera_captura - data_out=1234, data_ready=1");

        // ------------------------------------------------------------
        // CASO 3: data_out estable mientras latch_en=0
        // ------------------------------------------------------------
        $display("\n[CASO 3] Estabilidad mientras latch_en=0");
        data_in = 32'd9999; // cambiar data_in sin pulsar latch_en
        wait_clk(5);
        check(data_out === 32'd1234,
              "estable_sin_latch - data_out no cambia aunque data_in cambie");

        // ------------------------------------------------------------
        // CASO 4: Segunda captura actualiza el valor
        // ------------------------------------------------------------
        $display("\n[CASO 4] Segunda captura actualiza data_out");
        pulse_latch(32'd5678);
        check(data_out === 32'd5678 && data_ready === 1'b1,
              "segunda_captura - data_out=5678, data_ready sigue en 1");

        // ------------------------------------------------------------
        // CASO 5: data_ready persiste (no es un pulso) tras varias capturas
        // ------------------------------------------------------------
        $display("\n[CASO 5] data_ready persiste tras multiples ciclos");
        wait_clk(10);
        check(data_ready === 1'b1,
              "data_ready_persiste - sigue en 1 mucho despues de la captura");

        // ------------------------------------------------------------
        // CASO 6: Captura con valor 0 (caso de esquina: contador llego a 0)
        // ------------------------------------------------------------
        $display("\n[CASO 6] Captura de valor 0 (caso de esquina)");
        pulse_latch(32'd0);
        check(data_out === 32'd0 && data_ready === 1'b1,
              "captura_valor_cero - data_out=0, data_ready sigue en 1 (no se confunde con reset)");

        // ------------------------------------------------------------
        // CASO 7: Captura con valor máximo (32 bits todo en 1)
        // ------------------------------------------------------------
        $display("\n[CASO 7] Captura de valor maximo (0xFFFFFFFF)");
        pulse_latch(32'hFFFFFFFF);
        check(data_out === 32'hFFFFFFFF,
              "captura_valor_maximo - data_out=0xFFFFFFFF");

        // ------------------------------------------------------------
        // CASO 8: Reset borra data_out y data_ready tras varias capturas
        // ------------------------------------------------------------
        $display("\n[CASO 8] Reset borra el estado tras capturas previas");
        rst_n = 0;
        @(posedge clk);
        #1;
        check(data_out === 32'd0 && data_ready === 1'b0,
              "reset_post_capturas - data_out=0, data_ready=0");

        rst_n = 1;
        wait_clk(2);
        check(data_out === 32'd0 && data_ready === 1'b0,
              "post_reset_segunda_vez - permanece en 0 sin nuevo latch_en");

        // ------------------------------------------------------------
        // CASO 9: Tras el segundo reset, una nueva captura funciona igual
        // ------------------------------------------------------------
        $display("\n[CASO 9] Captura normal tras un reset previo");
        pulse_latch(32'd42);
        check(data_out === 32'd42 && data_ready === 1'b1,
              "captura_tras_reset - sistema funciona normalmente de nuevo");

        // ------------------------------------------------------------
        // CASO 10: latch_en sostenido por varios ciclos (no solo 1 pulso)
        // Verifica que mientras latch_en=1 sostenido, data_out sigue
        // actualizandose con cada flanco (comportamiento de paso through
        // sincronizado, no de pulso unico obligatorio).
        // ------------------------------------------------------------
        $display("\n[CASO 10] latch_en sostenido varios ciclos");
        data_in  = 32'd100;
        latch_en = 1;
        @(posedge clk);
        #1;
        check(data_out === 32'd100, "latch_sostenido_ciclo1 - data_out=100");

        data_in = 32'd200; // cambiar data_in mientras latch_en sigue en 1
        @(posedge clk);
        #1;
        check(data_out === 32'd200,
              "latch_sostenido_ciclo2 - data_out sigue actualizando a 200");

        latch_en = 0;
        data_in  = 32'd999; // ya no deberia importar
        wait_clk(3);
        check(data_out === 32'd200,
              "latch_sostenido_fin - al bajar latch_en, data_out se congela en el ultimo valor");

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
        #10000;
        $display("  TIMEOUT - testbench no termino en 10 us");
        $finish;
    end

endmodule

`default_nettype wire
