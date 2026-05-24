# Control de Brillo por PWM en iCESugar-Nano

**Plataforma:** iCESugar-Nano (Lattice iCE40LP1K-CM36)  
**Nivel:** Principiante — segundo proyecto después del LED parpadeante  
**Resultado:** El LED amarillo integrado hace un efecto de "respiración": sube y baja de brillo suavemente en ciclo continuo

---

## Requisitos previos

### Hardware necesario

- Placa iCESugar-Nano (Lattice iCE40LP1K, paquete **CM36**)
- Cable USB-C
- Computadora con macOS (esta guía usa macOS; los comandos de compilación son iguales en Linux)

### Software necesario

Instalar el toolchain open-source IceStorm. En macOS con Homebrew:

```bash
brew install yosys
brew install nextpnr-ice40
brew install icestorm
```

Verificar que están instalados:

```bash
yosys --version       # Yosys 0.x
nextpnr-ice40 --version
icepack --version
```

### Conocimientos previos recomendados

- Haber hecho el proyecto "Blink" (LED parpadeante básico) — o conocer los conceptos de `module`, `reg`, `always @(posedge clk)`, y archivo PCF

---

## Contexto: ¿Qué es PWM?

Los FPGA producen señales digitales puras: 0 V o 3.3 V. No pueden producir voltajes intermedios. Para simular un voltaje analógico (como "la mitad de brillo"), se usa **PWM** (Pulse Width Modulation).

La idea es simple: encender y apagar la señal a una frecuencia tan alta que el ojo humano no percibe el parpadeo y solo ve el promedio. La proporción de tiempo encendido vs apagado se llama **duty cycle** y es lo que controla el brillo.

```
Duty cycle 25% — LED tenue:
          ___               ___
_________|   |_____________|   |_____________
         encendido          encendido
         (25% del tiempo)

Duty cycle 75% — LED brillante:
   _______________   _______________
__|               |_|               |________
    encendido          encendido
    (75% del tiempo)
```

El umbral de percepción del ojo humano es aproximadamente 60 Hz. En este proyecto usamos una frecuencia PWM de **46.875 kHz** — casi 800 veces más rápido, completamente invisible.

---

## Cómo funciona el diseño

El módulo tiene tres bloques que trabajan en conjunto:

```
Reloj 12 MHz
    │
    ├──→ [Contador PWM, 8 bits]
    │    Cicla 0→255→0→... a 46.875 kHz
    │                    │
    │                    ↓
    │               COMPARADOR ──→ led (0 o 1)
    │                    ↑
    └──→ [Contador de respiración, 25 bits]
         Extrae el duty cycle actual (0→255→0)
         con un período de ~2.8 segundos
```

**Contador PWM:** Un registro de 8 bits que incrementa en cada ciclo de reloj. Al llegar a 255, desborda y vuelve a 0 automáticamente. Completa un ciclo en 256 pasos × (1/12 MHz) = ~21 microsegundos.

**Contador de respiración:** Un registro de 25 bits que cambia mucho más lento. Sus bits [23:16] forman el valor de duty cycle (0 a 255). El bit 24 indica si estamos subiendo o bajando el brillo.

**Comparador:** `led = (pwm_counter < duty)`. El LED se enciende cuando el contador PWM está por debajo del duty cycle. Si duty = 64, el LED está encendido 64/256 = 25% del tiempo.

---

## Archivos del proyecto

Crea una carpeta para el proyecto y dentro de ella crea los siguientes tres archivos:

```
pwm_led/
├── pwm_led.v    ← Diseño Verilog
├── pwm_led.pcf  ← Mapa de pines físicos
└── Makefile     ← Automatización del flujo
```

---

### Archivo 1: pwm_led.v

```verilog
// =============================================================================
// Proyecto: PWM — Control de Brillo del LED
// Placa:    iCESugar-Nano (Lattice iCE40LP1K-CM36)
// Reloj:    12 MHz (pin D1)
//
// El LED amarillo (pin B6) hace un efecto de "respiración":
// sube gradualmente de apagado a máximo brillo y vuelve a bajar.
// =============================================================================

module pwm_led (
    input  wire clk,   // Reloj 12 MHz (pin D1)
    output wire led    // LED amarillo (pin B6, activo en alto)
);

    // -------------------------------------------------------------------------
    // Contador PWM de 8 bits (0-255)
    // Frecuencia PWM = 12 MHz / 256 = ~46.875 kHz — invisible para el ojo
    // -------------------------------------------------------------------------
    reg [7:0] pwm_counter;

    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1;
    end

    // -------------------------------------------------------------------------
    // Contador de respiración de 25 bits
    //   bit 24     → dirección: 0 = subiendo brillo, 1 = bajando brillo
    //   bits[23:16] → valor del duty cycle actual (0-255)
    //   bits[15:0]  → subdivisión fina del tiempo (no se usan directamente)
    //
    // A 12 MHz, un ciclo completo (sube + baja) dura 2^25 / 12e6 ≈ 2.8 segundos
    // -------------------------------------------------------------------------
    reg [24:0] breath_counter;

    always @(posedge clk) begin
        breath_counter <= breath_counter + 1;
    end

    // Duty cycle actual:
    //   Si bit24 = 0 → subiendo → duty = bits[23:16]  (0 → 255)
    //   Si bit24 = 1 → bajando  → duty = ~bits[23:16] (255 → 0)
    // El operador ~ (NOT bit a bit) invierte todos los bits: ~x = 255 - x
    wire [7:0] duty = breath_counter[24]
                    ? ~breath_counter[23:16]   // bajando
                    :  breath_counter[23:16];  // subiendo

    // -------------------------------------------------------------------------
    // Comparador PWM
    // El LED está encendido cuando pwm_counter < duty
    //   duty = 0   → encendido 0% del tiempo   → apagado
    //   duty = 128 → encendido 50% del tiempo  → brillo medio
    //   duty = 255 → encendido ~100% del tiempo → máximo brillo
    // -------------------------------------------------------------------------
    assign led = (pwm_counter < duty);

endmodule
```

---

### Archivo 2: pwm_led.pcf

El archivo PCF (Pin Constraint File) conecta los nombres de señales del diseño Verilog con los pines físicos del chip.

```
# =============================================================================
# Pin Constraint File — Proyecto PWM LED
# Chip: Lattice iCE40LP1K-CM36
# =============================================================================

# Reloj principal: 12 MHz (provisto por iCELink)
set_io clk  D1

# LED amarillo integrado (activo en alto: 1 = encendido)
set_io led  B6
```

Los pines `D1` y `B6` corresponden al paquete BGA36 (CM36) de la iCESugar-Nano:

| Señal Verilog | Pin CM36 | Descripción |
|---------------|----------|-------------|
| `clk` | `D1` | Reloj 12 MHz desde iCELink |
| `led` | `B6` | LED amarillo integrado |

---

### Archivo 3: Makefile

```makefile
# =============================================================================
# Makefile — Proyecto PWM LED para iCESugar-Nano
# =============================================================================

TOP     = pwm_led
DEVICE  = lp1k
PACKAGE = cm36

SRC  = pwm_led.v
PCF  = pwm_led.pcf
JSON = pwm_led.json
ASC  = pwm_led.asc
BIN  = pwm_led.bin

all: $(BIN)

$(JSON): $(SRC)
	@echo ">>> Síntesis con yosys..."
	yosys -p "synth_ice40 -top $(TOP) -json $(JSON)" $(SRC)

$(ASC): $(JSON) $(PCF)
	@echo ">>> Place & Route con nextpnr-ice40..."
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(JSON) --pcf $(PCF) --asc $(ASC)

$(BIN): $(ASC)
	@echo ">>> Generando bitstream..."
	icepack $(ASC) $(BIN)
	@echo ">>> ¡Listo! Bitstream: $(BIN)"

flash: $(BIN)
	@echo ">>> Copiando a iCELink..."
	cp $(BIN) /Volumes/iCELink/

clean:
	rm -f $(JSON) $(ASC) $(BIN)

.PHONY: all flash clean
```

> **Importante:** Las líneas de comandos en el Makefile deben comenzar con un **tabulador** (Tab), no con espacios. Si copias el texto y tu editor convierte los tabs a espacios, el `make` fallará con el error `missing separator`.

---

## Flujo de compilación

El proceso transforma el código Verilog en un archivo binario que la FPGA puede ejecutar:

```
pwm_led.v
    │
    ↓  yosys (síntesis)
pwm_led.json   ← netlist: lista de compuertas y conexiones
    │
    ↓  nextpnr-ice40 (place & route)
pwm_led.asc    ← ubicación física de cada celda en el chip
    │
    ↓  icepack (empaquetado)
pwm_led.bin    ← bitstream listo para grabar
```

### Paso 1: Compilar

Desde la carpeta del proyecto:

```bash
make
```

Deberías ver los tres pasos ejecutarse secuencialmente. Al finalizar sin errores, el output termina con:

```
>>> ¡Listo! Bitstream: pwm_led.bin
```

Recursos típicos utilizados del iCE40LP1K (1280 LUTs disponibles):
- ~35 LUTs (3%)
- ~33 Flip-Flops (3%)

### Paso 2: Cargar en la placa

La iCESugar-Nano usa el programador **iCELink** integrado, que aparece como unidad USB al conectar la placa.

```bash
# Verificar que la placa está montada
ls /Volumes/
# Debe aparecer: iCELink

# Cargar el bitstream
make flash
# equivalente a: cp pwm_led.bin /Volumes/iCELink/
```

Espera 2-3 segundos. El LED comenzará el efecto de respiración.

---

## Resultado

El LED amarillo de la iCESugar-Nano sube gradualmente de apagado a máximo brillo en ~1.4 segundos, luego baja gradualmente durante otros ~1.4 segundos, y repite el ciclo indefinidamente.

---

## Variaciones para experimentar

### Cambiar la velocidad de respiración

Selecciona bits más bajos del contador para una respiración más rápida:

```verilog
// Más rápido (~1.4 segundos por ciclo completo)
wire [7:0] duty = breath_counter[24]
                ? ~breath_counter[22:15]
                :  breath_counter[22:15];

// Más lento (~5.6 segundos por ciclo completo)
wire [7:0] duty = breath_counter[24]
                ? ~breath_counter[25:18]
                :  breath_counter[25:18];
// (requiere ampliar breath_counter a 26 bits)
```

### Brillo fijo

Para un brillo constante al 50%, elimina el contador de respiración y usa:

```verilog
assign led = (pwm_counter < 8'd128);
```

Cambia `128` por cualquier valor entre 0 (apagado) y 255 (máximo).

### Mayor resolución PWM

Con 8 bits tienes 256 niveles. Con 10 bits tendrías 1024 niveles (transiciones aún más suaves):

```verilog
reg [9:0] pwm_counter;   // contador PWM de 10 bits
// duty también debe ser de 10 bits y ajustar la selección de bits
wire [9:0] duty = breath_counter[24]
                ? {~breath_counter[23:16], 2'b00}
                :  {breath_counter[23:16], 2'b00};
```

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| `make: missing separator` | Espacios en lugar de Tab en Makefile | Reemplazar la indentación por Tab real |
| Error de pines en nextpnr | Pin o paquete incorrecto | Verificar `--package cm36` y pines `D1`/`B6` en el PCF |
| `/Volumes/iCELink/` no existe | Placa no conectada o no montada | Conectar USB-C y verificar `ls /Volumes/` |
| LED no cambia tras copiar | Bitstream corrupto | Recompilar: `make clean && make` |
| LED parpadea rápido en lugar de variar suavidad | Frecuencia PWM demasiado baja | El diseño de esta guía ya usa 46 kHz — no debería ocurrir |

---

## Conceptos Verilog nuevos en este proyecto

| Concepto | Ejemplo | Descripción |
|----------|---------|-------------|
| Selección de bits | `counter[23:16]` | Extrae un subvector de un registro |
| NOT bit a bit | `~x` | Invierte todos los bits: equivale a `255 - x` para 8 bits sin signo |
| Operador ternario | `cond ? a : b` | Multiplexor 2:1 conciso |
| Comparador combinacional | `assign led = (a < b)` | Produce 1 si la condición es verdadera |
| Desbordamiento natural | contador de N bits | Al llegar a 2^N-1, vuelve a 0 automáticamente |

---

## Nota sobre SB_RGBA_DRV

Si buscas información sobre controlar el LED RGB del iCE40 con el primitivo `SB_RGBA_DRV`, ten en cuenta que **este primitivo no está disponible en el paquete CM36 (BGA36)**. nextpnr reportará `Unable to place cell of type 'SB_RGBA_DRV'` aunque la síntesis con yosys tenga éxito. El `SB_RGBA_DRV` solo funciona en paquetes que expongan los pads físicos del driver (por ejemplo, SG48). Para controlar un LED RGB con la iCESugar-Nano es necesario conectar uno externo via el conector PMOD y controlarlo con GPIO normales.

---

## Referencias

- Repositorio iCESugar-Nano: https://github.com/wuxx/icesugar-nano
- iCE40 LP/HX Datasheet: https://www.latticesemi.com/~/media/latticesemi/documents/datasheets/ice/ice40lphxfamilydatasheet.pdf
- Tutorial PWM en FPGA: https://www.fpga4fun.com/PWM_DAC.html
- Documentación IceStorm: http://www.clifford.at/icestorm/
