# =============================================================================
# Makefile — Contador Binario con PMOD-LED para iCESugar-Nano
# =============================================================================

TOP     = counter
DEVICE  = lp1k
PACKAGE = cm36

SRC  = counter.v
PCF  = counter.pcf
JSON = counter.json
ASC  = counter.asc
BIN  = counter.bin

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
	iverilog -o counter_sim counter_tb.v counter.v
	@echo ">>> Ejecutando simulación..."
	vvp counter_sim
	@echo ">>> Simulación completada. Abre counter.vcd en WaveTrace (VS Code)"

clean:
	rm -f $(JSON) $(ASC) $(BIN) counter_sim counter.vcd

.PHONY: all flash sim clean
