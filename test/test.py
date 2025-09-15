import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def reset(dut):
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	dut.ena.value = 1
	dut.rst_n.value = 0
	await ClockCycles(dut.clk, 1)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 1)

@cocotb.test()
async def memory_test(dut):
	clock = Clock(dut.clk, 10, units="us")
	cocotb.start_soon(clock.start())
	await reset(dut);

	dut.ui_in.value = 0b_0100_1011
	dut.uio_in.value = 0b_0110_000_1
	await ClockCycles(dut.clk, 2)

	assert dut.uo_out.value == 0b_0100_1011
	dut._log.info("memory test passed")

@cocotb.test()
async def multilayer_test(dut):
	clock = Clock(dut.clk, 10, units="us")
	cocotb.start_soon(clock.start())
	await reset(dut);

	dut.ui_in.value = 0b_0110_0101
	dut.uio_in.value = 0b_1000_110_0
	await ClockCycles(dut.clk, 4)

	assert dut.uo_out.value == 0b00110010
	assert dut.uo_out.value == 0b00000000
	dut._log.info("multilayer test passed")

