# Archivo    : tests/error_analysis.py
# Proyecto   : Frecuencímetro ASIC sky130A
# Autor      : Jose (Zanz-19)
# Fecha      : Junio 2025
# Descripción: Lee sweep_results.csv (generado por test_freq_top.py) y
#              produce las gráficas de Fase 3: error relativo vs frecuencia,
#              y un resumen tabular en formato Markdown para documentación.
#
# Uso:
#   python3 error_analysis.py
#
# Genera:
#   error_vs_frequency.png  — gráfica principal
#   sweep_summary.md        — tabla de resultados en Markdown

import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

THIS_DIR = Path(__file__).resolve().parent
CSV_PATH = THIS_DIR / "sweep_results.csv"
PNG_PATH = THIS_DIR / "error_vs_frequency.png"
MD_PATH  = THIS_DIR / "sweep_summary.md"


def load_results(csv_path):
    rows = []
    with open(csv_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "freq_hz":     float(row["freq_hz"]),
                "gate_cycles": int(row["gate_cycles"]),
                "t_gate_s":    float(row["t_gate_s"]),
                "expected":    float(row["expected"]),
                "measured":    float(row["measured"]),
                "error_pct":   float(row["error_pct"]),
            })
    return rows


def plot_error_vs_frequency(rows, out_path):
    freqs = [r["freq_hz"] for r in rows]
    errors = [max(r["error_pct"], 1e-4) for r in rows]  # piso para escala log

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(freqs, errors, marker="o", linewidth=1.5, color="#185FA5")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Frecuencia medida (Hz)")
    ax.set_ylabel("Error relativo (%)")
    ax.set_title("Frecuencímetro — Error relativo vs frecuencia\n(Fase 3, cocotb + IPs reales)")
    ax.grid(True, which="both", linestyle="--", alpha=0.4)

    # Línea de referencia: error teórico de ±1 cuenta para cada T_gate usado
    for r in rows:
        theoretical_error_pct = (1.0 / r["expected"]) * 100 if r["expected"] > 0 else 0
        ax.scatter(r["freq_hz"], max(theoretical_error_pct, 1e-4),
                   marker="x", color="#A32D2D", s=40, zorder=5)

    ax.legend(["Error medido", "Error teórico (±1 cuenta)"], loc="upper right")
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"Gráfica guardada en {out_path}")


def write_summary_markdown(rows, out_path):
    lines = [
        "# Resumen del barrido de frecuencias — Fase 3 (cocotb)",
        "",
        "Generado automáticamente por `error_analysis.py` a partir de "
        "`sweep_results.csv`, producido por `test_freq_top.py` "
        "(test_frequency_sweep).",
        "",
        "| Frecuencia (Hz) | T_gate (µs) | Esperado | Medido | Error (%) |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['freq_hz']:,.0f} | {r['t_gate_s']*1e6:.1f} | "
            f"{r['expected']:.2f} | {r['measured']:.0f} | {r['error_pct']:.3f} |"
        )

    max_error = max(r["error_pct"] for r in rows)
    lines += [
        "",
        f"**Error máximo observado:** {max_error:.3f}%",
        "",
        "Todas las mediciones usan T_gate corto (0.5–1 ms) para mantener la "
        "simulación rápida; el error relativo es mayor que en el T_gate de "
        "1 s especificado para producción, donde el error de ±1 cuenta "
        "representa una fracción mucho menor del conteo total.",
    ]

    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Resumen guardado en {out_path}")


def main():
    if not CSV_PATH.exists():
        print(f"ERROR: no se encontró {CSV_PATH}")
        print("Corre primero: python3 runner.py")
        raise SystemExit(1)

    rows = load_results(CSV_PATH)
    print(f"Cargados {len(rows)} resultados de {CSV_PATH}")

    plot_error_vs_frequency(rows, PNG_PATH)
    write_summary_markdown(rows, MD_PATH)


if __name__ == "__main__":
    main()
