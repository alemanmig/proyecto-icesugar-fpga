// =============================================================================
// Testbench: counter_tb.v
// Simula el módulo counter y genera un .vcd para visualizar en WaveTrace
// =============================================================================
// Uso:
//   iverilog -o counter_sim counter_tb.v counter.v
//   vvp counter_sim
//   (abrir counter.vcd en WaveTrace dentro de VS Code)
// =============================================================================

`timescale 1ns / 1ps

module counter_tb;

    // --- Señales ---
    reg        clk;
    wire [7:0] leds;

    // --- Instanciar el módulo bajo prueba ---
    counter uut (
        .clk  (clk),
        .leds (leds)
    );

    // --- Reloj 12 MHz: período = 83.33 ns → mitad ≈ 42 ns ---
    initial clk = 0;
    always #42 clk = ~clk;

    // --- Simulación por segmentos ---
    // leds = uut.counter[28:21], así que cada transición de leds requiere
    // 2^21 = 2,097,152 ciclos desde 0. Cargamos el contador justo antes
    // de cada transición de interés para ver el cambio en pocos ciclos.
    //
    // Transición leds N→N+1: ocurre cuando counter alcanza N * 2^21
    // Pre-carga: (N * 2^21) - 16  para ver el cambio en ~16 ciclos

    initial begin
        $dumpfile("counter.vcd");
        $dumpvars(0, counter_tb);

        // ---------------------------------------------------------------
        // Segmento 1: estado inicial — leds debe valer 0
        // ---------------------------------------------------------------
        uut.counter = 29'h0;
        #(42 * 2 * 20);
        $display("[t=%0t] Inicial:       leds = %08b (%3d)", $time, leds, leds);

        // ---------------------------------------------------------------
        // Segmento 2: transición leds 0 → 1
        // Ocurre cuando counter[21] sube por primera vez (counter = 2^21)
        // Pre-carga a 2^21 - 16 = 0x01FFFF0
        // ---------------------------------------------------------------
        uut.counter = 29'h01FFFF0;
        #(42 * 2 * 40);
        $display("[t=%0t] Tras 0→1:     leds = %08b (%3d)", $time, leds, leds);

        // ---------------------------------------------------------------
        // Segmento 3: transición leds 1 → 2
        // Ocurre en counter = 2 * 2^21 = 2^22
        // Pre-carga a 2^22 - 16 = 0x03FFFF0
        // ---------------------------------------------------------------
        uut.counter = 29'h03FFFF0;
        #(42 * 2 * 40);
        $display("[t=%0t] Tras 1→2:     leds = %08b (%3d)", $time, leds, leds);

        // ---------------------------------------------------------------
        // Segmento 4: transición leds 127 → 128
        // Es el momento más dramático: D7 (MSB) se enciende por primera vez
        // y todos los demás se apagan. Ocurre en counter = 128 * 2^21 = 2^28
        // Pre-carga a 2^28 - 16 = 0x0FFFFFF0
        // ---------------------------------------------------------------
        uut.counter = 29'h0FFFFFF0;
        #(42 * 2 * 40);
        $display("[t=%0t] Tras 127→128: leds = %08b (%3d)", $time, leds, leds);

        // ---------------------------------------------------------------
        // Segmento 5: transición leds 255 → 0 (overflow / reinicio)
        // Ocurre cuando el contador de 29 bits desborda
        // counter máximo = 2^29 - 1 = 0x1FFFFFFF
        // Pre-carga a 0x1FFFFFF0
        // ---------------------------------------------------------------
        uut.counter = 29'h1FFFFFF0;
        #(42 * 2 * 40);
        $display("[t=%0t] Tras 255→0:   leds = %08b (%3d)", $time, leds, leds);

        $display("Simulación completada.");
        $finish;
    end

endmodule
