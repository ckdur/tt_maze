/*
 * Copyright (c) 2026 Ckristian Duran
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_maze (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock (50MHz)
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unused outputs assigned to 0.
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, ui_in, uio_in};

    wire gamepad_is_present;
    wire gamepad_b;
    wire gamepad_y;
    wire gamepad_select;
    wire gamepad_start;
    wire gamepad_up;
    wire gamepad_down;
    wire gamepad_left;
    wire gamepad_right;
    wire gamepad_a;
    wire gamepad_x;
    wire gamepad_l;
    wire gamepad_r;

    // Copied from tt08-cfib-demo
    /*localparam CLOCK_FREQUENCY = 50000000;
    reg [4:0]  sys_presc;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sys_presc    <= 5'b0;
        end else begin
            sys_presc    <= sys_presc + 5'b1;
        end
    end*/
    wire vga_ena = 1'b1;//sys_presc[0];

    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .ena(vga_ena),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    maze maze_impl(
        .clk(clk),
        .rst_n(rst_n),
        .ena(vga_ena),
    // From/to VGA
        .video_active(video_active),
        .hsync(hsync),
        .vsync(vsync),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .R(R),
        .G(G),
        .B(B),
    // From the controller
        .is_present(gamepad_is_present),
        .b(gamepad_b),
        .y(gamepad_y),
        .select(gamepad_select),
        .start(gamepad_start),
        .up(gamepad_up),
        .down(gamepad_down),
        .left(gamepad_left),
        .right(gamepad_right),
        .a(gamepad_a),
        .x(gamepad_x),
        .l(gamepad_l),
        .r(gamepad_r)
    );

    // Instance the gamepad for now
    gamepad_pmod_single gamepad (
        // Inputs:
        .rst_n(rst_n),
        .clk(clk),
        .pmod_data(ui_in[6]),
        .pmod_clk(ui_in[5]),
        .pmod_latch(ui_in[4]),

        // Outputs:
        .is_present(gamepad_is_present),
        .b(gamepad_b),
        .y(gamepad_y),
        .select(gamepad_select),
        .start(gamepad_start),
        .up(gamepad_up),
        .down(gamepad_down),
        .left(gamepad_left),
        .right(gamepad_right),
        .a(gamepad_a),
        .x(gamepad_x),
        .l(gamepad_l),
        .r(gamepad_r)
    );

endmodule
