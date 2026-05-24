# Proyecto 03 — Contador Binario con PMOD-LED

Primer proyecto con periférico externo: el módulo **PMOD-LED v1.1** (8 LEDs) conectado al conector PMOD de 2×6 de la iCESugar-Nano. El FPGA cuenta de 0 a 255 en binario y muestra el valor en los LEDs en tiempo real.

---

## Hardware necesario

- iCESugar-Nano conectada por USB-C
- PMOD-LED v1.1 enchufado al conector de 2×6 (el más grande de la placa)

## Conexión del PMOD-LED

El PMOD-LED se enchufa directamente al conector de 2×6 de la iCESugar-Nano. El mapeo de pines es:

| PMOD-LED | Rol | Ball CM36 |
|----------|-----|-----------|
| D0 | LED bit 0 (LSB) | C6 |
| D1 | LED bit 1 | E3 |
| D2 | LED bit 2 | C2 |
| D3 | LED bit 3 | A1 |
| D4 | LED bit 4 | B4 |
| D5 | LED bit 5 | B5 |
| D6 | LED bit 6 | E1 |
| D7 | LED bit 7 (MSB) | B1 |

Lectura visual de los LEDs: `D7 D6 D5 D4 D3 D2 D1 D0` (izquierda = más significativo)

---

## Concepto: Contador Binario

Un contador binario de N bits cuenta de 0 a 2^N−1 y luego reinicia. Con 8 bits contamos de **0 a 255**. Al conectar cada bit del contador a un LED, podemos "leer" el número en binario con los ojos.

```
Número  Binario    LEDs (D7→D0)
  0     00000000   ○○○○○○○○
  1     00000001   ○○○○○○○●
  2     00000010   ○○○○○○●○
  3     00000011   ○○○○○○●●
 ...
127     01111111   ○●●●●●●●
128     10000000   ●○○○○○○○
255     11111111   ●●●●●●●●
```

Una observación interesante: el LED D0 (LSB) parpadea a la mitad de velocidad del reloj interno del contador. El D1 a la mitad del D0, y así sucesivamente. Es el mismo principio del divisor de frecuencia del proyecto Blink, pero con 8 salidas.

---

## Código Verilog: counter.v

```verilog
module counter (
    input  wire clk,
    output wire [7:0] leds
);
    reg [28:0] counter;
    initial counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    assign leds = counter[28:21];
endmodule
```

El truco está en el **prescaler**: no usamos los 8 bits bajos del contador (cambiarían a 6 MHz, invisible). Usamos los bits `[28:21]`, que cambian a una frecuencia humana:

| Bit del contador | Frecuencia de cambio |
|-----------------|----------------------|
| `counter[21]` → `leds[0]` (D0) | 12 MHz / 2²² ≈ **2.86 Hz** |
| `counter[22]` → `leds[1]` (D1) | 12 MHz / 2²³ ≈ 1.43 Hz |
| `counter[28]` → `leds[7]` (D7) | 12 MHz / 2²⁹ ≈ 0.022 Hz (1 cambio cada ~44 s) |

Un ciclo completo de 0 a 255 dura ≈ 256 × 0.35 s ≈ **89 segundos**.

### Ajustar la velocidad

Cambia los bits seleccionados en `assign leds = counter[28:21]`:

| Selección | Velocidad D0 | Ciclo completo |
|-----------|-------------|----------------|
| `[24:17]` | ~45 Hz | ~5.7 s |
| `[26:19]` | ~11 Hz | ~22 s |
| `[28:21]` | ~2.86 Hz | ~89 s ← **default** |
| `[30:23]` | ~0.7 Hz | ~360 s |

---

## Nuevo concepto Verilog: Bus de salida `[7:0]`

En los proyectos anteriores siempre tuvimos una sola señal de salida (`output wire led`). Aquí usamos un **bus de 8 bits**:

```verilog
output wire [7:0] leds   // 8 señales de salida empaquetadas
```

`[7:0]` significa 8 bits: desde el índice 7 (MSB) hasta el índice 0 (LSB). Se accede igual que un array: `leds[0]`, `leds[3]`, etc.

En el PCF, cada bit del bus se asigna individualmente a su pin físico:
```
set_io leds[0]  C6
set_io leds[7]  B1
```

Y la asignación `assign leds = counter[28:21]` conecta el subbvector de 8 bits `[28:21]` del contador directamente a los 8 bits del bus de salida.

---

## Compilar y cargar

```bash
cd ~/Documents/Claude/Projects/FPGA-iCESugar/FPGA-ICE/03_counter

make
make flash
```

---

## Simulación con testbench

El proyecto incluye `counter_tb.v` para verificar el diseño sin necesitar la placa.

```bash
make sim
```

Esto ejecuta internamente:
```bash
iverilog -o counter_sim counter_tb.v counter.v   # compilar
vvp counter_sim                                  # simular → genera counter.vcd
```

### El problema del prescaler en simulación

`leds` usa bits `[28:21]` del contador interno. Para que `leds` cambie de 0 a 1, el contador necesita llegar a 2²¹ = **2,097,152 ciclos** — simular eso directamente tomaría minutos. La solución es pre-cargar el contador a valores justo antes de cada transición de interés, exactamente igual que en el testbench del proyecto 01 (Blink).

### Segmentos del testbench

El testbench simula 5 transiciones clave, cada una con ~40 ciclos de contexto:

| Segmento | Pre-carga del counter | Qué se observa |
|----------|-----------------------|----------------|
| 1 | `0x000000000` | Estado inicial — `leds = 00000000` |
| 2 | `0x01FFFF0` | Transición `leds` **0 → 1** (primer LED D0 enciende) |
| 3 | `0x03FFFF0` | Transición `leds` **1 → 2** |
| 4 | `0x0FFFFFF0` | Transición `leds` **127 → 128** — D7 enciende por primera vez, todos los demás se apagan |
| 5 | `0x1FFFFFF0` | Transición `leds` **255 → 0** — el contador de 29 bits desborda y reinicia |

El segmento 4 es el más interesante: `01111111 → 10000000`. Todos los bits inferiores se apagan simultáneamente cuando el carry se propaga hasta el bit 7. Esto es el **carry ripple** del sumador binario, visible en el VCD.

### Visualizar en WaveTrace (VS Code)

1. Correr `make sim` — genera `counter.vcd`
2. Click derecho sobre `counter.vcd` en el explorador de VS Code
3. Seleccionar **"Open with WaveTrace"**
4. En el VCD verás `clk`, `leds[7:0]` y `uut.counter` como ondas segmentadas

### Output esperado en terminal

```
[t=1680] Inicial:       leds = 00000000 (  0)
[t=...] Tras 0→1:     leds = 00000001 (  1)
[t=...] Tras 1→2:     leds = 00000010 (  2)
[t=...] Tras 127→128: leds = 10000000 (128)
[t=...] Tras 255→0:   leds = 00000000 (  0)
Simulación completada.
```

---

## Resultado esperado

Con el PMOD-LED enchufado, verás los LEDs contando en binario. El LED D0 (derecha) parpadea rápido, D1 a la mitad de velocidad, D2 a la mitad del anterior, y así sucesivamente. D7 (izquierda) solo cambia cada ~44 segundos.

Patrones interesantes que puedes observar:
- Cuando D0 cambia, siempre es la transición más rápida
- Cuando un LED de orden alto cambia, todos los de orden inferior cambian al mismo tiempo (carry en binario)
- El patrón `10000000` (solo D7 encendido) ocurre exactamente a la mitad del ciclo

---

## Conceptos nuevos aprendidos

| Concepto | Descripción |
|----------|-------------|
| Bus de salida `[7:0]` | Agrupar 8 señales en un vector para manejarlas juntas |
| `set_io signal[n]` en PCF | Asignar cada bit de un bus a su pin físico |
| Prescaler multi-bit | Seleccionar un subvector de bits para controlar velocidad |
| Lectura binaria | Visualizar números binarios directamente en hardware |
| PMOD estándar | Interfaz de expansión de 6 o 12 pines para periféricos |

---

## Referencias

- PMOD Standard: https://digilent.com/reference/pmod/start
- Repositorio iCESugar-Nano: https://github.com/wuxx/icesugar-nano
