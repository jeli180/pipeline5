module execute (
  input logic clk, rst,

  //hazard
  input logic branch_flush, stall, jal_flush, //from mem and wb
  input logic [31:0] stall_val, //loaded val mem was stalling for
  input logic [4:0] regD_stall, //dependency reg for lw in mem

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
  output logic regwrite, loadF, storeF, branchF, jalF, jalrF,
  output logic [31:0] target,
  output logic [31:0] result, //either mem addr for lw/sw, rd val for rtype/itype/jal/jalr
  output logic [31:0] store_data,
  output logic branch_cond,
  output logic [4:0] regDF
);
  //don't need to send rtype/itype flags to mem

  //internal
  logic [31:0] final_reg1val, final_reg2val; //used for calculations
  logic next_stallreg, stallreg;
  logic next_regwrite, next_loadF, next_storeF, next_branchF, next_jalF, next_jalrF; //pass through
  logic [31:0] next_target, next_result, next_store_data; //calculated
  logic next_branch_cond; //calculated
  logic [4:0] next_regDF; //pass through
  logic [31:0] operator; //rs2 for rtype, imm for itype

  always_comb begin
    final_reg1val = reg1val;
    final_reg2val = reg2val;
    next_stallreg = 0;
    operator = 32'b0;

    //defaults for registered outputs
    next_regwrite = 0;
    next_loadF = load;
    next_storeF = store;
    next_branchF = branch;
    next_jalF = jal;
    next_jalrF = jalr;
    next_target = '0;
    next_result = '0;
    next_store_data = '0;
    next_branch_cond = 0;
    next_regDF = regD;

    //fill final register vals
    if (!jal_flush) begin //don't need to store stall if everything is getting flushed
      next_stallreg = stall; //used for negedge detection of stall -> use stall_val
    end
    //on negedge stall, only dependency is lw regD
    if (stallreg && !stall) begin //negedge stall, highest prio, directly after stall
      if (regD_stall != 5'b0 && regD_stall == reg1) final_reg1val = stall_val;
      if (regD_stall != 5'b0 && regD_stall == reg2) final_reg2val = stall_val;
    end else if ((regD_mem == reg1 || regD_mem == reg2) && regwrite_mem && regD_mem != 5'b0) begin //does not interfere with stall logic since if stall, outputs are overriden below
      if (regD_mem == reg1) final_reg1val = regD_val_mem;
      if (regD_mem == reg2) final_reg2val = regD_val_mem;
    end else if ((regD_wb == reg1 || regD_wb == reg2) && regwrite_wb && regD_wb != 5'b0) begin //lower prio than mem phase val since mem instr is completed later
      if (regD_wb == reg1) final_reg1val = regD_val_wb;
      if (regD_wb == reg2) final_reg2val = regD_val_wb;
    end

    //generate regwrite, branch_cond, target, result, store_data from input flags and derived finalreg vals
    
    //generate regwrite
    next_regwrite = (rtype || itype || load || jal|| jalr) ? 1'b1 : 1'b0;

    //generate target
    if (branch || jal) begin
      next_target = pc + imm;
    end else if (jalr) begin
      next_target = final_reg1val + imm;
    end

    //generate branch_cond
    if (branch) begin
      case (inst[14:12]) //funct3
        3'h0: next_branch_cond = final_reg1val == final_reg2val ? 1'b1 : 1'b0;
        3'h1: next_branch_cond = final_reg1val != final_reg2val ? 1'b1 : 1'b0;
        3'h4: next_branch_cond = $signed(final_reg1val) < $signed(final_reg2val) ? 1'b1 : 1'b0;
        3'h5: next_branch_cond = $signed(final_reg1val) >= $signed(final_reg2val) ? 1'b1 : 1'b0;
        3'h6: next_branch_cond = final_reg1val < final_reg2val ? 1'b1 : 1'b0;
        3'h7: next_branch_cond = final_reg1val >= final_reg2val ? 1'b1 : 1'b0;
        default:;
      endcase
    end

    //generate store_data
    if (store) begin
      next_store_data = final_reg2val;
    end

    //generate result
    if (rtype) operator = final_reg2val;
    else if (itype) operator = imm;

    if (rtype || itype) begin
      case (inst[14:12]) //funct3
        3'h0: begin
          if (inst[31:25] == 7'h20 && rtype) next_result = final_reg1val - operator;
          else next_result = final_reg1val + operator;
        end
        3'h1: next_result = final_reg1val << operator[4:0];
        3'h2: next_result = $signed(final_reg1val) < $signed(operator) ? 32'd1 : 32'b0;
        3'h3: next_result = final_reg1val < operator ? 32'd1 : 32'b0;
        3'h4: next_result = final_reg1val ^ operator;
        3'h5: begin
          if (inst[31:25] == 7'b0) next_result = final_reg1val >> operator[4:0];
          else if (inst[31:25] == 7'h20) next_result = $signed(final_reg1val) >>> operator[4:0];
        end
        3'h6: next_result = final_reg1val | operator;
        3'h7: next_result = final_reg1val & operator;
        default:;
      endcase
    end else if (load || store) next_result = final_reg1val + imm;
    else if (jal || jalr) next_result = pc + 4;

    //override should be at bottom of comb
    if (jal_flush || branch_flush || stall) begin //outputs correspond to nop
      next_regwrite = 0;
      next_loadF = 0;
      next_storeF = 0;
      next_branchF = 0;
      next_jalF = 0;
      next_jalrF = 0;
      next_regDF = '0;
      next_target = '0;
      next_result = '0;
      next_store_data = '0;
      next_branch_cond = 0;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin //rst to nop
      stallreg <= 0;
      regwrite <= 0;
      loadF <= 0;
      storeF <= 0;
      branchF <= 0;
      jalF <= 0;
      jalrF <= 0;
      target <= '0;
      result <= '0;
      store_data <= '0;
      branch_cond <= 0;
      regDF <= '0;
    end else begin
      stallreg <= next_stallreg;
      regwrite <= next_regwrite;
      loadF <= next_loadF;
      storeF <= next_storeF;
      branchF <= next_branchF;
      jalF <= next_jalF;
      jalrF <= next_jalrF;
      target <= next_target;
      result <= next_result;
      store_data <= next_store_data;
      branch_cond <= next_branch_cond;
      regDF <= next_regDF;
    end
  end
endmodule  