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
