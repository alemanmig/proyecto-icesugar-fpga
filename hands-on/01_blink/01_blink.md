# Proyecto 01 — LED Parpadeante (Blink)

El proyecto más básico para verificar que el entorno de desarrollo y la placa funcionan correctamente. Equivalente al "Hola Mundo" en programación.

**Estado: ✅ Completado y verificado en hardware**

---

## Objetivo

Hacer parpadear el **LED amarillo integrado** de la iCESugar-Nano usando un divisor de frecuencia implementado en Verilog.

> **Nota importante:** La placa tiene un LED amarillo en el pin `B6` accesible directamente como GPIO. El LED RGB requiere un primitivo especial (`SB_RGBA_DRV`) que se verá en proyectos posteriores.

---

## Hardware: iCESugar-Nano v1.2

| Componente | Detalle |
|------------|---------|
| FPGA | Lattice iCE40LP1K |
| **Paquete** | **CM36** (BGA36, 0.4mm pitch) |
| Reloj | 12 MHz (provisto por iCELink, pin `D1`) |
| LED amarillo | Pin `B6` (activo en alto: 1 = encendido) |
| Programador | iCELink integrado (drag & drop o icesprog) |

---

## Concepto: Divisor de Frecuencia

La placa tiene un oscilador de **12 MHz** — eso significa 12,000,000 pulsos por segundo. Si conectáramos el LED directamente al reloj, parpadearía 6 millones de veces por segundo, invisible para el ojo humano.

La solución es un **contador binario**. Cada bit del contador cambia a la mitad de la frecuencia del bit anterior:

```
clk         → 12,000,000 Hz  (invisible)
counter[0]  →  6,000,000 Hz  (invisible)
counter[1]  →  3,000,000 Hz  (invisible)
...
counter[20] →      2,861 Hz  (invisible)
counter[21] →      1,430 Hz  (invisible)
counter[22] →        715 Hz  (invisible)
counter[23] →        0.71 Hz ← conectamos el LED aquí ✓
```

El bit `counter[23]` cambia aproximadamente **cada 0.7 segundos**, dando un parpadeo cómodo y visible.

---

## Archivos del Proyecto

```
01_blink/
├── blink.v       ← Diseño Verilog
├── blink.pcf     ← Mapa de pines físicos
├── blink_tb.v    ← Testbench para simulación
├── Makefile      ← Automatización del flujo
└── 01_blink.md   ← Esta guía
```

---

## Código Verilog: blink.v

```verilog
module blink (
    input  wire clk,   // Reloj de entrada: 12 MHz (pin D1)
    output wire led    // LED amarillo (pin B6, activo en alto)
);

    reg [23:0] counter;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    // LED activo en alto (1 = encendido, 0 = apagado)
    assign led = counter[23];

endmodule
```

### Explicación línea por línea

**`module blink (...)`**
Define el módulo (bloque de hardware). Los puertos son las "patitas" del circuito: una entrada de reloj y una salida para el LED.

**`reg [23:0] counter`**
Declara un registro de 24 bits. Un `reg` es un elemento de memoria — retiene su valor entre ciclos de reloj.

**`always @(posedge clk)`**
Bloque que se ejecuta en cada flanco positivo (subida) del reloj. Todo lo que está dentro describe lógica secuencial (flip-flops).

**`counter <= counter + 1`**
En cada pulso del reloj, el contador incrementa en 1. El operador `<=` es asignación no bloqueante — característica clave de la lógica secuencial en Verilog.

**`assign led = counter[23]`**
Lógica combinacional: el LED se conecta directamente al bit 23 del contador. El LED amarillo en la iCESugar-Nano es **activo en alto** (1 = encendido, 0 = apagado).

---

## Archivo de Pines: blink.pcf

```
# Reloj principal: 12 MHz (provisto por iCELink)
set_io clk  D1

# LED amarillo integrado en la placa (activo en alto: 1 = encendido)
set_io led  B6
```

El archivo PCF (Pin Constraint File) conecta los nombres de señales del diseño Verilog con los pines físicos del chip iCE40LP1K-**CM36**.

| Señal Verilog | Pin CM36 | Descripción |
|---------------|----------|-------------|
| `clk` | `D1` | Reloj 12 MHz desde iCELink |
| `led` | `B6` | LED amarillo integrado |

> **Sobre el paquete CM36:** Los pines se nombran con letra + número (A1, B6, D1…), no con números solos. Esta es la convención del paquete BGA36.

---

## Flujo de Compilación

### Opción A: Usar el Makefile (recomendado)

Desde la terminal, dentro de la carpeta `01_blink/`:

```bash
cd ~/Documents/Claude/Projects/FPGA-iCESugar/FPGA-ICE/01_blink
```

Compilar todo (síntesis + place & route + bitstream):
```bash
make
```

Limpiar archivos generados:
```bash
make clean
```

### Opción B: Comandos manuales paso a paso

**Paso 1 — Síntesis con yosys:**
```bash
yosys -p "synth_ice40 -top blink -json blink.json" blink.v
```
Genera `blink.json` — la netlist (lista de compuertas y conexiones).

**Paso 2 — Place & Route con nextpnr-ice40:**
```bash
nextpnr-ice40 --lp1k --package cm36 --json blink.json --pcf blink.pcf --asc blink.asc
```
Genera `blink.asc` — la ubicación y conexión de cada celda en el chip.

> ⚠️ El paquete es `cm36`, no `qn84`. Usar el paquete incorrecto causa un error de pines.

**Paso 3 — Generar bitstream con icepack:**
```bash
icepack blink.asc blink.bin
```
Genera `blink.bin` — el archivo binario listo para grabar en la placa.

---

## Cómo Cargar el Bitstream en la Placa

La iCESugar-Nano usa el programador **iCELink** integrado. Hay dos métodos:

### Método 1: Drag & Drop (recomendado en macOS) ✅

El iCELink aparece como una unidad USB al conectar la placa. Es el método más simple.

```bash
# 1. Verificar que la placa está montada
ls /Volumes/
# Debe aparecer: iCELink

# 2. Copiar el bitstream
cp blink.bin /Volumes/iCELink/

# 3. Esperar 2-3 segundos → el LED comienza a parpadear
```

> ⚠️ El nombre del volumen es `iCELink` con mayúsculas y minúsculas exactas. No confundir con `ICELINK`.

### Método 2: icesprog (herramienta oficial)

`icesprog` es la herramienta de línea de comandos oficial para iCESugar. No está disponible en pip, pero se puede compilar desde:
```
https://github.com/wuxx/icesugar/tree/master/tools
```

### Método 3: iceprog ❌ No funciona

`iceprog` (incluido en icestorm) busca dispositivos FTDI. La iCESugar-Nano **no usa FTDI**, por lo que este método no es compatible.

---

## Simulación (sin necesitar la placa)

La simulación permite verificar el diseño antes de grabarlo en hardware real.

```bash
make sim
```

Esto ejecuta internamente:
```bash
iverilog -o blink_sim blink_tb.v blink.v   # compilar
vvp blink_sim                              # simular → genera blink.vcd
```

Para visualizar las señales, abrir `blink.vcd` con la extensión **WaveTrace** en VS Code:
1. Clic derecho sobre `blink.vcd` en el explorador de VS Code
2. Seleccionar "Open with WaveTrace"
3. Verás las señales `clk`, `led` y el valor del contador a lo largo del tiempo

---

## Resultado Obtenido ✅

El **LED amarillo** parpadea con un período de ~1.4 segundos (0.7 seg encendido, 0.7 seg apagado).

Recursos utilizados del iCE40LP1K:
- **25 LUTs** de 1280 disponibles (2%)
- **24 Flip-Flops** de 1280 disponibles (2%)

---

## Variaciones para Experimentar

Una vez que el proyecto base funciona, modifica `blink.v` para experimentar:

**Cambiar la velocidad de parpadeo:**
```verilog
assign led = counter[22];  // más rápido (~1.4 Hz)
assign led = counter[21];  // aún más rápido (~2.8 Hz)
```
Para parpadeo más lento necesitas ampliar el registro a 25 bits: `reg [24:0] counter`.

**Efecto de fade (aproximado con PWM simple):**
Usa bits bajos del contador para modular el encendido:
```verilog
assign led = (counter[23] & counter[15]);  // parpadeo irregular
```

---

## Lecciones Aprendidas

Durante este proyecto se identificaron y resolvieron los siguientes problemas:

**1. Paquete incorrecto**
El chip iCE40LP1K en la iCESugar-Nano viene en paquete **CM36** (BGA36), no QN84. Usar `--package qn84` en nextpnr causa error de pines.

**2. Nombres de pines en CM36**
El paquete CM36 usa notación alfanumérica (`D1`, `B6`…), no números solos (`35`, `41`…). Siempre verificar el esquemático de la placa.

**3. iceprog no compatible**
La iCESugar-Nano usa iCELink (basado en APM32F1), no FTDI. El comando `iceprog` de icestorm no funciona. Usar drag & drop al volumen `iCELink`.

**4. LED amarillo vs RGB**
El LED accesible directamente como GPIO es el **amarillo** (pin B6, activo en alto). El LED RGB requiere el primitivo `SB_RGBA_DRV` de Lattice.

---

## Conceptos Verilog Aprendidos

| Concepto | Descripción |
|----------|-------------|
| `module` | Bloque de hardware con puertos de entrada/salida |
| `input wire` | Puerto de entrada |
| `output wire` | Puerto de salida |
| `reg` | Registro — elemento de memoria |
| `always @(posedge clk)` | Lógica secuencial — se ejecuta en cada pulso del reloj |
| `<=` | Asignación no bloqueante — usada en lógica secuencial |
| `assign` | Lógica combinacional — conexión directa |
| `1'b1` | Constante: 1 bit con valor 1 |

---

## Resumen: Pasos para Cargar un Proyecto

Estos son los pasos completos desde cero hasta ver el resultado en la placa:

```
1. ESCRIBIR el diseño
   └── blink.v    → código Verilog del hardware
   └── blink.pcf  → mapa de pines físicos (CM36: D1, B6…)

2. COMPILAR
   └── make
       ├── yosys      → blink.v   → blink.json  (síntesis)
       ├── nextpnr    → blink.json → blink.asc  (place & route)
       └── icepack    → blink.asc  → blink.bin  (bitstream)

3. CARGAR EN LA PLACA (drag & drop)
   └── cp blink.bin /Volumes/iCELink/
       └── Esperar 2-3 segundos → ¡listo!
```

### Comandos de referencia rápida

```bash
# Entrar a la carpeta del proyecto
cd ~/Documents/Claude/Projects/FPGA-iCESugar/FPGA-ICE/01_blink

# Compilar
make

# Cargar en la placa
cp blink.bin /Volumes/iCELink/

# Simular (sin placa)
make sim

# Limpiar archivos generados
make clean
```

### Verificación rápida si algo falla

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| Error de pines en nextpnr | Paquete o pin incorrecto | Verificar `--package cm36` y pins `D1`/`B6` |
| `iceprog` no encuentra dispositivo | iceprog no compatible | Usar `cp blink.bin /Volumes/iCELink/` |
| Volumen no aparece | Placa no conectada | Conectar cable USB-C y verificar `ls /Volumes/` |
| LED no parpadea tras copiar | Archivo .bin corrupto | Recompilar con `make clean && make` |

---

## Referencias

- Datasheet iCE40LP1K: https://www.latticesemi.com/view_document?document_id=49312
- Repositorio iCESugar-Nano: https://github.com/wuxx/icesugar-nano
- Esquemático v1.2: https://github.com/wuxx/icesugar-nano/blob/main/schematic/ICESugar-nano-v1.2.pdf
- Tutorial IceStorm: http://www.clifford.at/icestorm/
- Guía de Verilog: https://www.asic-world.com/verilog/veritut.html
