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

## Estructura del proyecto

Ver [`spec/project_tree.md`](spec/project_tree.md) para el árbol completo de archivos.

## Plan de implementación

Ver [`spec/module_list.md`](spec/module_list.md) para los contratos de interfaz de cada módulo.

## Clonar las IPs

```bash
cd ip/
git clone https://github.com/mattvenn/tt06-analog-r2r-dac.git dac_r2r
git clone https://github.com/chipfoundry/sky130_ef_ip__adc3v_12bit.git adc_sar
```

## Estado actual

| Fase | Estado |
|---|---|
| Fase 1 — Especificación | ✅ Completada |
| Fase 2 — RTL Verilog | 🔲 Pendiente |
| Fase 3 — Verificación cocotb | 🔲 Pendiente |
| Fase 4 — Xschem analógico | 🔲 Pendiente |
| Fase 5 — Simulaciones ngspice | 🔲 Pendiente |
| Fase 6 — Síntesis LibreLane | 🔲 Pendiente |
| Fase 7 — Integración Caravel | 🔲 Pendiente |
