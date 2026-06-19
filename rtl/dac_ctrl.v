// Módulo     : dac_ctrl
// Archivo    : rtl/dac_ctrl.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Interfaz entre el bus Wishbone (vía wb_regs) y el módulo
//              r2r_dac_control de la IP del DAC R-2R 8 bits
//              (mattvenn/tt06-analog-r2r-dac).
//
// Modos de operación:
//   - Modo externo   (ext_data_en=1): dac_data_out = dac_word (valor del CPU).
//                    La IP reproduce ese valor estático en su salida analógica.
//   - Modo selftest  (ext_data_en=0): la IP genera internamente una rampa
//                    sawtooth automática. La velocidad de la rampa se configura
//                    cargando un divisor via load_divider_pulse.
//
// Notas críticas de diseño:
//   [1] SEMANTICA DE RESET DE LA IP: r2r_dac_control tiene lógica de reset
//       no convencional. Su señal n_rst funciona como un "enable":
//         n_rst=1 → IP opera (ext_data o rampa interna activa)
//         n_rst=0 → IP resetea r2r_out y counter a 0
//       Esto COINCIDE con nuestro rst_n:
//         rst_n=1 (operando) → dac_n_rst=1 (IP opera) ✓
//         rst_n=0 (en reset) → dac_n_rst=0 (IP resetea) ✓
//       Por lo tanto: dac_n_rst = rst_n  (sin inversión)
//
//       NOTA: El código fuente de la IP tiene un always asíncrono que pone
//       rst_interno=0 cuando n_rst=1, y rst_interno=1 cuando n_rst=0. El
//       always del counter usa if(rst_interno) para RESETEAR, lo que hace
//       que la lógica parezca invertida pero en realidad es equivalente a
//       un enable activo alto cuando visto desde el pin n_rst.
//
//   [2] FRECUENCIA DE RELOJ: El comentario en r2r_dac_control.v dice
//       "expect a 10M clock". Conectar el DAC a una señal de reloj dividida
//       si clk_user es 100 MHz, o verificar que la lógica del divisor interno
//       funciona correctamente a 100 MHz. Este módulo pasa clk transparentemente
//       para que freq_top.v maneje la división si es necesaria.
//
//   [3] load_divider_pulse: debe ser un pulso de exactamente 1 ciclo. Este
//       módulo genera el pulso automáticamente cuando wb_regs escribe el bit
//       load_div en el registro CTRL. El pulso se auto-limpia en 1 ciclo.
//
// Tabla de frecuencias de rampa (ext_data=0, clk=10 MHz recomendado):
//   divisor=0   → ~39 kHz (máxima, el contador satura inmediatamente)
//   divisor=10  → ~3.9 kHz
//   divisor=100 → ~390 Hz
//   divisor=255 → ~153 Hz

`default_nettype none
`timescale 1ns/1ps

module dac_ctrl (
    input  wire       clk,
    input  wire       rst_n,          // reset síncrono activo bajo (NUESTRO diseño)

    // Interfaz con wb_regs (escritas por el CPU via Wishbone)
    input  wire [7:0] dac_word,       // dato de 8 bits para modo externo
    input  wire       ext_data_en,    // 1=modo externo, 0=rampa interna (selftest)
    input  wire       load_div_pulse, // pulso de 1 ciclo: carga dac_word como
                                      // divisor de velocidad de la rampa interna

    // Salidas hacia la IP r2r_dac_control
    output reg  [7:0] dac_data_out,   // → data[7:0] de r2r_dac_control
    output reg        dac_ext_data,   // → ext_data de r2r_dac_control
    output reg        dac_load_div,   // → load_divider de r2r_dac_control
    output wire       dac_n_rst       // → n_rst de r2r_dac_control
                                      // ⚠️ ACTIVO ALTO en la IP — invertido aquí
);

    // Conexión de reset hacia la IP r2r_dac_control:
    // La IP tiene lógica de reset no convencional:
    //   n_rst=1 → rst interno=0 → IP opera (ext_data o rampa)
    //   n_rst=0 → rst interno=1 → IP resetea r2r_out y counter a 0
    //
    // Esto significa que n_rst funciona como "enable" (1=activo, 0=reset).
    // Coincide con nuestro rst_n: rst_n=1 (operar) → dac_n_rst=1 (IP opera).
    // NO es necesaria inversión: dac_n_rst = rst_n directamente.
    assign dac_n_rst = rst_n;

    always @(posedge clk) begin
        if (!rst_n) begin
            dac_data_out <= 8'd0;
            dac_ext_data <= 1'b1;   // modo externo por defecto tras reset
                                     // (evita que la rampa selftest arranque sola)
            dac_load_div <= 1'b0;
        end else begin
            // Pasar directamente el modo de operación elegido por el CPU
            dac_ext_data <= ext_data_en;

            // Dato al DAC: siempre refleja dac_word
            // En modo externo (ext_data_en=1): la IP usa este valor como salida
            // En modo selftest (ext_data_en=0): la IP ignora data[7:0] para
            // la rampa, pero si load_divider sube, carga data[7:0] como divisor
            dac_data_out <= dac_word;

            // load_divider: pulso de 1 ciclo que viene de wb_regs
            // load_div_pulse ya dura exactamente 1 ciclo (lo genera wb_regs)
            dac_load_div <= load_div_pulse;
        end
    end

endmodule

`default_nettype wire
