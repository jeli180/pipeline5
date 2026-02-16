module tensor_mem (
  //writes are from mmio, reads from tensor 
  input logic clk, rst,
  input logic wen, ren,
  input logic [31:0] waddr, raddr,
  input logic [31:0] wdata,
  output logic [31:0] rdata
);
  /*
    holds:
    - 64x3600 of 8b for W1 | addr 0 -> 57599
    - 64x1 of 32b for b1   | addr 57600 -> 57663 
    - 3x64 of 8b for W2    | addr 57664 -> 57727
    - 3x1 of 32b for b2    | addr 57728 -> 57730
    add 1036 to get CPU equivalent addr 

    every unique address corresponds to a 32b word (not a byte)
    matrices arranged in row major (1st element second row is 1 * cols)
  */

  /*
    mem store structure
    for W1
    - first 4 int8s of the first column is the first address
    - lsb 8 bits are first entry in the column slice
    - first 4 int8s of the second column is the second address
    for B1
    - first address is first 32b entry in B1 vector
    for W2
    - msb 8 bits are not used, lsb are first row
    for B2
    - same as B1
  */

  //wen never overlaps with rens
  localparam int DIM = 57715;
  localparam int ADDR_W = $clog2(DIM);

  (* ram_style = "block" *) logic [31:0] data [0:DIM - 1];

  logic [ADDR_W-1:0] waddrT, raddrT;

  assign waddrT = waddr[ADDR_W - 1:0];
  assign raddrT = raddr[ADDR_W - 1:0];

  //ports in seperate blocks to infer FPGA BRAM

  `ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    if (wen && (waddr >= DIM)) $fatal("tensor_mem: waddr out of range: %0d", waddr);
    if (ren && (raddr  >= DIM)) $fatal("tensor_mem: raddr out of range: %0d", raddr);
  end
  `endif

  //write port
  always_ff @(posedge clk) begin
    if (wen) data[waddrT] <= wdata;
  end

  //read port
  always_ff @(posedge clk) begin
    if (rst) rdata <= '0;
    else if (ren) rdata <= data[raddrT];
  end

endmodule