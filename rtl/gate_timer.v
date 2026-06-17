// Módulo     : gate_timer
// Archivo    : rtl/gate_timer.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Genera la ventana de medición (gate_en) con duración exacta de
//              gate_cycles ciclos de reloj. T_gate = gate_cycles / f_clk.
//              Configurable en tiempo de ejecución desde Wishbone (vía wb_regs).
//
// Referencia de valores (clk_user = 100 MHz):
//   gate_cycles = 100_000      -> T_gate = 1 ms   -> resolución 1 kHz
//   gate_cycles = 10_000_000   -> T_gate = 100 ms  -> resolución 10 Hz
//   gate_cycles = 100_000_000  -> T_gate = 1 s     -> resolución 1 Hz
//
// Comportamiento:
//   - En reset: gate_en=0, gate_done=0, contador en 0.
//   - Al recibir 'start' (estando inactivo): arranca la cuenta regresiva.
//   - Durante la cuenta: gate_en=1.
//   - Al llegar a 0: gate_en baja, gate_done sube 1 ciclo, luego vuelve a 0.
//   - 'start' mientras gate_en=1 se ignora (no reinicia el timer).

`default_nettype none
`timescale 1ns/1ps

module gate_timer (
    input  wire        clk,         // clk_user de Caravel
    input  wire        rst_n,       // reset síncrono activo bajo
    input  wire        start,       // pulso de inicio de ciclo de medición
    input  wire [26:0] gate_cycles, // duración de T_gate en ciclos de clk
    output reg          gate_en,    // '1' durante la ventana activa
    output reg          gate_done   // pulso de 1 ciclo al finalizar la ventana
);

    // Estados de la FSM interna
    localparam S_IDLE    = 1'b0;
    localparam S_RUNNING = 1'b1;

    reg        state;
    reg [26:0] count;

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            count     <= 27'd0;
            gate_en   <= 1'b0;
            gate_done <= 1'b0;
        end else begin
            // gate_done es un pulso de 1 ciclo: por defecto baja cada ciclo
            gate_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    gate_en <= 1'b0;
                    if (start && gate_cycles != 27'd0) begin
                        // Inicia la ventana: carga el contador y activa gate_en
                        count   <= gate_cycles - 27'd1;
                        gate_en <= 1'b1;
                        state   <= S_RUNNING;
                    end
                    // start con gate_cycles=0 se ignora (configuración inválida)
                end

                S_RUNNING: begin
                    gate_en <= 1'b1;
                    if (count == 27'd0) begin
                        // Fin de la ventana
                        gate_en   <= 1'b0;
                        gate_done <= 1'b1;
                        state     <= S_IDLE;
                    end else begin
                        count <= count - 27'd1;
                    end
                    // 'start' es ignorado mientras S_RUNNING (no reinicia)
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
