// =============================================================================
// Proyecto: PWM — Control de Brillo del LED
// Placa:    iCESugar-Nano (Lattice iCE40LP1K-CM36)
// Reloj:    12 MHz (pin D1)
// Autor:    Miguel
//
// Descripción:
//   Controla el brillo del LED amarillo (pin B6) mediante PWM
//   (Pulse Width Modulation — Modulación por Ancho de Pulso).
//
//   El LED hace un ciclo de "breathing" (respiración):
//   - Sube gradualmente de apagado a máximo brillo
//   - Baja gradualmente de máximo brillo a apagado
//   - Repite indefinidamente
//
// Concepto PWM:
//   En lugar de encender/apagar el LED lentamente (como en blink),
//   lo encendemos y apagamos MUY rápido (más rápido de lo que el ojo percibe).
//   Controlando cuánto tiempo está encendido vs apagado en cada ciclo
//   (llamado "duty cycle"), controlamos el brillo percibido.
//
//   duty cycle 10% → LED muy tenue
//   duty cycle 50% → LED a mitad de brillo
//   duty cycle 90% → LED casi al máximo
//   duty cycle 100% → LED al máximo
// =============================================================================

module pwm_led (
    input  wire clk,   // Reloj 12 MHz (pin D1)
    output wire led    // LED amarillo (pin B6, activo en alto)
);

    // -------------------------------------------------------------------------
    // Contador PWM de 8 bits (0-255)
    // Frecuencia PWM = 12 MHz / 256 = ~46.875 kHz
    // Muy por encima de lo que el ojo humano puede detectar (~60 Hz)
    // -------------------------------------------------------------------------
    reg [7:0] pwm_counter;

    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1;
    end

    // -------------------------------------------------------------------------
    // Contador de "fase de respiración" — controla qué tan brillante está el LED
    //
    // Usamos un contador de 25 bits que se divide en:
    //   bit 24: indica si estamos subiendo (0) o bajando (1) el brillo
    //   bits [23:16]: valor del duty cycle actual (0-255)
    //
    // A 12 MHz:
    //   El duty cycle avanza 1 paso cada 2^16 ciclos = ~182 Hz (invisible)
    //   Hace un ciclo completo sube-baja en 2^25 ciclos = ~2.8 segundos
    // -------------------------------------------------------------------------
    reg [24:0] breath_counter;

    always @(posedge clk) begin
        breath_counter <= breath_counter + 1;
    end

    // Extraer el duty cycle actual (0-255)
    // Cuando bit 24 = 0: subiendo  → duty = bits[23:16] (0→255)
    // Cuando bit 24 = 1: bajando   → duty = 255 - bits[23:16] (255→0)
    wire [7:0] duty = breath_counter[24]
                    ? ~breath_counter[23:16]   // bajando: invertimos
                    :  breath_counter[23:16];  // subiendo: directo

    // -------------------------------------------------------------------------
    // Comparador PWM
    //
    // El LED se enciende cuando el contador PWM está POR DEBAJO del duty cycle.
    // Ejemplo con duty = 64 (25%):
    //   pwm_counter = 0..63  → led = 1 (encendido)   25% del tiempo
    //   pwm_counter = 64..255 → led = 0 (apagado)    75% del tiempo
    // -------------------------------------------------------------------------
    assign led = (pwm_counter < duty);

endmodule
