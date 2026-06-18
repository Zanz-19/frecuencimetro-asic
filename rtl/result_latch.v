// Módulo     : result_latch
// Archivo    : rtl/result_latch.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Captura y mantiene estable el valor del contador de frecuencia
//              en el momento exacto en que termina una ventana de medición
//              (latch_en = gate_done de gate_timer). Mientras el CPU lee
//              data_out vía Wishbone, freq_counter ya puede estar contando
//              la siguiente ventana sin afectar el valor leído.
//
// Notas de diseño:
//   - data_ready sube en la primera captura y permanece en 1 indefinidamente
//     (no es un pulso): indica que el sistema ya completó al menos una
//     medición y data_out contiene un valor válido para leer en cualquier
//     momento, no solo justo después de la captura.
//   - Un nuevo pulso de latch_en simplemente actualiza data_out con el
//     valor más reciente; data_ready no necesita "rearmarse".
//   - rst_n vuelve a poner data_ready en 0, indicando que aún no hay
//     ninguna medición válida tras el reset.

`default_nettype none
`timescale 1ns/1ps

module result_latch (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        latch_en,    // pulso de captura (= gate_done de gate_timer)
    input  wire [31:0] data_in,     // count_out de freq_counter
    output reg  [31:0] data_out,    // resultado estable para lectura Wishbone
    output reg          data_ready  // '1' desde la primera captura en adelante
);

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out   <= 32'd0;
            data_ready <= 1'b0;
        end else if (latch_en) begin
            data_out   <= data_in;
            data_ready <= 1'b1;
        end
        // Si latch_en=0, data_out y data_ready se mantienen estables
        // (no hay rama 'else' explícita: los registros retienen su valor)
    end

endmodule

`default_nettype wire
