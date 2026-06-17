// Módulo     : tb_gate_timer
// Archivo    : tb/tb_gate_timer.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de verificación de gate_timer.
//              Prueba: reset, duración exacta para varios gate_cycles,
//              start ignorado durante ventana activa, reset durante ventana
//              activa, y gate_cycles=0 (configuración inválida).
//
// Uso:
//   make sim MODULE=gate_timer

`default_nettype none
`timescale 1ns/1ps

module tb_gate_timer;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [26:0] gate_cycles;
    wire        gate_en;
    wire        gate_done;

    integer pass_count;
    integer fail_count;

    gate_timer dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .gate_cycles (gate_cycles),
        .gate_en     (gate_en),
        .gate_done   (gate_done)
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

    // Tarea: medir cuántos ciclos de clk dura gate_en=1 tras un 'start'
    // Devuelve el conteo en la variable 'measured_cycles' (declarada en el caller)
    task measure_gate_duration;
        input  [26:0] cycles_to_program;
        output integer measured_cycles;
        integer counter;
        begin
            gate_cycles = cycles_to_program;
            counter     = 0;

            // Disparar start
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // Esperar a que gate_en suba (debería ya estar arriba tras el start)
            // Contar ciclos mientras gate_en esté en 1
            while (gate_en === 1'b1) begin
                counter = counter + 1;
                @(posedge clk);
            end

            measured_cycles = counter;
        end
    endtask

    initial begin
        $dumpfile("tb_gate_timer.vcd");
        $dumpvars(0, tb_gate_timer);

        pass_count = 0;
        fail_count = 0;

        rst_n       = 0;
        start       = 0;
        gate_cycles = 27'd0;

        $display("");
        $display("=== TEST: gate_timer ===");
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        // ------------------------------------------------------------
        // CASO 1: Reset
        // ------------------------------------------------------------
        $display("\n[CASO 1] Reset activo");
        wait_clk(3);
        check(gate_en === 1'b0 && gate_done === 1'b0,
              "reset_inicial - gate_en=0, gate_done=0");

        rst_n = 1;
        wait_clk(2);
        check(gate_en === 1'b0,
              "post_reset_sin_start - gate_en sigue en 0");

        // ------------------------------------------------------------
        // CASO 2: Duración exacta para gate_cycles pequeño (10 ciclos)
        // ------------------------------------------------------------
        $display("\n[CASO 2] Duracion exacta - gate_cycles=10");
        begin : caso2
            integer measured;
            measure_gate_duration(27'd10, measured);
            $display("       gate_cycles=10 -> medido=%0d ciclos", measured);
            check(measured == 10, "duracion_10_ciclos - medido == 10");
        end

        // ------------------------------------------------------------
        // CASO 3: Duración exacta para gate_cycles mayor (1000 ciclos)
        // ------------------------------------------------------------
        $display("\n[CASO 3] Duracion exacta - gate_cycles=1000");
        wait_clk(3);
        begin : caso3
            integer measured;
            measure_gate_duration(27'd1000, measured);
            $display("       gate_cycles=1000 -> medido=%0d ciclos", measured);
            check(measured == 1000, "duracion_1000_ciclos - medido == 1000");
        end

        // ------------------------------------------------------------
        // CASO 4: gate_done es un pulso de exactamente 1 ciclo
        // ------------------------------------------------------------
        $display("\n[CASO 4] gate_done es pulso de 1 ciclo");
        wait_clk(3);
        gate_cycles = 27'd5;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        // En este flanco el DUT ya transicionó a S_RUNNING con count=gate_cycles-1=4

        // gate_done sube (gate_cycles - 1) flancos despues del flanco de start=0,
        // es decir, en el flanco donde count llega a 0 y bajada de gate_en ocurre.
        // Con gate_cycles=5: hacen falta 4 flancos adicionales (no 5).
        wait_clk(4);
        #1;
        check(gate_done === 1'b1, "gate_done_sube - en el ciclo de fin");

        @(posedge clk);
        #1;
        check(gate_done === 1'b0, "gate_done_baja - 1 ciclo despues");

        // ------------------------------------------------------------
        // CASO 5: 'start' ignorado mientras gate_en=1 (no reinicia)
        // ------------------------------------------------------------
        $display("\n[CASO 5] start ignorado durante ventana activa");
        wait_clk(3);
        gate_cycles = 27'd20;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // A mitad de la ventana, intentar reiniciar con otro start
        wait_clk(5);
        check(gate_en === 1'b1, "ventana_activa_a_mitad - gate_en=1");

        start = 1;   // intento de reinicio — debe ser ignorado
        @(posedge clk);
        start = 0;

        // Si el start fuera respetado, la ventana se alargaría más allá
        // de los 20 ciclos originales. Verificamos que termina en el
        // tiempo esperado (20 ciclos desde el primer start, no se reinicia).
        wait_clk(20); // ya deberia haber terminado (5 + 1 + margen > 20-5)
        #1;
        check(gate_en === 1'b0,
              "no_se_reinicio - gate_en bajo en el tiempo original esperado");

        // ------------------------------------------------------------
        // CASO 6: Reset durante ventana activa
        // ------------------------------------------------------------
        $display("\n[CASO 6] Reset durante ventana activa");
        wait_clk(3);
        gate_cycles = 27'd50;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait_clk(10); // a mitad de la ventana
        check(gate_en === 1'b1, "ventana_activa_antes_reset - gate_en=1");

        rst_n = 0;
        @(posedge clk);
        #1;
        check(gate_en === 1'b0 && gate_done === 1'b0,
              "reset_corta_ventana - gate_en=0, gate_done=0");

        rst_n = 1;
        wait_clk(2);

        // ------------------------------------------------------------
        // CASO 7: gate_cycles=0 es configuración inválida — start se ignora
        // ------------------------------------------------------------
        $display("\n[CASO 7] gate_cycles=0 - start debe ignorarse");
        wait_clk(3);
        gate_cycles = 27'd0;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        wait_clk(3);
        check(gate_en === 1'b0,
              "gate_cycles_cero - gate_en permanece en 0 (config invalida)");

        // ------------------------------------------------------------
        // CASO 8: Ciclo completo repetido (dos mediciones consecutivas)
        // ------------------------------------------------------------
        $display("\n[CASO 8] Dos ciclos de medicion consecutivos");
        wait_clk(3);
        begin : caso8
            integer measured_a, measured_b;
            measure_gate_duration(27'd15, measured_a);
            wait_clk(3); // tiempo entre mediciones (simula lectura del CPU)
            measure_gate_duration(27'd15, measured_b);
            check(measured_a == 15 && measured_b == 15,
                  "dos_ciclos_consecutivos - ambos midieron 15 ciclos");
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
        #50000;
        $display("  TIMEOUT - testbench no termino en 50 us");
        $finish;
    end

endmodule

`default_nettype wire
