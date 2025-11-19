module execute (
  input logic clk, rst,

  //hazard
  input logic branch_flush, stall, jal_flush, //from mem and wb
  output logic [4:0] reg1_mem, reg2_mem, //to mem for it to generate stall
  input logic [31:0] stall_val, //loaded val mem was stalling for
  input logic [4:0] regD_mem, //dependency reg for lw in mem

  //regD early sendback from mem and wb
  input logic [4:0] regD_mem, regD_wb,
  input logic [31:0] regD_val_mem, regD_val_wb,
  input logic regwrite_mem, regwrite_wb,

  //from decode
  input logic rtype, itype, load, store, branch, jal, jalr, //itype flag is for opcode 0010011
  input logic [31:0] imm, inst, pc,
  input logic [4:0] reg1, reg2, regD,
  input logic [31:0] reg1val, reg2val,

  //to mem
  output logic regwrite, rtypeF, itypeF, loadF, storeF, branchF, jalF, jalrF,
  output logic [31:0] target,
  output logic [31:0] result,
  output logic [31:0] store_data,
  output logic branch_cond,
  output logic [4:0] regDF
);

  //internal
  logic [31:0] final_reg1val, final_reg2val; //used for calculations
  logic next_stallreg, stallreg;
  logic next_regwrite, next_rtypeF, next_itypeF, next_loadF, next_storeF, next_branchF, next_jalF, next_jalrF; //pass through
  logic [31:0] next_target, next_result, next_store_data; //calculated
  logic next_branch_cond; //calculated
  logic [4:0] next_regDF; //pass through

  always_comb begin
    final_reg1val = reg1val;
    final_reg2val = reg2val;

    //defaults for registered outputs
    next_regwrite = 0;
    next_rtypeF = rtype;
    next_itypeF = itype;
    next_loadF = load;
    next_storeF = store;
    next_branchF = branch;
    next_jalF = jal;
    next_jalrF = jalr;
    next_target = '0;
    next_result = '0;
    next_store_data = '0;
    next_branch_cond = 0;
    next_regDF = regDF;

    //fill final register vals
    if (!jal_flush) begin //don't need to store stall if everything is getting flushed
      next_stallreg = stall; //used for negedge detection of stall -> use stall_val
    end
    //on negedge stall, only dependency is lw regD
    if (stallreg && !stall) begin //negedge stall



    //override should be at bottom of comb
    if (jal_flush || branch_flush || stall) begin //outputs correspond to nop
      next_regwrite = 0;
      next_rtypeF = 0;
      next_itypeF = 1'b1;
      next_loadF = 0;
      next_storeF = 0;
      next_branchF = 0;
      next_jalF = 0;
      next_jalrF = 0;
      next_regDF = '0;
      //other output signals 



    