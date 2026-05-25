# El Entorno de Desarrollo — Qué es y para qué sirve cada herramienta

Cuando programas un microcontrolador (Arduino, por ejemplo), usas un IDE que compila tu código y lo carga en el chip con un solo clic. En el mundo FPGA el proceso es diferente: en lugar de compilar a instrucciones de máquina, estás **describiendo circuitos**, y cada herramienta del toolchain transforma esa descripción de una forma distinta hasta producir el archivo binario que configura el hardware.

Este documento explica qué hace cada pieza del entorno, por qué existe, y cómo encaja en el flujo completo.

---

## El flujo completo de un proyecto FPGA

```
Tu código Verilog (.v)
         │
         ▼
    ┌─────────┐
    │  yosys  │  ← síntesis: convierte comportamiento en compuertas
    └─────────┘
         │  netlist (.json)
         ▼
    ┌──────────────┐
    │ nextpnr-ice40│  ← place & route: ubica las compuertas en el chip real
    └──────────────┘
         │  layout (.asc)
         ▼
    ┌─────────┐
    │ icepack │  ← empaqueta: genera el bitstream binario (.bin)
    └─────────┘
         │  bitstream (.bin)
         ▼
    ┌──────────────────────────────────┐
    │  iCELink (dentro de la placa)   │  ← graba el bitstream en la FPGA
    └──────────────────────────────────┘
         │
         ▼
    FPGA configurada y funcionando
```

Para simular sin necesitar la placa física:

```
Tu código Verilog (.v) + Testbench (_tb.v)
         │
         ▼
    ┌──────────┐
    │ iverilog │  ← compila para simulación
    └──────────┘
         │  ejecutable de simulación
         ▼
    ┌─────┐
    │ vvp │  ← ejecuta la simulación → genera archivo de señales (.vcd)
    └─────┘
         │  archivo de ondas (.vcd)
         ▼
    ┌──────────┐
    │WaveTrace │  ← visualiza las señales en el tiempo
    └──────────┘
```

---

## Las herramientas — una por una

---

### Homebrew

**Tipo:** Gestor de paquetes para macOS  
**Instalación:** Herramienta de arranque — se instala primero, el resto con ella  
**Comando:** `brew install <paquete>`

macOS no incluye un gestor de paquetes como `apt` (Ubuntu) o `dnf` (Fedora). Homebrew llena ese vacío: mantiene un catálogo de miles de herramientas de desarrollo y las instala en `/opt/homebrew/` (Apple Silicon) o `/usr/local/` (Intel), gestionando dependencias automáticamente.

En este proyecto Homebrew instala las cuatro herramientas del toolchain FPGA con un solo comando cada una. También permite actualizarlas y desinstalarlas de forma limpia.

```bash
brew --version          # verificar versión
brew update             # actualizar el catálogo
brew upgrade yosys      # actualizar una herramienta específica
brew list               # listar todo lo instalado
```

Sin Homebrew, instalar yosys o nextpnr en macOS requeriría compilar el código fuente manualmente — un proceso de varias horas con decenas de dependencias.

---

### yosys

**Tipo:** Sintetizador de HDL  
**Rol en el flujo:** Primero — convierte Verilog en una netlist de celdas primitivas  
**Versión instalada:** 0.65  
**Comando típico:** `yosys -p "synth_ice40 -top blink -json blink.json" blink.v`

#### El problema que resuelve

Cuando escribes Verilog describes **comportamiento**:

```verilog
always @(posedge clk) begin
    counter <= counter + 1;
end
assign led = counter[23];
```

La FPGA no entiende "suma 1" ni "asigna". Solo contiene recursos físicos: look-up tables (LUTs), flip-flops, carry chains, bloques de RAM. **yosys traduce el código a una red de esos recursos**, un proceso llamado síntesis.

#### Qué produce

Un archivo `.json` con la **netlist** — la lista de todas las celdas primitivas del iCE40 usadas y cómo están conectadas entre sí. Por ejemplo, para un contador de 24 bits:

- 24 flip-flops `SB_DFF` (uno por cada bit del contador)
- Carry chains `SB_CARRY` para el sumador +1
- Una LUT `SB_LUT4` para la señal de salida

#### Por qué es importante para FPGA

Las herramientas propietarias de Lattice (iCEcube2) hacen lo mismo, pero requieren registro, son cerradas y tienen restricciones de licencia. yosys es MIT — libre, transparente y sin restricciones. Además, su reporte de síntesis muestra exactamente cuántos recursos usa tu diseño, convirtiendo cada compilación en una lección de arquitectura digital.

> Guía detallada: [guia_yosys.md](guia_yosys.md)

---

### nextpnr-ice40

**Tipo:** Place & Route (P&R) para la familia iCE40  
**Rol en el flujo:** Segundo — ubica y conecta las celdas en el chip físico  
**Versión instalada:** 0.10  
**Comando típico:** `nextpnr-ice40 --lp1k --package cm36 --json blink.json --pcf blink.pcf --asc blink.asc`

#### El problema que resuelve

La netlist de yosys dice *qué* celdas se necesitan y cómo se conectan lógicamente, pero no dice *dónde* en el chip iCE40 va cada flip-flop ni *qué* wire de interconexión lleva cada señal. nextpnr resuelve ese problema:

- **Place (ubicar):** Asigna cada celda lógica a una Location Cell específica del chip, respetando las restricciones del archivo PCF (qué señal va a qué ball del BGA).
- **Route (enrutar):** Selecciona los recursos de interconexión del iCE40 para conectar las celdas según el diagrama de la netlist.

El resultado es un mapa completo de la configuración del chip: qué LUT tiene qué función, qué flip-flop está en qué posición, qué switch boxes están habilitados para enrutar cada señal.

#### Por qué hay una versión específica para iCE40

El iCE40LP1K-CM36 tiene una arquitectura interna particular: 1280 Logic Cells organizadas en tiles, recursos de interconexión específicos, bloques de RAM en posiciones fijas, etc. nextpnr-ice40 conoce esa arquitectura en detalle. Hay versiones separadas para otras familias: `nextpnr-ecp5` para Lattice ECP5, `nextpnr-xilinx` para FPGAs de AMD/Xilinx, etc.

#### El rol del PCF

nextpnr lee el archivo `.pcf` para saber qué señales están restringidas a pines físicos específicos. Por ejemplo, `set_io clk D1` le dice que la señal `clk` debe conectarse al ball D1 del BGA — donde está soldado el oscilador de 12 MHz. Sin el PCF, nextpnr asignaría los pines arbitrariamente.

> Guía de PCF y pines: [guia_pcf_y_pines.md](guia_pcf_y_pines.md)

---

### icestorm (icepack + iceprog)

**Tipo:** Suite de utilidades para chips iCE40  
**Rol en el flujo:** Tercero — genera el bitstream y lo carga en la placa  
**Versión instalada:** 1.1  
**Comandos:** `icepack` (empaquetar), `iceprog` (flashear)

icestorm es en realidad un conjunto de herramientas. Las dos más usadas en este proyecto son:

#### icepack

Convierte el archivo `.asc` (resultado de nextpnr, formato de texto ASCII) al archivo `.bin` — el **bitstream binario** que la FPGA puede leer directamente para configurarse.

```bash
icepack blink.asc blink.bin
```

El archivo `.asc` es un formato de texto legible que describe la configuración completa del chip (qué bits de configuración están activos en cada tile, cada switch box, cada celda). El `.bin` es la versión binaria compacta del mismo contenido — el formato que el chip espera recibir al arrancar.

#### iceprog

Es el programador que envía el `.bin` a la FPGA a través de USB usando el chip FTDI.

```bash
iceprog blink.bin    # cargar en la FPGA
```

> ⚠️ **Importante para la iCESugar-Nano:** iceprog usa el protocolo FTDI para comunicarse con la FPGA, pero la iCESugar-Nano usa **iCELink** (basado en APM32F1), que no habla ese protocolo. En esta placa, iceprog **no funciona**. En su lugar, el Makefile usa `cp blink.bin /Volumes/iCELink/` — copiar el archivo al volumen USB que expone iCELink. El efecto es el mismo: la FPGA se reprograma, pero sin necesitar FTDI.

#### ¿Qué más hay en icestorm?

| Herramienta | Descripción |
|-------------|-------------|
| `icepack` | `.asc` → `.bin` (el que usamos) |
| `iceunpack` | `.bin` → `.asc` (ingeniería inversa de bitstreams) |
| `iceprog` | Programar via FTDI (no aplica para iCESugar-Nano) |
| `icetime` | Análisis de timing: estima la frecuencia máxima del reloj |
| `icemulti` | Combinar múltiples bitstreams en uno (para warm boot) |
| `icebram` | Modificar contenidos de BRAM en un bitstream ya generado |

El proyecto icestorm fue el resultado de un esfuerzo de ingeniería inversa completo del formato de bitstream del iCE40 — documentado completamente por Clifford Wolf y colaboradores. Antes de icestorm, no existía ningún toolchain open-source para FPGAs.

---

### icarus-verilog (iverilog + vvp)

**Tipo:** Simulador de Verilog  
**Rol en el flujo:** Paralelo — verifica el diseño sin necesitar hardware  
**Versión instalada:** 11.0 / 13.0  
**Comandos:** `iverilog` (compilar), `vvp` (ejecutar)

#### El problema que resuelve

Sintetizar, hacer P&R y grabar en la FPGA toma tiempo. Más importante: si el diseño tiene un bug lógico, no lo verás hasta que el hardware haga algo inesperado — y depurar en hardware es difícil. La simulación permite verificar el comportamiento del diseño en software, con control total sobre el tiempo y la capacidad de ver todas las señales internas simultáneamente.

#### Cómo funciona

Icarus Verilog tiene dos partes separadas:

**`iverilog`** — el compilador. Lee tu módulo Verilog y el testbench, verifica la sintaxis y la conectividad, y genera un ejecutable de simulación:

```bash
iverilog -o blink_sim blink_tb.v blink.v
```

**`vvp`** — el ejecutor. Corre el ejecutable de simulación e interpreta el modelo de tiempo del hardware. El testbench le dice cuándo cambian las entradas, y vvp calcula las salidas para cada instante de tiempo. Los resultados se vuelcan a un archivo `.vcd`:

```bash
vvp blink_sim   # genera blink.vcd
```

#### El testbench

Un testbench (`_tb.v`) es un módulo Verilog especial que no se sintetiza a hardware — solo existe para simulación. Instancia el módulo que quieres probar, genera el reloj y las entradas de prueba, y observa las salidas.

```verilog
module blink_tb;
    reg clk;
    wire led;

    blink uut (.clk(clk), .led(led));   // instanciar el módulo

    initial clk = 0;
    always #42 clk = ~clk;              // reloj de 12 MHz (periodo = 84 ns)

    initial begin
        $dumpfile("blink.vcd");         // guardar todas las señales
        $dumpvars(0, blink_tb);
        uut.counter = 24'h7FFFF0;       // pre-cargar estado interno
        #(42 * 2 * 40);                 // esperar 40 ciclos
        $finish;
    end
endmodule
```

#### Diferencia con la síntesis

Icarus Verilog simula **comportamiento** — no genera hardware real. Esto significa que constructs como `initial begin` funcionan en simulación aunque yosys los ignore en síntesis. También significa que la simulación puede ser más lenta que el hardware real para diseños con millones de ciclos (de ahí la técnica de pre-cargar el contador al valor de interés).

---

### WaveTrace (extensión de VS Code)

**Tipo:** Visualizador de señales digitales  
**Rol en el flujo:** Diagnóstico — inspecciona el resultado de la simulación  
**Instalación:** Extensión de VS Code (buscar "WaveTrace")  
**Formato de entrada:** `.vcd` (Value Change Dump)

#### El problema que resuelve

El archivo `.vcd` que genera vvp es texto plano — registra cada cambio de señal con su timestamp:

```
$timescale 1ns / 1ps $end
$var wire 1 ! clk $end
$var wire 1 " led $end
...
#0
0!
0"
#42
1!
#84
0!
```

Leer eso directamente es imposible para señales reales. WaveTrace convierte ese archivo en un diagrama de formas de onda interactivo donde puedes:

- Ver todas las señales (reloj, entradas, salidas, señales internas) en el tiempo
- Hacer zoom en zonas de interés
- Medir tiempos entre eventos
- Detectar visualmente cuándo una señal tiene valor X (indefinido, en rojo) — señal de que falta inicialización

#### Por qué WaveTrace y no GTKWave

GTKWave fue la herramienta estándar para visualizar VCDs durante décadas, pero en 2025 fue eliminada del catálogo de Homebrew (incompatibilidad con las últimas versiones de macOS en Apple Silicon). WaveTrace funciona directamente dentro de VS Code sin instalación adicional de aplicaciones — basta con hacer clic derecho sobre el `.vcd` y elegir "Open with WaveTrace".

#### Cómo interpretar las señales

| Color de señal | Significado |
|----------------|-------------|
| Verde / Azul | Señal definida con valor 0 o 1 |
| Rojo | Señal con valor **X** (indefinido) — registro no inicializado |
| Amarillo / Naranja | Alta impedancia **Z** |
| Barras de datos | Bus multi-bit (muestra el valor hexadecimal o binario) |

Una señal en rojo al inicio de la simulación es el síntoma más común: el registro no tiene `initial` y el simulador lo deja en X. La solución es agregar `initial contador = 0;` al módulo Verilog.

---

### iCELink (integrado en la placa)

**Tipo:** Programador/depurador USB integrado  
**Rol en el flujo:** Último paso — transfiere el bitstream a la FPGA  
**Chip:** APM32F1 (compatible con STM32F103)

iCELink no es software que instales en tu Mac — es un microcontrolador soldado en la propia placa iCESugar-Nano que actúa como puente entre USB y la FPGA.

#### Qué hace exactamente

1. Cuando conectas la iCESugar-Nano por USB-C, tu Mac ve dos dispositivos:
   - Un **puerto serie virtual** (`/dev/cu.usbmodem...`) para comunicación UART
   - Un **volumen USB** llamado `iCELink` (como una memoria USB de 2 MB)

2. Cuando copias un `.bin` al volumen iCELink, el APM32F1 detecta el archivo nuevo y lo transfiere a la FPGA usando el protocolo SPI.

3. La FPGA lee la configuración desde su memoria flash (W25Q16, 16 Mbit) al arrancar, y queda configurada con tu diseño.

#### Por qué no funciona iceprog

iceprog se comunica con la FPGA asumiendo que hay un chip FTDI como intermediario (FT2232H), que es el programador estándar en placas como la iCEstick. La iCESugar-Nano usa iCELink (APM32F1), que habla un protocolo diferente. El resultado es que `iceprog` reporta error:

```
Can't find iCE FTDI USB device (vendor_id 0x0403, device_id 0x6010 or 0x6014)
```

El método correcto para la iCESugar-Nano es siempre copiar directamente:

```bash
cp mi_diseño.bin /Volumes/iCELink/
```

#### Ventaja de este diseño

No necesitas instalar drivers. Cualquier Mac puede programar la placa sin configuración adicional — funciona igual que copiar un archivo a una memoria USB.

---

## Resumen: el rol de cada herramienta

| Herramienta | Categoría | Entrada | Salida | ¿Necesita la placa? |
|-------------|-----------|---------|--------|---------------------|
| **Homebrew** | Gestor de paquetes | — | Instala las demás | No |
| **yosys** | Síntesis | `.v` (Verilog) | `.json` (netlist) | No |
| **nextpnr-ice40** | Place & Route | `.json` + `.pcf` | `.asc` (layout) | No |
| **icepack** | Empaquetado | `.asc` | `.bin` (bitstream) | No |
| **iCELink** | Programación | `.bin` | FPGA configurada | **Sí** |
| **iverilog** | Simulación (compilar) | `.v` + `_tb.v` | ejecutable sim | No |
| **vvp** | Simulación (ejecutar) | ejecutable sim | `.vcd` (ondas) | No |
| **WaveTrace** | Visualización | `.vcd` | diagrama interactivo | No |

Solo el último paso requiere la placa física. Todo lo demás — síntesis, place & route, generación de bitstream y simulación — se hace completamente en el Mac.

---

## Relación entre herramientas y archivos del proyecto

```
blink.v ─────────────────┬──────────────────────────────────────────────────────┐
                         │ (yosys)                                              │ (iverilog)
                         ▼                                                      ▼
                    blink.json ─────────────────────┐                    blink_tb.v ──┐
                         │ (nextpnr-ice40)           │                                │
                    blink.pcf ──────────────────────►│                                │ (iverilog)
                                                     ▼                                ▼
                                               blink.asc                        blink_sim ──► (vvp)
                                                     │ (icepack)                              │
                                                     ▼                                        ▼
                                               blink.bin ──► /Volumes/iCELink/       blink.vcd ──► WaveTrace
                                                               (iCELink)
```

Los archivos en **negrita** son los que escribes tú:

- `blink.v` — el diseño (lógica del circuito)
- `blink.pcf` — el mapa de pines (qué señal va a qué pin físico)
- `blink_tb.v` — el testbench (pruebas para la simulación)
- `Makefile` — la automatización (no hay que recordar los comandos)

Todo lo demás lo generan las herramientas.

---

## Referencias

| Herramienta | Repositorio / Documentación |
|-------------|----------------------------|
| Homebrew | https://brew.sh |
| yosys | https://github.com/YosysHQ/yosys |
| nextpnr | https://github.com/YosysHQ/nextpnr |
| icestorm | https://github.com/YosysHQ/icestorm |
| Icarus Verilog | https://github.com/steveicarus/iverilog |
| WaveTrace (VS Code) | https://marketplace.visualstudio.com/items?itemName=wavetrace.wavetrace |
| iCESugar-Nano | https://github.com/wuxx/icesugar-nano |
