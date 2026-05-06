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

    localparam STATE_INIT = 5'd0;
    localparam STATE_IDLE = 5'd1;

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
    reg [4:0] index;

    function [9:0] sizes;
	input [5:0] in;
	begin
        case(in)
            5'd5: begin sizes = 640/5; end
            5'd6: begin sizes = 640/6; end
            5'd7: begin sizes = 640/7; end
            5'd8: begin sizes = 640/8; end
            5'd9: begin sizes = 640/9; end
            5'd10: begin sizes = 640/10; end
            5'd11: begin sizes = 640/11; end
            5'd12: begin sizes = 640/12; end
            5'd13: begin sizes = 640/13; end
            5'd14: begin sizes = 640/14; end
            default: begin sizes = 640/5; end
        endcase
	end
endfunction

    always @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= STATE_INIT;
            start_maze_x <= 0;
            start_maze_y <= 0;
            size_maze_x <= 10;
            size_maze_y <= 10;
            size_square_x <= 10;
            size_square_y <= 10;
            index <= 0;
        end else begin
            if(state == STATE_INIT) begin
                // An state to just soft-reset everything
                size_square_x <= sizes(size_maze_x);
                size_square_y <= sizes(size_maze_y);
                state <= STATE_IDLE;
            end else if (state == STATE_IDLE) begin
            end
        end
    end

    reg [9:0] counter;
    wire [9:0] moving_x = pix_x + counter;

    assign R = video_active ? {moving_x[5], pix_y[2]} : 2'b00;
    assign G = video_active ? {moving_x[6], pix_y[2]} : 2'b00;
    assign B = video_active ? {moving_x[7], pix_y[5]} : 2'b00;
    
    always @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            counter <= 0;
        end else if(ena && vsync) begin
            counter <= counter + 1;
        end
    end

    // Suppress unused signals warning
    wire _unused_ok_ = &{moving_x, pix_y};

endmodule