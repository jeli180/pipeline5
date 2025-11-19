module decode (
  input logic clk, rst,

  //hazard
  input logic stall, jal_flush, branch_flush,

  //fetch
  input logic [31:0] inst, pc,

  //regfile
  input logic [31:0] file_val1, file_val2,
  output logic [4:0] file_reg1, file_reg2,

  //output to execute
  output logic rtype, itype, load, store, branch, jal, jalr, //itype flag is for opcode 0010011
  output logic [31:0] imm, finalI, finalpc,
  output logic [4:0] reg1, reg2, regD,
  output logic [31:0] reg1val, reg2val
);

  //supports rtype, itype, branching, jal, jalr, lw, sw, NO UTYPE OR ENVIRONMENT

  //internal signals
  logic next_rtype, next_itype, next_load, next_store, next_branch, next_jal, next_jalr;
  logic [31:0] next_imm, next_finalI, next_finalpc;
  logic [4:0] next_reg1, next_reg2, next_regD;
  logic [31:0] next_reg1val, next_reg2val;
  logic [6:0] op;
  logic [31:0] nop;

  assign op = inst[6:0];
  assign nop = 32'h00000013;

  always_comb begin
    //default nop
    next_itype = 0;
    next_rtype = 0;
    next_load = 0;
    next_store = 0;
    next_branch = 0;
    next_jal = 0;
    next_jalr = 0;
    next_imm = '0;
    next_reg1 = '0;
    next_reg2 = '0;
    next_regD = '0;
    next_reg1val = '0;
    next_reg2val = '0;
    next_finalI = inst;
    next_finalpc = pc;
    file_reg1 = '0;
    file_reg2 = '0;

    //jal and branch flush, so defaults are valid
    if (jal_flush || branch_flush) begin
      next_finalI = nop;
      next_itype = 1;
    end else if (stall) begin
      next_itype = itype;
      next_rtype = rtype;
      next_load = load;
      next_store = store;
      next_branch = branch;
      next_jal = jal;
      next_jalr = jalr;
      next_imm = imm;
      next_reg1 = reg1;
      next_reg2 = reg2;
      next_regD = regD;
      next_reg1val = reg1val;
      next_reg2val = reg2val;
      next_finalI = finalI;
      next_finalpc = finalpc;
      file_reg1 = reg1;
      file_reg2 = reg2;
    end else begin
      //fill next type, imm, reg based on opcodes
      case (op)
        7'b0110011: begin //rtype: reg1, reg2, regD
          next_rtype = 1;
          next_reg1 = inst[19:15];
          next_reg2 = inst[24:20];
          next_regD = inst[11:7];
          //register file fetch
          file_reg1 = next_reg1;
          file_reg2 = next_reg2;
          next_reg1val = file_val1;
          next_reg2val = file_val2;
        end
        7'b0010011: begin //itype: imm, reg1, regD
          next_itype = 1;
          next_reg1 = inst [19:15];
          next_regD = inst [11:7];
          next_imm = {{20{inst[31]}}, inst[31:20]};
          //register file fetch
          file_reg1 = next_reg1;
          next_reg1val = file_val1;
        end
        7'b0000011: begin //load: imm, reg1, regD
          next_load = 1;
          next_reg1 = inst [19:15];
          next_regD = inst [11:7];
          next_imm = {{20{inst[31]}}, inst[31:20]};
          //register file fetch
          file_reg1 = next_reg1;
          next_reg1val = file_val1;
        end
        7'b0100011: begin //store: reg1, reg2, imm
          next_store = 1;
          next_reg1 = inst [19:15];
          next_reg2 = inst [24:20];
          next_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
          //register file fetch
          file_reg1 = next_reg1;
          file_reg2 = next_reg2;
          next_reg1val = file_val1;
          next_reg2val = file_val2;
        end
        7'b1100011: begin //branch: reg1, reg2, imm
          next_branch = 1;
          next_reg1 = inst[19:15];
          next_reg2 = inst[24:20];
          next_imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
          //register file fetch
          file_reg1 = next_reg1;
          file_reg2 = next_reg2;
          next_reg1val = file_val1;
          next_reg2val = file_val2;
        end
        7'b1101111: begin //jal: imm, regD
          next_jal = 1;
          next_imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
          next_regD = inst [11:7];
        end
        7'b1100111: begin //jalr: imm, reg1, regD
          next_jalr = 1;
          next_reg1 = inst [19:15];
          next_regD = inst [11:7];
          next_imm = {{20{inst[31]}}, inst[31:20]};
          //register file fetch
          file_reg1 = next_reg1;
          next_reg1val = file_val1;
        end
      endcase
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      itype <= 0;
      rtype <= 0;
      load <= 0;
      store <= 0;
      branch <= 0;
      jal <= 0;
      jalr <= 0;
      imm <= '0;
      reg1 <= '0;
      reg2 <= '0;
      regD <= '0;
      reg1val <= '0;
      reg2val <= '0;
      finalI <= nop;
      finalpc <= '0;
    end else begin
      itype <= next_itype;
      rtype <= next_rtype;
      load <= next_load;
      store <= next_store;
      branch <= next_branch;
      jal <= next_jal;
      jalr <= next_jalr;
      imm <= next_imm;
      reg1 <= next_reg1;
      reg2 <= next_reg2;
      regD <= next_regD;
      reg1val <= next_reg1val;
      reg2val <= next_reg2val;
      finalI <= next_finalI;
      finalpc <= next_finalpc;
    end
  end
endmodule