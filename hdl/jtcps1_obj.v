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
    
`timescale 1ns/1ps

// Scroll 1 is 512x512, 8x8 tiles
// Scroll 2 is 1024x1024 16x16 tiles
// Scroll 3 is 2048x2048 32x32 tiles

module jtcps1_obj(
    input              rst,
    input              clk,

    // input              HB,
    input              VB,

    input              start,
    input      [ 7:0]  vrender, // 1 line ahead of vdump
    input      [ 7:0]  vdump,
    input      [ 8:0]  hdump,
    // control registers
    output     [23:1]  vram_addr,
    input      [15:0]  vram_data,
    input              vram_ok,
    output             vram_cs,

    output     [22:0]  rom_addr,    // up to 1 MB
    output             rom_half,    // selects which half to read
    input      [31:0]  rom_data,
    output             rom_cs,
    input              rom_ok,

    output     [ 8:0]  pxl
);

jtcps1_obj_table u_table(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .VB         ( VB            ),

    // OBJ renderization
    .table_addr ( table_addr    ),
    .table_data ( table_data    ),

    // VRAM
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_data     ),
    .vram_ok    ( vram_ok       ),
    .vram_cs    ( vram_cs       )

);

jtcps1_obj_draw u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .start      ( start         ),
    .vrender    ( vrender       ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),

    .table_addr ( table_addr    ),
    .table_data ( table_data    ),

    .rom_addr   ( rom_addr      ),
    .rom_half   ( rom_half      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),

    .pxl        ( pxl           )
);

endmodule