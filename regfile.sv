module regfile (
  input logic clk, rst,

  //from decode
  input logic [4:0] reg1, reg2,
  output logic [31:0] reg1val, reg2val,

  //from writeback
  input logic [4:0] regD,
  input logic [31:0] write_data,
  input logic regwrite
);

  logic [31:0] cur_reg [1:31];

  always_comb begin
    //decode comb logic
    if (reg1 == 5'b0) begin
      reg1val = '0;
    end else begin
      reg1val = cur_reg[reg1];
    end
    if (reg2 == 5'b0) begin
      reg2val = '0;
    end else begin
      reg2val = cur_reg[reg2];
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      cur_reg[1] <= '0;
      cur_reg[2] <= '0;
      cur_reg[3] <= '0;
      cur_reg[4] <= '0;
      cur_reg[5] <= '0;
      cur_reg[6] <= '0;
      cur_reg[7] <= '0;
      cur_reg[8] <= '0;
      cur_reg[9] <= '0;
      cur_reg[10] <= '0;
      cur_reg[11] <= '0;
      cur_reg[12] <= '0;
      cur_reg[13] <= '0;
      cur_reg[14] <= '0;
      cur_reg[15] <= '0;
      cur_reg[16] <= '0;
      cur_reg[17] <= '0;
      cur_reg[18] <= '0;
      cur_reg[19] <= '0;
      cur_reg[20] <= '0;
      cur_reg[21] <= '0;
      cur_reg[22] <= '0;
      cur_reg[23] <= '0;
      cur_reg[24] <= '0;
      cur_reg[25] <= '0;
      cur_reg[26] <= '0;
      cur_reg[27] <= '0;
      cur_reg[28] <= '0;
      cur_reg[29] <= '0;
      cur_reg[30] <= '0;
      cur_reg[31] <= '0;
    end else begin
      if (regD != 5'b0 && regwrite) begin //writing to x0 ignored
        cur_reg[regD] <= write_data;
      end
    end
  end
endmodule