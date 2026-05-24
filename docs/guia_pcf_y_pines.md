# Guía de PCF y Mapa de Pines — iCESugar-Nano

Referencia para escribir archivos `.pcf` (Pin Constraint File) y mapear señales Verilog a los pines físicos de la iCESugar-Nano (Lattice iCE40LP1K-CM36).

---

## ¿Qué es un archivo PCF?

El archivo PCF es el puente entre los **nombres de señales** de tu diseño Verilog y los **pines físicos** del chip. Sin él, nextpnr no sabe a qué pin del chip conectar cada señal.

```
blink.v           blink.pcf          chip iCE40LP1K-CM36
─────────────     ──────────────     ─────────────────────
output wire led ──→ set_io led B6 ──→  ball B6 del BGA36
input  wire clk ──→ set_io clk D1 ──→  ball D1 del BGA36
```

El PCF **no afecta la síntesis** (yosys lo ignora). Solo lo usa nextpnr durante el place & route para ubicar las celdas de I/O en el chip.

---

## Sintaxis del PCF

### Señal simple

```
set_io <nombre_señal>  <pin_físico>
```

Ejemplos:
```
set_io clk   D1
set_io led   B6
```

### Bus (señal de múltiples bits)

Cada bit se asigna individualmente usando la notación `[n]`:

```
set_io leds[0]  C6
set_io leds[1]  E3
set_io leds[2]  C2
set_io leds[7]  B1
```

### Opciones adicionales

```
set_io -pullup yes  btn  A3    # habilitar pull-up interno
set_io -slewrate fast dato D2  # modo de slew rate rápido (señales de alta velocidad)
```

### Comentarios

Líneas que empiezan con `#` son comentarios:
```
# Reloj principal: 12 MHz
set_io clk  D1
```

---

## El paquete CM36 — Nomenclatura de pines

El iCE40LP1K de la iCESugar-Nano viene en el paquete **CM36** (BGA36 — Ball Grid Array de 36 bolas, 6×6, paso de 0.4 mm).

Los pines se nombran con una **letra** (fila: A–F) y un **número** (columna: 1–6):

```
     col1  col2  col3  col4  col5  col6
fA  [ A1] [ A2] [ A3] [ A4] [ A5] [ A6]
fB  [ B1] [ B2] [ B3] [ B4] [ B5] [ B6]
fC  [ C1] [ C2] [ C3] [ C4] [ C5] [ C6]
fD  [ D1] [ D2] [ D3] [ D4] [ D5] [ D6]
fE  [ E1] [ E2] [ E3] [ E4] [ E5] [ E6]
fF  [ F1] [ F2] [ F3] [ F4] [ F5] [ F6]
```

> ⚠️ El CM36 usa notación **alfanumérica** (A1, B6…), no números solos. Si usas `--package qn84` o pines numéricos (`35`, `41`…), nextpnr dará error.

---

## Pines confirmados de la iCESugar-Nano

Los siguientes pines fueron verificados en hardware con la placa iCESugar-Nano v1.2.

### Señales del sistema

| Señal | Ball CM36 | Descripción |
|-------|-----------|-------------|
| `clk` | **D1** | Reloj 12 MHz provisto por iCELink (MCO del APM32F1) |
| `led` | **B6** | LED amarillo integrado en la placa (activo en alto: 1 = encendido) |

### Conector PMOD de 2×6 (J_PMOD principal)

El conector más grande de la placa. Acepta módulos PMOD de 12 pines (8 datos + 2 GND + 2 VCC).

```
        ┌─────────────────────────────────┐
        │  1    2    3    4   GND  VCC    │  ← fila superior
        │  7    8    9   10   GND  VCC    │  ← fila inferior
        └─────────────────────────────────┘
            ↕    ↕    ↕    ↕
           D0   D1   D2   D3   (PMOD-LED: LEDs bit 0–3)
           D4   D5   D6   D7   (PMOD-LED: LEDs bit 4–7)
```

| Pin PMOD | Ball CM36 | Uso con PMOD-LED v1.1 |
|----------|-----------|------------------------|
| 1 (D0)  | **C6** | LED bit 0 (LSB) |
| 2 (D1)  | **E3** | LED bit 1 |
| 3 (D2)  | **C2** | LED bit 2 |
| 4 (D3)  | **A1** | LED bit 3 |
| 5       | GND    | — |
| 6       | VCC    | — |
| 7 (D4)  | **B4** | LED bit 4 |
| 8 (D5)  | **B5** | LED bit 5 |
| 9 (D6)  | **E1** | LED bit 6 |
| 10 (D7) | **B1** | LED bit 7 (MSB) |
| 11      | GND    | — |
| 12      | VCC    | — |

### Conectores PMOD de 1×6 (laterales)

La placa tiene dos conectores de 6 pines adicionales con 4 señales de datos cada uno. Los pines exactos deben verificarse en el esquemático oficial:

📄 [ICESugar-nano-v1.2.pdf](https://github.com/wuxx/icesugar-nano/blob/main/schematic/ICESugar-nano-v1.2.pdf)

---

## Pines reservados / no disponibles como GPIO

Algunos balls del CM36 están reservados para funciones internas y **no se deben usar como GPIO**:

| Ball(s) | Función | Motivo |
|---------|---------|--------|
| D1 | CLK entrada | Reloj del sistema (iCELink → FPGA) |
| Varios | SPI Flash (W25Q16) | MOSI, MISO, SCK, CS de la memoria de configuración |
| Varios | UART iCELink | TX/RX del puerto serie virtual (CDC) |
| Varios | VCC / GND | Alimentación del chip |

> El esquemático oficial muestra todos los balls y sus conexiones. Antes de usar un pin no documentado aquí, verificar que no esté conectado a otra función en la placa.

---

## Proceso para determinar pines nuevos

Si conectas un periférico nuevo y necesitas saber qué balls del CM36 usar:

**Opción A — Leer el esquemático:**
1. Abrir el PDF del esquemático en GitHub (link arriba)
2. Localizar el conector PMOD correspondiente
3. Rastrear cada pin del conector hasta el ball del BGA

**Opción B — Leer físicamente la placa:**
1. Usar un multímetro en modo continuidad
2. Tocar un pin del conector PMOD con una punta
3. Tocar la otra punta sobre la documentación visual del chip hasta encontrar el ball
4. (Es el método que usamos para documentar el conector 2×6 en esta guía)

**Opción C — Dejar que nextpnr asigne automáticamente:**
Agregar `--pcf-allow-unconstrained` al comando de nextpnr. Las señales sin constrainar se asignan a cualquier pin libre. Útil para prototipado rápido, pero el resultado depende de qué pins queden disponibles. **No recomendado para proyectos finales.**

---

## Errores comunes y soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `package does not have a pin named '35'` | Usando paquete QN84 o pin numérico | Cambiar a `--package cm36` y usar notación alfanumérica |
| `IO 'led' is unconstrained in PCF` | Señal del módulo sin asignar en el PCF | Agregar `set_io led <ball>` en el PCF, o usar `--pcf-allow-unconstrained` |
| `pin X is used by multiple signals` | Dos señales asignadas al mismo ball | Revisar duplicados en el PCF |
| `unknown pin X` | Ball que no existe en CM36 | Verificar que el ball existe en la cuadrícula A1–F6 |

---

## Plantilla de PCF para nuevos proyectos

```
# =============================================================================
# Pin Constraint File — [Nombre del proyecto]
# Chip: Lattice iCE40LP1K-CM36
# =============================================================================

# Reloj principal: 12 MHz (provisto por iCELink)
set_io clk  D1

# LED amarillo integrado (activo en alto)
# set_io led  B6

# PMOD 2x6 — 8 señales de datos
# set_io signal[0]  C6   # PMOD pin 1
# set_io signal[1]  E3   # PMOD pin 2
# set_io signal[2]  C2   # PMOD pin 3
# set_io signal[3]  A1   # PMOD pin 4
# set_io signal[4]  B4   # PMOD pin 7
# set_io signal[5]  B5   # PMOD pin 8
# set_io signal[6]  E1   # PMOD pin 9
# set_io signal[7]  B1   # PMOD pin 10
```

---

## Referencias

- Esquemático iCESugar-Nano v1.2: https://github.com/wuxx/icesugar-nano/blob/main/schematic/ICESugar-nano-v1.2.pdf
- Repositorio oficial: https://github.com/wuxx/icesugar-nano
- Datasheet iCE40LP1K: https://www.latticesemi.com/view_document?document_id=49312
- Documentación nextpnr PCF: https://github.com/YosysHQ/nextpnr/blob/master/docs/pcf.md
