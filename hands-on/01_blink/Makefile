# =============================================================================
# Makefile — Proyecto Blink para iCESugar-Nano
# =============================================================================
# Uso:
#   make          → síntesis + place&route + bitstream (todo)
#   make synth    → solo síntesis (yosys)
#   make pnr      → solo place & route (nextpnr-ice40)
#   make pack     → solo generar bitstream (.bin)
#   make flash    → flashear la placa (conectarla primero!)
#   make sim      → simular con iverilog
#   make clean    → borrar archivos generados
# =============================================================================

# --- Configuración del proyecto ---
TOP    = blink          # Nombre del módulo top-level en Verilog
DEVICE = lp1k           # Chip: iCE40LP1K
PACKAGE = cm36          # Encapsulado: CM36 (BGA36)

# --- Archivos ---
SRC    = blink.v        # Archivo(s) fuente Verilog
PCF    = blink.pcf      # Pin constraints
JSON   = blink.json     # Netlist intermedia (yosys → nextpnr)
ASC    = blink.asc      # Resultado place & route
BIN    = blink.bin      # Bitstream final para flashear

# =============================================================================
# Reglas
# =============================================================================

all: $(BIN)

# 1. Síntesis: Verilog → netlist JSON
$(JSON): $(SRC)
	@echo ">>> Síntesis con yosys..."
	yosys -p "synth_ice40 -top $(TOP) -json $(JSON)" $(SRC)

# 2. Place & Route: netlist → ubicación en el chip
$(ASC): $(JSON) $(PCF)
	@echo ">>> Place & Route con nextpnr-ice40..."
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(JSON) --pcf $(PCF) --asc $(ASC)

# 3. Empaquetar: generar bitstream binario
$(BIN): $(ASC)
	@echo ">>> Generando bitstream con icepack..."
	icepack $(ASC) $(BIN)
	@echo ">>> ¡Listo! Bitstream generado: $(BIN)"

# Alias para cada paso
synth: $(JSON)
pnr:   $(ASC)
pack:  $(BIN)

# 4. Flashear la placa
# La iCESugar-Nano usa iCELink (APM32F1), NO FTDI — iceprog no es compatible.
# El método correcto es copiar el .bin al volumen iCELink que aparece como USB.
flash: $(BIN)
	@echo ">>> Copiando a iCELink..."
	cp $(BIN) /Volumes/iCELink/

# 5. Simulación con iverilog
sim:
	@echo ">>> Compilando simulación..."
	iverilog -o blink_sim blink_tb.v blink.v
	@echo ">>> Ejecutando simulación..."
	vvp blink_sim
	@echo ">>> Simulación completada. Abre blink.vcd en WaveTrace (VS Code)"

# Limpiar archivos generados
clean:
	rm -f $(JSON) $(ASC) $(BIN) blink_sim blink.vcd
	@echo ">>> Limpieza completada"

.PHONY: all synth pnr pack flash sim clean
