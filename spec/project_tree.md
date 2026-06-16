# Árbol de Archivos del Proyecto — Frecuencímetro ASIC
**Versión:** 3.0 — Estructura 100% verificada contra repos clonados  
**Leyenda:**
- ✅ `[EXISTE]` — archivo real verificado
- ⚠️ `[EXISTE*]` — existe con nombre/estructura diferente a lo anticipado
- 🔲 `[PENDIENTE]` — a crear en la fase indicada
- 🔑 `[CLAVE]` — archivo especialmente importante para el proyecto

---

```
frecuencimetro_asic/
│
├── README.md                                        ✅ [FASE 1]
├── .gitignore                                       ✅ [FASE 1]
├── .gitmodules                                      ✅ [FASE 1]
│
├── spec/
│   ├── spec.md                                      ✅ [FASE 1] v2.0
│   ├── pin_map.md                                   ✅ [FASE 1] v3.0 — FINAL
│   ├── module_list.md                               ✅ [FASE 1] v2.0 — FINAL
│   └── project_tree.md                              ✅ [FASE 1] v3.0 — este archivo
│
├── ip/
│   │
│   ├── dac_r2r/                      ← submódulo: mattvenn/tt06-analog-r2r-dac
│   │   │
│   │   ├── src/
│   │   │   └── project.v             🔑 [EXISTE] Top-level stub TinyTapeout
│   │   │                                          tt_um_mattvenn_r2r_dac
│   │   │                                          Pines: ui_in[7:0], uio_in[1:0],
│   │   │                                          clk, rst_n(⚠️activo ALTO),
│   │   │                                          ena, ua[0]
│   │   │
│   │   ├── verilog/
│   │   │   ├── rtl/
│   │   │   │   └── r2r_dac_control.v 🔑 [EXISTE] RTL del control digital
│   │   │   │                                      r2r_dac_control
│   │   │   │                                      Pines: clk, n_rst, ext_data,
│   │   │   │                                      data[7:0], load_divider,
│   │   │   │                                      r2r_out[7:0]
│   │   │   ├── gl/
│   │   │   │   ├── r2r_dac_control.v ✅ [EXISTE] Netlist gate-level
│   │   │   │   └── tt_um_mattvenn_r2r_dac.v ✅ [EXISTE] Netlist GL top
│   │   │   └── test/
│   │   │       ├── test.py           🔑 [EXISTE] Test cocotb original del DAC
│   │   │       │                                  (referencia para Fase 3)
│   │   │       ├── Makefile          ✅ [EXISTE]
│   │   │       └── r2r_dac_control.gtkw ✅ [EXISTE] Config GTKWave
│   │   │
│   │   ├── sim/
│   │   │   ├── mixed.cir             🔑 [EXISTE] Cosimulación ngspice+verilator
│   │   │   │                                     ⚠️ Ruta PDK hardcoded a /home/matt/
│   │   │   │                                     Entradas: clk,n_rst,ext_data,
│   │   │   │                                     d[7:0],load_divider
│   │   │   │                                     Salidas: b[7:0] → red R-2R
│   │   │   │                                     (base para Fase 5 Monte Carlo)
│   │   │   ├── full_spice_sim.cir    ✅ [EXISTE] Simulación SPICE completa
│   │   │   ├── README.md             ✅ [EXISTE] Instrucciones cosimulación
│   │   │   └── .spiceinit            ✅ [EXISTE]
│   │   │
│   │   ├── xschem/
│   │   │   ├── r2r.sch               🔑 [EXISTE] Esquemático red R-2R
│   │   │   ├── r2r.sym               🔑 [EXISTE] Símbolo Xschem R-2R
│   │   │   │                                     (reutilizar en Fase 4)
│   │   │   ├── testbench.sch         ✅ [EXISTE] TB Xschem original
│   │   │   ├── xschemrc              ✅ [EXISTE]
│   │   │   └── simulation/
│   │   │       ├── r2r.spice         🔑 [EXISTE] Netlist generado por Xschem
│   │   │       ├── testbench.raw     ✅ [EXISTE] Resultado previo (referencia)
│   │   │       └── .spiceinit        ✅ [EXISTE]
│   │   │
│   │   ├── mag/
│   │   │   ├── r2r.mag               ✅ [EXISTE] Layout escalera R-2R
│   │   │   ├── r2r.sim.spice         🔑 [EXISTE] Netlist PEX con parásitos
│   │   │   │                                     (usar en Fase 5 Monte Carlo)
│   │   │   ├── r2r_dac_control.mag   ✅ [EXISTE] Layout control digital
│   │   │   ├── tt_um_mattvenn_r2r_dac.mag ✅ [EXISTE] Layout top
│   │   │   └── tcl/                  ✅ [EXISTE] Scripts Magic
│   │   │
│   │   ├── gds/
│   │   │   └── tt_um_mattvenn_r2r_dac.gds 🔑 [EXISTE] GDS macro DAC
│   │   │                                           (usar en Fase 6 como macro)
│   │   ├── lef/
│   │   │   └── tt_um_mattvenn_r2r_dac.lef 🔑 [EXISTE] LEF para P&R
│   │   │
│   │   ├── openlane/
│   │   │   └── r2r_dac_control/
│   │   │       ├── config.tcl        ✅ [EXISTE] Config OpenLane del control
│   │   │       └── pin_order.cfg     ✅ [EXISTE]
│   │   │
│   │   ├── docs/
│   │   │   ├── info.md               ✅ [EXISTE]
│   │   │   └── layout.png            ✅ [EXISTE]
│   │   │
│   │   ├── info.yaml                 ✅ [EXISTE]
│   │   ├── LOG.md                    ✅ [EXISTE]
│   │   ├── Makefile                  ✅ [EXISTE]
│   │   └── LICENSE                   ✅ [EXISTE]
│   │
│   └── adc_sar/                      ← submódulo: chipfoundry/sky130_ef_ip__adc3v_12bit
│       │
│       ├── verilog/
│       │   ├── sar_ctrl.v            🔑 [EXISTE] Control SAR digital
│       │   │                                     sar_ctrl #(SIZE=8→usar 12)
│       │   │                                     Pines: clk, rst_n, soc, cmp,
│       │   │                                     en, swidth[3:0], sample_n,
│       │   │                                     data[SIZE-1:0], eoc, dac_rst
│       │   │                                     ✅ SIZE=12 confirmado por SPICE
│       │   ├── sky130_ef_ip__adc3v_12bit.v 🔑 [EXISTE] Modelo behavioral analógico
│       │   │                                     Pines: adc_in, adc_ena,
│       │   │                                     adc_reset, adc_hold,
│       │   │                                     adc_dac_val[11:0], adc_comp_out,
│       │   │                                     adc_vrefH, adc_vrefL,
│       │   │                                     adc_vCM, adc_trim
│       │   ├── adc_testbench.v       🔑 [EXISTE] TB Verilog del ADC
│       │   │                                     (referencia para Fase 2/3)
│       │   ├── README.md             ✅ [EXISTE] Instrucciones cosimulación
│       │   └── run_make_object.sh    ✅ [EXISTE] Compila .so para verilator
│       │
│       ├── xschem/
│       │   ├── sky130_ef_ip__adc3v_12bit.sch 🔑 [EXISTE] Esquemático principal
│       │   ├── sky130_ef_ip__adc3v_12bit.sym 🔑 [EXISTE] Símbolo Xschem ADC
│       │   │                                           (reutilizar en Fase 4)
│       │   ├── adc_cosim_tb.sch      🔑 [EXISTE] TB cosimulación
│       │   │                                     (base para tb_adc_dac_loop.sch
│       │   │                                      en Fase 4)
│       │   ├── adc_tb.sch            ✅ [EXISTE] TB básico
│       │   ├── adc_testbench.sym     ✅ [EXISTE]
│       │   ├── run_extract_adc3v_12bit.sh ✅ [EXISTE]
│       │   └── xschemrc              ✅ [EXISTE]
│       │
│       ├── netlist/
│       │   ├── schematic/
│       │   │   └── sky130_ef_ip__adc3v_12bit.spice 🔑 [EXISTE] Netlist esquemático
│       │   │                                                    Subcircuito verificado:
│       │   │                                                    pines adc_in, adc_ena,
│       │   │                                                    adc_dac_val[11:0], etc.
│       │   └── layout/
│       │       └── sky130_ef_ip__adc3v_12bit.spice 🔑 [EXISTE] Netlist layout (PEX)
│       │
│       ├── ip/                       ← Sub-IPs internas del ADC
│       │   ├── sky130_ef_ip__ccomp3v/ ✅ [EXISTE] IP comparador (scomp3v)
│       │   └── sky130_ef_ip__cdac3v_12bit/ ✅ [EXISTE] IP CDAC 12 bits
│       │
│       ├── cace/
│       │   ├── sky130_ef_ip__adc3v_12bit.yaml ✅ [EXISTE] Spec CACE
│       │   └── scripts/run_lvs.tcl   ✅ [EXISTE]
│       │
│       ├── mag/
│       │   ├── sky130_ef_ip__adc3v_12bit.mag  ✅ [EXISTE] Layout Magic
│       │   ├── adc_via2_8cut.mag     ✅ [EXISTE]
│       │   ├── adc_via3_30cut.mag    ✅ [EXISTE]
│       │   ├── adc_via_3cut.mag      ✅ [EXISTE]
│       │   └── run_extract_*.sh      ✅ [EXISTE] Scripts extracción PEX
│       │
│       ├── gds/
│       │   └── sky130_ef_ip__adc3v_12bit.gds.gz 🔑 [EXISTE] GDS comprimido
│       │                                                    (descomprimir en Fase 6)
│       ├── lef/
│       │   └── sky130_ef_ip__adc3v_12bit.lef    🔑 [EXISTE] LEF para P&R
│       │
│       ├── lvs/                      ✅ [EXISTE] Reportes LVS originales
│       ├── docs/                     ✅ [EXISTE] Documentación y SVGs
│       ├── README.md                 ✅ [EXISTE]
│       └── LICENSE                   ✅ [EXISTE]
│
├── rtl/                              ← Módulos Verilog nuevos (Fase 2)
│   ├── cdc_sync.v                   🔲 [FASE 2] #1 — sin dependencias
│   ├── gate_timer.v                 🔲 [FASE 2] #2 — sin dependencias
│   ├── freq_counter.v               🔲 [FASE 2] #3 — usa gate_en
│   ├── result_latch.v               🔲 [FASE 2] #4 — usa count_out, gate_done
│   ├── adc_ctrl.v                   🔲 [FASE 2] #5 — usa eoc_sync de cdc_sync
│   ├── dac_ctrl.v                   🔲 [FASE 2] #6 — sin dependencias nuevas
│   ├── wb_regs.v                    🔲 [FASE 2] #7 — usa todos los anteriores
│   └── freq_top.v                   🔲 [FASE 2] #8 — instancia todo
│
├── tb/                              ← Testbenches iverilog unitarios (Fase 2)
│   ├── tb_cdc_sync.v                🔲 [FASE 2]
│   ├── tb_gate_timer.v              🔲 [FASE 2]
│   ├── tb_freq_counter.v            🔲 [FASE 2]
│   └── tb_freq_top.v                🔲 [FASE 2]
│
├── tests/                           ← Tests cocotb Python (Fase 3)
│   ├── Makefile                     🔲 [FASE 3]
│   ├── test_freq_top.py             🔲 [FASE 3] barrido de frecuencias
│   ├── test_cdc.py                  🔲 [FASE 3] metaestabilidad
│   └── test_wishbone.py             🔲 [FASE 3] bus Wishbone
│
├── xschem/                          ← Esquemáticos propios (Fase 4)
│   ├── dac_ip.sym                   🔲 [FASE 4] wrapper símbolo DAC
│   │                                            (partir de ip/dac_r2r/xschem/r2r.sym)
│   ├── adc_ip.sym                   🔲 [FASE 4] wrapper símbolo ADC
│   │                                            (partir de ip/adc_sar/xschem/*.sym)
│   ├── schmitt_trigger.sch          🔲 [FASE 4] diseño del Schmitt trigger
│   ├── tb_schmitt.sch               🔲 [FASE 4] TB Schmitt con ruido
│   └── tb_adc_dac_loop.sch          🔲 [FASE 4] TB lazo DAC→ADC
│                                                (partir de ip/adc_sar/xschem/adc_cosim_tb.sch)
│
├── sim/                             ← Netlists ngspice propios (Fase 5)
│   ├── schmitt_tb.sp                🔲 [FASE 5]
│   ├── r2r_mc.sp                    🔲 [FASE 5] Monte Carlo R-2R
│   │                                            (partir de ip/dac_r2r/sim/mixed.cir
│   │                                             corrigiendo ruta PDK)
│   ├── corners.sp                   🔲 [FASE 5] TT/SS/FF
│   └── results/                     🔲 [FASE 5] archivos .raw de ngspice
│
├── notebooks/                       ← Análisis Python/Jupyter (Fases 3, 5)
│   ├── error_analysis.ipynb         🔲 [FASE 3] error vs frecuencia (RTL)
│   ├── error_analysis_spice.ipynb   🔲 [FASE 5] error vs frecuencia (SPICE)
│   ├── enob_analysis.ipynb          🔲 [FASE 5] ENOB/SFDR del ADC
│   ├── monte_carlo.ipynb            🔲 [FASE 5] THD/DNL/INL del DAC
│   └── characterization_report.pdf  🔲 [FASE 5] reporte exportado
│
├── gds/                             ← Bloque digital hardened (Fase 6)
│   ├── freq_top.gds                 🔲 [FASE 6]
│   ├── freq_top.lef                 🔲 [FASE 6]
│   └── reports/
│       ├── sta_report.txt           🔲 [FASE 6]
│       ├── drc_report.txt           🔲 [FASE 6]
│       └── lvs_report.txt           🔲 [FASE 6]
│
└── caravel/                         ← Integración Caravel (Fase 7)
    ├── user_project_wrapper.v       🔲 [FASE 7]
    ├── config.json                  🔲 [FASE 7]
    └── firmware/
        ├── freq_meter_test.c        🔲 [FASE 7]
        └── freq_meter_test.hex      🔲 [FASE 7]
```

---

## Mapa de archivos clave por fase

| Fase | Archivo IP a usar | Propósito específico |
|---|---|---|
| **2** | `ip/dac_r2r/verilog/rtl/r2r_dac_control.v` | Referencia exacta de pines para `dac_ctrl.v` |
| **2** | `ip/adc_sar/verilog/sar_ctrl.v` | Referencia exacta de pines para `adc_ctrl.v` |
| **2** | `ip/adc_sar/verilog/adc_testbench.v` | Referencia de cómo instanciar el ADC |
| **3** | `ip/dac_r2r/verilog/test/test.py` | Referencia del test cocotb original del DAC |
| **4** | `ip/dac_r2r/xschem/r2r.sym` | Símbolo base para `xschem/dac_ip.sym` |
| **4** | `ip/adc_sar/xschem/sky130_ef_ip__adc3v_12bit.sym` | Símbolo base para `xschem/adc_ip.sym` |
| **4** | `ip/adc_sar/xschem/adc_cosim_tb.sch` | Base para `xschem/tb_adc_dac_loop.sch` |
| **5** | `ip/dac_r2r/sim/mixed.cir` | Base para `sim/r2r_mc.sp` (corregir ruta PDK) |
| **5** | `ip/dac_r2r/mag/r2r.sim.spice` | Netlist PEX R-2R con parásitos para Monte Carlo |
| **5** | `ip/adc_sar/netlist/schematic/*.spice` | Netlist ADC para ngspice |
| **5** | `ip/dac_r2r/xschem/simulation/r2r.spice` | Netlist R-2R generado por Xschem |
| **6** | `ip/dac_r2r/gds/tt_um_mattvenn_r2r_dac.gds` | Macro GDS del DAC para wrapper |
| **6** | `ip/dac_r2r/lef/tt_um_mattvenn_r2r_dac.lef` | LEF del DAC para P&R |
| **6** | `ip/adc_sar/gds/sky130_ef_ip__adc3v_12bit.gds.gz` | Macro GDS del ADC (descomprimir primero) |
| **6** | `ip/adc_sar/lef/sky130_ef_ip__adc3v_12bit.lef` | LEF del ADC para P&R |

---

## Pendientes abiertos al cierre de Fase 1

| # | Pendiente | Fase donde se resuelve |
|---|---|---|
| ⚠️ | Nivel de reset DAC: 3V en sim original vs 1.8V del pad digital | Fase 4 — simular umbral con ngspice |
| ⚠️ | Frecuencia máxima DAC: comentario dice 10 MHz | Fase 3 — verificar con cocotb a 100 MHz |
| ⚠️ | Ruta PDK hardcoded en `mixed.cir` | Fase 5 — reemplazar con `$PDK_ROOT` |
| ⚠️ | Fuente de referencias vrefH/vrefL/vCM del ADC | Fase 6 — definir en floorplan del wrapper |
| ⚠️ | Descomprimir `sky130_ef_ip__adc3v_12bit.gds.gz` | Fase 6 — antes de P&R |

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Estructura anticipada |
| 2.0 | Junio 2025 | Actualizado con repos reales clonados |
| 3.0 | Junio 2025 | Pines 100% verificados desde SPICE; archivos clave marcados; mapa por fase añadido |
