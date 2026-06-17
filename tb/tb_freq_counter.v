// Módulo     : tb_freq_counter
// Archivo    : tb/tb_freq_counter.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de freq_counter. Genera señales fx_in de frecuencia
//              conocida (vía periodo programable) y verifica que el conteo
//              durante una ventana gate_en de duración conocida sea correcto.
//
// Uso:
//   make sim MODULE=freq_counter

`default_nettype none
`timescale 1ns/1ps

module tb_freq_counter;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz (clk_user)

    reg         clk;
    reg         rst_n;
    reg         gate_en;
    reg         cnt_reset;
    reg         fx_in;
    wire [31:0] count_out;
    wire        count_valid;

    integer pass_count;
    integer fail_count;

    // Variables para el generador de fx_in independiente
    real    fx_half_period_ns;   // medio periodo de fx_in en ns
    reg     fx_gen_stop;         // bandera para detener el generador limpiamente

    freq_counter dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .gate_en     (gate_en),
        .cnt_reset   (cnt_reset),
        .fx_in       (fx_in),
        .count_out   (count_out),
        .count_valid (count_valid)
    );

    // --- Reloj principal del sistema ---
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        fx_in             = 0;
        fx_gen_stop       = 0;
        fx_half_period_ns = 50;
    end

    // Tarea: genera fx_in durante exactamente 'duration_ns' nanosegundos
    // con medio periodo fx_half_ns, luego se detiene limpiamente (fx_in=0).
    // No deja ningún delay pendiente: el bucle se controla con tiempo real.
    task generate_fx_for_duration;
        input real fx_half_ns;
        input real duration_ns;
        real elapsed;
        begin
            fx_in   = 1'b0;
            elapsed = 0;
            while (elapsed < duration_ns) begin
                #(fx_half_ns);
                fx_in   = ~fx_in;
                elapsed = elapsed + fx_half_ns;
            end
            fx_in = 1'b0; // dejar en nivel conocido al terminar
        end
    endtask

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

    // Tarea: corre una ventana de medición de duración gate_duration_cycles
    // ciclos de clk, con fx_in oscilando a medio periodo fx_half_ns durante
    // toda la ventana, y devuelve el conteo final en measured_count.
    task run_measurement;
        input  integer gate_duration_cycles;
        input  real    fx_half_ns;
        output [31:0]  measured_count;
        real gate_duration_ns;
        begin
            gate_duration_ns = gate_duration_cycles * CLK_PERIOD;

            // Asegurar contador en 0 antes de empezar
            fx_in     = 1'b0;
            cnt_reset = 1;
            @(posedge clk);
            #1;
            cnt_reset = 0;

            // Abrir la ventana y generar fx_in en paralelo, ambos por la
            // misma duración exacta (gate_duration_ns), sin dejar ningún
            // proceso de generación pendiente al finalizar.
            gate_en = 1;
            fork
                generate_fx_for_duration(fx_half_ns, gate_duration_ns);
                begin : wait_gate
                    integer k;
                    for (k = 0; k < gate_duration_cycles; k = k + 1)
                        @(posedge clk);
                end
            join

            // Cerrar la ventana
            gate_en = 0;

            // Esperar count_valid (1 ciclo despues de bajar gate_en)
            @(posedge clk);
            #1;

            measured_count = count_out;
        end
    endtask

    // -------------------------------------------------------------------
    // Bloque principal de pruebas
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_freq_counter.vcd");
        $dumpvars(0, tb_freq_counter);

        pass_count = 0;
        fail_count = 0;

        rst_n     = 0;
        gate_en   = 0;
        cnt_reset = 0;

        $display("");
        $display("=== TEST: freq_counter ===");
        $display("Reloj sistema: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        wait_clk(3);
        rst_n = 1;
        wait_clk(2);

        // ------------------------------------------------------------
        // CASO 1: Reset
        // ------------------------------------------------------------
        $display("\n[CASO 1] Reset inicial");
        check(count_out === 32'd0 && count_valid === 1'b0,
              "reset_inicial - count_out=0, count_valid=0");

        // ------------------------------------------------------------
        // CASO 2: Medicion basica - fx conocida, contar N flancos exactos
        // fx_half_period = 50ns -> periodo fx = 100ns -> fx = 10 MHz
        // gate_duration = 1000 ciclos de clk (100ns cada uno) = 100000ns = 100us
        // En 100us a 10MHz esperamos ~1000 flancos de subida
        // ------------------------------------------------------------
        $display("\n[CASO 2] Medicion basica: fx=10MHz, T_gate=100us -> esperado ~1000");
        begin : caso2
            reg [31:0] measured;
            run_measurement(10000, 50.0, measured); // 10000 ciclos clk = 100us
            $display("       medido = %0d (esperado ~1000)", measured);
            // Margen de tolerancia +-2 por posibles flancos parciales en los bordes
            check((measured >= 998) && (measured <= 1002),
                  "medicion_basica_10MHz - dentro de tolerancia +-2");
        end

        wait_clk(3);

        // ------------------------------------------------------------
        // CASO 3: Frecuencia baja conocida con conteo exacto controlado
        // Generamos fx_in manualmente con N flancos exactos, sin depender
        // del generador continuo, para verificar conteo exacto sin margen.
        // ------------------------------------------------------------
        $display("\n[CASO 3] Conteo exacto manual - 7 flancos de subida controlados");
        begin : caso3
            integer i;
            cnt_reset = 1;
            fx_in     = 0;
            @(posedge clk);
            #1;
            cnt_reset = 0;
            gate_en   = 1;
            wait_clk(2);

            // Generar exactamente 7 flancos de subida, bien espaciados
            // y completamente dentro de la ventana gate_en=1
            for (i = 0; i < 7; i = i + 1) begin
                fx_in = 1;
                wait_clk(2);
                fx_in = 0;
                wait_clk(2);
            end

            wait_clk(3);
            gate_en = 0;
            wait_clk(1);
            #1;
            $display("       count_out = %0d (esperado = 7)", count_out);
            check(count_out === 32'd7, "conteo_exacto_7_flancos - count_out == 7");
        end

        wait_clk(3);

        // ------------------------------------------------------------
        // CASO 4: count_valid es pulso de 1 ciclo tras gate_en bajar
        // ------------------------------------------------------------
        $display("\n[CASO 4] count_valid pulso de 1 ciclo");
        cnt_reset = 1;
        @(posedge clk);
        #1;
        cnt_reset = 0;
        gate_en   = 1;
        wait_clk(5);
        gate_en = 0;

        @(posedge clk);
        #1;
        check(count_valid === 1'b1, "count_valid_sube - 1 ciclo tras gate_en bajar");

        @(posedge clk);
        #1;
        check(count_valid === 1'b0, "count_valid_baja - 1 ciclo despues");

        wait_clk(3);

        // ------------------------------------------------------------
        // CASO 5: Flanco parcial al borde de gate_en no se cuenta
        // Se sube fx_in justo cuando gate_en ya bajo - no debe contarse.
        // ------------------------------------------------------------
        $display("\n[CASO 5] Flanco fuera de la ventana no se cuenta");
        cnt_reset = 1;
        fx_in     = 0;
        @(posedge clk);
        #1;
        cnt_reset = 0;
        gate_en   = 1;
        wait_clk(3);
        gate_en   = 0;     // ventana cerrada

        // Ahora generamos un flanco DESPUES de cerrar la ventana
        wait_clk(1);
        fx_in = 1;
        wait_clk(1);
        fx_in = 0;
        wait_clk(2);
        #1;
        check(count_out === 32'd0,
              "flanco_fuera_de_ventana - no incrementa count_out");

        wait_clk(3);

        // ------------------------------------------------------------
        // CASO 6: cnt_reset tiene prioridad sobre el conteo
        // Se intenta contar y resetear en el mismo ciclo: debe ganar el reset.
        // ------------------------------------------------------------
        $display("\n[CASO 6] cnt_reset tiene prioridad sobre conteo");
        cnt_reset = 1;
        fx_in     = 0;
        @(posedge clk);
        #1;
        cnt_reset = 0;
        gate_en   = 1;

        // Generar algunos flancos primero para tener un conteo > 0
        fx_in = 1; wait_clk(1); fx_in = 0; wait_clk(1);
        fx_in = 1; wait_clk(1); fx_in = 0; wait_clk(1);
        #1;
        check(count_out === 32'd2, "conteo_previo_a_reset - count_out == 2");

        // Ahora forzar cnt_reset y fx_in=1 (flanco) en el mismo ciclo
        fx_in     = 1;
        cnt_reset = 1;
        @(posedge clk);
        #1;
        cnt_reset = 0;
        fx_in     = 0;
        #1;
        check(count_out === 32'd0,
              "cnt_reset_prioridad - count_out vuelve a 0 pese a flanco simultaneo");

        gate_en = 0;
        wait_clk(3);

        // ------------------------------------------------------------
        // CASO 7: Varias mediciones consecutivas con reset entre ellas
        // ------------------------------------------------------------
        $display("\n[CASO 7] Mediciones consecutivas independientes");
        begin : caso7
            reg [31:0] measured_a, measured_b;

            run_measurement(5000, 100.0, measured_a); // fx=5MHz, T_gate=50us -> ~250
            wait_clk(5);
            run_measurement(5000, 100.0, measured_b); // misma config, repetir
            $display("       medicion A = %0d, medicion B = %0d (esperado ~250 cada una)",
                       measured_a, measured_b);
            check((measured_a >= 248) && (measured_a <= 252) &&
                  (measured_b >= 248) && (measured_b <= 252),
                  "mediciones_consecutivas - ambas dentro de tolerancia");
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
        #2000000; // 2 ms de tiempo simulado (suficiente para 100us de Caso2)
        $display("  TIMEOUT - testbench no termino a tiempo");
        $finish;
    end

endmodule

`default_nettype wire
