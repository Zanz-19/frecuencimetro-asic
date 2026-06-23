# Archivo    : tests/test_freq_top.py
# Proyecto   : Frecuencímetro ASIC sky130A
# Autor      : Jose (Zanz-19)
# Fecha      : Junio 2025
# Descripción: Test principal de Fase 3 (cocotb 2.0). Barrido de frecuencias
#              automatizado sobre tb_top.v (freq_top + ambas IPs reales),
#              con análisis de error relativo usando Python/matplotlib.
#
# NOTA DE VERSIÓN: este test usa la API de cocotb 2.0 (cocotb.start_soon,
# no cocotb.fork; Logic/LogicArray, no BinaryValue). Si en tu máquina tienes
# cocotb 1.x instalado, instala con: pip install --upgrade cocotb
#
# Uso:
#   cd tests/
#   python3 test_freq_top.py

import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

# ---------------------------------------------------------------------------
# Constantes del sistema (coinciden con spec.md / pin_map.md verificados)
# ---------------------------------------------------------------------------
CLK_PERIOD_NS = 10  # 100 MHz, igual que en todos los testbenches de Fase 2

ADDR_FREQ_RESULT = 0x00
ADDR_GATE_CFG    = 0x04
ADDR_ADC_DATA    = 0x08
ADDR_DAC_WORD    = 0x0C
ADDR_STATUS      = 0x10
ADDR_CTRL        = 0x14


# ---------------------------------------------------------------------------
# Helpers de bus Wishbone (equivalentes a las tareas wb_write/wb_read de los
# testbenches Verilog de Fase 2, pero en Python)
# ---------------------------------------------------------------------------
async def wb_write(dut, addr, data):
    """Escritura Wishbone de 1 ciclo. Sigue la misma regla del '#1' de Fase 2:
    se espera el flanco de reloj completo antes de bajar las señales de
    control, evitando carreras de simulación entre cocotb y el DUT."""
    dut.wbs_adr_i.value = addr
    dut.wbs_dat_i.value = data
    dut.wbs_we_i.value  = 1
    dut.wbs_sel_i.value = 0xF
    dut.wbs_stb_i.value = 1
    dut.wbs_cyc_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")  # margen equivalente al #1 de los TB Verilog
    dut.wbs_stb_i.value = 0
    dut.wbs_cyc_i.value = 0
    dut.wbs_we_i.value  = 0


async def wb_read(dut, addr):
    """Lectura Wishbone de 1 ciclo. Devuelve el valor leído como entero."""
    dut.wbs_adr_i.value = addr
    dut.wbs_we_i.value  = 0
    dut.wbs_sel_i.value = 0xF
    dut.wbs_stb_i.value = 1
    dut.wbs_cyc_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    data = int(dut.wbs_dat_o.value)
    dut.wbs_stb_i.value = 0
    dut.wbs_cyc_i.value = 0
    return data


async def soft_reset_with_gate(dut, gate_cycles):
    """Configura GATE_CFG y fuerza un soft_rst para que la FSM general
    arranque limpiamente con el nuevo valor (lección de Fase 2: la FSM
    arranca sola tras el reset global con el T_gate default de 1s, así
    que reconfigurar a mitad de una ventana de 1s sería impracticable
    para simular; soft_rst la reinicia de inmediato)."""
    await wb_write(dut, ADDR_GATE_CFG, gate_cycles)
    await wb_write(dut, ADDR_CTRL, 0x1)  # bit0 = soft_rst (pulso, autoclear)
    await ClockCycles(dut.clk, 3)


async def generate_fx_external(dut, freq_hz, duration_ns):
    """Genera fx_in_external como onda cuadrada de freq_hz durante
    duration_ns nanosegundos, usando Timer (no depende del reloj del
    sistema, igual que generate_fx_for_duration en los TB de Fase 2)."""
    half_period_ns = (1e9 / freq_hz) / 2.0
    dut.fx_in_external.value = 0
    elapsed = 0.0
    while elapsed < duration_ns:
        await Timer(half_period_ns, unit="ns")
        dut.fx_in_external.value = 1 - int(dut.fx_in_external.value)
        elapsed += half_period_ns
    dut.fx_in_external.value = 0


async def reset_dut(dut):
    """Secuencia de reset estándar usada en todos los tests de este archivo."""
    dut.rst_n.value = 0
    dut.wbs_stb_i.value = 0
    dut.wbs_cyc_i.value = 0
    dut.wbs_we_i.value = 0
    dut.wbs_sel_i.value = 0
    dut.wbs_dat_i.value = 0
    dut.wbs_adr_i.value = 0
    dut.fx_in_external.value = 0
    dut.selftest_mode.value = 0
    dut.target_value.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


# ---------------------------------------------------------------------------
# Test principal: barrido de frecuencias
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_frequency_sweep(dut):
    """Mide un conjunto de frecuencias conocidas y registra el error
    relativo de cada una. Los resultados se exportan a CSV para que
    el análisis posterior (fuera de cocotb) genere las gráficas."""

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Barrido de frecuencias: cada tupla es (freq_hz, gate_cycles)
    # gate_cycles se elige para que la simulación sea rápida (T_gate corto)
    # mientras se mantiene una resolución razonable para el conteo esperado.
    sweep_plan = [
        (1_000,    100_000),   # 1 kHz,   T_gate=1ms   -> esperado ~1
        (10_000,   100_000),   # 10 kHz,  T_gate=1ms   -> esperado ~10
        (100_000,  100_000),   # 100 kHz, T_gate=1ms   -> esperado ~100
        (500_000,   50_000),   # 500 kHz, T_gate=0.5ms -> esperado ~250
        (1_000_000, 50_000),   # 1 MHz,   T_gate=0.5ms -> esperado ~500
    ]

    results = []

    for freq_hz, gate_cycles in sweep_plan:
        await soft_reset_with_gate(dut, gate_cycles)

        t_gate_s = gate_cycles * CLK_PERIOD_NS * 1e-9
        expected = freq_hz * t_gate_s
        # Duración de estímulo con margen: T_gate + unos ciclos de sobra
        duration_ns = gate_cycles * CLK_PERIOD_NS + 200

        # Generar la señal y esperar el ciclo de medición en paralelo,
        # igual que el patrón fork/join de los testbenches Verilog
        gen_task = cocotb.start_soon(generate_fx_external(dut, freq_hz, duration_ns))

        await RisingEdge(dut.gate_active_out)
        await FallingEdge(dut.gate_active_out)
        await ClockCycles(dut.clk, 2)

        await gen_task  # asegurar que el generador terminó limpiamente

        measured = await wb_read(dut, ADDR_FREQ_RESULT)
        error_pct = abs(measured - expected) / expected * 100 if expected > 0 else 0.0

        results.append({
            "freq_hz": freq_hz,
            "gate_cycles": gate_cycles,
            "t_gate_s": t_gate_s,
            "expected": expected,
            "measured": measured,
            "error_pct": error_pct,
        })

        dut._log.info(
            f"fx={freq_hz:>9} Hz | T_gate={t_gate_s*1e6:>8.1f} us | "
            f"esperado={expected:>8.2f} | medido={measured:>6d} | "
            f"error={error_pct:>6.2f}%"
        )

    # Exportar resultados a CSV para el análisis posterior con matplotlib
    csv_path = Path(__file__).parent / "sweep_results.csv"
    with open(csv_path, "w") as f:
        f.write("freq_hz,gate_cycles,t_gate_s,expected,measured,error_pct\n")
        for r in results:
            f.write(f"{r['freq_hz']},{r['gate_cycles']},{r['t_gate_s']},"
                    f"{r['expected']},{r['measured']},{r['error_pct']}\n")

    dut._log.info(f"Resultados exportados a {csv_path}")

    # Criterio de aceptación de Fase 3 (spec.md): error <= algunos % en
    # T_gate cortos (con T_gate=1s real el error seria <=1Hz/freq*100)
    for r in results:
        assert r["error_pct"] < 5.0, (
            f"Error excesivo en fx={r['freq_hz']}Hz: {r['error_pct']:.2f}% "
            f"(esperado={r['expected']}, medido={r['measured']})"
        )


# ---------------------------------------------------------------------------
# Test: selftest completo (DAC -> modelo Schmitt -> freq_counter)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_selftest_loop(dut):
    """Verifica el camino de selftest: el DAC genera una rampa interna,
    el modelo de Schmitt (en tb_top.v) la convierte en pulsos digitales,
    y freq_counter mide esa frecuencia. No se compara contra un valor
    exacto (depende de la velocidad real de la rampa), solo se confirma
    que el lazo completo produce una medición mayor a cero.

    IMPORTANTE #1: CTRL es un registro de "golpe completo" — cada
    escritura reemplaza TODOS sus bits, no solo el que nos interesa
    (verificado en Fase 2, wb_regs.v 30/30 tests). Por eso aquí primero
    se configura T_gate (que internamente escribe CTRL con soft_rst=1
    y todo lo demás en 0), y SOLO DESPUÉS se configura el modo selftest
    del DAC — si el orden fuera al revés, la escritura de
    soft_reset_with_gate borraría la configuración de dac_ext_data.

    IMPORTANTE #2: la rampa del DAC (divisor=0) tarda ~256 pasos en dar
    una vuelta completa (0->255->0). Si T_gate es más corto que ese
    período, dependiendo de la FASE en que arranque la ventana, es
    posible no ver ningún flanco de subida del modelo de Schmitt.
    T_gate=500us cubre varios períodos completos sin importar la fase.
    """

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    await soft_reset_with_gate(dut, 50_000)  # T_gate = 500us

    await wb_write(dut, ADDR_DAC_WORD, 0)        # DAC_WORD=0 (sera el divisor)
    await wb_write(dut, ADDR_CTRL, 0x10)         # bit4=dac_load_div (pulso)
    await ClockCycles(dut.clk, 2)
    await wb_write(dut, ADDR_CTRL, 0x00)         # bit3=dac_ext_data=0 -> selftest

    dut.selftest_mode.value = 1

    # gate_active_out ya puede estar en 1 en este punto (la FSM general
    # corre en loop continuo desde el reset) — esperamos primero a que la
    # ventana en curso termine, y luego una ventana completa nueva.
    if dut.gate_active_out.value == 1:
        await FallingEdge(dut.gate_active_out)
    await RisingEdge(dut.gate_active_out)
    await FallingEdge(dut.gate_active_out)
    await ClockCycles(dut.clk, 2)

    measured = await wb_read(dut, ADDR_FREQ_RESULT)
    dut._log.info(f"Selftest FREQ_RESULT = {measured}")

    dut.selftest_mode.value = 0

    assert measured > 0, "El lazo de selftest DAC->Schmitt->freq_counter no produjo conteos"


# ---------------------------------------------------------------------------
# Test: ADC en paralelo, no interfiere con la medición de frecuencia
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_adc_parallel_operation(dut):
    """Reproduce el Caso 4 de Fase 2 en cocotb: el ADC convierte un valor
    conocido mientras freq_counter sigue midiendo, sin que se interfieran."""

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.target_value.value = 0x555

    # Disparar una conversión (single-shot emulado con continuous_adc)
    await wb_write(dut, ADDR_CTRL, 0x04)  # continuous_adc=1

    # Esperar a que arranque, luego desactivar para no encadenar otra
    timeout = 0
    while int(dut.adc_ready_out.value) != 1 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    await wb_write(dut, ADDR_CTRL, 0x00)

    assert timeout < 100, "El ADC no completo la conversion a tiempo"

    adc_data = await wb_read(dut, ADDR_ADC_DATA)
    dut._log.info(f"ADC_DATA leido = 0x{adc_data:03X} (esperado 0x555)")
    assert adc_data == 0x555, f"ADC_DATA incorrecto: 0x{adc_data:03X}"

    # Confirmar que gate_active sigue su ciclo normal (no se detuvo)
    timeout = 0
    while int(dut.gate_active_out.value) != 1 and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    assert timeout < 50, "gate_active no se reanudo tras la operacion del ADC"
