# Guía de Yosys — Síntesis de Verilog para iCESugar-Nano

Yosys es la herramienta de síntesis open-source que convierte código Verilog en una netlist — la descripción estructural de compuertas, flip-flops y conexiones que implementan tu diseño. Es el primer paso del toolchain antes de nextpnr-ice40.

---

## ¿Qué hace exactamente la síntesis?

Cuando escribes Verilog, describes comportamiento:

```verilog
always @(posedge clk) begin
    counter <= counter + 1;
end
assign led = counter[23];
```

Yosys traduce eso a una red de celdas primitivas del iCE40 — flip-flops (`SB_DFF`), look-up tables (`SB_LUT4`), carry chains — conectadas entre sí. Esa red es la **netlist**.

```
Verilog (comportamiento)  →  yosys  →  netlist JSON (estructura)
"suma 1 al contador"               "FF0.Q → LUT3.I0 → FF1.D ..."
```

La netlist no sabe nada de pines físicos ni ubicación en el chip — eso lo resuelve nextpnr en el paso siguiente.

---

## El comando en el Makefile

```makefile
yosys -p "synth_ice40 -top $(TOP) -json $(JSON)" $(SRC)
```

Desglose de cada parte:

| Parte | Descripción |
|-------|-------------|
| `yosys` | Invoca el ejecutable |
| `-p "..."` | Ejecuta un **script** de síntesis en línea (un string de comandos Yosys) |
| `synth_ice40` | Script de síntesis optimizado para la familia iCE40 de Lattice |
| `-top $(TOP)` | Nombre del módulo raíz del diseño (en nuestros proyectos: `blink`, `pwm_led`, `counter`) |
| `-json $(JSON)` | Archivo de salida: netlist en formato JSON que entiende nextpnr |
| `$(SRC)` | Archivo(s) Verilog de entrada |

---

## El script `synth_ice40` — internamente

`synth_ice40` no es un comando simple — es una macro que encadena varias etapas internas de Yosys. Si corrieras `yosys` de forma interactiva verías:

```
read_verilog blink.v       # leer y parsear el Verilog
hierarchy -check -top blink  # verificar jerarquía de módulos
proc                       # convertir bloques always a lógica
opt                        # optimización 1: eliminar redundancias
techmap                    # mapear a primitivas genéricas
opt                        # optimización 2: después del mapeo
abc -lut 4                 # mapear a LUTs de 4 entradas (iCE40)
opt_clean                  # eliminar celdas sin uso
stat                       # imprimir estadísticas de uso
write_json blink.json      # escribir netlist de salida
```

Yosys hace todo esto automáticamente con `synth_ice40`. Entender estas etapas ayuda a depurar si hay errores de síntesis.

---

## Banderas y opciones de `synth_ice40`

### Opciones principales

| Bandera | Uso | Descripción |
|---------|-----|-------------|
| `-top <módulo>` | **Siempre necesaria** | Especifica el módulo raíz. Sin esto, yosys puede confundirse si hay varios módulos en el Verilog |
| `-json <archivo>` | **Siempre necesaria** | Archivo de salida para nextpnr. Alternativa a `-blif` |
| `-blif <archivo>` | Opcional | Salida en formato BLIF (formato más antiguo, menos recomendado que JSON) |
| `-device <tipo>` | Raro | Variante del iCE40: `lp` (Low Power), `hx` (High Performance), `u` (Ultra). Por defecto detecta del contexto |
| `-nocarry` | Debug | Deshabilita el uso de carry chains. Útil para comparar implementaciones |
| `-nodffe` | Debug | No usar flip-flops con enable (`SB_DFFE`). Fuerza uso de LUTs para el enable |
| `-nobram` | Raro | No usar BRAM integrada. Implementa memorias en LUTs (consume muchos más recursos) |
| `-nolutram` | Raro | No usar la BRAM como LUT RAM distribuida |
| `-flatten` | A veces útil | Aplana la jerarquía — todos los módulos se funden en uno. Útil para análisis |
| `-retime` | Avanzado | Permite mover registros a través de la lógica para mejorar timing (retiming) |
| `-abc2` | Avanzado | Usa un segundo pase de ABC para optimización adicional de LUTs |
| `-abc9` | Avanzado | Usa ABC9 en lugar de ABC para mapeo a LUTs — en general produce mejores resultados |

### Opciones de diagnóstico

| Bandera | Descripción |
|---------|-------------|
| `-noflatten` | No aplanar la jerarquía (preserva módulos separados en el reporte) |
| `-run <desde>:<hasta>` | Ejecutar solo una parte del flujo de síntesis (para debug) |

### Ejemplo con opciones adicionales

```bash
# Síntesis con ABC9 (mejor optimización de LUTs)
yosys -p "synth_ice40 -top counter -json counter.json -abc9" counter.v

# Síntesis sin BRAM (fuerza todo en LUTs)
yosys -p "synth_ice40 -top mi_diseño -json mi_diseño.json -nobram" mi_diseño.v

# Solo síntesis, sin escribir JSON — útil para ver si hay errores de sintaxis
yosys -p "synth_ice40 -top blink" blink.v
```

---

## Interpretar la salida de Yosys

Cuando corres `make`, yosys imprime un reporte como este:

```
=== counter ===

   Number of wires:                  5
   Number of wire bits:             45
   Number of public wires:           2
   Number of public wire bits:      10
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:                 30
     SB_CARRY                        1
     SB_DFF                         29

Chip utilization:
   ICESTORM_LC:    29 / 1280     (  2%)
```

### Qué significa cada sección

**`Number of cells`** — las celdas primitivas del iCE40 usadas:

| Celda | Descripción |
|-------|-------------|
| `SB_LUT4` | Look-Up Table de 4 entradas — implementa funciones lógicas combinacionales |
| `SB_DFF` | Flip-flop D con reloj — registra un bit en el flanco positivo del reloj |
| `SB_DFFE` | Flip-flop D con enable — como SB_DFF pero con habilitación |
| `SB_DFFESR` | Flip-flop con enable, set y reset síncronos |
| `SB_CARRY` | Celda de carry para sumadores — más eficiente que implementar carry en LUTs |
| `SB_RAM40_4K` | Bloque de RAM de 4 Kbits integrado en el chip |

**`ICESTORM_LC`** — Logic Cells usadas del total disponible. El iCE40LP1K-CM36 tiene **1280 LCs**.

En el proyecto `counter`:
- 29 flip-flops (`SB_DFF`) = los 29 bits del contador interno
- 1 carry = el sumador `counter + 1` usa carry chain
- Solo el 2% del chip utilizado — hay espacio de sobra

---

## Modo interactivo de Yosys

Yosys también funciona como consola interactiva — útil para explorar y depurar:

```bash
yosys          # abrir la consola
```

Dentro de la consola:

```tcl
# Leer el Verilog
read_verilog blink.v

# Ver la jerarquía de módulos
hierarchy -check -top blink

# Hacer síntesis completa para iCE40
synth_ice40 -top blink -json blink.json

# Ver estadísticas
stat

# Ver el diseño como esquemático en el terminal (ASCII art)
show

# Salir
exit
```

El comando `show` puede generar un esquemático visual si tienes `xdot` instalado — muestra el grafo de compuertas del diseño.

---

## Scripts de Yosys (`.ys`)

Para proyectos complejos, en lugar de pasar el script con `-p`, puedes escribir un archivo `.ys`:

```tcl
# synth.ys — script de síntesis personalizado
read_verilog top.v modulo_a.v modulo_b.v
hierarchy -check -top top
synth_ice40 -top top -json top.json -abc9
stat
```

Y ejecutarlo con:

```bash
yosys synth.ys
```

Útil cuando el proyecto tiene muchos archivos fuente o quieres opciones especiales repetibles.

---

## Ventajas de Yosys para proyectos FPGA open-source

### 1. Gratuito y sin restricciones de licencia
Las herramientas propietarias de Lattice (iCEcube2) y otras (Vivado, Quartus) requieren licencias que pueden ser costosas o tener restricciones geográficas. Yosys es MIT — libre para uso comercial, educativo y sin registro.

### 2. Integración perfecta con el toolchain IceStorm
El trio **yosys + nextpnr + icepack** fue diseñado para trabajar en conjunto. El formato JSON que produce yosys es el formato nativo que consume nextpnr — no hay conversiones adicionales ni pérdida de información.

### 3. Calidad de síntesis comparable al flujo propietario
Estudios independientes han mostrado que yosys + nextpnr produce resultados similares o mejores que iCEcube2 para la familia iCE40, especialmente con la opción `-abc9`.

### 4. Transparencia total del proceso
Puedes inspeccionar cada paso de la síntesis, ver exactamente qué celdas se generaron y por qué, modificar el flujo si es necesario. Las herramientas propietarias son cajas negras.

### 5. Funciona en macOS, Linux y Windows
Sin restricciones de plataforma. Se instala con un comando en macOS (`brew install yosys`) y está disponible en los repositorios de todas las distribuciones Linux principales.

### 6. Soporte para múltiples familias de FPGA
Yosys soporta síntesis para iCE40 (Lattice), ECP5 (Lattice), Xilinx 7-series, Gowin, y más — con el mismo flujo de trabajo. Lo que aprendes para la iCESugar-Nano aplica directamente a otras plataformas.

### 7. Ideal para aprendizaje
El output detallado de yosys muestra exactamente cuántos flip-flops, LUTs y carry chains usa tu diseño. Esto convierte cada compilación en una lección sobre cómo el hardware implementa el código que escribiste.

---

## Archivos que produce yosys

| Archivo | Descripción | ¿Subir al repositorio? |
|---------|-------------|----------------------|
| `*.json` | Netlist intermedia | ❌ No — se genera desde el `.v` |
| `*.v` | Fuente Verilog | ✅ Sí — es el código fuente |

El `.json` es un archivo generado — no tiene sentido versionarlo porque se puede regenerar en cualquier momento con `make`. Por eso está en el `.gitignore`.

---

## Errores comunes de yosys y sus causas

| Error | Causa | Solución |
|-------|-------|----------|
| `ERROR: Module 'mi_modulo' not found` | El nombre en `-top` no coincide con ningún `module` en el Verilog | Verificar que `module mi_modulo` existe en el `.v` |
| `ERROR: Syntax error in input file` | Error de sintaxis en el Verilog | Revisar la línea indicada en el error |
| `WARNING: multiple driving` | Dos fuentes conducen la misma señal | Revisar `assign` o `always` que escriben en la misma señal |
| `WARNING: Latch inferred` | Un `always` sin `else` completo crea un latch en lugar de un FF | Agregar el caso `else` o inicializar todas las ramas |
| `SB_RGBA_DRV: Unable to place` | Celda hard-IP no disponible en el paquete CM36 | Usar el LED amarillo (B6) directamente — ver [proyecto 02_pwm](../hands-on/02_pwm/) |

### El warning de latch — importante

Un latch es una de las trampas más comunes en síntesis. Aparece cuando un registro se actualiza solo en algunas condiciones:

```verilog
// ⚠️ Esto crea un latch — led no se actualiza cuando btn == 0
always @(*) begin
    if (btn == 1)
        led = 1;
    // falta el else — qué vale led cuando btn es 0?
end

// ✅ Correcto — siempre hay un valor definido
always @(*) begin
    if (btn == 1)
        led = 1;
    else
        led = 0;
end
```

Yosys advierte sobre latches con `WARNING: Latch inferred for signal`. En diseños síncronos (con reloj), los latches casi siempre son un error de diseño.

---

## Referencias

- Repositorio oficial de Yosys: https://github.com/YosysHQ/yosys
- Documentación de Yosys: https://yosyshq.readthedocs.io
- Manual de `synth_ice40`: ejecutar `yosys -p "help synth_ice40"` en la terminal
- Proyecto IceStorm (contexto del toolchain completo): https://github.com/YosysHQ/icestorm
