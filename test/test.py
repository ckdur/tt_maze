# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
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

    # Set the input values to zero
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    internals = False  # Enable internals to debug. Post-layout of couse doesn't work

    # Just checking the VGA timings
    # A copy of the hsync_generator parameters in python
    # horizontal constants
    H_DISPLAY       = 640; # horizontal display width
    H_BACK          =  48; # horizontal left border (back porch)
    H_FRONT         =  16; # horizontal right border (front porch)
    H_SYNC          =  96; # horizontal sync width
    # vertical constants
    V_DISPLAY       = 480; # vertical display height
    V_TOP           =  33; # vertical top border
    V_BOTTOM        =  10; # vertical bottom border
    V_SYNC          =   2; # vertical sync # lines
    # derived constants
    H_SYNC_START    = H_DISPLAY + H_FRONT;
    H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
    H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    V_SYNC_START    = V_DISPLAY + V_BOTTOM;
    V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;
    CYCLES_PER_TICK = 1  # This is if we are using a divisor or a pre-scaler

    # Wait for one clock cycle to see the output values
    heval = False
    veval = False
    hpos = 0
    vpos = 0
    latchd_hval = False
    latchd_vval = False
    hval = not (hpos>=H_SYNC_START and hpos<=H_SYNC_END)
    vval = not (vpos>=V_SYNC_START and vpos<=V_SYNC_END)
    while not heval or not veval:
        await ClockCycles(dut.clk, CYCLES_PER_TICK)
        
        if internals:
            if dut.user_project.hvsync_gen.hpos.value != hpos:
                dut._log.info(f"WARNING: hpos do not match: {dut.user_project.hvsync_gen.hpos.value} != {hpos}")

        assert bool(dut.uo_out.value[7]) == latchd_hval, f"XPos {hpos} not match hsync"
        assert bool(dut.uo_out.value[3]) == latchd_vval, f"VPos {vpos} not match vsync"

        # Is registered, so should be 1 clock cycle delayed
        latchd_hval = hval
        latchd_vval = vval

        hpos = hpos + 1
        if hpos >= (H_MAX+1):
            hpos = 0
            heval = True
            vpos = vpos + 1
            if vpos >= (V_MAX+1):
                vpos = 0
                veval = True

        hval = not (hpos>=H_SYNC_START and hpos<=H_SYNC_END)
        vval = not (vpos>=V_SYNC_START and vpos<=V_SYNC_END)
