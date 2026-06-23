# Archivo    : tests/runner.py
# Proyecto   : Frecuencímetro ASIC sky130A
# Autor      : Jose (Zanz-19)
# Fecha      : Junio 2025
# Descripción: Python Runner de cocotb 2.0 — reemplaza el Makefile clásico
#              de cocotb 1.x (que usaba 'make SIM=icarus'). Este es el flujo
#              recomendado en cocotb 2.0+.
#
# Uso:
#   cd tests/
#   python3 runner.py
#
# Requiere: pip install cocotb (>=2.0), iverilog instalado en el sistema.

import os
from pathlib import Path

from cocotb_tools.runner import get_runner

# ---------------------------------------------------------------------------
# Rutas de los fuentes: tb_top.v + los 8 módulos RTL verificados en Fase 2
# + las dos IPs reales. Ajustar PROJECT_ROOT si la estructura de carpetas
# difiere de la documentada en spec/project_tree.md
# ---------------------------------------------------------------------------
THIS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = THIS_DIR.parent

RTL_SOURCES = [
    THIS_DIR / "tb_top.v",
    PROJECT_ROOT / "rtl" / "freq_top.v",
    PROJECT_ROOT / "rtl" / "cdc_sync.v",
    PROJECT_ROOT / "rtl" / "gate_timer.v",
    PROJECT_ROOT / "rtl" / "freq_counter.v",
    PROJECT_ROOT / "rtl" / "result_latch.v",
    PROJECT_ROOT / "rtl" / "adc_ctrl.v",
    PROJECT_ROOT / "rtl" / "dac_ctrl.v",
    PROJECT_ROOT / "rtl" / "wb_regs.v",
    PROJECT_ROOT / "ip" / "adc_sar" / "verilog" / "sar_ctrl.v",
    PROJECT_ROOT / "ip" / "dac_r2r" / "verilog" / "rtl" / "r2r_dac_control.v",
]


def main():
    sim = os.getenv("SIM", "icarus")
    runner = get_runner(sim)

    missing = [str(p) for p in RTL_SOURCES if not p.exists()]
    if missing:
        print("ERROR: no se encontraron estos archivos fuente:")
        for m in missing:
            print(f"  - {m}")
        print("\nVerifica que ejecutas runner.py desde tests/ dentro del repo,")
        print("y que las IPs estan clonadas en ip/adc_sar e ip/dac_r2r.")
        raise SystemExit(1)

    runner.build(
        sources=[str(p) for p in RTL_SOURCES],
        hdl_toplevel="tb_top",
        always=True,
        build_args=["-g2012"],
    )

    runner.test(
        hdl_toplevel="tb_top",
        test_module="test_freq_top",
    )


if __name__ == "__main__":
    main()
