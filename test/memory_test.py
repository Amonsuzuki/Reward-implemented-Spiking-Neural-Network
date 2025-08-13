# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

ADDR = 0b0110
DATA = 0b0100_1011


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # After reset, memory read should be 0
    # is this waste?
    """
    dut.ui_in.value = 0
    dut.uio_in.value = ADDR
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0x00, "Memory must be clearde on reset"
    """

    # Prepare data and address
    dut.ui_in.value = DATA
    dut.uio_in.value = ADDR # eliminate if check memory 0 after reset above
    await ClockCycles(dut.clk, 1)

    # Write Cycle
    dut.uio_in.value = (1 << 4) | ADDR # controlling bit
    await ClockCycles(dut.clk, 1)

    # Read cycle
    dut.uio_in.value = ADDR
    await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    assert int(dut.uo_out.value) == DATA, \
        f"Readback mismatch: got {int(dut.uo_out.value):#04x}, expected {DATA:#04x}"

    dut.log.info("Single write/read test passed")

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
