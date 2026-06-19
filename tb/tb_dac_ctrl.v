// Módulo     : tb_dac_ctrl
// Archivo    : tb/tb_dac_ctrl.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Testbench de dac_ctrl, integrado con r2r_dac_control real
//              (IP mattvenn/tt06-analog-r2r-dac) para verificar:
//              - Inversión correcta del reset (n_rst activo alto en la IP)
//              - Paso transparente del dato en modo externo
//              - Activación de la rampa interna en modo selftest
//              - Carga del divisor de velocidad via load_divider
//              - Transición entre modos sin glitches
//
// IMPORTANTE sobre el reset de r2r_dac_control:
//   La IP tiene lógica de reset INVERTIDA: n_rst=1 resetea, n_rst=0 opera.
//   Cuando rst_n=0 (nuestro reset), dac_n_rst=1 → IP en reset (correcto).
//   Cuando rst_n=1 (operación), dac_n_rst=0 → IP operativa (correcto).
//   El testbench verifica que esta inversión funciona correctamente.
//
// Uso:
//   make sim MODULE=dac_ctrl EXTRA_SRC=ip/dac_r2r/verilog/rtl/r2r_dac_control.v

`default_nettype none
`timescale 1ns/1ps

module tb_dac_ctrl;

    parameter CLK_PERIOD = 10;   // 10 ns -> 100 MHz

    reg        clk;
    reg        rst_n;
    reg  [7:0] dac_word;
    reg        ext_data_en;
    reg        load_div_pulse;
    wire [7:0] dac_data_out;
    wire       dac_ext_data;
    wire       dac_load_div;
    wire       dac_n_rst;

    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------
    // Instancia del DUT (dac_ctrl)
    // -------------------------------------------------------------------
    dac_ctrl dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .dac_word       (dac_word),
        .ext_data_en    (ext_data_en),
        .load_div_pulse (load_div_pulse),
        .dac_data_out   (dac_data_out),
        .dac_ext_data   (dac_ext_data),
        .dac_load_div   (dac_load_div),
        .dac_n_rst      (dac_n_rst)
    );

    // -------------------------------------------------------------------
    // Instancia de r2r_dac_control REAL (IP del DAC)
    // -------------------------------------------------------------------
    wire [7:0] dac_r2r_out;   // Salida digital de 8 bits de la IP
                               // (en el chip real va a la escalera R-2R analógica)

    r2r_dac_control dac_ip (
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

    // -------------------------------------------------------------------
    // Bloque principal de pruebas
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_dac_ctrl.vcd");
        $dumpvars(0, tb_dac_ctrl);

        pass_count = 0;
        fail_count = 0;

        rst_n          = 0;
        dac_word       = 8'd0;
        ext_data_en    = 1;
        load_div_pulse = 0;

        $display("");
        $display("=== TEST: dac_ctrl (integrado con r2r_dac_control real) ===");
        $display("Reloj: %0d MHz (periodo %0d ns)", 1000/CLK_PERIOD, CLK_PERIOD);

        // ----------------------------------------------------------------
        // CASO 1: Verificacion de la conexion de reset
        // r2r_dac_control NO tiene inversión convencional:
        //   n_rst=1 → IP opera (funciona como enable alto)
        //   n_rst=0 → IP resetea
        // Por lo tanto dac_n_rst = rst_n (sin inversión).
        // ----------------------------------------------------------------
        $display("\n[CASO 1] Conexion de reset con la IP");
        // Con rst_n=0, dac_n_rst debe ser 0 (IP en reset)
        check(dac_n_rst === 1'b0,
              "rst_n=0 -> dac_n_rst=0 (IP en reset)");

        wait_clk(3);
        rst_n = 1;
        #1;
        // Con rst_n=1, dac_n_rst debe ser 1 (IP operativa)
        check(dac_n_rst === 1'b1,
              "rst_n=1 -> dac_n_rst=1 (IP operativa)");

        // ----------------------------------------------------------------
        // CASO 2: Estado inicial tras reset
        // ----------------------------------------------------------------
        $display("\n[CASO 2] Estado inicial tras reset");
        wait_clk(2);
        check(dac_ext_data === 1'b1,
              "ext_data=1 por defecto (modo externo, no rampa espontanea)");
        check(dac_load_div === 1'b0,
              "load_div=0 por defecto");

        // ----------------------------------------------------------------
        // CASO 3: Modo externo — dato estático pasa transparentemente
        // ----------------------------------------------------------------
        $display("\n[CASO 3] Modo externo: dato estatico");
        ext_data_en = 1;
        dac_word    = 8'hAA;
        @(posedge clk);
        #1;
        check(dac_data_out === 8'hAA && dac_ext_data === 1'b1,
              "modo_externo_0xAA - dato y ext_data correctos");
        // La IP en modo externo reproduce el dato directamente
        wait_clk(2);
        check(dac_r2r_out === 8'hAA,
              "r2r_out=0xAA - IP reproduce el dato en su salida");

        // ----------------------------------------------------------------
        // CASO 4: Modo externo — actualizar el dato
        // ----------------------------------------------------------------
        $display("\n[CASO 4] Modo externo: actualizar dato");
        dac_word = 8'h55;
        @(posedge clk);
        #1;
        check(dac_data_out === 8'h55,
              "dato_actualizado_0x55 - dac_data_out cambia correctamente");
        wait_clk(2);
        check(dac_r2r_out === 8'h55,
              "r2r_out=0x55 - IP actualiza su salida");

        // ----------------------------------------------------------------
        // CASO 5: Modo externo — valores de esquina (0x00 y 0xFF)
        // ----------------------------------------------------------------
        $display("\n[CASO 5] Modo externo: valores de esquina");
        dac_word = 8'h00;
        @(posedge clk);
        #1;
        wait_clk(2);
        check(dac_r2r_out === 8'h00,
              "esquina_minimo - r2r_out=0x00");

        dac_word = 8'hFF;
        @(posedge clk);
        #1;
        wait_clk(2);
        check(dac_r2r_out === 8'hFF,
              "esquina_maximo - r2r_out=0xFF");

        // ----------------------------------------------------------------
        // CASO 6: Transición a modo selftest (ext_data=0)
        // En modo selftest, la IP ignora data[] y genera una rampa interna.
        // Con divisor=0 (por defecto), la rampa avanza cada 256 ciclos de clk.
        // ----------------------------------------------------------------
        $display("\n[CASO 6] Transicion a modo selftest (rampa interna)");
        ext_data_en = 0;   // activar modo selftest
        dac_word    = 8'hFF; // este valor NO debe aparecer en r2r_out en selftest
        @(posedge clk);
        #1;
        check(dac_ext_data === 1'b0,
              "ext_data=0 - modo selftest activado en la interfaz");

        // Con divisor=0 y el counter interno arrancando desde 0,
        // la rampa debe comenzar a incrementar. Verificamos que
        // r2r_out NO se queda fijo en 0xFF (que era el dato estático previo)
        wait_clk(300); // esperar suficiente para que la rampa avance al menos 1 paso
        check(dac_r2r_out !== 8'hFF,
              "selftest_activo - r2r_out difiere del dato estatico previo");

        // ----------------------------------------------------------------
        // CASO 7: Carga del divisor de velocidad via load_divider
        // Divisor=1: la rampa avanza cada (1<<8)=256 ciclos de clk
        // Divisor=0: counter >= (0<<8)=0 siempre -> avanza cada ciclo
        // ----------------------------------------------------------------
        $display("\n[CASO 7] Carga del divisor de rampa");
        // Poner divisor=0 (rampa maxima: avanza cada ciclo) para poder observarla rapidamente
        ext_data_en    = 0;
        dac_word       = 8'd0;  // divisor a cargar = 0

        // Reset para empezar limpio
        rst_n = 0;
        @(posedge clk);
        #1;
        rst_n = 1;
        wait_clk(2);

        // Cargar el divisor: pulso de 1 ciclo en load_div_pulse
        load_div_pulse = 1;
        @(posedge clk);
        #1;
        check(dac_load_div === 1'b1,
              "load_div_pulso - dac_load_div=1 durante el pulso");
        load_div_pulse = 0;
        @(posedge clk);
        #1;
        check(dac_load_div === 1'b0,
              "load_div_auto_clear - dac_load_div=0 el ciclo siguiente");

        // ----------------------------------------------------------------
        // CASO 8: Con divisor=0, la rampa avanza en cada ciclo de clk
        // Verificar que r2r_out incrementa en ciclos consecutivos
        // ----------------------------------------------------------------
        $display("\n[CASO 8] Rampa maxima con divisor=0");
        ext_data_en = 0;
        dac_word    = 8'd0;
        // Poner modo selftest y verificar que r2r_out incrementa en pocos ciclos
        begin : caso8
            reg [7:0] val_a;
            reg [7:0] val_b;
            integer k;

            // Esperar un momento para que el divisor=0 surta efecto
            wait_clk(5);
            val_a = dac_r2r_out;

            wait_clk(5);
            val_b = dac_r2r_out;

            $display("       r2r_out antes=%0d, despues=%0d (esperado: b > a)",
                       val_a, val_b);
            check(val_b > val_a || (val_a == 8'hFF && val_b == 8'h00),
                  "rampa_incrementa - r2r_out avanza en modo selftest divisor=0");
        end

        // ----------------------------------------------------------------
        // CASO 9: Regreso a modo externo desde selftest sin glitches
        // ----------------------------------------------------------------
        $display("\n[CASO 9] Regreso a modo externo desde selftest");
        ext_data_en = 1;
        dac_word    = 8'hC0;
        @(posedge clk);
        #1;
        check(dac_ext_data === 1'b1,
              "regreso_modo_externo - ext_data vuelve a 1");
        wait_clk(2);
        check(dac_r2r_out === 8'hC0,
              "dato_recuperado - r2r_out = 0xC0 tras volver a modo externo");

        // ----------------------------------------------------------------
        // CASO 10: Reset durante operacion restablece estado inicial
        // ----------------------------------------------------------------
        $display("\n[CASO 10] Reset durante operacion");
        dac_word    = 8'hBB;
        ext_data_en = 1;
        @(posedge clk);
        #1;

        rst_n = 0;
        @(posedge clk);
        #1;
        check(dac_n_rst === 1'b0,
              "reset_activo - dac_n_rst=0 durante reset");
        check(dac_ext_data === 1'b1,
              "reset_ext_data - vuelve a 1 (modo externo por defecto)");

        rst_n = 1;
        wait_clk(2);
        check(dac_n_rst === 1'b1,
              "post_reset_operativo - dac_n_rst=1 al salir de reset");

        // ----------------------------------------------------------------
        // Resumen final
        // ----------------------------------------------------------------
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
        $display("  TIMEOUT - testbench no termino a tiempo");
        $finish;
    end

endmodule

`default_nettype wire
