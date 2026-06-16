# Árbol de Archivos del Proyecto — Frecuencímetro ASIC
**Versión:** 2.0 — Actualizado con estructura real de los repositorios clonados  
**Leyenda:**
- ✅ `[EXISTE]` — archivo real del repositorio de la IP (verificado)
- ⚠️ `[EXISTE*]` — existe pero con nombre/estructura diferente a lo anticipado
- 🔲 `[PENDIENTE]` — archivo a crear en la fase indicada
- 📋 `[FASE N]` — fase en que se genera

---

```
frecuencimetro_asic/
│
├── README.md                                  ✅ [FASE 1]
├── .gitignore                                 ✅ [FASE 1]
├── .gitmodules                                ✅ [FASE 1] Registra los 2 submódulos
│
├── spec/                                      ← Documentación (Fase 1) ✅ COMPLETA
│   ├── spec.md                                ✅ [FASE 1] v2.0
│   ├── pin_map.md                             ✅ [FASE 1] v2.0 — pines reales verificados
│   ├── module_list.md                         ✅ [FASE 1] v2.0 — interfaces actualizadas
│   └── project_tree.md                        ✅ [FASE 1] v2.0 — este archivo
│
├── ip/
│   │
│   ├── dac_r2r/                               ← submódulo: mattvenn/tt06-analog-r2r-dac
│   │   ├── docs/
│   │   │   ├── info.md                        ✅ [EXISTE] Descripción del proyecto TT06
│   │   │   └── layout.png                     ✅ [EXISTE] Imagen del layout
│   │   ├── gds/
│   │   │   └── tt_um_mattvenn_r2r_dac.gds     ✅ [EXISTE] GDS final hardened
│   │   ├── lef/
│   │   │   └── tt_um_mattvenn_r2r_dac.lef     ✅ [EXISTE] LEF del macro
│   │   ├── mag/
│   │   │   ├── r2r.mag                        ✅ [EXISTE] Layout de la escalera R-2R
│   │   │   ├── r2r.sim.spice                  ✅ [EXISTE] Netlist SPICE extraído (PEX)
│   │   │   ├── r2r_dac_control.mag            ✅ [EXISTE] Layout del control digital
│   │   │   ├── tt_um_mattvenn_r2r_dac.mag     ✅ [EXISTE] Layout top level
│   │   │   └── tcl/                           ✅ [EXISTE] Scripts TCL para Magic
│   │   │       ├── drc.tcl
│   │   │       ├── extract_for_lvs.tcl
│   │   │       ├── extract_for_sim.tcl
│   │   │       ├── lvs_netgen.tcl
│   │   │       ├── tt-analog-draw.tcl
│   │   │       └── update_gds_lef.tcl
│   │   ├── openlane/                          ⚠️ [EXISTE*] Antes anticipado como cace/
│   │   │   └── r2r_dac_control/
│   │   │       ├── config.tcl                 ✅ [EXISTE] Config OpenLane del control
│   │   │       └── pin_order.cfg              ✅ [EXISTE] Orden de pines P&R
│   │   ├── sim/                               ⚠️ [EXISTE*] No anticipado — simulaciones
│   │   │   ├── full_spice_sim.cir             ✅ [EXISTE] Simulación SPICE completa
│   │   │   ├── mixed.cir                      ✅ [EXISTE] Simulación mixta digital+analógica
│   │   │   ├── README.md                      ✅ [EXISTE]
│   │   │   └── .spiceinit                     ✅ [EXISTE] Init de ngspice
│   │   ├── src/
│   │   │   └── project.v                      ✅ [EXISTE] Top-level stub TinyTapeout
│   │   │                                               Módulo: tt_um_mattvenn_r2r_dac
│   │   │                                               Pines clave: ui_in[7:0], uio_in[1:0],
│   │   │                                               clk, rst_n (⚠️activo ALTO=n_rst),
│   │   │                                               ena, ua[0] (Vout analógico)
│   │   ├── verilog/
│   │   │   ├── gl/
│   │   │   │   ├── r2r_dac_control.v          ✅ [EXISTE] Netlist gate-level del control
│   │   │   │   └── tt_um_mattvenn_r2r_dac.v   ✅ [EXISTE] Netlist gate-level top
│   │   │   ├── rtl/
│   │   │   │   └── r2r_dac_control.v          ✅ [EXISTE] RTL del control digital
│   │   │   │                                           Módulo: r2r_dac_control
│   │   │   │                                           Pines: clk, n_rst, ext_data,
│   │   │   │                                           data[7:0], load_divider, r2r_out[7:0]
│   │   │   └── test/
│   │   │       ├── Makefile                   ✅ [EXISTE]
│   │   │       ├── r2r_dac_control.gtkw       ✅ [EXISTE] Configuración GTKWave
│   │   │       └── test.py                    ✅ [EXISTE] Test cocotb original del DAC
│   │   └── xschem/
│   │       ├── r2r.sch                        ✅ [EXISTE] Esquemático de la red R-2R
│   │       ├── r2r.sym                        ✅ [EXISTE] Símbolo Xschem de la red R-2R
│   │       ├── testbench.sch                  ✅ [EXISTE] Testbench Xschem original
│   │       ├── xschemrc                       ✅ [EXISTE] Config de Xschem
│   │       └── simulation/
│   │           ├── r2r.spice                  ✅ [EXISTE] Netlist generado por Xschem
│   │           ├── .spiceinit                 ✅ [EXISTE]
│   │           └── testbench.raw              ✅ [EXISTE] Resultado de simulación previa
│   │
│   └── adc_sar/                               ← submódulo: chipfoundry/sky130_ef_ip__adc3v_12bit
│       ├── cace/
│       │   ├── sky130_ef_ip__adc3v_12bit.yaml ✅ [EXISTE] Especificación CACE
│       │   └── scripts/
│       │       └── run_lvs.tcl                ✅ [EXISTE]
│       ├── docs/
│       │   ├── sky130_ef_ip__adc3v_12bit.md   ✅ [EXISTE] Documentación principal
│       │   ├── sky130_ef_ip__adc3v_12bit_schematic.md ✅ [EXISTE]
│       │   ├── sky130_ef_ip__adc3v_12bit_layout.md    ✅ [EXISTE]
│       │   ├── sky130_ef_ip__adc3v_12bit_schematic.svg ✅ [EXISTE] Esquemático en SVG
│       │   ├── sky130_ef_ip__adc3v_12bit_symbol.svg   ✅ [EXISTE] Símbolo en SVG
│       │   ├── sky130_ef_ip__adc3v_12bit_b.png        ✅ [EXISTE]
│       │   └── sky130_ef_ip__adc3v_12bit_w.png        ✅ [EXISTE]
│       ├── gds/
│       │   └── sky130_ef_ip__adc3v_12bit.gds.gz ✅ [EXISTE] GDS comprimido
│       ├── ip/                                ⚠️ [EXISTE*] No anticipado — sub-IPs internas
│       │   ├── sky130_ef_ip__ccomp3v/         ✅ [EXISTE] IP del comparador interno
│       │   └── sky130_ef_ip__cdac3v_12bit/    ✅ [EXISTE] IP del CDAC interno
│       ├── lef/
│       │   └── sky130_ef_ip__adc3v_12bit.lef  ✅ [EXISTE] LEF del macro ADC
│       ├── lvs/                               ⚠️ [EXISTE*] No anticipado — reportes LVS
│       │   ├── netgen_sky130_ef_ip__adc3v_12bit.log ✅ [EXISTE]
│       │   ├── run_lvs_sky130_ef_ip__adc3v_12bit.sh ✅ [EXISTE]
│       │   ├── sky130_ef_ip__adc3v_12bit_comp.out   ✅ [EXISTE]
│       │   └── sky130_ef_ip__adc3v_12bit.tcl         ✅ [EXISTE]
│       ├── mag/
│       │   ├── sky130_ef_ip__adc3v_12bit.mag  ✅ [EXISTE] Layout Magic del ADC
│       │   ├── adc_via2_8cut.mag              ✅ [EXISTE] Celdas de via auxiliares
│       │   ├── adc_via3_30cut.mag             ✅ [EXISTE]
│       │   ├── adc_via_3cut.mag               ✅ [EXISTE]
│       │   ├── run_extract_adc3v_12bit.sh     ✅ [EXISTE]
│       │   ├── run_extract_adc_pex.sh         ✅ [EXISTE]
│       │   └── run_extract_adc_rcx.sh         ✅ [EXISTE]
│       ├── netlist/
│       │   ├── layout/
│       │   │   └── sky130_ef_ip__adc3v_12bit.spice ✅ [EXISTE] Netlist extraído del layout
│       │   └── schematic/
│       │       └── sky130_ef_ip__adc3v_12bit.spice ✅ [EXISTE] Netlist del esquemático
│       ├── verilog/
│       │   ├── sky130_ef_ip__adc3v_12bit.v    ✅ [EXISTE] Modelo behavioral del bloque analógico
│       │   │                                           Módulo: sky130_ef_ip__adc3v_12bit
│       │   │                                           Pines: adc0 (analógico), adc0_ena,
│       │   │                                           adc0_reset, adc0_hold,
│       │   │                                           adc0_dac_val_0[11:0], adc0_comp_out
│       │   ├── sar_ctrl.v                     ✅ [EXISTE] Control digital SAR
│       │   │                                           Módulo: sar_ctrl #(SIZE=8)
│       │   │                                           ⚠️ Verificar SIZE=12 en wrapper
│       │   │                                           Pines: clk, rst_n, soc, cmp, en,
│       │   │                                           swidth[3:0], sample_n, data[SIZE-1:0],
│       │   │                                           eoc, dac_rst
│       │   ├── adc_testbench.v                ✅ [EXISTE] Testbench Verilog del ADC
│       │   ├── README.md                      ✅ [EXISTE]
│       │   └── run_make_object.sh             ✅ [EXISTE]
│       └── xschem/
│           ├── sky130_ef_ip__adc3v_12bit.sch  ✅ [EXISTE] Esquemático principal del ADC
│           ├── sky130_ef_ip__adc3v_12bit.sym  ✅ [EXISTE] Símbolo Xschem del ADC
│           ├── adc_tb.sch                     ✅ [EXISTE] Testbench básico
│           ├── adc_cosim_tb.sch               ✅ [EXISTE] TB de cosimulación (¡útil para Fase 4!)
│           ├── adc_testbench.sym              ✅ [EXISTE] Símbolo del testbench
│           ├── run_extract_adc3v_12bit.sh     ✅ [EXISTE]
│           └── xschemrc                       ✅ [EXISTE]
│
├── rtl/                                       ← Módulos Verilog nuevos (Fase 2)
│   ├── cdc_sync.v                             🔲 [FASE 2] Sincronizador 2-FF
│   ├── gate_timer.v                           🔲 [FASE 2] Divisor T_gate 27 bits
│   ├── freq_counter.v                         🔲 [FASE 2] Contador 32 bits
│   ├── result_latch.v                         🔲 [FASE 2] Registro de captura
│   ├── adc_ctrl.v                             🔲 [FASE 2] Controlador ADC (usa sar_ctrl)
│   ├── dac_ctrl.v                             🔲 [FASE 2] Controlador DAC (simplificado)
│   ├── wb_regs.v                              🔲 [FASE 2] Registros Wishbone
│   └── freq_top.v                             🔲 [FASE 2] Top level integrador
│
├── tb/                                        ← Testbenches iverilog (Fase 2)
│   ├── tb_cdc_sync.v                          🔲 [FASE 2]
│   ├── tb_gate_timer.v                        🔲 [FASE 2]
│   ├── tb_freq_counter.v                      🔲 [FASE 2]
│   └── tb_freq_top.v                          🔲 [FASE 2]
│
├── tests/                                     ← Tests cocotb Python (Fase 3)
│   ├── Makefile                               🔲 [FASE 3]
│   ├── test_freq_top.py                       🔲 [FASE 3] Barrido de frecuencias
│   ├── test_cdc.py                            🔲 [FASE 3] Metaestabilidad
│   └── test_wishbone.py                       🔲 [FASE 3] Bus Wishbone
│
├── xschem/                                    ← Esquemáticos propios (Fase 4)
│   ├── dac_ip.sym                             🔲 [FASE 4] Símbolo wrapper del DAC
│   ├── adc_ip.sym                             🔲 [FASE 4] Símbolo wrapper del ADC
│   │                                                   (puede reutilizar ip/adc_sar/xschem/*.sym)
│   ├── schmitt_trigger.sch                    🔲 [FASE 4] Diseño del Schmitt
│   ├── tb_schmitt.sch                         🔲 [FASE 4] TB: señal+ruido → Schmitt
│   └── tb_adc_dac_loop.sch                    🔲 [FASE 4] TB lazo DAC→ADC
│                                                        (puede partir de ip/adc_sar/xschem/adc_cosim_tb.sch)
│
├── sim/                                       ← Netlists ngspice (Fase 5)
│   ├── schmitt_tb.sp                          🔲 [FASE 5]
│   ├── r2r_mc.sp                              🔲 [FASE 5] Monte Carlo R-2R
│   │                                                   (partir de ip/dac_r2r/sim/full_spice_sim.cir)
│   ├── corners.sp                             🔲 [FASE 5] TT/SS/FF
│   └── results/                               🔲 [FASE 5] Archivos .raw de ngspice
│
├── notebooks/                                 ← Análisis Python/Jupyter (Fases 3, 5)
│   ├── error_analysis.ipynb                   🔲 [FASE 3] Error vs frecuencia (RTL)
│   ├── error_analysis_spice.ipynb             🔲 [FASE 5] Error vs frecuencia (SPICE)
│   ├── enob_analysis.ipynb                    🔲 [FASE 5] ENOB/SFDR del ADC
│   ├── monte_carlo.ipynb                      🔲 [FASE 5] THD/DNL/INL del DAC
│   └── characterization_report.pdf            🔲 [FASE 5] Reporte exportado
│
├── gds/                                       ← Bloque digital hardened (Fase 6)
│   ├── freq_top.gds                           🔲 [FASE 6]
│   ├── freq_top.lef                           🔲 [FASE 6]
│   └── reports/
│       ├── sta_report.txt                     🔲 [FASE 6]
│       ├── drc_report.txt                     🔲 [FASE 6]
│       └── lvs_report.txt                     🔲 [FASE 6]
│
└── caravel/                                   ← Integración Caravel (Fase 7)
    ├── user_project_wrapper.v                 🔲 [FASE 7]
    ├── config.json                            🔲 [FASE 7]
    └── firmware/
        ├── freq_meter_test.c                  🔲 [FASE 7]
        └── freq_meter_test.hex                🔲 [FASE 7]
```

---

## Archivos clave de las IPs para cada fase

| Fase | Archivo de IP a usar | Propósito |
|---|---|---|
| Fase 2 | `ip/dac_r2r/verilog/rtl/r2r_dac_control.v` | Referencia de pines para `dac_ctrl.v` |
| Fase 2 | `ip/adc_sar/verilog/sar_ctrl.v` | Referencia de pines para `adc_ctrl.v` |
| Fase 3 | `ip/dac_r2r/verilog/test/test.py` | Referencia del test cocotb original del DAC |
| Fase 3 | `ip/adc_sar/verilog/adc_testbench.v` | Referencia del testbench Verilog del ADC |
| Fase 4 | `ip/adc_sar/xschem/adc_cosim_tb.sch` | Base para el TB de cosimulación propio |
| Fase 4 | `ip/dac_r2r/xschem/r2r.sym` | Símbolo Xschem de la red R-2R |
| Fase 5 | `ip/dac_r2r/sim/full_spice_sim.cir` | Base para simulación Monte Carlo |
| Fase 5 | `ip/dac_r2r/mag/r2r.sim.spice` | Netlist PEX de la red R-2R con parásitos |
| Fase 5 | `ip/adc_sar/netlist/schematic/*.spice` | Netlist del ADC para ngspice |
| Fase 6 | `ip/dac_r2r/gds/tt_um_mattvenn_r2r_dac.gds` | Macro GDS del DAC para el wrapper |
| Fase 6 | `ip/dac_r2r/lef/tt_um_mattvenn_r2r_dac.lef` | LEF del DAC para P&R |
| Fase 6 | `ip/adc_sar/gds/sky130_ef_ip__adc3v_12bit.gds.gz` | Macro GDS del ADC (descomprimir) |
| Fase 6 | `ip/adc_sar/lef/sky130_ef_ip__adc3v_12bit.lef` | LEF del ADC para P&R |

---

## Pendientes verificar antes de Fase 2

- [ ] Leer `ip/adc_sar/docs/sky130_ef_ip__adc3v_12bit.md` — confirmar SIZE=12 en wrapper
- [ ] Leer `ip/dac_r2r/sim/README.md` — confirmar frecuencia máxima de operación del DAC
- [ ] Leer `ip/adc_sar/verilog/README.md` — instrucciones de uso del modelo Verilog

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Junio 2025 | Versión inicial basada en estructura anticipada |
| 2.0 | Junio 2025 | Actualizado con estructura real de repos clonados; pines verificados |
