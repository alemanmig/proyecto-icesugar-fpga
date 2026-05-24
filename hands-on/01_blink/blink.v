// =============================================================================
// Proyecto: LED Parpadeante (Blink)
// Placa:    iCESugar-Nano (Lattice iCE40LP1K-CM36)
// Reloj:    12 MHz (provisto por iCELink en pin D1)
// LED:      Amarillo integrado en pin B6 (activo en alto: 1 = encendido)
// Autor:    Miguel
// Descripción:
//   Divide el reloj de 12MHz usando un contador de 24 bits.
//   El bit [23] del contador cambia a ~0.71 Hz, haciendo que el LED
//   parpadee con un período de ~1.4 segundos (visible a simple vista).
//
//   Frecuencia de parpadeo = 12,000,000 / 2^24 ≈ 0.71 Hz
// =============================================================================

module blink (
    input  wire clk,   // Reloj de entrada: 12 MHz (pin D1)
    output wire led    // LED amarillo (pin B6, activo en alto)
);

    // Contador de 24 bits
    // A 12 MHz, el bit [23] cambia cada 2^23 / 12e6 ≈ 0.7 segundos
    reg [23:0] counter;

    // Valor inicial para simulación (en hardware el FPGA arranca en 0 automáticamente)
    // Sin esto, el simulador deja counter en X (desconocido) y led aparece en rojo
    initial counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    // LED activo en alto (1 = encendido, 0 = apagado)
    assign led = counter[23];

endmodule
