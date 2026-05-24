# Proyectos Prácticos (Hands-On)

Cada proyecto introduce conceptos nuevos y se construye sobre el anterior. Todos están verificados en hardware con la iCESugar-Nano.

| # | Proyecto | Concepto principal | Estado |
|---|----------|--------------------|--------|
| 01 | [Blink — LED parpadeante](01_blink/) | Divisor de frecuencia, contador, flip-flops | ✅ Verificado |
| 02 | [PWM — Control de brillo](02_pwm/) | PWM, duty cycle, comparador, operador ternario | ✅ Verificado |

## Cómo usar estos proyectos

Cada carpeta contiene:
- El código Verilog fuente (`.v`)
- El archivo de pines físicos (`.pcf`)
- El testbench de simulación (`_tb.v`) cuando aplica
- Un `Makefile` con los comandos `make`, `make flash`, `make sim`, `make clean`
- Una guía en markdown con explicación detallada del diseño

```bash
cd 01_blink
make          # compilar
make flash    # cargar en la placa
make sim      # simular (genera .vcd para visualizar en WaveTrace)
make clean    # borrar archivos generados
```

## Requisitos

Ver [../docs/setup_macos.md](../docs/setup_macos.md) para instalar el toolchain completo (yosys, nextpnr-ice40, icestorm).
