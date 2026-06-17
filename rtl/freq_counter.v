// Módulo     : freq_counter
// Archivo    : rtl/freq_counter.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Cuenta flancos de subida de fx_in mientras gate_en=1.
//              El valor final es N en la ecuación fx = N / T_gate.
//
// Notas de diseño:
//   - fx_in NO está sincronizada con clk. La detección de flanco usa un
//     registro de dos etapas (fx_d1, fx_d2) para detectar la transición
//     0->1 de forma robusta, sin necesidad de sincronizar la señal completa
//     con un CDC dedicado (aquí solo nos interesa el flanco, no el nivel).
//   - Si gate_en baja a mitad de un ciclo de fx_in, ese flanco parcial
//     NO se cuenta (se requiere ver el flanco completo con gate_en=1
//     en el ciclo de clk donde se detecta).
//   - count_valid sube 1 ciclo después de que gate_en baja, indicando que
//     count_out ya contiene el valor final estable de esa ventana.

`default_nettype none
`timescale 1ns/1ps

module freq_counter (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        gate_en,     // '1': contar flancos; '0': detener
    input  wire        cnt_reset,   // pulso: borra el contador (1 ciclo)
    input  wire        fx_in,       // señal de frecuencia digitalizada (post-Schmitt)
    output reg  [31:0] count_out,   // valor actual del contador
    output reg          count_valid // '1' un ciclo despues de que gate_en baja
);

    // Registros de detección de flanco (doble registro, no es CDC formal:
    // solo se usa para detectar la transición 0->1 de fx_in)
    reg fx_d1, fx_d2;

    // Detecta flanco de subida: fx_d1=1 y fx_d2=0 en el ciclo anterior
    wire fx_rising_edge = fx_d1 & ~fx_d2;

    // Registro de gate_en del ciclo anterior, para detectar su flanco de bajada
    reg gate_en_d1;
    wire gate_falling_edge = gate_en_d1 & ~gate_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            fx_d1       <= 1'b0;
            fx_d2       <= 1'b0;
            gate_en_d1  <= 1'b0;
            count_out   <= 32'd0;
            count_valid <= 1'b0;
        end else begin
            // --- Cadena de detección de flanco de fx_in ---
            fx_d1 <= fx_in;
            fx_d2 <= fx_d1;

            // --- Registro de gate_en para detectar su flanco de bajada ---
            gate_en_d1 <= gate_en;

            // --- count_valid: pulso de 1 ciclo tras bajar gate_en ---
            count_valid <= gate_falling_edge;

            // --- Lógica del contador ---
            if (cnt_reset) begin
                // Reset explícito del contador (prioridad sobre conteo)
                count_out <= 32'd0;
            end else if (gate_en && fx_rising_edge) begin
                // Solo cuenta flancos de subida mientras gate_en=1
                count_out <= count_out + 32'd1;
            end
            // Si gate_en=0 y no hay cnt_reset, count_out se mantiene estable
        end
    end

endmodule

`default_nettype wire
