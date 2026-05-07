// Extracted from: https://www.chipverify.com/verilog/verilog-single-port-ram
// Modified to match our requirements

module single_port_sync_ram
  # (parameter ADDR_WIDTH = 4,
     parameter DATA_WIDTH = 32,
     parameter DEPTH = 16
    )

  ( 	input 					clk,
   		input [ADDR_WIDTH-1:0]	addr,
   		input [DATA_WIDTH-1:0]	idata,
   		input 					cs,
   		input 					we,
   		output [DATA_WIDTH-1:0]	odata
  );

  reg [DATA_WIDTH-1:0] 	tmp_data;
  reg [DATA_WIDTH-1:0] 	mem [DEPTH];

  always @ (posedge clk) begin
    if (cs & we)
      mem[addr] <= idata;
  end

  always @ (posedge clk) begin
    if (cs) begin
        if(!we) tmp_data <= mem[addr];
        else    tmp_data <= idata;
    end
  end

  assign odata = tmp_data;
endmodule
