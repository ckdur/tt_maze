module double_port_ram_neigh # (
    parameter MAX_MAZE_X = 10,
    parameter BITS_MAX_MAZE = 4,
    parameter LABEL_WIDTH = 5
) (
    input wire clk,
    // The equal
    output wire [MAX_MAZE_X-2:0] neighboor_equal,
    // Write-read port
    input wire [LABEL_WIDTH-1:0] write_label_data,
    input wire [BITS_MAX_MAZE-1:0] write_label_index,
    input wire write_label_en,
    output wire [LABEL_WIDTH-1:0] write_label_odata,
    // Read port
    input reg [BITS_MAX_MAZE-1:0] index,
    output reg [LABEL_WIDTH-1:0] read_label_data
);
    reg [LABEL_WIDTH*MAX_MAZE_X-1:0] labels_row; // The labels for this row
    wire [LABEL_WIDTH-1:0] labels_row_q [0:MAX_MAZE_X-1];

    // To evaluate if neighboor cells are the same
    genvar i;
    generate
        for(i = 0; i < (MAX_MAZE_X-1); i=i+1) begin : neighboor_eval
            assign neighboor_equal[i] = 
                labels_row[(i+1)*LABEL_WIDTH-1:(i+0)*LABEL_WIDTH] == 
                labels_row[(i+2)*LABEL_WIDTH-1:(i+1)*LABEL_WIDTH];
        end
        // Kinda like a RAM, but we need immediate access for now
        for(i = 0; i < MAX_MAZE_X; i=i+1) begin : label_write
            always @(posedge clk) begin
                if(write_label_en && write_label_index == i) labels_row[(i+1)*LABEL_WIDTH-1:(i+0)*LABEL_WIDTH] <= write_label_data;
            end
            assign labels_row_q[i] = labels_row[(i+1)*LABEL_WIDTH-1:(i+0)*LABEL_WIDTH];
        end
    endgenerate

    assign write_label_odata = labels_row_q[write_label_index];
    assign read_label_data = labels_row_q[index];
endmodule

module maze(
    input wire clk,
    input wire rst_n,
    input wire ena,
// From/to VGA
    input wire video_active,
    input wire hsync,
    input wire vsync,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    output wire [1:0] R,
    output wire [1:0] G,
    output wire [1:0] B,
// From the controller
    input wire b,
    input wire y,
    input wire select,
    input wire start,
    input wire up,
    input wire down,
    input wire left,
    input wire right,
    input wire a,
    input wire x,
    input wire l,
    input wire r,
    input wire is_present
);
    /* Experience
    1x1: 75% with a fixed 10x10 maze
    1x2: 82% with several fixed mazes from 3x3 to 10x10
    2x2: Full-featured
          8 does it right away (42% util). 
         10 also no problems (53% util). 
         14 and 12 are possible if disable the DYNAMIC_SQUARES (~70% density) but too long runtime
    */
    `define ULTRA_SMALL_1x1  // For 1x1
    //`define ULTRA_SMALL_1x2  // For 1x2
    //`define ULTRA_SMALL_2x2  // For 2x2

`ifdef ULTRA_SMALL_1x1
    `define MAZE_ROM
    `define MAZE_NO_MULTI
    localparam MIN_MAZE_X = 10;
    localparam MIN_MAZE_Y = 10;
    localparam MAX_MAZE_X = 10; 
    localparam MAX_MAZE_Y = 10;
`endif

`ifdef ULTRA_SMALL_1x2
    `define MAZE_ROM
    //`define MAZE_NO_MULTI
    //`define DYNAMIC_SQUARES
    localparam MIN_MAZE_X = 3;
    localparam MIN_MAZE_Y = 3;
    localparam MAX_MAZE_X = 10; 
    localparam MAX_MAZE_Y = 10;
`endif

`ifdef ULTRA_SMALL_2x2
    //`define MAZE_ROM
    //`define MAZE_NO_MULTI
    //`define DYNAMIC_SQUARES
    localparam MIN_MAZE_X = 3;
    localparam MIN_MAZE_Y = 3;
    localparam MAX_MAZE_X = 10; 
    localparam MAX_MAZE_Y = 10;
`endif

    localparam BITS_MAX_MAZE = $clog2(MAX_MAZE_X)+1; // TODO: Make it depending on both
    localparam LABEL_WIDTH = $clog2(MAX_MAZE_X*(MAX_MAZE_X/2)); // NOTE: This is arbitrary
    localparam LINE_WIDTH = 4;

    // Press indications of the controllers
    reg rb; always @(posedge clk) rb <= b; wire pb; assign pb = !rb && b;
    reg ry; always @(posedge clk) ry <= y; wire py; assign py = !ry && y;
    reg rselect; always @(posedge clk) rselect <= select; wire pselect; assign pselect = !rselect && select;
    reg rstart; always @(posedge clk) rstart <= start; wire pstart; assign pstart = !rstart && start;
    reg rup; always @(posedge clk) rup <= up; wire pup; assign pup = !rup && up;
    reg rdown; always @(posedge clk) rdown <= down; wire pdown; assign pdown = !rdown && down;
    reg rleft; always @(posedge clk) rleft <= left; wire pleft; assign pleft = !rleft && left;
    reg rright; always @(posedge clk) rright <= right; wire pright; assign pright = !rright && right;
    reg ra; always @(posedge clk) ra <= a; wire pa; assign pa = !ra && a;
    reg rx; always @(posedge clk) rx <= x; wire px; assign px = !rx && x;
    reg rl; always @(posedge clk) rl <= l; wire pl; assign pl = !rl && l;
    reg rr; always @(posedge clk) rr <= r; wire pr; assign pr = !rr && r;
    reg ris_present; always @(posedge clk) ris_present <= is_present; wire pis_present; assign pis_present = !ris_present && is_present;

    wire [3:0] _not_used_ = {pl, pr, pis_present, pselect};


    reg [BITS_MAX_MAZE-1:0] size_maze_x;
    reg [BITS_MAX_MAZE-1:0] size_maze_y;
    reg [BITS_MAX_MAZE-1:0] loc_x;
    reg [BITS_MAX_MAZE-1:0] loc_y;
    reg [BITS_MAX_MAZE-1:0] goal_x;
    reg [BITS_MAX_MAZE-1:0] goal_y;

    localparam MAX_SIZE_SQUARE = 460/MAX_MAZE_Y;
    localparam MAX_SIZE_SQUARE_2 = MAX_SIZE_SQUARE/2;
    localparam MAX_SIZE_SQUARE_4 = MAX_SIZE_SQUARE/4;

    // Part of the graphic system, brought here
    reg [BITS_MAX_MAZE-1:0] draw_square_index;
    reg [BITS_MAX_MAZE-1:0] draw_square_y;

`ifdef DYNAMIC_SQUARES
    reg [9:0] size_square;
    reg [9:0] loc_size;
    reg [9:0] start_maze_x;
    reg [9:0] start_maze_y;
    reg [9:0] loc_square_x;
    reg [9:0] loc_square_y;
    reg [9:0] goal_square_x;
    reg [9:0] goal_square_y;
    reg [9:0] bar_x;
    reg [9:0] bar_y;
`else
    wire [9:0] size_square = MAX_SIZE_SQUARE;
    wire [9:0] loc_size = MAX_SIZE_SQUARE_2;
    `ifndef MAZE_NO_MULTI
        reg [9:0] start_maze_x;
        reg [9:0] start_maze_y;
        reg [9:0] loc_square_x;
        reg [9:0] loc_square_y;
        reg [9:0] goal_square_x;
        reg [9:0] goal_square_y;
        reg [9:0] bar_x;
        reg [9:0] bar_y;
    `else
        wire [9:0] start_maze_x = 320 - MAX_SIZE_SQUARE_2*MAX_MAZE_X;
        wire [9:0] start_maze_y = 240 - MAX_SIZE_SQUARE_2*MAX_MAZE_Y;

        // Make it decoder-wise
        wire [9:0] loc_square_x;
        wire [9:0] loc_square_y;
        wire [9:0] goal_square_x;
        wire [9:0] goal_square_y;

        wire [9:0] locs_square_x [0:MAX_MAZE_X-1];
        wire [9:0] locs_square_y [0:MAX_MAZE_X-1];
        genvar w;
        generate
            for(w = 0; w < MAX_MAZE_X; w=w+1) begin : locs_square_gen
                //                 Same as start_maze
                assign locs_square_x[w] = 320 - MAX_SIZE_SQUARE_2*MAX_MAZE_X + MAX_SIZE_SQUARE_4 + MAX_SIZE_SQUARE*w;
                assign locs_square_y[w] = 240 - MAX_SIZE_SQUARE_2*MAX_MAZE_Y + MAX_SIZE_SQUARE_4 + MAX_SIZE_SQUARE*w;
            end
            assign loc_square_x = locs_square_x[loc_x];
            assign loc_square_y = locs_square_y[loc_y];
            assign goal_square_x = locs_square_x[goal_x];
            assign goal_square_y = locs_square_y[goal_y];
        endgenerate

        wire [9:0] bar_x;
        wire [9:0] bar_y;
        wire [9:0] bars_x [0:MAX_MAZE_X+1];
        wire [9:0] bars_y [0:MAX_MAZE_X+1];

        generate
            for(w = 0; w < (MAX_MAZE_X+2); w=w+1) begin : bars_gen
                //                 Same as start_maze
                assign bars_x[w] = 320 - MAX_SIZE_SQUARE_2*MAX_MAZE_X + MAX_SIZE_SQUARE*w;
                assign bars_y[w] = 240 - MAX_SIZE_SQUARE_2*MAX_MAZE_Y + MAX_SIZE_SQUARE*w;
            end
            assign bar_x = bars_x[draw_square_index];
            assign bar_y = bars_y[draw_square_y];
        endgenerate
    `endif
`endif

    function [9:0] sizes_x;
	input [BITS_MAX_MAZE-1:0] in;
	begin
        case(in)
        `ifdef DYNAMIC_SQUARES
            'd3: begin sizes_x = 620/3; end
            'd4: begin sizes_x = 620/4; end
            'd5: begin sizes_x = 620/5; end
            'd6: begin sizes_x = 620/6; end
            'd7: begin sizes_x = 620/7; end
            'd8: begin sizes_x = 620/8; end
            'd9: begin sizes_x = 620/9; end
            'd10: begin sizes_x = 620/10; end
            'd11: begin sizes_x = 620/11; end
            'd12: begin sizes_x = 620/12; end
            'd13: begin sizes_x = 620/13; end
            'd14: begin sizes_x = 620/14; end
            default: begin sizes_x = 620/5; end
        `else
            default: begin sizes_x = MAX_SIZE_SQUARE; end
        `endif
        endcase
	end
    endfunction

    function [9:0] sizes_y;
	input [BITS_MAX_MAZE-1:0] in;
	begin
        case(in)
        `ifdef DYNAMIC_SQUARES
            // NOTE: Commenting all of this. Helps reducing area
            'd3: begin sizes_y = 460/3; end
            'd4: begin sizes_y = 460/4; end
            'd5: begin sizes_y = 460/5; end
            'd6: begin sizes_y = 460/6; end
            'd7: begin sizes_y = 460/7; end
            'd8: begin sizes_y = 460/8; end
            'd9: begin sizes_y = 460/9; end
            'd10: begin sizes_y = 460/10; end
            'd11: begin sizes_y = 460/11; end
            'd12: begin sizes_y = 460/12; end
            'd13: begin sizes_y = 460/13; end
            'd14: begin sizes_y = 460/14; end
            default: begin sizes_y = 460/5; end
        `else
            default: begin sizes_y = MAX_SIZE_SQUARE; end
        `endif
        endcase
	end
    endfunction

`ifdef DYNAMIC_SQUARES
    reg [9:0] size_square_x_d;
    reg [9:0] size_square_y_d;
    always @(size_maze_x or size_maze_y) begin
        size_square_x_d = sizes_x(size_maze_x);
        size_square_y_d = sizes_y(size_maze_y);
    end
`endif

    // Random number generator
`ifndef MAZE_NO_MULTI
    reg prbs_init;
    wire [31:0] prbs_out;
    prbs_generator #(
        .TYPE(7) // PRBS29
    ) prbs (
        .clock(clk),
        .init(prbs_init),
        .out(prbs_out)
    );
`else   
    // A simple counter to replace the PRBS.
    reg [1:0] prbs_out;
    always @(posedge clk) begin
        if(~rst_n) prbs_out <= 0;
        else prbs_out <= prbs_out + 1;
    end
`endif

    /* Structure of the RAM for the maze
     _ _ _ _ _ _ _ _ _ 
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|
    |_|_|_|_|_|_|_|_|_|

    addr 0: _|_|_|_|_|_|_|_|_ (W + W-1 = 2W-1)
    Depth = Height
    */

    // RAM instance
    localparam DATA_WIDTH = 2*MAX_MAZE_X-1;
    localparam ADDR_WIDTH = $clog2(MAX_MAZE_Y);
    wire [ADDR_WIDTH-1:0] addrram;
    wire [DATA_WIDTH-1:0] odata;
`ifdef MAZE_ROM
    `ifdef MAZE_NO_MULTI
    maze_rom_only #(
        .DATA_WIDTH(2*MAX_MAZE_X-1), 
        .ADDR_WIDTH(ADDR_WIDTH)
    ) rom (
        .clk(clk),
        .addr(addrram),
        .odata(odata)
    );
    `else
    maze_rom_multi #(
        .DATA_WIDTH(2*MAX_MAZE_X-1), 
        .ADDR_WIDTH(ADDR_WIDTH),
        .MIN_MAZE_X(MIN_MAZE_X),
        .MAX_MAZE_X(MAX_MAZE_X),
        .BITS_MAX_MAZE(BITS_MAX_MAZE)
    ) rom (
        .clk(clk),
        .sel(size_maze_x),
        .addr(addrram),
        .odata(odata)
    );
    `endif
`else
    reg we;
    reg [DATA_WIDTH-1:0] idata;
    single_port_sync_ram #(
        .DATA_WIDTH(2*MAX_MAZE_X-1), 
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(MAX_MAZE_Y))
    ram (
        .clk(clk),
        .addr(addrram),
        .idata(idata),
        .cs(1'b1),
        .we(we),
        .odata(odata)
    );
`endif

    reg [DATA_WIDTH-1:0] prev_step;
    reg [DATA_WIDTH-1:0] cur_step;
    reg [BITS_MAX_MAZE-1:0] index;
    reg [ADDR_WIDTH-1:0] addr;

`ifndef MAZE_ROM  // We enable the ellier algorithm. We need the label ram
    reg [LABEL_WIDTH-1:0] next_label;
    reg [LABEL_WIDTH-1:0] write_label_data;
    reg [BITS_MAX_MAZE-1:0] write_label_index;
    reg write_label_en;
    wire [MAX_MAZE_X-2:0] neighboor_equal;
    wire [LABEL_WIDTH-1:0] read_label_data;
    wire [LABEL_WIDTH-1:0] write_label_odata;

    double_port_ram_neigh #(
        .MAX_MAZE_X(MAX_MAZE_X), 
        .BITS_MAX_MAZE(BITS_MAX_MAZE),
        .LABEL_WIDTH(LABEL_WIDTH))
    neigh (
        .clk(clk),
        .write_label_data(write_label_data),
        .write_label_index(write_label_index),
        .write_label_en(write_label_en),
        .write_label_odata(write_label_odata),
        .neighboor_equal(neighboor_equal),
        .index(index),
        .read_label_data(read_label_data)
    );
`endif

    // To see the debug
    `ifdef SIM
    integer k;
    always @(posedge clk) begin
        if(we) begin
            $write("Writting: |");
            for(k = 0; k < size_maze_x; k=k+1) begin
                if(idata[k << 1]) $write("_"); else $write(" ");
                if(k != (size_maze_x-1) && idata[(k << 1)+1]) $write("|"); else $write(" ");
            end
            $write("|\n");
        end
    end
    `endif // SIM

    reg [2:0] state;
    localparam STATE_INIT = 3'd0;
    localparam STATE_IDLE = 3'd1;
    localparam STATE_FETCH = 3'd2;
    localparam STATE_ELLER_COMMIT = 3'd3;
`ifndef MAZE_ROM
    localparam STATE_ELLER_HSTEP = 3'd4;
    localparam STATE_ELLER_VSTEP = 3'd5;
    localparam STATE_ELLER_RELABEL = 3'd6;
    reg force_vconn;
`endif
    reg win;

`ifdef DYNAMIC_SQUARES
    wire [9:0] gen_pos_x = start_maze_x + (size_square >> 2);
    wire [9:0] gen_pos_y = start_maze_y + (size_square >> 2);
`else
    wire [9:0] gen_pos_x = start_maze_x + MAX_SIZE_SQUARE_4;
    wire [9:0] gen_pos_y = start_maze_y + MAX_SIZE_SQUARE_4;
`endif

    always @(posedge clk) begin
        if(~rst_n) begin
            state <= STATE_INIT;
            size_maze_x <= MAX_MAZE_X;
            size_maze_y <= MAX_MAZE_Y;
            index <= 0;
            `ifndef MAZE_ROM
            next_label <= 0;
            write_label_en <= 1'b0;
            `endif
            `ifndef MAZE_NO_MULTI
            prbs_init <= 1'b1;
            `endif
        end else begin
            if(state == STATE_INIT) begin
                // An state to just soft-reset everything
            `ifdef DYNAMIC_SQUARES
                if(size_square_x_d >= size_square_y_d) begin
                    size_square <= size_square_y_d;
                    size_square <= size_square_y_d;
                end else begin
                    size_square <= size_square_x_d;
                    size_square <= size_square_x_d;
                end
            `endif
                if(index == 0) begin
                `ifdef DYNAMIC_SQUARES
                    if(size_square_x_d >= size_square_y_d) begin
                        start_maze_x <= 320 - (size_square_y_d>>1);
                        start_maze_y <= 240 -  (size_square_y_d>>1);
                    end else begin
                        start_maze_x <= 320 - (size_square_x_d>>1);
                        start_maze_y <= 240 - (size_square_x_d>>1);
                    end
                    goal_square_x <= 0;
                    goal_square_y <= 0;
                `else
                    `ifndef MAZE_NO_MULTI
                    start_maze_x <= 320 - MAX_SIZE_SQUARE_2;
                    start_maze_y <= 240 - MAX_SIZE_SQUARE_2;
                    goal_square_x <= 0;
                    goal_square_y <= 0;
                    `endif
                `endif
                end else begin
                `ifdef DYNAMIC_SQUARES
                    if(index < size_maze_x) begin
                        start_maze_x <= start_maze_x - (size_square>>1);
                        goal_square_x <= goal_square_x + (size_square);
                    end
                    if(index < size_maze_y) begin
                        start_maze_y <= start_maze_y - (size_square>>1);
                        goal_square_y <= goal_square_y + (size_square);
                    end
                `else
                    if(index < size_maze_x) begin
                        `ifndef MAZE_NO_MULTI
                        start_maze_x <= start_maze_x - MAX_SIZE_SQUARE_2; // (size_square>>1);
                        goal_square_x <= goal_square_x + MAX_SIZE_SQUARE; //(size_square);
                        `endif
                    end
                    if(index < size_maze_y) begin
                        `ifndef MAZE_NO_MULTI
                        start_maze_y <= start_maze_y - MAX_SIZE_SQUARE_2; // (size_square>>1);
                        goal_square_y <= goal_square_y + MAX_SIZE_SQUARE; //(size_square);
                        `endif
                    end
                `endif
                end
            `ifdef DYNAMIC_SQUARES
                loc_size <= size_square>>1;
            `endif
                
            `ifndef MAZE_NO_MULTI
                prbs_init <= 1'b0;
            `endif
                addr <= 0; // This will reflect the y-direction
                win <= 1'b0;

                `ifndef MAZE_ROM
                write_label_en <= 1'b1;
                write_label_data <= next_label;
                write_label_index <= index;
                we <= 1'b0;
                `endif
            
                if(index >= (size_maze_x-1) && index >= (size_maze_y-1)) begin 
                    `ifndef MAZE_ROM
                    state <= STATE_ELLER_HSTEP;
                    write_label_index <= 0;
                    write_label_en <= 1'b0;
                    idata <= {DATA_WIDTH{1'b1}};
                    `else
                    state <= STATE_ELLER_COMMIT; // Just do a bare commit
                    `endif
                    index <= 0;
                end else begin
                    index <= index+1;
                    `ifndef MAZE_ROM
                    next_label <= next_label+1;
                    `endif
                end

        `ifndef MAZE_ROM
            end else if (state == STATE_ELLER_HSTEP) begin
                // Connected already      || (Not finish              && randomly connect)
                if(neighboor_equal[index] || (addr != (size_maze_y-1) && prbs_out[0])) begin
                    write_label_en <= 0;
                end else begin
                    // Merge
                    if(!write_label_en) // If it was written before, do not change the label
                        write_label_data <= read_label_data;
                    write_label_en <= 1'b1;
                    write_label_index <= index+1;
                    idata[{index, 1'b0} + 1] <= 1'b0;  // TODO: Is this synthesizable?
                end

                if(index == (size_maze_x-2)) begin
                    if(addr == (size_maze_y-1)) begin 
                        we <= 1'b1;      
                        state <= STATE_ELLER_COMMIT; 
                    end else begin 
                        state <= STATE_ELLER_VSTEP;
                    end
                    index <= 0;
                    write_label_en <= 1'b0;
                    write_label_index <= 0;
                    force_vconn <= 1'b1;  // For initialization of the next state
                end else begin
                    index <= index + 1;
                end

            end else if (state == STATE_ELLER_VSTEP) begin
                // We just reuse things here
                // write_label_index is the current x position being judged for V-connection
                // index is the x position to see if already connected

                if(write_label_index == size_maze_x) begin
                    state <= STATE_ELLER_RELABEL;
                    index <= 0;
                end else begin
                    // Explore all 'index' to evaluate commons to `write_label_index`
                    if(index == size_maze_x) begin
                        // Judge the v-conn
                        idata[{write_label_index, 1'b0}] <= !(prbs_out[0] || force_vconn);
                        index <= 0;
                        write_label_index <= write_label_index + 1;
                        force_vconn <= 1'b1;
                    end else begin
                        index <= index+1;
                        // is not same cell           && labels are equal
                        if(index != write_label_index && read_label_data == write_label_odata &&
                        //  already connected || is further from the judgement
                        (!idata[{index, 1'b0}] || index > write_label_index)) begin
                            // No necessary to force
                            force_vconn <= 1'b0;
                        end
                    end
                end
            end else if (state == STATE_ELLER_RELABEL) begin
                // Re-label everything that was not connected in vertical
                if(index == (size_maze_x-1)) begin
                    state <= STATE_ELLER_COMMIT;
                    we <= 1'b1;
                    index <= 0;
                    write_label_en <= 1'b0;
                    write_label_index <= 0;
                end else begin
                    index <= index + 1;
                    // If blocked in vertical
                    if(idata[{index, 1'b0}]) begin
                        write_label_en <= 1'b1;
                        write_label_data <= next_label;
                        next_label <= next_label + 1;
                        write_label_index <= index;
                    end else begin
                        write_label_en <= 1'b0;
                    end
                end
        `endif // MAZE_ROM
            end else if (state == STATE_ELLER_COMMIT) begin

                `ifndef MAZE_ROM
                we <= 1'b0;
                idata <= {DATA_WIDTH{1'b1}};
                if(addr == (size_maze_y-1)) begin
                `endif
                    state <= STATE_FETCH;
                    index <= 0;

                    // Put the goal and the initial location
                    case (prbs_out[1:0])
                        2'b00:      begin loc_x <= 0; addr <= 0; loc_y <= 0; goal_x <= size_maze_x-1; goal_y <= size_maze_y-1; end
                        2'b01:      begin loc_x <= size_maze_x-1; addr <= 0; loc_y <= 0; goal_x <= 0; goal_y <= size_maze_y-1; end
                        2'b10:      begin loc_x <= 0; addr <= size_maze_y-1; loc_y <= size_maze_y-1; goal_x <= size_maze_x-1; goal_y <= 0; end
                        default:    begin loc_x <= size_maze_x-1; addr <= size_maze_y-1; loc_y <= size_maze_y-1; goal_x <= 0; goal_y <= 0; end
                    endcase

                    `ifndef MAZE_NO_MULTI
                    // At this point, goal_square_x,y contans the lower right position.
                    // We just swap according to the randomizer
                    case (prbs_out[1:0])
                        2'b00:      begin 
                            loc_square_x <= gen_pos_x; loc_square_y <= gen_pos_y; 
                            goal_square_x <= gen_pos_x+goal_square_x; goal_square_y <= gen_pos_y+goal_square_y; 
                        end
                        2'b01:      begin 
                            loc_square_x <= gen_pos_x+goal_square_x; loc_square_y <= gen_pos_y; 
                            goal_square_x <= gen_pos_x; goal_square_y <= gen_pos_y+goal_square_y; 
                        end
                        2'b10:      begin 
                            loc_square_x <= gen_pos_x; loc_square_y <= gen_pos_y+goal_square_y; 
                            goal_square_x <= gen_pos_x+goal_square_x; goal_square_y <= gen_pos_y; 
                        end
                        default:    begin 
                            loc_square_x <= gen_pos_x+goal_square_x; loc_square_y <= gen_pos_y+goal_square_y; 
                            goal_square_x <= gen_pos_x; goal_square_y <= gen_pos_y; 
                        end
                    endcase
                    `endif
                `ifndef MAZE_ROM
                    next_label <= 0;
                    
                end else begin
                    state <= STATE_ELLER_HSTEP;
                    addr <= addr + 1;
                end
                `endif
            end else if (state == STATE_IDLE) begin
            `ifndef MAZE_ROM
                if(pa) begin // Increase height
                    if(size_maze_y < MAX_MAZE_Y) size_maze_y <= size_maze_y+1;
                    state <= STATE_INIT;
                end
                if(pb) begin // Decrease height
                    if(size_maze_y > MIN_MAZE_Y) size_maze_y <= size_maze_y-1;
                    state <= STATE_INIT;
                end
                if(px) begin // Increase width
                    if(size_maze_x < MAX_MAZE_X) size_maze_x <= size_maze_x+1;
                    state <= STATE_INIT;
                end
                if(py) begin // Decrease width
                    if(size_maze_x > MIN_MAZE_X) size_maze_x <= size_maze_x-1;
                    state <= STATE_INIT;
                end
            `else // MAZE_ROM (only squares)
                if(px || pa) begin // Increase
                    `ifndef MAZE_NO_MULTI
                    if(size_maze_x < MAX_MAZE_X) begin
                        size_maze_x <= size_maze_x+1;
                        size_maze_y <= size_maze_y+1;
                    end
                    `endif
                    state <= STATE_INIT;
                end
                if(py || pb) begin // Decrease
                    `ifndef MAZE_NO_MULTI
                    if(size_maze_x > MIN_MAZE_X) begin
                        size_maze_x <= size_maze_x-1;
                        size_maze_y <= size_maze_y-1;
                    end
                    `endif
                    state <= STATE_INIT;
                end
            `endif
                if(pstart) begin // Just randomize
                    state <= STATE_INIT;
                end
                if(pup && !win) begin
                    if(loc_y != 0 && !prev_step[{loc_x, 1'b0}]) begin 
                        loc_y <= loc_y - 1; 
                        `ifndef MAZE_NO_MULTI
                        loc_square_y <= loc_square_y - size_square; 
                        `endif
                        addr <= loc_y - 1; state <= STATE_FETCH;
                    end
                end
                if(pdown && !win) begin
                    if(loc_y != (size_maze_y-1) && !cur_step[{loc_x, 1'b0}]) begin 
                        loc_y <= loc_y + 1; 
                        `ifndef MAZE_NO_MULTI
                        loc_square_y <= loc_square_y + size_square; 
                        `endif
                        addr <= loc_y + 1; state <= STATE_FETCH;
                    end
                end
                if(pleft && !win) begin
                    if(loc_x != 0 && !cur_step[{loc_x, 1'b0} - 1]) begin 
                        loc_x <= loc_x - 1; 
                        `ifndef MAZE_NO_MULTI
                        loc_square_x <= loc_square_x - size_square; 
                        `endif
                    end
                end
                if(pright && !win) begin
                    if(loc_x != (size_maze_x-1) && !cur_step[{loc_x, 1'b0} + 1]) begin 
                        loc_x <= loc_x + 1; 
                        `ifndef MAZE_NO_MULTI
                        loc_square_x <= loc_square_x + size_square; 
                        `endif
                    end
                end
                if(loc_x == goal_x && loc_y == goal_y) win <= 1'b1;
            end else if (state == STATE_FETCH) begin
                if(loc_y != 0) addr <= loc_y-1;
                index <= index + 1;
                if(index == 1) cur_step <= odata;
                if(index == 2) begin
                    if(loc_y != 0) prev_step <= odata;
                    else           prev_step <= {DATA_WIDTH{1'b1}};
                    index <= 0;
                    state <= STATE_IDLE;
                end
            end
        end
    end

    reg [1:0] Ra;
    reg [1:0] Ga;
    reg [1:0] Ba;
    reg [ADDR_WIDTH-1:0] addra;
    wire [BITS_MAX_MAZE-1:0] draw_square_index_1 = draw_square_index-1;
    reg draw;
    always @(posedge clk) begin
        if(~rst_n) begin
            draw_square_index <= 0;
            draw_square_y <= 0;
            `ifndef MAZE_NO_MULTI
            bar_x <= 0;
            bar_y <= 0;
            `endif
            addra <= 0;
            draw <= 0;
        end else if(ena) begin
            Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b00;
            if(pix_x == start_maze_x && pix_y == start_maze_y) draw <= 1'b1;

            if(loc_square_x <= pix_x && pix_x < (loc_square_x+loc_size) &&
               loc_square_y <= pix_y && pix_y < (loc_square_y+loc_size)) begin
                Ra <= 2'b11; Ga <= 2'b00; Ba <= 2'b10;
            end

            if(goal_square_x <= pix_x && pix_x < (goal_square_x+loc_size) &&
               goal_square_y <= pix_y && pix_y < (goal_square_y+loc_size)) begin
                Ra <= 2'b00; Ga <= 2'b11; Ba <= 2'b00;
            end

            if(bar_x <= pix_x && pix_x < (bar_x+LINE_WIDTH)) begin
                if(draw_square_index == 0 || draw_square_index == size_maze_x) begin
                    Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b11;
                end else if(draw_square_index > 0 && draw_square_index < size_maze_x && odata[{draw_square_index_1, 1'b0} + 1]) begin
                    if(win) begin Ra <= 2'b00; Ga <= 2'b10; Ba <= 2'b00; end
                    else begin    Ra <= 2'b11; Ga <= 2'b00; Ba <= 2'b00; end
                end
            end else if(pix_x == (bar_x+LINE_WIDTH)) begin
                `ifndef MAZE_NO_MULTI
                bar_x <= bar_x + size_square;
                `endif
                if(draw_square_index != (size_maze_x+1)) draw_square_index <= draw_square_index + 1;
            end

            if(bar_y <= pix_y && pix_y < (bar_y+LINE_WIDTH)) begin
                if(draw_square_y == 0 || draw_square_y == (size_maze_y)) begin
                    Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b11;
                end else if(
                    draw_square_y > 0 && draw_square_y < size_maze_y && 
                    draw_square_index > 0 && draw_square_index <= (size_maze_x) && 
                    odata[{draw_square_index_1, 1'b0}]) begin
                    if(win) begin Ra <= 2'b00; Ga <= 2'b10; Ba <= 2'b00; end
                    else begin    Ra <= 2'b11; Ga <= 2'b00; Ba <= 2'b00; end
                end
            end else if(pix_y == (bar_y+LINE_WIDTH) && pix_x == (bar_x+LINE_WIDTH)) begin
                `ifndef MAZE_NO_MULTI
                bar_y <= bar_y + size_square;
                `endif
                if(draw_square_y != (size_maze_y+1)) draw_square_y <= draw_square_y + 1;
                if(draw_square_y == size_maze_y) draw <= 1'b0;
                addra <= draw_square_y;
            end

            if(!hsync || !vsync) begin
                draw_square_index <= 0;
                `ifndef MAZE_NO_MULTI
                bar_x <= start_maze_x;
                `endif
            end

            if(!vsync) begin
                `ifndef MAZE_NO_MULTI
                bar_y <= start_maze_y;
                `endif
                draw_square_y <= 0;
                draw <= 1'b0;
            end
        end
    end

    assign addrram = state == STATE_IDLE ? addra : addr; // TODO: Temporal

    assign R = video_active && draw ? Ra : 2'b00;
    assign G = video_active && draw ? Ga : 2'b00;
    assign B = video_active && draw ? Ba : 2'b00;

endmodule