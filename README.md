# Frecuencímetro ASIC — sky130A

Frecuencímetro digital de señal mixta implementado como ASIC en el proceso CMOS sky130A de SkyWater Technology, integrado dentro del `user_project_wrapper` de Caravel (efabless).

## IPs integradas

| IP | Repositorio | Resolución | Rol |
|---|---|---|---|
| DAC R-2R | [mattvenn/tt06-analog-r2r-dac](https://github.com/mattvenn/tt06-analog-r2r-dac) | 8 bits | Generador de señal de prueba interna (selftest) |
| ADC SAR | [chipfoundry/sky130_ef_ip__adc3v_12bit](https://github.com/chipfoundry/sky130_ef_ip__adc3v_12bit) | 12 bits | Análisis de amplitud de la señal (Camino B) |

## Especificaciones rápidas

- **Rango de medición:** 1 Hz – 500 kHz
- **Resolución:** 1 Hz (con T_gate = 1 s)
- **Error máximo:** ±1 Hz (cuantización inherente)
- **Interfaz:** Bus Wishbone + Logic Analyzer de Caravel
- **Tensión:** 1.8 V (digital) / 3.3 V (analógico)
- **Timing ADC verificado:** 15 + swidth ciclos de clk por conversión (SIZE=12)
- **Reset DAC verificado:** `dac_n_rst = rst_n`, sin inversión (ver hallazgos abajo)
- **Schmitt trigger:** histéresis garantizada ≥23.4 mV (peor caso PVT), típica 43.5 mV — ver Detalle de Fase 5

## Estructura del proyecto

Ver [`spec/project_tree.md`](spec/project_tree.md) para el árbol completo de archivos.

## Plan de implementación

Ver [`spec/plan_maestro_frecuencimetro.md`](spec/plan_maestro_frecuencimetro.md) para la definición completa de cada fase (objetivo, tareas, entregables), [`spec/module_list.md`](spec/module_list.md) para los contratos de interfaz de cada módulo, y [`spec/pin_map.md`](spec/pin_map.md) para el mapa de pines verificado por simulación.

## Clonar las IPs

```bash
cd ip/
git clone https://github.com/mattvenn/tt06-analog-r2r-dac.git dac_r2r
git clone https://github.com/chipfoundry/sky130_ef_ip__adc3v_12bit.git adc_sar
```

## Correr las simulaciones

```bash
# Módulo simple, sin dependencias externas
make sim MODULE=cdc_sync

# Módulo que integra una IP real
make sim MODULE=adc_ctrl EXTRA_SRC=ip/adc_sar/verilog/sar_ctrl.v

# Integración completa (freq_top compila automáticamente todos los rtl/*.v)
make sim MODULE=freq_top EXTRA_SRC="ip/adc_sar/verilog/sar_ctrl.v ip/dac_r2r/verilog/rtl/r2r_dac_control.v"

# Ver las formas de onda del último módulo simulado
make wave MODULE=<nombre>

# Suite de Fase 3 (cocotb): barrido de frecuencias + análisis Python
make cocotb
```

## Estado actual

| Fase | Estado |
|---|---|
| Fase 1 — Especificación | ✅ Completada |
| Fase 2 — RTL Verilog | ✅ **Completada — 118/118 tests, 8/8 módulos** |
| Fase 3 — Verificación cocotb | ✅ **Completada — 3/3 tests** |
| Fase 4 — Xschem analógico | 🟡 **En progreso — `schmitt_trigger.sch` diseñado.** Faltan símbolos de las IPs y `tb_adc_dac_loop.sch` |
| Fase 5 — Simulaciones ngspice | 🟡 **En progreso — Schmitt trigger caracterizado (histéresis + velocidad, PVT completo).** Falta ENOB del ADC y Monte Carlo del DAC |
| Fase 6 — Síntesis LibreLane | 🔲 Pendiente |
| Fase 7 — Integración Caravel | 🔲 Pendiente |

### Detalle de Fase 2 — módulos verificados

| Módulo | Tests | IP real integrada |
|---|---|---|
| `cdc_sync.v` | 12/12 ✅ | — |
| `gate_timer.v` | 12/12 ✅ | — |
| `freq_counter.v` | 9/9 ✅ | — |
| `result_latch.v` | 14/14 ✅ | — |
| `adc_ctrl.v` | 13/13 ✅ | `sar_ctrl.v` (chipfoundry) |
| `dac_ctrl.v` | 20/20 ✅ | `r2r_dac_control.v` (mattvenn) |
| `wb_regs.v` | 30/30 ✅ | — |
| `freq_top.v` | 12/12 ✅ | ambas IPs simultáneamente |

### Detalle de Fase 3 — verificación con cocotb 2.0

Suite en `tests/`, corrida con `make cocotb` (Python Runner de cocotb 2.0, no el Makefile clásico de 1.x — ver nota de versión en `tests/runner.py`).

| Test | Resultado | Qué verifica |
|---|---|---|
| `test_frequency_sweep` | ✅ | Barrido 1 kHz–1 MHz, error relativo 0.00% en todos los puntos |
| `test_selftest_loop` | ✅ | Camino completo DAC → modelo de Schmitt → freq_counter → FREQ_RESULT |
| `test_adc_parallel_operation` | ✅ | ADC convirtiendo en paralelo sin interferir con la medición de frecuencia |

`make cocotb` genera además `tests/error_vs_frequency.png` (gráfica log-log de error medido vs error teórico de cuantización) y `tests/sweep_summary.md` (tabla de resultados) — ambos regenerables, no versionados.

### Detalle de Fase 4 — Xschem analógico (en progreso)

Por el plan maestro (`spec/plan_maestro_frecuencimetro.md`), Fase 4 es **solo** captura de esquemáticos — sin ejecutar simulación todavía. Entregables:

| Archivo | Estado |
|---|---|
| `xschem/schmitt_trigger.sch` | ✅ Diseñado — topología CMOS de 6 transistores (2 PMOS + 2 NMOS principales en serie, 1 PMOS + 1 NMOS de realimentación en paralelo, gate de realimentación = vout) |
| `xschem/dac_ip.sym` | 🔲 Pendiente — símbolo Xschem de la IP del DAC R-2R |
| `xschem/adc_ip.sym` | 🔲 Pendiente — símbolo Xschem de la IP del ADC SAR |
| `xschem/tb_schmitt.sch` | 🔲 Pendiente — testbench Xschem con fuente de ruido superpuesto (lo que sí se hizo fue el equivalente en SPICE puro, ver Fase 5 abajo, no como esquemático Xschem) |
| `xschem/tb_adc_dac_loop.sch` | 🔲 Pendiente — testbench de lazo cerrado DAC→ADC |

### Detalle de Fase 5 — Caracterización ngspice del Schmitt trigger (en progreso)

El sizing final de `schmitt_trigger.sch` se validó en ngspice (`sim/schmitt_tb.spice`), cubriendo las tareas 5.1 (transitorio + medición de histéresis) y 5.5 (esquinas de proceso TT/SS/FF) del plan maestro, más un barrido de temperatura adicional no contemplado originalmente.

| Esquina | -40°C | 27°C | 85°C | 125°C |
|---|---|---|---|---|
| TT | 65.95 mV | 43.48 mV | 36.59 mV | 34.12 mV |
| FF | 28.56 mV | 24.52 mV | 23.58 mV | 23.36 mV (peor caso) |
| SS | 142.06 mV | 75.13 mV | 55.97 mV | 49.19 mV |

- **Sizing final:** `MP_FB` W=16.0µm/L=64.0µm, `MN_FB` W=8.0µm/L=64.0µm (resto de transistores sin cambios)
- **Histéresis garantizada (peor caso PVT):** 23.36 mV — corrige el placeholder de >200mV de `spec.md` v1, que era circular (no derivado de una fuente de ruido real)
- **Velocidad:** peor caso `trise=104ns` a 500kHz (5.2% del periodo) — nunca es el factor limitante
- Detalle completo, incluyendo por qué no se alcanzaron los 200mV originales, en `spec/spec.md` sección 9

**Cómo correr la validación:**
```bash
make simspice       # solo resultados numericos
make waveschmitt    # con graficas (lazo de histeresis + forma de onda)
```

**Pendiente de Fase 5:** 5.2 (barrido automático de frecuencias), 5.3 (Monte Carlo de la red R-2R del DAC), 5.4 (análisis de ENOB del ADC) — ninguna de estas se ha iniciado, ya que requieren los símbolos de las IPs (Fase 4) primero.

### Hallazgos críticos de Fase 2

Durante la verificación con las IPs reales surgieron dos hallazgos que corrigieron suposiciones de diseño hechas en Fase 1 — documentados en detalle en `spec/pin_map.md` y `spec/module_list.md`:

1. **Polaridad de reset del DAC.** Se asumía que el pin `n_rst` de `r2r_dac_control` requería invertir nuestra señal `rst_n`. La IP real demuestra lo contrario: `n_rst` funciona como un enable activo-alto que coincide exactamente con nuestra convención sin inversión.
2. **Captura de datos del ADC a través de `cdc_sync`.** `sar_ctrl.data` solo es válido durante 1 ciclo (el estado `DONE`), mientras que `cdc_sync` introduce 2 ciclos de latencia en la señal de notificación `eoc`. Sin un registro de captura inmediata (`adc_data_latch` en `freq_top.v`, disparado por el `eoc` crudo sin sincronizar), el dato se pierde antes de que el resto del sistema pueda reaccionar a la notificación ya sincronizada.

### Qué significa "Fase 2 y 3 completadas"

El núcleo 100% digital del frecuencímetro está diseñado y verificado en simulación —tanto con testbenches Verilog puros (Fase 2) como con cocotb/Python (Fase 3)—, incluyendo su interacción con el comportamiento real (no simplificado) de ambas IPs analógicas. Esto **no** equivale a tener un chip funcional todavía — faltan piezas bloqueantes:

- **Fase 4:** el Schmitt trigger ya existe como esquemático (`xschem/schmitt_trigger.sch`), pero faltan los símbolos Xschem de las dos IPs y el testbench que cierra el lazo DAC→ADC.
- **Fase 5:** el sizing del Schmitt trigger ya está caracterizado en ngspice (histéresis + velocidad, PVT completo — ver Detalle de Fase 5 arriba), pero el ADC y el DAC aún no se han simulado (falta ENOB del ADC y Monte Carlo de la red R-2R del DAC). Tampoco existe layout (GDS) de nada todavía.
- **Fase 6:** el RTL nunca se ha sintetizado a un layout físico (GDS). Sin esto no existe ninguna posibilidad de fabricación.
- **Fase 7:** las dos IPs reales nunca se han instanciado físicamente junto al núcleo digital — solo se simularon juntas en software durante Fases 2 y 3.

## Próximo paso

Terminar Fase 4 (Xschem): crear `dac_ip.sym` y `adc_ip.sym` (símbolos de las dos IPs), y construir `tb_adc_dac_loop.sch` — el testbench de interfaz analógica que cierra el lazo DAC→ADC con componentes verdaderamente analógicos, no modelos digitales de comportamiento. Una vez existan esos símbolos, continuar Fase 5 con las tareas 5.3 (Monte Carlo de la red R-2R) y 5.4 (ENOB del ADC).
