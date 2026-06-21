// Módulo     : adc_ctrl
// Archivo    : rtl/adc_ctrl.v
// Proyecto   : Frecuencímetro ASIC sky130A
// Autor      : Jose (Zanz-19)
// Fecha      : Junio 2025
// Descripción: Orquesta el protocolo de conversión de sar_ctrl (IP del ADC SAR
//              12 bits, chipfoundry/sky130_ef_ip__adc3v_12bit). Genera el pulso
//              de soc (Start Of Conversion), espera eoc_sync (ya sincronizado
//              por cdc_sync), y captura el resultado de 12 bits.
//
// Referencia de timing verificada empíricamente sobre sar_ctrl.v real:
//   ciclos_soc_a_eoc = 15 + swidth   (con SIZE=12, confirmado en simulación)
//   swidth=0  -> 15 ciclos
//   swidth=5  -> 20 ciclos
//   swidth=15 -> 30 ciclos
//
// Notas de diseño:
//   - eoc_sync proviene de cdc_sync (Fase 2, ya verificado), por lo que aquí
//     se asume ya libre de metaestabilidad.
//   - adc_data_raw proviene directamente de sar_ctrl.data[11:0]; es estable
//     y válido en el mismo ciclo donde eoc_sync sube (sar_ctrl mantiene
//     'result' congelado durante el estado DONE).
//   - En modo continuous_en=1, tras capturar el resultado se vuelve a
//     disparar soc automáticamente sin esperar a adc_trigger.
//   - En modo single-shot (continuous_en=0), cada conversión requiere un
//     nuevo pulso de adc_trigger.

`default_nettype none
`timescale 1ns/1ps

module adc_ctrl (
    input  wire        clk,            // clk_user de Caravel
    input  wire        rst_n,          // reset síncrono activo bajo
    // Interfaz con cdc_sync (eoc ya sincronizado)
    input  wire        eoc_sync,
    // Interfaz directa con sar_ctrl de la IP del ADC
    input  wire [11:0] adc_data_raw,   // sar_ctrl.data[11:0]
    output reg          adc_soc,       // → sar_ctrl.soc (pulso de 1 ciclo)
    output reg          adc_en,        // → sar_ctrl.en
    output wire [3:0]  adc_swidth_out, // → sar_ctrl.swidth (pass-through directo)
    // Interfaz con wb_regs
    output reg  [11:0] adc_result,
    output reg          adc_ready,     // '1' tras la primera conversión completa
    // Configuración
    input  wire         continuous_en, // '1' = muestreo continuo
    input  wire         adc_trigger,   // pulso externo para single-shot
    input  wire [3:0]  adc_swidth_in  // ← wb_regs.adc_swidth
);

    // swidth es configuración estática del CPU: se pasa directamente a
    // sar_ctrl sin necesidad de registrarla en este módulo (sar_ctrl ya
    // la usa de forma combinacional en su propia FSM interna).
    assign adc_swidth_out = adc_swidth_in;

    // Estados de la FSM de control
    localparam S_IDLE      = 2'b00;
    localparam S_SOC_PULSE = 2'b01;
    localparam S_WAIT_EOC  = 2'b10;
    localparam S_CAPTURE   = 2'b11;

    reg [1:0] state;

    // Registro de eoc_sync del ciclo anterior, para detectar su flanco de subida
    // (sar_ctrl mantiene eoc=1 solo durante 1 ciclo, pero detectamos el flanco
    // por robustez ante posibles variaciones de la IP)
    reg eoc_sync_d1;
    wire eoc_rising = eoc_sync & ~eoc_sync_d1;

    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            adc_soc      <= 1'b0;
            adc_en       <= 1'b0;
            adc_result   <= 12'd0;
            adc_ready    <= 1'b0;
            eoc_sync_d1  <= 1'b0;
        end else begin
            eoc_sync_d1 <= eoc_sync;
            adc_en      <= 1'b1; // habilitado permanentemente tras salir de reset

            case (state)
                S_IDLE: begin
                    adc_soc <= 1'b0;
                    if (continuous_en || adc_trigger) begin
                        state <= S_SOC_PULSE;
                    end
                end

                S_SOC_PULSE: begin
                    // Pulso de 1 ciclo: sar_ctrl ve soc=1 exactamente en este ciclo
                    adc_soc <= 1'b1;
                    state   <= S_WAIT_EOC;
                end

                S_WAIT_EOC: begin
                    adc_soc <= 1'b0;
                    if (eoc_rising) begin
                        state <= S_CAPTURE;
                    end
                end

                S_CAPTURE: begin
                    // HALLAZGO CRÍTICO (Fase 2, integración con sar_ctrl real a
                    // través de cdc_sync): sar_ctrl.data (y por tanto adc_data_raw)
                    // solo es válido durante el único ciclo en que sar_ctrl está en
                    // estado DONE; en el ciclo siguiente sar_ctrl ya volvió a IDLE
                    // y puso result<=0. Como cdc_sync introduce 2 ciclos de latencia
                    // en eoc_sync, para cuando eoc_rising se detecta AQUÍ, el dato
                    // crudo de sar_ctrl.data ya decayó — capturar adc_data_raw en
                    // este punto (o en S_WAIT_EOC) siempre lee 0, sin importar el
                    // orden de los estados de esta FSM.
                    //
                    // La solución correcta NO es mover esta asignación: es que el
                    // dato crudo se capture en un registro dedicado en freq_top.v
                    // (adc_data_latch), disparado directamente por adc_eoc SIN
                    // pasar por cdc_sync, ya que es un registro de datos (no de
                    // control) y por tanto tolera el riesgo de metaestabilidad
                    // mucho mejor que un pulso de control de 1 ciclo. adc_ctrl
                    // simplemente lee ese registro ya estable cuando eoc_sync
                    // (la notificación, sincronizada) confirma que hay dato nuevo.
                    adc_result <= adc_data_raw;
                    adc_ready  <= 1'b1;
                    if (continuous_en) begin
                        // Encadenar automáticamente la siguiente conversión
                        state <= S_SOC_PULSE;
                    end else begin
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
