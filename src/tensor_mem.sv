module tensor_mem #(
  parameter int DIM = 57715 //EXACT WORDS STORED IN THIS MODULE
) (
  input logic clk, rst,
  input logic wen, ren,
  input logic [31:0] waddr, addr,
  input logic [31:0] wdata,
  output logic [31:0] rdata
);
  /*
    holds:
    - 64x3600 of 8b for W1 | addr 0 -> 57599
    - 64x1 of 32b for b1   | addr 57600 -> 57663
    - 3x64 of 8b for W2    | addr 57664 -> 57711
    - 3x1 of 32b for b2    | addr 57712 -> 57714
    add 1036 to get CPU equivalent addr 

    every address corresponds to a 32b word (not a byte)
    matrices arranged in row major (1st element second row is 1 * cols)
  */

  //wen never overlaps with rens

  localparam int ADDR_W = $clog2(DIM);

  (* ram_style = "block" *) logic [31:0] data [0:DIM - 1];
  logic [ADDR_W-1:0] waddrT, addrT;

  assign waddrT = waddr[ADDR_W - 1:0];
  assign addrT = addr[ADDR_W - 1:0];

  //ports in seperate blocks to infer FPGA BRAM

  `ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    if (wen && (waddr >= DIM)) $fatal("tensor_mem: waddr out of range: %0d", waddr);
    if (ren && (addr  >= DIM)) $fatal("tensor_mem: addr out of range: %0d", addr);
  end
  `endif

  //write port
  always_ff @(posedge clk) begin
    if (wen) data[waddrT] <= wdata;
  end

  //read port
  always_ff @(posedge clk) begin
    if (rst) rdata <= '0;
    else if (ren) rdata <= data[addrT];
  end

endmodule