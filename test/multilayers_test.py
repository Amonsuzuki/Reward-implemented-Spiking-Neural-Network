import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

INPUT1 = 0b110
INPUT2 = 0b101
INPUT3 = 0b1000
INPUT4 = 0b110
#ANSWER = 0b11001000
ANSWER = 0b00110010

@cocotb.test()
async def test_project(dut):
	dut._log.info("start")
	
	clock = Clock(dut.clk, 10, units="us")
	cocotb.start_soon(clock.start())

	# Reset
	dut._log.info("reset")
	dut.ena.value = 1
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	dut.rst_n.value = 0
	await ClockCycles(dut.clk, 5)
	dut.rst_n.value = 1

	dut._log.info("Initial Add")

	# Input
	dut.ui_in.value = ((INPUT1 & 0xF) << 4) | (INPUT2 & 0xF)
	dut.uio_in.value = ((INPUT3 & 0xF) << 4) | (INPUT4 & 0xF)
	await ClockCycles(dut.clk, 5)
	assert dut.uo_out.value == ANSWER, \
		f"The output {int(dut.uo_out.value):08b}, and answer {ANSWER:08b} did not match"

	dut.log.info("multi layer test passed")
