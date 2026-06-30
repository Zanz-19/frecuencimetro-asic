# Makefile — Frecuencímetro ASIC
# Automatiza compilación y simulación de testbenches con iverilog.
#
# Uso:
#   make sim MODULE=cdc_sync                                    → compila y corre el TB
#   make sim MODULE=adc_ctrl EXTRA_SRC=ip/adc_sar/verilog/sar_ctrl.v
#                                                                → con dependencia externa (IP real)
#   make sim MODULE=freq_top EXTRA_SRC="ip/adc_sar/verilog/sar_ctrl.v ip/dac_r2r/verilog/rtl/r2r_dac_control.v"
#                                                                → freq_top incluye TODOS los .v de rtl/
#                                                                  automaticamente (ver nota abajo)
#   make wave MODULE=cdc_sync                                   → abre GTKWave con el .vcd generado
#   make cocotb                                                 → corre la suite de Fase 3 (cocotb + Python)
#   make clean                                                  → borra todos los archivos generados
#   make list                                                   → lista los módulos disponibles en rtl/
#
# Estructura esperada:
#   rtl/<modulo>.v       → código fuente del módulo
#   tb/tb_<modulo>.v     → testbench correspondiente
#   tests/               → suite de Fase 3 (cocotb): tb_top.v, runner.py, test_*.py
#   build/sim/           → carpeta de salida (ignorada por git)
#
# EXTRA_SRC: lista opcional de archivos fuente adicionales (separados por
# espacio) necesarios para compilar el testbench, típicamente IPs reales
# bajo ip/ que el módulo bajo prueba instancia directamente.
#
# NOTA IMPORTANTE: la compilación incluye TODOS los archivos .v de rtl/
# automáticamente (no solo rtl/$(MODULE).v). Esto es necesario porque
# freq_top.v instancia los otros 7 módulos hermanos, y así no hace falta
# listarlos uno por uno en EXTRA_SRC. Es seguro para los demás módulos:
# iverilog simplemente ignora los módulos que nadie instancia desde el
# testbench, así que compilar de más no causa conflictos ni errores.

BUILD_DIR := build/sim
RTL_DIR   := rtl
TB_DIR    := tb
TESTS_DIR := tests

IVERILOG_FLAGS := -g2012 -Wall

.PHONY: sim wave clean list help cocotb simspice waveschmitt

help:
	@echo "Uso:"
	@echo "  make sim MODULE=<nombre> [EXTRA_SRC=\"archivo1.v archivo2.v\"]"
	@echo "  make wave MODULE=<nombre>   Abre GTKWave con el resultado"
	@echo "  make cocotb                 Corre la suite de Fase 3 (cocotb + Python)"
	@echo "  make simspice               Corre el testbench PVT del Schmitt trigger (Fase 5)"
	@echo "  make waveschmitt            Igual, pero con graficas (ngspice interactivo)"
	@echo "  make clean                  Borra archivos generados"
	@echo "  make list                   Lista modulos disponibles en rtl/"

sim:
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: especifica MODULE=<nombre>. Ejemplo: make sim MODULE=cdc_sync"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	@echo "=== Compilando $(MODULE) ==="
	iverilog $(IVERILOG_FLAGS) -o $(BUILD_DIR)/tb_$(MODULE).vvp \
		$(TB_DIR)/tb_$(MODULE).v $(RTL_DIR)/*.v $(EXTRA_SRC)
	@echo "=== Ejecutando simulación ==="
	@rm -f *.vcd
	vvp $(BUILD_DIR)/tb_$(MODULE).vvp
	@mv -f tb_$(MODULE).vcd $(BUILD_DIR)/ 2>/dev/null || true
	@for f in *.vcd; do \
		if [ -f "$$f" ]; then \
			echo "Nota: la IP forzó su propio nombre de VCD ('$$f'); renombrando a tb_$(MODULE).vcd"; \
			mv -f "$$f" $(BUILD_DIR)/tb_$(MODULE).vcd; \
		fi; \
	done

wave:
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: especifica MODULE=<nombre>. Ejemplo: make wave MODULE=cdc_sync"; \
		exit 1; \
	fi
	@if [ ! -f "$(BUILD_DIR)/tb_$(MODULE).vcd" ]; then \
		echo "No existe $(BUILD_DIR)/tb_$(MODULE).vcd — corre 'make sim MODULE=$(MODULE)' primero"; \
		exit 1; \
	fi
	@gtkwave $(BUILD_DIR)/tb_$(MODULE).vcd > /dev/null 2>&1 &
	@echo "GTKWave abierto en background (PID $$!). La terminal queda libre."

cocotb:
	@if [ ! -f "$(TESTS_DIR)/runner.py" ]; then \
		echo "Error: no existe $(TESTS_DIR)/runner.py"; \
		exit 1; \
	fi
	@echo "=== Corriendo suite de Fase 3 (cocotb) ==="
	@cd $(TESTS_DIR) && python3 runner.py
	@if [ -f "$(TESTS_DIR)/error_analysis.py" ] && [ -f "$(TESTS_DIR)/sweep_results.csv" ]; then \
		echo "=== Generando grafica y resumen ==="; \
		cd $(TESTS_DIR) && python3 error_analysis.py; \
	fi

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vvp *.vcd
	rm -rf $(TESTS_DIR)/sim_build $(TESTS_DIR)/__pycache__
	rm -f $(TESTS_DIR)/sweep_results.csv $(TESTS_DIR)/error_vs_frequency.png $(TESTS_DIR)/sweep_summary.md
	@echo "Limpieza completa."

list:
	@echo "Modulos disponibles en $(RTL_DIR)/:"
	@ls $(RTL_DIR)/*.v 2>/dev/null | xargs -n1 basename | sed 's/\.v$$//' || echo "  (ninguno aun)"

# --- Fase 5: caracterizacion del Schmitt trigger (ngspice) ---
# (el esquematico vive en xschem/ -- Fase 4; el netlist y la simulacion van en sim/ -- Fase 5)
# Testbench maestro: corre las 3 esquinas de proceso (tt/ff/ss) x 4 temperaturas
# (-40/27/85/125 C) = 12 casos, mas las graficas del caso nominal (tt, 27C).
# Requiere en sim/: schmitt_tb.spice, schmitt_circuit_tt.cir,
# schmitt_circuit_ff.cir, schmitt_circuit_ss.cir
SIM_DIR := sim
SCHMITT_TB := schmitt_tb.spice

simspice:
	@echo "=== Corriendo testbench PVT del Schmitt trigger (solo resultados) ==="
	@cd $(SIM_DIR) && ngspice -b $(SCHMITT_TB)

waveschmitt:
	@echo "=== Corriendo testbench del Schmitt trigger con graficas ==="
	@echo "(ngspice interactivo: cierra las ventanas de grafica para terminar)"
	@cd $(SIM_DIR) && ngspice $(SCHMITT_TB)
