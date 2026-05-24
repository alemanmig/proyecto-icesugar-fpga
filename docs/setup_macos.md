# Puesta en Marcha — iCESugar-Nano en macOS

Guía completa para configurar el entorno de desarrollo open-source para la placa **iCESugar-Nano** (Lattice iCE40LP1K) en macOS, usando la cadena de herramientas IceStorm.

---

## ¿Qué es la iCESugar-Nano?

La **iCESugar-Nano** es una placa de desarrollo FPGA ultracompacta basada en el chip **Lattice iCE40LP1K**. Sus características principales son:

- **1,280 celdas lógicas** (LUTs de 4 entradas)
- **64 KB de RAM** embebida (16 bloques de 4K bits)
- **PLL** para generación de relojes
- **iCELink integrado**: programador/depurador USB incorporado, no necesitas hardware externo
- **Núcleo RISC-V**: puede correr un softcore RISC-V dentro del FPGA
- **Oscilador de 12 MHz** en placa
- Familia iCE40 de Lattice — con soporte de herramientas **100% open-source**

---

## Flujo de Trabajo General

```
Diseño HDL (Verilog)
        ↓
   Síntesis (yosys)         ← convierte Verilog en netlist
        ↓
  Place & Route (nextpnr)   ← ubica y conecta en el chip real
        ↓
  Bitstream (icepack)       ← genera el archivo binario para la placa
        ↓
  Programar la placa (iceprog)
```

Para simular antes de grabar:
```
Verilog + Testbench
        ↓
   Simular (iverilog + vvp)
        ↓
   Archivo .vcd
        ↓
   Visualizar señales (WaveTrace en VS Code)
```

---

## Herramientas Necesarias

| Herramienta | Función | Versión instalada |
|-------------|---------|-------------------|
| **yosys** | Síntesis: Verilog → netlist | 0.65 |
| **nextpnr-ice40** | Place & Route para iCE40 | 0.10 |
| **icestorm** | Utilidades iCE40: icepack, iceprog | 1.1 |
| **icarus-verilog** | Simulación de diseños Verilog | 11.0 |
| **Homebrew** | Gestor de paquetes para macOS | — |

---

## Instalación Paso a Paso

### Paso 1: Instalar Homebrew

Homebrew es el gestor de paquetes para macOS. Es el punto de partida para instalar todas las herramientas.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verificar instalación:
```bash
brew --version
```

### Paso 2: Instalar yosys (síntesis)

yosys convierte el código Verilog en una descripción de compuertas lógicas (netlist).

```bash
brew install yosys
```

Resultado esperado:
```
🍺  /opt/homebrew/Cellar/yosys/0.65: 345 files, 44.6MB
```

### Paso 3: Instalar icarus-verilog (simulación)

Simulador de Verilog para verificar el diseño antes de grabar en la placa.

```bash
brew install icarus-verilog
```

Resultado esperado:
```
🍺  /opt/homebrew/Cellar/icarus-verilog/13.0: 54 files, 6.8MB
```

### Paso 4: Instalar icestorm (utilidades iCE40)

Incluye `icepack` (genera bitstream) e `iceprog` (flashea la placa).

```bash
brew install icestorm
```

Resultado esperado:
```
🍺  /opt/homebrew/Cellar/icestorm/1.1: 47 files, 115.2MB
```

### Paso 5: Instalar nextpnr-ice40 (Place & Route)

> **Nota:** El nombre correcto en Homebrew es `nextpnr-ice40`, no `nextpnr`.

```bash
brew install nextpnr-ice40
```

Resultado esperado:
```
🍺  /opt/homebrew/Cellar/nextpnr-ice40/0.10: 17 files, 233.4MB
```

---

## Verificación del Entorno

Ejecuta cada comando para confirmar que las herramientas están correctamente instaladas:

```bash
yosys --version
```
```
Yosys 0.65 (git sha1 aec814bdf3071f7e0fd0fbe43f7f711e99d01e24, ...)
```

```bash
nextpnr-ice40 --version
```
```
"nextpnr-ice40" -- Next Generation Place and Route (Version 0.10)
```

```bash
which icepack && which iceprog
```
```
/opt/homebrew/bin/icepack
/opt/homebrew/bin/iceprog
```

```bash
iverilog -V
```
```
Icarus Verilog version 11.0 (stable)
```

---

## Visualizador de Señales (Opcional)

GTKWave fue deprecado en Homebrew (2025). Las alternativas actuales son:

**WaveTrace** — extensión de VS Code (recomendada, sin instalación adicional):
- Abre VS Code → Extensions → busca `WaveTrace`
- Permite abrir archivos `.vcd` directamente en el editor

**GTKWave manual** — sigue funcionando descargando el `.dmg` desde:
```
https://github.com/gtkwave/gtkwave/releases
```

---

## Posible Problema: Autenticación de GitHub

Si al hacer `brew tap` de repositorios externos ves un error de autenticación:

```
remote: Invalid username or token. Password authentication is not supported.
```

La causa es que GitHub eliminó la autenticación por contraseña en 2021. La solución es deshabilitar temporalmente el credential helper:

```bash
git config --global credential.helper ""
```

Para restaurarlo después:
```bash
git config --global credential.helper osxkeychain
```

> **Nota:** Las herramientas principales (`yosys`, `nextpnr-ice40`, `icestorm`, `icarus-verilog`) están disponibles directamente en Homebrew sin necesidad de repositorios externos.

---

## Posible Problema: Permisos USB (placa no reconocida)

Si conectas la placa y no aparece en el sistema:

```bash
# Verificar si macOS detecta el dispositivo
ls /dev/cu.*
# Debe aparecer algo como: /dev/cu.usbmodem...
```

Si no aparece, revisar en **Preferencias del Sistema → Privacidad y Seguridad** si hay algún driver bloqueado pendiente de aprobación.

---

## Estado Final del Entorno

| Herramienta | Estado | Versión |
|-------------|--------|---------|
| Homebrew | ✅ | — |
| yosys | ✅ | 0.65 |
| nextpnr-ice40 | ✅ | 0.10 |
| icestorm (icepack + iceprog) | ✅ | 1.1 |
| icarus-verilog | ✅ | 11.0 |
| WaveTrace (VS Code) | ✅ | — |

---

## Siguiente Paso

Con el entorno listo, el primer proyecto es el **LED Parpadeante** — el "Hola Mundo" del mundo FPGA. Ver `01_blink/01_blink.md`.

---

## Referencias

- Repositorio oficial iCESugar-Nano: https://github.com/wuxx/icesugar-nano
- Proyecto IceStorm (herramientas open-source): https://github.com/YosysHQ/icestorm
- yosys: https://github.com/YosysHQ/yosys
- nextpnr: https://github.com/YosysHQ/nextpnr
- Icarus Verilog: https://github.com/steveicarus/iverilog
