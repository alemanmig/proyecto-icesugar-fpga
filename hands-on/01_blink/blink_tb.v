// =============================================================================
// Testbench: blink_tb.v
// Simula el módulo blink y genera un archivo .vcd para visualizar señales
// =============================================================================
// Uso:
//   iverilog -o blink_sim blink_tb.v blink.v
//   vvp blink_sim
//   (abrir blink.vcd en WaveTrace dentro de VS Code)
// =============================================================================

`timescale 1ns / 1ps   // unidad de tiempo = 1ns, precisión = 1ps

module blink_tb;

    // --- Señales del testbench ---
    reg  clk;   // Reloj generado por el testbench
    wire led;   // Salida LED amarillo (observamos esta señal)

    // --- Instanciar el módulo bajo prueba (DUT) ---
    blink uut (
        .clk (clk),
        .led (led)
    );

    // --- Generador de reloj: 12 MHz ---
    // Período = 1/12MHz ≈ 83.33 ns → mitad = 41.67 ns ≈ 42 ns
    initial clk = 0;
    always #42 clk = ~clk;

    // --- Simulación acelerada ---
    // counter[23] necesita 2^23 = 8 millones de ciclos para cambiar desde 0.
    // Simular eso tomaría minutos. La técnica estándar es arrancar el contador
    // justo antes de la transición de interés.
    //
    // 24'h7FFFF0 = 0111_1111_1111_1111_1111_0000
    //              ↑ bit23=0 (led apagado)
    //              Faltan solo 16 ciclos para que bit23 pase a 1.
    //
    // Luego simulamos ~600 ciclos para ver: apagado → encendido → apagado
    //   (la segunda transición 1→0 ocurre otros 2^23 ciclos después, demasiado
    //    lejos, así que pre-cargamos también esa transición en el segundo bloque)
    initial begin
        $dumpfile("blink.vcd");
        $dumpvars(0, blink_tb);

        // --- Segmento 1: transición 0 → 1 del LED ---
        // Arrancamos con counter justo antes de que bit23 se ponga en 1
        uut.counter = 24'h7FFFF0;   // bit23=0, faltan 16 ciclos para cambiar
        #(42 * 2 * 40);             // simular 40 ciclos: veremos led ir de 0 a 1

        // --- Segmento 2: transición 1 → 0 del LED ---
        // Cargamos el contador cerca de la siguiente transición (bit23 vuelve a 0)
        uut.counter = 24'hFFFFF0;   // bit23=1, faltan 16 ciclos para que desborde
        #(42 * 2 * 40);             // simular 40 ciclos: veremos led ir de 1 a 0

        $display("Simulación completada.");
        $display("  Valor final de counter = %h", uut.counter);
        $display("  led = %b (1=encendido, 0=apagado)", led);
        $finish;
    end

endmodule
