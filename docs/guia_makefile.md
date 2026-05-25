# Guía del Makefile — iCESugar-Nano

Referencia completa para entender, usar y crear archivos `Makefile` en proyectos FPGA con la iCESugar-Nano y el toolchain open-source IceStorm.

---

## ¿Qué es un Makefile y para qué sirve?

Un `Makefile` es un archivo de automatización que define **recetas** para transformar archivos fuente en el producto final. En lugar de recordar y teclear comandos largos cada vez, escribes `make` y el sistema ejecuta los pasos correctos en el orden correcto.

En el contexto de FPGA, el Makefile encadena cuatro herramientas del toolchain:

```
blink.v  ──(yosys)──▶  blink.json  ──(nextpnr-ice40)──▶  blink.asc  ──(icepack)──▶  blink.bin
Verilog      síntesis    netlist        place & route       resultado     empaquetar    bitstream
```

El archivo `.bin` final es el que se carga en la FPGA.

---

## Estructura general de un Makefile

```makefile
# Comentario
VARIABLE = valor

objetivo: dependencias
	comando
	comando
```

Reglas de sintaxis importantes:

- La **indentación de los comandos es con TAB**, nunca con espacios. Si usas espacios, `make` dará error.
- Las **variables** se definen con `=` y se usan con `$(VARIABLE)`.
- Cada **objetivo** (target) puede depender de otros archivos o targets.
- `make` solo reconstruye lo que cambió: si `blink.v` no cambió desde la última vez, no ejecuta yosys de nuevo.

---

## El Makefile de la iCESugar-Nano — Sección por sección

El siguiente es el Makefile completo del proyecto `01_blink`, el más documentado de la serie. Los demás proyectos siguen el mismo patrón.

### Bloque de variables

```makefile
TOP     = blink     # Nombre del módulo top-level en el Verilog
DEVICE  = lp1k      # Chip: iCE40LP1K
PACKAGE = cm36      # Encapsulado: CM36 (BGA36, 6×6 balls)

SRC  = blink.v      # Archivo fuente Verilog (puede ser una lista)
PCF  = blink.pcf    # Pin Constraint File
JSON = blink.json   # Netlist intermedia (salida de yosys)
ASC  = blink.asc    # Resultado del place & route (salida de nextpnr)
BIN  = blink.bin    # Bitstream final para cargar en la FPGA
```

`TOP`, `DEVICE` y `PACKAGE` son los únicos valores que cambian de chip a chip. Para la iCESugar-Nano siempre son `lp1k` y `cm36`.

---

### Paso 1 — Síntesis con yosys

```makefile
$(JSON): $(SRC)
	yosys -p "synth_ice40 -top $(TOP) -json $(JSON)" $(SRC)
```

**Qué hace:** Convierte el código Verilog en una **netlist** — una descripción abstracta de las compuertas lógicas, flip-flops y conexiones que implementan el diseño.

| Argumento | Significado |
|-----------|-------------|
| `-p "synth_ice40 ..."` | Ejecuta el script de síntesis específico para chips iCE40 |
| `-top $(TOP)` | Le dice a yosys cuál es el módulo raíz del diseño |
| `-json $(JSON)` | Archivo de salida: netlist en formato JSON que entiende nextpnr |
| `$(SRC)` | Archivo(s) Verilog de entrada |

**Entrada:** `blink.v`  
**Salida:** `blink.json`

---

### Paso 2 — Place & Route con nextpnr-ice40

```makefile
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(JSON) --pcf $(PCF) --asc $(ASC)
```

**Qué hace:** Toma la netlist abstracta y **ubica** cada celda lógica en un lugar físico del chip (place), y luego **enruta** las conexiones entre ellas usando los recursos de interconexión del iCE40 (route).

| Argumento | Significado |
|-----------|-------------|
| `--lp1k` | Tipo de chip (iCE40LP1K) |
| `--package cm36` | Encapsulado físico — determina cuáles pins son válidos |
| `--json $(JSON)` | Netlist de entrada (salida de yosys) |
| `--pcf $(PCF)` | Restricciones de pines — qué señal va a qué ball del BGA |
| `--asc $(ASC)` | Archivo de salida con el diseño ubicado y enrutado |

**Entrada:** `blink.json` + `blink.pcf`  
**Salida:** `blink.asc`

> ⚠️ Si `--package` no coincide con el chip real, nextpnr rechaza los nombres de pins. Para la iCESugar-Nano siempre es `cm36`.

---

### Paso 3 — Empaquetar bitstream con icepack

```makefile
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)
```

**Qué hace:** Convierte el archivo de place & route (`.asc`, formato de texto ASCII) al **bitstream binario** (`.bin`) que la FPGA puede cargar directamente.

**Entrada:** `blink.asc`  
**Salida:** `blink.bin`

Este es el archivo que se transfiere a la FPGA.

---

### Target `all` — compilación completa

```makefile
all: $(BIN)
```

Es el target por defecto (se ejecuta con `make` sin argumentos). Depende de `$(BIN)`, que a su vez depende de `$(ASC)`, que depende de `$(JSON)`. Make resuelve la cadena automáticamente y ejecuta solo los pasos necesarios.

---

### Target `flash` — cargar en la placa

```makefile
flash: $(BIN)
	cp $(BIN) /Volumes/iCELink/
```

**Qué hace:** Copia el bitstream al volumen USB que expone el programador iCELink.

> **Importante:** La iCESugar-Nano usa **iCELink** (basado en APM32F1), no un chip FTDI. El comando estándar `iceprog` requiere FTDI y **no es compatible** con esta placa. El método correcto en macOS es copiar el `.bin` directamente al volumen montado, tal como si fuera una memoria USB.

Para que funcione:
1. Conectar la placa por USB-C
2. El volumen `iCELink` debe aparecer en Finder (y en `/Volumes/iCELink/`)
3. Ejecutar `make flash`

La FPGA se reprograma automáticamente al detectar el nuevo archivo.

---

### Target `sim` — simulación

```makefile
sim:
	iverilog -o blink_sim blink_tb.v blink.v
	vvp blink_sim
```

**Qué hace:** Compila el testbench junto con el módulo principal usando **iverilog** y lo ejecuta con **vvp**. El testbench genera un archivo `.vcd` (Value Change Dump) para visualizar las señales.

| Herramienta | Función |
|-------------|---------|
| `iverilog` | Compilador de Verilog para simulación |
| `vvp` | Ejecutor del archivo compilado |
| `.vcd` | Archivo de ondas — se abre en WaveTrace (VS Code) |

La simulación no requiere la placa física. Es el equivalente a correr pruebas unitarias antes de cargar en hardware.

---

### Target `clean` — limpiar archivos generados

```makefile
clean:
	rm -f $(JSON) $(ASC) $(BIN) blink_sim blink.vcd
```

Elimina todos los archivos generados por el proceso de compilación y simulación. Los archivos fuente (`.v`, `.pcf`, `Makefile`) no se tocan.

Es buena práctica correr `make clean` antes de hacer commit al repositorio — o mejor aún, agregar estos patrones al `.gitignore`.

---

### Directiva `.PHONY`

```makefile
.PHONY: all flash sim clean
```

Le dice a `make` que `all`, `flash`, `sim` y `clean` son **nombres de targets**, no archivos reales. Sin esto, si existiera un archivo llamado `clean` en la carpeta, `make clean` no haría nada (porque el "archivo" ya existe y está "actualizado").

Siempre declara como `.PHONY` todos los targets que no producen un archivo con el mismo nombre.

---

## Flujo completo de trabajo

```
Editar blink.v
      │
      ▼
   make          ← síntesis + place&route + bitstream
      │
      ├─ blink.json  (netlist, yosys)
      ├─ blink.asc   (place & route, nextpnr)
      └─ blink.bin   (bitstream, icepack)
      │
      ▼
   make flash    ← copia blink.bin a /Volumes/iCELink/
      │
      ▼
   FPGA cargada  ← iCELink programa el chip automáticamente
```

Para simulación (sin placa):

```
   make sim      ← compila testbench + módulo, ejecuta simulación
      │
      └─ blink.vcd  (ondas para WaveTrace)
```

---

## Cómo adaptar el Makefile a un nuevo proyecto

Cambia las variables del bloque inicial — el resto del Makefile es idéntico en todos los proyectos:

```makefile
TOP     = mi_proyecto       # ← nombre del módulo top en tu Verilog
DEVICE  = lp1k              # no cambia para iCESugar-Nano
PACKAGE = cm36              # no cambia para iCESugar-Nano

SRC  = mi_proyecto.v        # ← tu archivo fuente
PCF  = mi_proyecto.pcf      # ← tu archivo de pines
JSON = mi_proyecto.json
ASC  = mi_proyecto.asc
BIN  = mi_proyecto.bin
```

Si tienes múltiples archivos Verilog (módulos separados), listarlos todos en `SRC`:

```makefile
SRC = top.v modulo_a.v modulo_b.v
```

yosys los leerá todos y resolverá las dependencias entre módulos.

---

## Plantilla de Makefile para nuevos proyectos

```makefile
# =============================================================================
# Makefile — [Nombre del proyecto] para iCESugar-Nano
# =============================================================================
# Uso:
#   make          → compilación completa (síntesis + P&R + bitstream)
#   make flash    → cargar en la placa (conectar USB-C primero)
#   make sim      → simulación con iverilog (genera .vcd)
#   make clean    → borrar archivos generados
# =============================================================================

TOP     = mi_proyecto
DEVICE  = lp1k
PACKAGE = cm36

SRC  = mi_proyecto.v
PCF  = mi_proyecto.pcf
JSON = mi_proyecto.json
ASC  = mi_proyecto.asc
BIN  = mi_proyecto.bin

# --- Reglas ---

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

sim:
	@echo ">>> Compilando simulación..."
	iverilog -o mi_proyecto_sim mi_proyecto_tb.v $(SRC)
	@echo ">>> Ejecutando simulación..."
	vvp mi_proyecto_sim
	@echo ">>> Simulación completada. Abre el .vcd en WaveTrace (VS Code)"

clean:
	rm -f $(JSON) $(ASC) $(BIN) mi_proyecto_sim mi_proyecto.vcd

.PHONY: all flash sim clean
```

---

## Errores comunes

| Error | Causa probable | Solución |
|-------|----------------|----------|
| `Makefile:XX: *** missing separator. Stop.` | Indentación con espacios en lugar de TAB | Convertir la indentación a TAB en tu editor |
| `No rule to make target 'blink.v'` | El archivo fuente no existe o el nombre en `SRC` es incorrecto | Verificar nombre y ubicación del archivo `.v` |
| `Unable to place cell of type SB_RGBA_DRV` | Usando el driver RGB duro del iCE40, no disponible en CM36 | Usar el LED amarillo (B6) directamente en vez de SB_RGBA_DRV |
| `cp: /Volumes/iCELink/: No such file or directory` | La placa no está conectada o el volumen no montó | Conectar USB-C y verificar que `iCELink` aparece en Finder |
| `iverilog: command not found` | iverilog no instalado | `brew install icarus-verilog` |

---

## Resumen de comandos del día a día

```bash
make              # compilar todo
make flash        # cargar en la FPGA
make sim          # simular y generar .vcd
make clean        # limpiar archivos generados
make synth        # solo síntesis (alias disponible en 01_blink)
make pnr          # solo place & route (alias disponible en 01_blink)
```

---

## Referencias

- Documentación de GNU Make: https://www.gnu.org/software/make/manual/
- Repositorio IceStorm (yosys + nextpnr + icepack): https://github.com/YosysHQ/icestorm
- Repositorio oficial iCESugar-Nano: https://github.com/wuxx/icesugar-nano
