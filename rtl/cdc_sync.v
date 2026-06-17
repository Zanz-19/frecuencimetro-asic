// Módulo   : cdc_sync
// Archivo  : rtl/cdc_sync.v
// Proyecto : Frecuencímetro ASIC sky130A
// Autor    : Jose (Zanz-19)
// Fecha    : Junio 2025
// Descripción: Sincronizador de 2 flip-flops para cruce de dominio de reloj.
//              Usado para sincronizar la señal EOC del sar_ctrl (asíncrona
//              respecto a clk_user) al dominio del núcleo digital.
//
// Notas de implementación:
//   - Los dos FFs deben tener atributo (* dont_touch = "true" *) para que
//     Yosys/LibreLane no los fusione, reordene ni optimice.
//   - El MTBF con 2 etapas en sky130 @ 100 MHz es > décadas.
//   - Reset síncrono activo bajo.

`default_nettype none

module cdc_sync #(
    parameter STAGES = 2          // número de etapas FF — mínimo 2
)(
    input  wire clk,              // reloj destino (clk_user de Caravel)
    input  wire rst_n,            // reset síncrono activo bajo
    input  wire async_in,         // señal asíncrona de entrada (eoc de sar_ctrl)
    output wire sync_out          // señal sincronizada al dominio clk
);

    // Cadena de registros de sincronización
    // (* dont_touch = "true" *) evita que el sintetizador los optimice
    (* dont_touch = "true" *) reg [STAGES-1:0] sync_chain;

    always @(posedge clk) begin
        if (!rst_n)
            sync_chain <= {STAGES{1'b0}};
        else
            // Desplaza la señal a través de la cadena:
            // sync_chain[0] captura async_in
            // sync_chain[1] captura sync_chain[0], etc.
            sync_chain <= {sync_chain[STAGES-2:0], async_in};
    end

    // La salida es el último eslabón de la cadena
    assign sync_out = sync_chain[STAGES-1];

endmodule

`default_nettype wire
