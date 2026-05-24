// =============================================================================
// Proyecto: Contador Binario de 8 bits con PMOD-LED
// Placa:    iCESugar-Nano (Lattice iCE40LP1K-CM36)
// PMOD:     PMOD-LED v1.1 (8 LEDs) en el conector de 2x6
// Reloj:    12 MHz (pin D1)
// Autor:    Miguel
//
// Descripción:
//   Cuenta de 0 a 255 en binario y muestra el valor en los 8 LEDs del módulo
//   PMOD-LED. El bit más significativo (D7) está a la izquierda y el menos
//   significativo (D0) a la derecha — lectura natural de izquierda a derecha.
//
//   Velocidad de conteo:
//   - Se usa un prescaler de 22 bits → LSB cambia a 12MHz/2^22 ≈ 2.86 Hz
//   - Cada LED se apaga/enciende de forma visible
//   - Un ciclo completo (0→255→0) dura ~89 segundos
//   - Para contar más rápido: cambiar [28:21] por [26:19] (~22 Hz)
//   - Para contar más lento: cambiar [28:21] por [30:23] (~0.7 Hz)
// =============================================================================

module counter (
    input  wire clk,        // Reloj 12 MHz (pin D1)
    output wire [7:0] leds  // 8 LEDs del PMOD-LED (activo en alto)
);

    // -------------------------------------------------------------------------
    // Contador de 29 bits
    // Los bits [28:21] forman el valor de 8 bits que se muestra en los LEDs
    //
    // A 12 MHz, los bits [28:21] cambian a:
    //   bit[21] (D0, LSB): 12MHz / 2^22 ≈ 2.86 Hz  → 1 cambio cada 0.35 s
    //   bit[28] (D7, MSB): 12MHz / 2^29 ≈ 0.022 Hz → 1 cambio cada 44.7 s
    // -------------------------------------------------------------------------
    reg [28:0] counter;
    initial counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    // Los 8 bits de display: MSB=counter[28] (D7) ... LSB=counter[21] (D0)
    assign leds = counter[28:21];

endmodule
