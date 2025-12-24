module writeback (
  //hazard
  output logic jal_flush,
  output logic [31:0] j_target,

  //register back to execute (comb)
  output logic [4:0] regD_ex,
  output logic [31:0] regD_val_ex,
  output logic regwrite_ex,

  //from mem
  input logic regwrite, jal,
  input logic [4:0] regD,
  input logic [31:0] target, regdata,

  //register file
  output logic [31:0] write_data,
  output logic [4:0] reg_num,
  output logic wen
);

  //regfile interface
  assign write_data = regdata;
  assign reg_nfinishum = regD;
  assign wen = regwrite;

  //jal_flush gen
  assign jal_flush = jal;
  assign j_target = jal ? target : '0;

  //register back to ex
  assign regD_ex = regD;
  assign regD_val_ex = regdata;
  assign regwrite_ex = regwrite;

endmodule
