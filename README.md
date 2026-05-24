# proyecto-icesugar-fpga

Aprendiendo FPGA desde cero con la placa **iCESugar-Nano** (Lattice iCE40LP1K-CM36) y el toolchain open-source IceStorm. Cada proyecto introduce conceptos nuevos de Verilog y diseño digital, verificados en hardware real.

## Hardware

| Componente | Detalle |
|------------|---------|
| FPGA | Lattice iCE40LP1K |
| Paquete | CM36 (BGA36, 0.4 mm pitch) |
| Recursos | 1280 LUTs, 1280 flip-flops, 64 KB BRAM |
| Reloj | 12 MHz (provisto por iCELink, pin D1) |
| LED integrado | Amarillo en pin B6 (activo en alto) |
| Programador | iCELink integrado — drag & drop, sin drivers |

## Toolchain (open-source)

```
Verilog → yosys → nextpnr-ice40 → icepack → .bin → iCELink
           síntesis   place&route   bitstream   flash
```

Instrucciones de instalación en macOS: [docs/setup_macos.md](docs/setup_macos.md)

## Estructura del repositorio

```
proyecto-icesugar-fpga/
├── docs/
│   ├── setup_macos.md        ← Instalación del toolchain en macOS
│   └── guia_pcf_y_pines.md   ← Referencia de pines CM36 y sintaxis PCF
├── hands-on/
│   ├── 01_blink/             ← LED parpadeante (Hola Mundo)
│   ├── 02_pwm/               ← Control de brillo por PWM
│   ├── 03_counter/           ← Contador binario con PMOD-LED
│   └── README.md             ← Índice de proyectos
└── README.md                 ← Este archivo
```

## Proyectos

| # | Proyecto | Qué hace | Conceptos |
|---|----------|----------|-----------|
| 01 | [Blink](hands-on/01_blink/) | LED amarillo parpadea cada ~0.7 s | `reg`, `always @(posedge clk)`, divisor de frecuencia |
| 02 | [PWM](hands-on/02_pwm/) | LED sube y baja de brillo suavemente | PWM, duty cycle, comparador, operador ternario |
| 03 | [Counter](hands-on/03_counter/) | Contador binario 0–255 en PMOD-LED de 8 LEDs | bus `[7:0]`, PMOD, prescaler multi-bit, testbench |

## Quick Start

```bash
# 1. Instalar toolchain (macOS)
brew install yosys nextpnr-ice40 icestorm

# 2. Clonar el repo
git clone https://github.com/alemanmig/proyecto-icesugar-fpga.git
cd proyecto-icesugar-fpga/hands-on/01_blink

# 3. Compilar
make

# 4. Conectar la placa por USB-C y cargar
make flash
```

> **Nota sobre el programador:** La iCESugar-Nano usa iCELink (APM32F1), no FTDI. `iceprog` no es compatible — el Makefile usa `cp archivo.bin /Volumes/iCELink/` que funciona directamente en macOS.

## Referencias

- Repositorio oficial iCESugar-Nano: https://github.com/wuxx/icesugar-nano
- Documentación IceStorm: http://www.clifford.at/icestorm/
- Datasheet iCE40LP1K: https://www.latticesemi.com/view_document?document_id=49312
