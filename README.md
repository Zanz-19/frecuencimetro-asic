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

## Estructura del proyecto

Ver [`spec/project_tree.md`](spec/project_tree.md) para el árbol completo de archivos.

## Plan de implementación

Ver [`spec/module_list.md`](spec/module_list.md) para los contratos de interfaz de cada módulo, y [`spec/pin_map.md`](spec/pin_map.md) para el mapa de pines verificado por simulación.

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
```

## Estado actual

| Fase | Estado |
|---|---|
| Fase 1 — Especificación | ✅ Completada |
| Fase 2 — RTL Verilog | ✅ **Completada — 118/118 tests, 8/8 módulos** |
| Fase 3 — Verificación cocotb | 🔲 Pendiente |
| Fase 4 — Xschem analógico | 🔲 Pendiente |
| Fase 5 — Simulaciones ngspice | 🔲 Pendiente |
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

### Hallazgos críticos de Fase 2

Durante la verificación con las IPs reales surgieron dos hallazgos que corrigieron suposiciones de diseño hechas en Fase 1 — documentados en detalle en `spec/pin_map.md` y `spec/module_list.md`:

1. **Polaridad de reset del DAC.** Se asumía que el pin `n_rst` de `r2r_dac_control` requería invertir nuestra señal `rst_n`. La IP real demuestra lo contrario: `n_rst` funciona como un enable activo-alto que coincide exactamente con nuestra convención sin inversión.
2. **Captura de datos del ADC a través de `cdc_sync`.** `sar_ctrl.data` solo es válido durante 1 ciclo (el estado `DONE`), mientras que `cdc_sync` introduce 2 ciclos de latencia en la señal de notificación `eoc`. Sin un registro de captura inmediata (`adc_data_latch` en `freq_top.v`, disparado por el `eoc` crudo sin sincronizar), el dato se pierde antes de que el resto del sistema pueda reaccionar a la notificación ya sincronizada.

### Qué significa "Fase 2 completada"

El núcleo 100% digital del frecuencímetro está diseñado y verificado en simulación, incluyendo su interacción con el comportamiento real (no simplificado) de ambas IPs analógicas. Esto **no** equivale a tener un chip funcional todavía — faltan piezas bloqueantes:

- **Fase 4:** el Schmitt trigger que convierte la señal analógica externa en pulsos digitales no existe aún ni en diseño ni en layout. Hoy `fx_in` se alimenta directamente en simulación.
- **Fase 6:** el RTL nunca se ha sintetizado a un layout físico (GDS). Sin esto no existe ninguna posibilidad de fabricación.
- **Fase 7:** las dos IPs reales nunca se han instanciado físicamente junto al núcleo digital — solo se simularon juntas en software durante Fase 2.

## Próximo paso

Actualizar `spec/spec.md`, `spec/pin_map.md` y `spec/module_list.md` con el cierre formal de Fase 2 (ya en curso), y luego decidir si se avanza a Fase 3 (cocotb) o directo a Fase 4 (Xschem), dado que el Schmitt trigger es la pieza bloqueante más temprana en la ruta crítica hacia un chip fabricable.
