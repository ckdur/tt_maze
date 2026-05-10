# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(abspath ..)/src
PROJECT_SOURCES = tt_um_maze.v hsync_generator.v gamepad_pmod.v maze.v prbs_generator.v single_port_sync_ram.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(abspath .)/gate_level_netlist.v
endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(abspath .)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

VGA_PLAYGROUND_DIR=$(abspath .)/vga-playground
# Just some additional tests using vga-playground
playground: $(VGA_PLAYGROUND_DIR)/src/examples/maze/index.ts
	cd $(VGA_PLAYGROUND_DIR) && npm install && npm start

.PHONY: $(SRC_DIR)/index.ts
$(VGA_PLAYGROUND_DIR)/src/examples/maze/index.ts: $(VGA_PLAYGROUND_DIR)/index.html $(SRC_DIR)/index.ts $(SRC_DIR)/menu.ts
# Hackish af. Please kill me
	mkdir -p $(VGA_PLAYGROUND_DIR)/src/examples/maze/
	cp -r $(SRC_DIR)/* $(VGA_PLAYGROUND_DIR)/src/examples/maze/
	cp $(SRC_DIR)/menu.ts $(VGA_PLAYGROUND_DIR)/src/examples/index.ts
ifeq ($(GATES),yes)
# Copy the netlist and the gates also
	echo "\`timescale 1ns / 1ps" > $(VGA_PLAYGROUND_DIR)/src/examples/maze/tt_um_maze.nl.v
	cat $(abspath ..)/runs/wokwi/final/nl/tt_um_maze.nl.v >> $(VGA_PLAYGROUND_DIR)/src/examples/maze/tt_um_maze.nl.v
	cp $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v $(VGA_PLAYGROUND_DIR)/src/examples/maze/
	echo "" > $(VGA_PLAYGROUND_DIR)/src/examples/maze/sky130_fd_sc_hd.v
#	echo "\`define FUNCTIONAL" > $(VGA_PLAYGROUND_DIR)/src/examples/maze/sky130_fd_sc_hd.v
	cat $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v >> $(VGA_PLAYGROUND_DIR)/src/examples/maze/sky130_fd_sc_hd.v
	cp $(SRC_DIR)/index.postlayout.ts $(VGA_PLAYGROUND_DIR)/src/examples/maze/index.ts
endif

$(VGA_PLAYGROUND_DIR)/index.html:
# Hackish af. Please kill me
	cd $(abspath .) && git clone https://github.com/TinyTapeout/vga-playground.git

ifeq ($(GATES_COPY),yes)
POST_LAYOUT_SOURCE = $(abspath ..)/runs/wokwi/final/pnl/tt_um_maze.pnl.v

.PHONY: $(abspath .)/gate_level_netlist.v
$(abspath .)/gate_level_netlist.v: $(POST_LAYOUT_SOURCE)
	cp $(POST_LAYOUT_SOURCE) $(abspath .)/gate_level_netlist.v
endif
