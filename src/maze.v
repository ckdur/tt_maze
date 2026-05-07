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
    localparam MIN_MAZE_X = 5;
    localparam MIN_MAZE_Y = 5;
    localparam MAX_MAZE_X = 14;
    localparam MAX_MAZE_Y = 14;

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

    reg [4:0] state;
    reg [9:0] start_maze_x;
    reg [9:0] start_maze_y;
    reg [5:0] size_maze_x;
    reg [5:0] size_maze_y;
    reg [9:0] size_square_x;
    reg [9:0] size_square_y;

    function [9:0] sizes_x;
	input [5:0] in;
	begin
        case(in)
            5'd5: begin sizes_x = 620/5; end
            5'd6: begin sizes_x = 620/6; end
            5'd7: begin sizes_x = 620/7; end
            5'd8: begin sizes_x = 620/8; end
            5'd9: begin sizes_x = 620/9; end
            5'd10: begin sizes_x = 620/10; end
            5'd11: begin sizes_x = 620/11; end
            5'd12: begin sizes_x = 620/12; end
            5'd13: begin sizes_x = 620/13; end
            5'd14: begin sizes_x = 620/14; end
            default: begin sizes_x = 620/5; end
        endcase
	end
    endfunction

    function [9:0] sizes_y;
	input [5:0] in;
	begin
        case(in)
            5'd5: begin sizes_y = 460/5; end
            5'd6: begin sizes_y = 460/6; end
            5'd7: begin sizes_y = 460/7; end
            5'd8: begin sizes_y = 460/8; end
            5'd9: begin sizes_y = 460/9; end
            5'd10: begin sizes_y = 460/10; end
            5'd11: begin sizes_y = 460/11; end
            5'd12: begin sizes_y = 460/12; end
            5'd13: begin sizes_y = 460/13; end
            5'd14: begin sizes_y = 460/14; end
            default: begin sizes_y = 460/5; end
        endcase
	end
    endfunction

    reg [9:0] size_square_x_d;
    reg [9:0] size_square_y_d;
    always @(size_maze_x or size_maze_y) begin
        size_square_x_d = sizes_x(size_maze_x);
        size_square_y_d = sizes_y(size_maze_y);
    end

    // Random number generator
    reg prbs_init;
    wire [31:0] prbs_out;
    prbs_generator #(
        .TYPE(7) // PRBS29
    ) prbs (
        .clock(clk),
        .init(prbs_init),
        .out(prbs_out)
    );

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
    reg we;
    wire [DATA_WIDTH-1:0] odata;
    reg [DATA_WIDTH-1:0] idata;
    wire cs = 1'b1;
    single_port_sync_ram #(
        .DATA_WIDTH(2*MAX_MAZE_X-1), 
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(MAX_MAZE_Y))
    ram (
        .clk(clk),
        .addr(addrram),
        .idata(idata),
        .cs(cs),
        .we(we),
        .odata(odata)
    );


    reg [DATA_WIDTH-1:0] prev_step;
    localparam LABEL_WIDTH = 8; // NOTE: This is arbitrary
    reg [LABEL_WIDTH-1:0] labels_row [0:MAX_MAZE_X-1]; // The labels for this row
    reg [LABEL_WIDTH-1:0] next_label;
    wire [MAX_MAZE_X-2:0] neighboor_equal;

    reg [$clog2(MAX_MAZE_X)-1:0] index;
    reg [LABEL_WIDTH-1:0] write_label_data;
    reg [$clog2(MAX_MAZE_X)-1:0] write_label_index;
    reg write_label_en;
    reg [ADDR_WIDTH-1:0] addr;

    // To evaluate if neighboor cells are the same
    genvar i;
    generate
        for(i = 0; i < (MAX_MAZE_X-1); i=i+1) begin : neighboor_eval
            assign neighboor_equal[i] = labels_row[i] == labels_row[i+1];
        end
    endgenerate
    // Kinda like a RAM, but we need immediate access for now
    always @(posedge clk) begin
        if(write_label_en) labels_row[write_label_index] <= write_label_data;
    end

    // To see the debug
    `ifndef SYNTHESIS
    wire [LABEL_WIDTH-1:0] labels_row_0 = labels_row[0];
    wire [LABEL_WIDTH-1:0] labels_row_1 = labels_row[1];
    wire [LABEL_WIDTH-1:0] labels_row_2 = labels_row[2];
    wire [LABEL_WIDTH-1:0] labels_row_3 = labels_row[3];
    wire [LABEL_WIDTH-1:0] labels_row_4 = labels_row[4];
    wire [LABEL_WIDTH-1:0] labels_row_5 = labels_row[5];
    wire [LABEL_WIDTH-1:0] labels_row_6 = labels_row[6];
    wire [LABEL_WIDTH-1:0] labels_row_7 = labels_row[7];
    wire [LABEL_WIDTH-1:0] labels_row_8 = labels_row[8];
    wire [LABEL_WIDTH-1:0] labels_row_9 = labels_row[9];
    wire [LABEL_WIDTH-1:0] labels_row_10 = labels_row[10];
    wire [LABEL_WIDTH-1:0] labels_row_11 = labels_row[11];
    wire [LABEL_WIDTH-1:0] labels_row_12 = labels_row[12];
    wire [LABEL_WIDTH-1:0] labels_row_13 = labels_row[13];

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
    `endif

    localparam STATE_INIT = 5'd0;
    localparam STATE_IDLE = 5'd1;
    localparam STATE_ELLER_HSTEP = 5'd2;
    localparam STATE_ELLER_VSTEP = 5'd3;
    localparam STATE_ELLER_RELABEL = 5'd4;
    localparam STATE_ELLER_COMMIT = 5'd5;
    reg force_vconn;
    reg win;

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= STATE_INIT;
            size_maze_x <= 5;
            size_maze_y <= 10;
            prbs_init <= 1'b1;
            we <= 1'b0;
            index <= 0;
            next_label <= 0;
            write_label_en <= 1'b0;
        end else begin
            if(state == STATE_INIT) begin
                // An state to just soft-reset everything
                if(size_square_x_d >= size_square_y_d) begin
                    size_square_x <= size_square_y_d;
                    size_square_y <= size_square_y_d;
                end else begin
                    size_square_x <= size_square_x_d;
                    size_square_y <= size_square_x_d;
                end
                if(index == 0) begin
                    if(size_square_x_d >= size_square_y_d) begin
                        start_maze_x <= 320 - (size_square_y_d>>1);
                        start_maze_y <= 240 - (size_square_y_d>>1);
                    end else begin
                        start_maze_x <= 320 - (size_square_x_d>>1);
                        start_maze_y <= 240 - (size_square_x_d>>1);
                    end
                end else begin
                    if(index < size_maze_x) begin
                        if(start_maze_x > (size_square_x>>1)) start_maze_x <= start_maze_x - (size_square_x>>1);
                        else start_maze_x <= 0;
                    end
                    if(index < size_maze_y) begin
                        if(start_maze_y > (size_square_y>>1)) start_maze_y <= start_maze_y - (size_square_y>>1);
                        else start_maze_y <= 0;
                    end
                end
                
                // TODO: Set start_maze_x,y
                prbs_init <= 1'b0;
                addr <= 0; // This will reflect the y-direction
                win <= 1'b0;

                write_label_en <= 1'b1;
                write_label_data <= next_label;
                write_label_index <= index;

                if(index >= (size_maze_x-1) && index >= (size_maze_y-1)) begin 
                    state <= STATE_ELLER_HSTEP;
                    write_label_index <= 0;
                    write_label_en <= 1'b0;
                    index <= 0;
                    idata <= {DATA_WIDTH{1'b1}};
                end else begin
                    index <= index+1;
                    next_label <= next_label+1;
                end

            end else if (state == STATE_ELLER_HSTEP) begin
                // Connected already      || (Not finish              && randomly connect)
                if(neighboor_equal[index] || (addr != (size_maze_y-1) && prbs_out[0])) begin
                    write_label_en <= 0;
                end else begin
                    // Merge
                    if(!write_label_en) // If it was written before, do not change the label
                        write_label_data <= labels_row[index];
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
                        if(index != write_label_index && labels_row[index] == labels_row[write_label_index] &&
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
            end else if (state == STATE_ELLER_COMMIT) begin

                we <= 1'b0;
                idata <= {DATA_WIDTH{1'b1}};
                if(addr == (size_maze_y-1)) begin
                    state <= STATE_IDLE;
                    addr <= 0;
                end else begin
                    state <= STATE_ELLER_HSTEP;
                    addr <= addr + 1;
                end
            end else if (state == STATE_IDLE) begin
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
            end
        end
    end

    reg [9:0] bar_x;
    reg [9:0] bar_y;
    reg [1:0] Ra;
    reg [1:0] Ga;
    reg [1:0] Ba;
    reg [ADDR_WIDTH-1:0] addra;
    reg [$clog2(MAX_MAZE_X)-1:0] draw_square_index;
    reg [$clog2(MAX_MAZE_X)-1:0] draw_square_y;
    wire [$clog2(MAX_MAZE_X)-1:0] draw_square_index_1 = draw_square_index-1;
    reg draw;
    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            draw_square_index <= 0;
            draw_square_y <= 0;
            bar_x <= 0;
            bar_y <= 0;
            addra <= 0;
            draw <= 0;
        end else if(ena) begin
            Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b00;
            if(pix_x == start_maze_x && pix_y == start_maze_y) draw <= 1'b1;

            if(bar_x <= pix_x && pix_x < (bar_x+LINE_WIDTH)) begin
                if(draw_square_index == 0 || draw_square_index == size_maze_x) begin
                    Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b11;
                end else if(draw_square_index > 0 && draw_square_index < size_maze_x && odata[{draw_square_index_1, 1'b0} + 1]) begin
                    if(win) begin Ra <= 2'b00; Ga <= 2'b11; Ba <= 2'b00; end
                    else begin    Ra <= 2'b11; Ga <= 2'b00; Ba <= 2'b00; end
                end
            end else if(pix_x == (bar_x+LINE_WIDTH)) begin
                bar_x <= bar_x + size_square_x;
                if(draw_square_index != (size_maze_x+1)) draw_square_index <= draw_square_index + 1;
            end

            if(bar_y <= pix_y && pix_y < (bar_y+LINE_WIDTH)) begin
                if(draw_square_y == 0 || draw_square_y == (size_maze_y)) begin
                    Ra <= 2'b00; Ga <= 2'b00; Ba <= 2'b11;
                end else if(
                    draw_square_y > 0 && draw_square_y < size_maze_y && 
                    draw_square_index > 0 && draw_square_index <= (size_maze_x) && 
                    odata[{draw_square_index_1, 1'b0}]) begin
                    if(win) begin Ra <= 2'b00; Ga <= 2'b11; Ba <= 2'b00; end
                    else begin    Ra <= 2'b11; Ga <= 2'b00; Ba <= 2'b00; end
                end
            end else if(pix_y == (bar_y+LINE_WIDTH) && pix_x == (bar_x+LINE_WIDTH)) begin
                bar_y <= bar_y + size_square_y;
                if(draw_square_y != (size_maze_y+1)) draw_square_y <= draw_square_y + 1;
                if(draw_square_y == size_maze_y) draw <= 1'b0;
                addra <= draw_square_y;
            end

            if(!hsync || !vsync) begin
                draw_square_index <= 0;
                bar_x <= start_maze_x;
            end

            if(!vsync) begin
                draw_square_y <= 0;
                bar_y <= start_maze_y;
                draw <= 1'b0;
            end
        end
    end

    assign addrram = state == STATE_IDLE ? addra : addr; // TODO: Temporal

    assign R = video_active && draw ? Ra : 2'b00;
    assign G = video_active && draw ? Ga : 2'b00;
    assign B = video_active && draw ? Ba : 2'b00;

endmodule