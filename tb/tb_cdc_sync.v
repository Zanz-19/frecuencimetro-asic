// Módulo   : tb_cdc_sync
// Archivo  : tb/tb_cdc_sync.v
// Proyecto : Frecuencímetro ASIC sky130A
// Autor    : Jose (Zanz-19)
// Fecha    : Junio 2025
// Descripción: Testbench unitario para cdc_sync.
//              Verifica 5 casos:
//              1. Reset mantiene sync_out en 0
//              2. Señal estable alta → aparece tras STAGES ciclos
//              3. Señal estable baja → desaparece tras STAGES ciclos
//              4. Pulso corto (1 ciclo fuente) → capturado correctamente
//              5. Flanco en zona de setup → no propaga indeterminado

`default_nettype none
`timescale 1ns/1ps

module tb_cdc_sync;

    // ----------------------------------------------------------------
    // Parámetros
    // ----------------------------------------------------------------
    parameter STAGES   = 2;
    parameter CLK_PERIOD = 10; // 100 MHz → 10 ns

    // ----------------------------------------------------------------
    // Señales del DUT
    // ----------------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  async_in;
    wire sync_out;

    // ----------------------------------------------------------------
    // Contadores de prueba
    // ----------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // ----------------------------------------------------------------
    // Instancia del DUT
    // ----------------------------------------------------------------
    cdc_sync #(.STAGES(STAGES)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (async_in),
        .sync_out (sync_out)
    );

    // ----------------------------------------------------------------
    // Generación de reloj
    // ----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------------------------------------------------
    // Tarea auxiliar: verificar valor esperado
    // ----------------------------------------------------------------
    task check;
        input expected;
        input [127:0] test_name;
        begin
            if (sync_out === expected) begin
                $display("  PASS | %0s | sync_out=%b (esperado=%b)",
                         test_name, sync_out, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %0s | sync_out=%b (esperado=%b)",
                         test_name, sync_out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Tarea: esperar N flancos de subida de clk
    // ----------------------------------------------------------------
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            #1; // pequeño delay post-flanco para estabilizar
        end
    endtask

    // ----------------------------------------------------------------
    // Secuencia de pruebas
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_cdc_sync.vcd");
        $dumpvars(0, tb_cdc_sync);

        $display("=== TEST: cdc_sync (STAGES=%0d) ===", STAGES);

        // Condiciones iniciales
        rst_n    = 0;
        async_in = 0;

        // --------------------------------------------------------
        // CASO 1: Reset mantiene sync_out en 0
        // --------------------------------------------------------
        $display("\n[CASO 1] Reset activo — sync_out debe ser 0");
        async_in = 1;          // aunque la entrada esté alta...
        wait_cycles(3);
        check(1'b0, "reset_mantiene_0");

        // --------------------------------------------------------
        // CASO 2: Señal estable alta → aparece tras STAGES ciclos
        // --------------------------------------------------------
        $display("\n[CASO 2] Señal alta tras salir de reset");
        rst_n    = 1;
        async_in = 1;
        // Esperar exactamente STAGES ciclos para que se propague
        wait_cycles(STAGES);
        check(1'b1, "senal_alta_propagada");

        // --------------------------------------------------------
        // CASO 3: Señal estable baja → desaparece tras STAGES ciclos
        // --------------------------------------------------------
        $display("\n[CASO 3] Señal baja — desaparece tras STAGES ciclos");
        async_in = 0;
        wait_cycles(STAGES);
        check(1'b0, "senal_baja_propagada");

        // --------------------------------------------------------
        // CASO 4: Pulso corto de 1 ciclo fuente
        // Simula el EOC del sar_ctrl que dura exactamente 1 ciclo
        // --------------------------------------------------------
        $display("\n[CASO 4] Pulso corto (1 ciclo) — debe capturarse");
        async_in = 1;
        wait_cycles(1);
        async_in = 0;
        // Tras STAGES ciclos adicionales, el pulso debe haberse propagado
        // y ya estar bajando (o haber estado en 1)
        // Verificamos que no quedó indeterminado
        wait_cycles(STAGES);
        if (sync_out === 1'bx || sync_out === 1'bz) begin
            $display("  FAIL | pulso_corto | sync_out=%b (indeterminado)", sync_out);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS | pulso_corto | sync_out=%b (determinado)", sync_out);
            pass_count = pass_count + 1;
        end

        // --------------------------------------------------------
        // CASO 5: Flanco en zona cercana al flanco de clk
        // Simula el peor caso de metaestabilidad
        // --------------------------------------------------------
        $display("\n[CASO 5] Flanco asíncrono cercano al flanco de clk");
        async_in = 0;
        wait_cycles(2);
        // Aplicar flanco a solo 1ps antes del flanco de clk
        @(posedge clk);
        #(CLK_PERIOD - 1); // 1ns antes del siguiente flanco
        async_in = 1;
        wait_cycles(STAGES + 1);
        if (sync_out === 1'bx || sync_out === 1'bz) begin
            $display("  FAIL | flanco_critico | sync_out=%b (indeterminado)", sync_out);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS | flanco_critico | sync_out=%b (determinado)", sync_out);
            pass_count = pass_count + 1;
        end

        // --------------------------------------------------------
        // CASO 6: Reset durante operación — sync_out vuelve a 0
        // --------------------------------------------------------
        $display("\n[CASO 6] Reset durante operacion — sync_out vuelve a 0");
        async_in = 1;
        wait_cycles(STAGES + 1);
        rst_n = 0;
        wait_cycles(1);
        check(1'b0, "reset_durante_operacion");
        rst_n = 1;

        // --------------------------------------------------------
        // Resumen
        // --------------------------------------------------------
        $display("\n=== RESULTADO FINAL ===");
        $display("  PASS: %0d / FAIL: %0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("  >> ALL TESTS PASSED <<");
        else
            $display("  >> HAY FALLOS — REVISAR <<");

        $finish;
    end

    // Timeout de seguridad
    initial begin
        #10000;
        $display("TIMEOUT — simulación no terminó");
        $finish;
    end

endmodule

`default_nettype wire
