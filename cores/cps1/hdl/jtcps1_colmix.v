/*  This file is part of JTCPS1.
    JTCPS1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCPS1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCPS1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */


// See file cc/brightness.cc for the LUT generation

module jtcps1_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              VB,
    input              HB,
    output  reg        LVBL_dly,
    output  reg        LHBL_dly,
    input   [ 3:0]     gfx_en,

    input   [10:0]     scr1_pxl,
    input   [10:0]     scr2_pxl,
    input   [10:0]     scr3_pxl,
    input   [ 8:0]     star0_pxl,
    input   [ 8:0]     star1_pxl,
    input   [ 8:0]     obj_pxl,

    // Layer priority
    input   [15:0]     layer_ctrl,
    input   [ 7:0]     layer_mask0, // mask for enable bits
    input   [ 7:0]     layer_mask1,
    input   [ 7:0]     layer_mask2,
    input   [ 7:0]     layer_mask3,
    input   [ 7:0]     layer_mask4,
    input   [15:0]     prio0,
    input   [15:0]     prio1,
    input   [15:0]     prio2,
    input   [15:0]     prio3,

    // Palette RAM
    output  [11:0]     pal_addr,
    input   [15:0]     pal_raw,

    (*keep*) output reg [7:0]  red,
    (*keep*) output reg [7:0]  green,
    (*keep*) output reg [7:0]  blue
);

reg  [11:0] pxl;

// Palette
wire [ 3:0] raw_r, raw_g, raw_b, raw_br;
reg  [ 7:0] lut_r, lut_g, lut_b;
reg  [ 3:0] lut_addr;
wire [ 7:0] lut_dout;
reg  [ 2:0] lut_k; // counter

// These are the top four bits written by CPS-B to each
// pixel of the frame buffer. These are likely sent by CPS-A
// via pins XS[4:0] and CPS-B encodes them
// 000 = OBJ ?
// 001 = SCROLL 1
// 010 = SCROLL 2
// 011 = SCROLL 3
// 100 = STAR FIELD

localparam [2:0] OBJ=3'b0, SCR1=3'b1, SCR2=3'd2, SCR3=3'd3, STA=3'd4;

`ifdef GRAY
assign raw_br   = 4'hf ;
assign raw_r    = pal_addr[3:0];
assign raw_g    = pal_addr[3:0];
assign raw_b    = pal_addr[3:0];
`else
assign raw_br   = pal_raw[15:12]; // r
assign raw_r    = pal_raw[11: 8]; // br
assign raw_g    = pal_raw[ 7: 4]; // b
assign raw_b    = pal_raw[ 3: 0]; // g
`endif
assign pal_addr = pxl;
/////////////////////////// LAYER MUX ////////////////////////////////////////////
function [13:0] layer_mux;
    input [ 8:0] obj;
    input [10:0] scr1;
    input [10:0] scr2;
    input [10:0] scr3;
    input [ 1:0] sel;

    layer_mux =  sel==2'b00 ? {      2'b00,  OBJ, obj }   :
                (sel==2'b01 ? { scr1[10:9], SCR1, scr1[8:0]}   :
                (sel==2'b10 ? { scr2[10:9], SCR2, scr2[8:0]}   :
                (sel==2'b11 ? { scr3[10:9], SCR3, scr3[8:0]}   : 13'h1fff )));
endfunction

(*keep*) wire [4:0] lyren = {
    |(layer_mask4[5:0] & layer_ctrl[5:0]), // Star layer 1
    |(layer_mask3[5:0] & layer_ctrl[5:0]), // Star layer 0
    |(layer_mask2[5:0] & layer_ctrl[5:0]),
    |(layer_mask1[5:0] & layer_ctrl[5:0]),
    |(layer_mask0[5:0] & layer_ctrl[5:0])
};

//reg [4:0] lyren2, lyren3;

// OBJ layer cannot be disabled by hardware
wire [ 8:0] obj_mask  = { obj_pxl[8:4],   obj_pxl[3:0]  | {4{~gfx_en[3]}} };
wire [10:0] scr1_mask = { scr1_pxl[10:4], scr1_pxl[3:0] | {4{~(lyren[0]& gfx_en[0])}} };
wire [10:0] scr2_mask = { scr2_pxl[10:4], scr2_pxl[3:0] | {4{~(lyren[1]& gfx_en[1])}} };
wire [10:0] scr3_mask = { scr3_pxl[10:4], scr3_pxl[3:0] | {4{~(lyren[2]& gfx_en[2])}} };
wire [ 8:0] sta0_mask = { star0_pxl[8:4], star0_pxl[3:0] | {4{~lyren[3]}} };
wire [ 8:0] sta1_mask = { star1_pxl[8:4], star1_pxl[3:0] | {4{~lyren[4]}} };

localparam QW = 14*5;
reg [13:0] lyr5, lyr4, lyr3, lyr2, lyr1, lyr0;
reg [QW-1:0] lyr_queue;
reg [11:0] pre_pxl;
reg [ 1:0] group;

jtframe_ram #(.aw(8),.synfile("pal_lut.hex")) u_lut (
    .clk    ( clk                  ),
    .cen    ( 1'b1                 ),
    .data   ( 8'd0                 ),
    .addr   ( { raw_br, lut_addr } ),
    .we     ( 1'b0                 ),
    .q      ( lut_dout             )
);

always @(posedge clk, posedge rst) begin
    if(rst) begin
        lut_r    <= 8'h0;
        lut_g    <= 8'h0;
        lut_b    <= 8'h0;
        lut_k    <= 3'd0;
        lut_addr <= 4'd0;
    end else begin // the clock frequency must be a multiple of 3*8=24MHz
        if( pxl_cen ) begin
            lut_k <= 3'd0;
        end else if( lut_k != 3'd7 )
            lut_k <= lut_k+3'd1;
        case( lut_k )
            3'd2: begin
                lut_addr <= raw_r;
            end
            3'd3: begin
                lut_addr <= raw_g ;
            end
            3'd4: begin
                lut_r    <= lut_dout;
                lut_addr <= raw_b;
            end
            3'd5: begin
                lut_g    <= lut_dout;
            end
            3'd6: begin
                lut_b    <= lut_dout;
            end
        endcase
    end
end

always @(posedge clk) if(pxl_cen) begin
    lyr5 <= { 2'b00, STA, sta1_mask };
    lyr4 <= { 2'b00, STA, sta0_mask };
    lyr3 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[ 7: 6] );
    lyr2 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[ 9: 8] );
    lyr1 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[11:10] );
    lyr0 <= layer_mux( obj_mask, scr1_mask, scr2_mask, scr3_mask, layer_ctrl[13:12] );
    //lyren2[5:4] <= lyren[5:4];
    //lyren2[3] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[2] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[1] <= lyren[ layer_ctrl[7:6] ];
    //lyren2[0] <= lyren[ layer_ctrl[7:6] ];
end

reg has_priority, check_prio;

always @(*) begin
    case( group )
        2'd0: has_priority = prio0[ pre_pxl[3:0] ];
        2'd1: has_priority = prio1[ pre_pxl[3:0] ];
        2'd2: has_priority = prio2[ pre_pxl[3:0] ];
        2'd3: has_priority = prio3[ pre_pxl[3:0] ];
    endcase
end

localparam [13:0] BLANK_PXL = { 2'b11, 12'hBFF }; // according to DL-0921 RE

// This take 6 clock cycles to process the 6 layers
always @(posedge clk) begin
    if(pxl_cen) begin
        pxl               <= pre_pxl;
        {group, pre_pxl } <= lyr5;
        lyr_queue         <= { lyr0, lyr1, lyr2, lyr3, lyr4 };
        check_prio        <= 1'b0;
        //lyren3            <= lyren2;
    end else begin
        if( (pre_pxl[3:0]==4'hf ||
            ( !(lyr_queue[11:9]==OBJ && has_priority && check_prio )
                && lyr_queue[3:0] != 4'hf ))  )
        begin
            { group, pre_pxl } <= lyr_queue[13:0];
            check_prio <= lyr_queue[11:9]!=STA;
            lyr_queue <= { BLANK_PXL, lyr_queue[QW-1:14] };
        end
        else begin
            check_prio <= 1'b0;
            lyr_queue <= { BLANK_PXL, lyr_queue[QW-1:14] };
        end
    end
end


wire vb1, hb1;

jtframe_sh #(.width(2),.stages(3)) u_sh(
    .clk    ( clk           ),
    .clk_en ( pxl_cen       ),
    .din    ( {VB, HB}      ),
    .drop   ( {vb1, hb1}    )
);

// Blanking signals must be active during reset
always @(posedge clk) if(pxl_cen) begin
    LVBL_dly <= ~vb1;
    LHBL_dly <= ~hb1;
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        red   <= 8'd0;
        green <= 8'd0;
        blue  <= 8'd0;
    end else if(pxl_cen) begin
        // signal * 17 - signal*15/2 - signal*15/4 = signal * (17-15/2-15/4)
        // 66% max attenuation for brightness
        if( vb1 || (hb1 && !LHBL_dly) ) begin
            red   <= 8'd0;
            green <= 8'd0;
            blue  <= 8'd0;
        end else begin
            red   <= lut_r;
            green <= lut_g;
            blue  <= lut_b;
        end
    end
end

endmodule
