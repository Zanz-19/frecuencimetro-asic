# Makefile — Frecuencímetro ASIC
# Automatiza compilación y simulación de testbenches con iverilog.
#
# Uso:
#   make sim MODULE=cdc_sync          → compila y corre el TB de cdc_sync
#   make wave MODULE=cdc_sync         → abre GTKWave con el .vcd generado
#   make clean                        → borra todos los archivos generados
#   make list                         → lista los módulos disponibles en rtl/
#
# Estructura esperada:
#   rtl/<modulo>.v       → código fuente del módulo
#   tb/tb_<modulo>.v     → testbench correspondiente
#   build/sim/           → carpeta de salida (ignorada por git)

BUILD_DIR := build/sim
RTL_DIR   := rtl
TB_DIR    := tb

IVERILOG_FLAGS := -g2012 -Wall

.PHONY: sim wave clean list help

help:
	@echo "Uso:"
	@echo "  make sim MODULE=<nombre>    Compila y corre el testbench"
	@echo "  make wave MODULE=<nombre>   Abre GTKWave con el resultado"
	@echo "  make clean                 Borra archivos generados"
	@echo "  make list                  Lista modulos disponibles en rtl/"

sim:
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: especifica MODULE=<nombre>. Ejemplo: make sim MODULE=cdc_sync"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	@echo "=== Compilando $(MODULE) ==="
	iverilog $(IVERILOG_FLAGS) -o $(BUILD_DIR)/tb_$(MODULE).vvp \
		$(TB_DIR)/tb_$(MODULE).v $(RTL_DIR)/$(MODULE).v
	@echo "=== Ejecutando simulación ==="
	vvp $(BUILD_DIR)/tb_$(MODULE).vvp
	@mv -f tb_$(MODULE).vcd $(BUILD_DIR)/ 2>/dev/null || true

wave:
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: especifica MODULE=<nombre>. Ejemplo: make wave MODULE=cdc_sync"; \
		exit 1; \
	fi
	@if [ ! -f "$(BUILD_DIR)/tb_$(MODULE).vcd" ]; then \
		echo "No existe $(BUILD_DIR)/tb_$(MODULE).vcd — corre 'make sim MODULE=$(MODULE)' primero"; \
		exit 1; \
	fi
	gtkwave $(BUILD_DIR)/tb_$(MODULE).vcd &

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vvp *.vcd
	@echo "Limpieza completa."

list:
	@echo "Modulos disponibles en $(RTL_DIR)/:"
	@ls $(RTL_DIR)/*.v 2>/dev/null | xargs -n1 basename | sed 's/\.v$$//' || echo "  (ninguno aun)"
