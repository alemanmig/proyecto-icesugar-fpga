# Proyecto 02 — Control de Brillo por PWM

Control del brillo del LED amarillo integrado usando **PWM** (Pulse Width Modulation — Modulación por Ancho de Pulso). El LED hace un efecto de "respiración": sube gradualmente de apagado a máximo brillo y vuelve a bajar, en ciclo continuo.

> **Nota sobre SB_RGBA_DRV:** El intento original de este proyecto era controlar un LED RGB usando el primitivo `SB_RGBA_DRV`. Se descubrió que el iCE40LP1K en paquete **CM36 (BGA36) no expone los pads físicos del driver RGBA** — nextpnr reporta "Unable to place cell of type SB_RGBA_DRV". Este es un aspecto del paquete: el CM36 tiene solo 36 pines y omite esos pads dedicados. Los LED de colores que se ven en la placa son del iCELink (el programador), no del FPGA.

---

## Concepto Principal: PWM

### ¿Qué es PWM?

PWM consiste en encender y apagar una señal a una frecuencia muy alta — tan alta que el ojo humano no detecta el parpadeo — y variar la **proporción de tiempo encendido vs apagado**.

```
Duty cycle 25% (LED tenue):
          ___               ___
_________|   |_____________|   |_____________
         ↑                 ↑
       encendido         encendido
         25%               25%

Duty cycle 75% (LED brillante):
   _______________   _______________
__|               |_|               |_______
         75%               75%
```

La **frecuencia de conmutación** (qué tan rápido se cicla) debe ser mayor a ~60 Hz para que el ojo no perciba parpadeo. En este diseño usamos **46.875 kHz** — casi 800 veces más rápido que el umbral de percepción.

El **duty cycle** (ciclo de trabajo) es el porcentaje de tiempo que la señal está en alto. Es lo que controla el brillo.

### ¿Por qué no usar analogía de voltaje?

Los FPGA producen señales digitales: 0V o 3.3V. No pueden producir 1.65V para "mitad de brillo". PWM es la técnica estándar para simular señales analógicas con hardware digital.

---

## Archivos del Proyecto

```
02_pwm/
├── pwm_led.v    ← Diseño Verilog con dos contadores + comparador
├── pwm_led.pcf  ← Pines: clk=D1, led=B6
├── Makefile     ← Automatización
└── 02_pwm.md   ← Esta guía
```

---

## Código Verilog: pwm_led.v

### Estructura general

El diseño tiene **tres partes**:

```
Reloj 12MHz
    │
    ├──→ [Contador PWM 8 bits] ──→ pwm_counter (0→255→0→255...)
    │                                         │
    │                                         ↓ comparador
    │                                   led = (pwm_counter < duty)
    │                                         ↑
    └──→ [Contador Respiración 25 bits] ──→ duty (varía 0→255→0 lentamente)
```

### Contador PWM

```verilog
reg [7:0] pwm_counter;
always @(posedge clk) begin
    pwm_counter <= pwm_counter + 1;
end
```

Este contador de 8 bits va de 0 a 255 y reinicia automáticamente (overflow natural). A 12 MHz, completa un ciclo en:

```
12,000,000 Hz / 256 = 46,875 Hz ≈ 46.875 kHz
```

Período de ~21 microsegundos por ciclo. El LED no puede parpadear a 47kHz — el ojo promedia el tiempo.

### Contador de respiración

```verilog
reg [24:0] breath_counter;
always @(posedge clk) begin
    breath_counter <= breath_counter + 1;
end
```

Este contador de 25 bits cambia lentamente. Sus bits [23:16] varían a:
```
12,000,000 / 2^16 = 183 Hz  ← cada paso de brillo (invisible)
Ciclo completo (0→255→0): 2^25 / 12,000,000 = 2.8 segundos
```

### Cálculo del duty cycle

```verilog
wire [7:0] duty = breath_counter[24]
                ? ~breath_counter[23:16]   // bajando: invertimos
                :  breath_counter[23:16];  // subiendo: directo
```

El bit 24 actúa como indicador de dirección:
- `breath_counter[24] = 0` → subiendo: duty = bits[23:16] (0→255)
- `breath_counter[24] = 1` → bajando: duty = ~bits[23:16] = 255-bits[23:16] (255→0)

El operador `~` (NOT bit a bit) invierte todos los bits. Para un contador de 8 bits: `~x = 255 - x`.

### Comparador PWM

```verilog
assign led = (pwm_counter < duty);
```

La señal `led` vale 1 cuando `pwm_counter < duty`. Como `pwm_counter` va de 0 a 255:

| `duty` | Tiempo en alto | Tiempo en bajo | Brillo |
|--------|---------------|----------------|--------|
| 0      | 0/256 = 0%    | 256/256 = 100% | Apagado |
| 64     | 64/256 = 25%  | 192/256 = 75%  | Tenue  |
| 128    | 128/256 = 50% | 128/256 = 50%  | Medio  |
| 192    | 192/256 = 75% | 64/256 = 25%   | Brillante |
| 255    | 255/256 ≈ 100%| 1/256 ≈ 0%     | Máximo |

---

## Nuevo Concepto Verilog: Operadores de Bit

```verilog
~x          // NOT bit a bit: invierte todos los bits
x & y       // AND bit a bit
x | y       // OR bit a bit
x ^ y       // XOR bit a bit
```

El NOT bit a bit (`~`) sobre un número sin signo de N bits equivale a `2^N - 1 - x`. Para 8 bits: `~x = 255 - x`. Esto nos permite invertir una rampa ascendente en una descendente sin aritmética.

---

## Nuevo Concepto Verilog: Operador Ternario

```verilog
wire resultado = condicion ? valor_si_true : valor_si_false;
```

Equivalente al operador ternario de C/Python. Se sintetiza como un multiplexor 2:1. Muy útil para lógica combinacional concisa.

```verilog
wire [7:0] duty = breath_counter[24]
                ? ~breath_counter[23:16]   // si bit24=1 → bajando
                :  breath_counter[23:16];  // si bit24=0 → subiendo
```

---

## Nuevo Concepto Verilog: Selección de bits con `[n:m]`

```verilog
wire [7:0] duty = breath_counter[23:16];
```

Selecciona un subconjunto de bits de un vector. Aquí tomamos los 8 bits del bit 23 al bit 16 del contador de 25 bits. Esto es una operación de **extracción de campo** — fundamental en diseño digital.

```
breath_counter[24:0]:
  bit 24 = dirección (sube/baja)
  bits [23:16] = valor del duty cycle (0-255)
  bits [15:0]  = subdivisión fina del tiempo (ignorados aquí)
```

---

## Compilar y Cargar

```bash
cd ~/Documents/Claude/Projects/FPGA-iCESugar/FPGA-ICE/02_pwm

# Compilar
make

# Cargar en la placa
make flash
```

### Resultado esperado

El LED amarillo de la iCESugar-Nano hará un efecto de "breathing":
- Enciende gradualmente durante ~1.4 segundos
- Baja gradualmente durante ~1.4 segundos
- Repite continuamente

Si ves el LED parpadeando rápido en lugar de brillar suavemente, es posible que el duty cycle esté cambiando pero la frecuencia PWM es visible — ajusta el contador PWM a más bits.

---

## Variaciones para Experimentar

### Cambiar la velocidad de respiración

Modifica qué bits seleccionas del contador de respiración:
```verilog
wire [7:0] duty = breath_counter[24]
                ? ~breath_counter[22:15]   // más rápido (bits más bajos)
                :  breath_counter[22:15];
```

### Cambiar la resolución PWM

Cambia el contador PWM a 10 bits para 1024 niveles de brillo:
```verilog
reg [9:0] pwm_counter;
// duty también debe ser de 10 bits
wire [9:0] duty = breath_counter[24]
                ? ~{breath_counter[23:16], 2'b00}
                :  {breath_counter[23:16], 2'b00};
```

### LED siempre a brillo fijo

Para un brillo fijo del 50%:
```verilog
assign led = (pwm_counter < 8'd128);
```

---

## Conceptos Nuevos Aprendidos

| Concepto | Descripción |
|----------|-------------|
| **PWM** | Simulación analógica mediante conmutación digital rápida |
| **Duty cycle** | Porcentaje de tiempo en alto — controla el valor "analógico" |
| `~x` | NOT bit a bit — invierte todos los bits del vector |
| `cond ? a : b` | Operador ternario — sintetiza como multiplexor |
| `reg[n:m]` | Selección de campo de bits — extrae un subvector |
| **Comparador** | `assign led = (counter < threshold)` → salida digital de comparación |
| **Overflow natural** | Un contador de N bits reinicia solo al llegar a 2^N |

---

## Por qué no funciona SB_RGBA_DRV en CM36

Para referencia futura:

| Aspecto | Detalle |
|---------|---------|
| Error de nextpnr | `Unable to place cell 'rgb_driver' of type 'SB_RGBA_DRV'` |
| Causa | El paquete BGA36 (CM36) no expone los pads físicos del driver RGBA |
| Chip afectado | iCE40LP1K **CM36** — otros paquetes del mismo chip (SG48) sí lo tienen |
| Solución alternativa | Control directo de LED RGB via GPIO + resistencias limitadoras (proyecto futuro con PMOD) |

---

## Referencias

- Lattice LED Driver Usage Guide: https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx
- iCE40 LP/HX Family Datasheet: https://www.latticesemi.com/~/media/latticesemi/documents/datasheets/ice/ice40lphxfamilydatasheet.pdf
- PWM en FPGA (tutorial): https://www.fpga4fun.com/PWM_DAC.html
