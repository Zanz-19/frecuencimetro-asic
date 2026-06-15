# Árbol de Archivos del Proyecto — Frecuencímetro ASIC
**Leyenda de estado:**
- ✅ `[EXISTE]` — archivo proveniente del repositorio original de la IP
- 🔲 `[PENDIENTE]` — archivo a crear en la fase indicada
- 📋 `[FASE N]` — fase en que se genera este archivo

---

```
frecuencimetro_asic/
│
├── 📄 README.md                              🔲 [FASE 1] Descripción general del proyecto
│
├── spec/                                     ← Documentación de especificaciones (Fase 1)
│   ├── spec.md                               ✅ [FASE 1] Especificaciones del sistema
│   ├── pin_map.md                            ✅ [FASE 1] Asignación de pines Caravel
│   ├── module_list.md                        ✅ [FASE 1] Contratos de interfaz de módulos
│   └── project_tree.md                       ✅ [FASE 1] Este archivo
│
├── ip/                                       ← IPs externas (submodules git o copia)
│   │
│   ├── dac_r2r/                              ← mattvenn/tt06-analog-r2r-dac
│   │   ├── xschem/
│   │   │   ├── r2r_dac.sch                  ✅ [EXISTE] Esquemático principal del DAC
│   │   │   ├── r2r_dac.sym                  ✅ [EXISTE] Símbolo Xschem del DAC
│   │   │   └── r2r_dac_tb.sch               ✅ [EXISTE] Testbench original del DAC
│   │   ├── mag/
│   │   │   ├── r2r.mag                      ✅ [EXISTE] Layout Magic de la escalera R-2R
│   │   │   └── r2r.sim.spice                ✅ [EXISTE] Netlist SPICE extraído (PEX)
│   │   ├── gds/
│   │   │   └── tt_um_r2r_dac.gds            ✅ [EXISTE] GDS final hardened
│   │   ├── netlist/
│   │   │   └── tt_um_r2r_dac.spice          ✅ [EXISTE] Netlist SPICE del macro completo
│   │   ├── cace/
│   │   │   └── r2r_dac.yaml                 ✅ [EXISTE] Especificación CACE (si existe)
│   │   └── src/
│   │       └── tt_um_r2r_dac.v              ✅ [EXISTE] Verilog del secuenciador interno
│   │
│   └── adc_sar/                              ← chipfoundry/sky130_ef_ip__adc3v_12bit
│       ├── xschem/
│       │   ├── sky130_ef_ip__adc3v_12bit.sch      ✅ [EXISTE] Esquemático del ADC
│       │   ├── sky130_ef_ip__adc3v_12bit.sym      ✅ [EXISTE] Símbolo Xschem del ADC
│       │   └── sky130_ef_ip__adc3v_12bit_tb.sch   ✅ [EXISTE] Testbench del ADC
│       ├── mag/
│       │   └── sky130_ef_ip__adc3v_12bit.mag ✅ [EXISTE] Layout Magic del ADC
│       ├── gds/
│       │   └── sky130_ef_ip__adc3v_12bit.gds ✅ [EXISTE] GDS final del ADC
│       ├── netlist/
│       │   └── sky130_ef_ip__adc3v_12bit.spice ✅ [EXISTE] Netlist SPICE del ADC
│       ├── cace/
│       │   └── sky130_ef_ip__adc3v_12bit.yaml ✅ [EXISTE] Especificación CACE del ADC
│       └── verilog/
│           └── sky130_ef_ip__adc3v_12bit.v  ✅ [EXISTE] Modelo Verilog behavioral del ADC
│
├── rtl/                                      ← Módulos Verilog del núcleo digital (Fase 2)
│   ├── cdc_sync.v                            🔲 [FASE 2] Sincronizador 2-FF para CDC
│   ├── gate_timer.v                          🔲 [FASE 2] Divisor T_gate configurable (27b)
│   ├── freq_counter.v                        🔲 [FASE 2] Contador de pulsos 32 bits
│   ├── result_latch.v                        🔲 [FASE 2] Registro de captura del resultado
│   ├── adc_ctrl.v                            🔲 [FASE 2] Controlador del ADC SAR
│   ├── dac_ctrl.v                            🔲 [FASE 2] Controlador del DAC R-2R
│   ├── wb_regs.v                             🔲 [FASE 2] Mapa de registros Wishbone
│   └── freq_top.v                            🔲 [FASE 2] Top level: instancia todos
│
├── tb/                                       ← Testbenches iverilog unitarios (Fase 2)
│   ├── tb_cdc_sync.v                         🔲 [FASE 2] TB del sincronizador
│   ├── tb_gate_timer.v                       🔲 [FASE 2] TB del divisor T_gate
│   ├── tb_freq_counter.v                     🔲 [FASE 2] TB del contador de pulsos
│   └── tb_freq_top.v                         🔲 [FASE 2] TB de integración del top level
│
├── tests/                                    ← Testbenches cocotb en Python (Fase 3)
│   ├── Makefile                              🔲 [FASE 3] Makefile para correr cocotb
│   ├── test_freq_top.py                      🔲 [FASE 3] Test principal: barrido de frecuencias
│   ├── test_cdc.py                           🔲 [FASE 3] Test de metaestabilidad CDC
│   └── test_wishbone.py                      🔲 [FASE 3] Test del bus Wishbone
│
├── xschem/                                   ← Esquemáticos Xschem propios (Fase 4)
│   ├── dac_ip.sym                            🔲 [FASE 4] Símbolo del macro DAC (wrapper)
│   ├── adc_ip.sym                            🔲 [FASE 4] Símbolo del macro ADC (wrapper)
│   ├── schmitt_trigger.sch                   🔲 [FASE 4] Diseño del disparador Schmitt
│   ├── tb_schmitt.sch                        🔲 [FASE 4] TB: señal con ruido → Schmitt
│   └── tb_adc_dac_loop.sch                   🔲 [FASE 4] TB: lazo cerrado DAC→ADC
│
├── sim/                                      ← Netlists ngspice y resultados (Fase 5)
│   ├── schmitt_tb.sp                         🔲 [FASE 5] Netlist ngspice del Schmitt
│   ├── r2r_mc.sp                             🔲 [FASE 5] Monte Carlo de la red R-2R
│   ├── corners.sp                            🔲 [FASE 5] Simulación TT/SS/FF corners
│   └── results/                              ← Archivos .raw generados por ngspice
│       ├── schmitt_tran.raw                  🔲 [FASE 5] Resultado transitorio Schmitt
│       ├── mc_run_*.raw                      🔲 [FASE 5] Resultados Monte Carlo
│       └── corners_*.raw                     🔲 [FASE 5] Resultados de corners
│
├── notebooks/                                ← Análisis Python/Jupyter (Fases 3 y 5)
│   ├── error_analysis.ipynb                  🔲 [FASE 3] Error relativo vs frecuencia (RTL)
│   ├── error_analysis_spice.ipynb            🔲 [FASE 5] Error vs frecuencia (ngspice)
│   ├── enob_analysis.ipynb                   🔲 [FASE 5] ENOB/SFDR del ADC SAR
│   ├── monte_carlo.ipynb                     🔲 [FASE 5] THD/DNL/INL del DAC R-2R
│   └── characterization_report.pdf           🔲 [FASE 5] Reporte exportado de los notebooks
│
├── gds/                                      ← GDS del bloque digital hardened (Fase 6)
│   ├── freq_top.gds                          🔲 [FASE 6] GDS del núcleo digital
│   ├── freq_top.lef                          🔲 [FASE 6] LEF del macro digital
│   └── reports/
│       ├── sta_report.txt                    🔲 [FASE 6] Reporte de timing (OpenSTA)
│       ├── drc_report.txt                    🔲 [FASE 6] Reporte DRC (Magic)
│       └── lvs_report.txt                    🔲 [FASE 6] Reporte LVS (Netgen)
│
└── caravel/                                  ← Integración final en Caravel (Fase 7)
    ├── user_project_wrapper.v                🔲 [FASE 7] Wrapper con las 3 IPs instanciadas
    ├── config.json                           🔲 [FASE 7] Configuración LibreLane del wrapper
    └── firmware/
        ├── freq_meter_test.c                 🔲 [FASE 7] Firmware de validación para PicoRV32
        └── freq_meter_test.hex               🔲 [FASE 7] Binario compilado del firmware
```

---

## Resumen de archivos por fase

| Fase | Archivos generados | Total |
|---|---|---|
| Fase 1 (spec) | spec.md, pin_map.md, module_list.md, project_tree.md, README.md | 5 |
| Fase 2 (RTL) | 8 módulos .v + 4 testbenches .v | 12 |
| Fase 3 (cocotb) | Makefile + 3 tests .py + 1 notebook | 5 |
| Fase 4 (Xschem) | 2 símbolos .sym + 3 esquemáticos .sch | 5 |
| Fase 5 (ngspice) | 3 netlists .sp + 4 notebooks + 1 reporte PDF | 8 |
| Fase 6 (LibreLane) | GDS + LEF + 3 reportes | 5 |
| Fase 7 (Caravel) | wrapper .v + config.json + firmware .c + .hex | 4 |
| **IPs externas** | Ya existentes en repositorios originales | ~15 |
| **Total** | | **~59** |

---

## Instrucciones para clonar las IPs

```bash
# Dentro de frecuencimetro_asic/ip/
git clone https://github.com/mattvenn/tt06-analog-r2r-dac.git dac_r2r
git clone https://github.com/chipfoundry/sky130_ef_ip__adc3v_12bit.git adc_sar
```

Una vez clonados, verificar que los archivos marcados como `✅ [EXISTE]` están presentes. Si alguno falta, actualizar este árbol y notificar antes de continuar con la Fase siguiente.

---

## Historial de cambios del árbol

| Fecha | Cambio |
|---|---|
| Junio 2025 | Versión inicial — Fase 1 completada |
| — | Actualizar tras Fase 2: marcar ✅ los módulos RTL creados |
| — | Actualizar tras Fase 3: marcar ✅ los tests cocotb |
| — | Actualizar tras Fase 4: marcar ✅ los esquemáticos Xschem |
| — | Actualizar tras Fase 5: marcar ✅ los notebooks y el PDF |
| — | Actualizar tras Fase 6: marcar ✅ el GDS y los reportes |
| — | Actualizar tras Fase 7: marcar ✅ el wrapper y el firmware |
