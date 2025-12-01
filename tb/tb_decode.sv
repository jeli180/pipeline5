`timescale 1ns/1ps
module tb_decode;

  logic clk, rst;

  //regfile
  logic [31:0] file_val1, file_val2;
  logic [4:0] file_reg1, file_reg2;

  //dut
  logic stall, jal_flush, branch_flush, rtype, itype;
  logic load, store, branch, jal, jalr;
  logic [31:0] inst, pc, imm, finalI, finalpc;
  logic [4:0] reg1, reg2, regD;
  logic [31:0] reg1val, reg2val;

  decode dut (
    .clk(clk),
    .rst(rst),

    //hazards (drive)
    .stall(stall),
    .jal_flush(jal_flush),
    .branch_flush(branch_flush),

    //from fetch (drive)
    .inst(inst),
    .pc(pc),

    //regfile inputs (drive)
    .file_val1(file_val1),
    .file_val2(file_val2),

    //regfile outputs (monitor)
    .file_reg1(file_reg1),
    .file_reg2(file_reg2),

    //to execute (monitor)
    .rtype(rtype),
    .itype(itype),
    .load(load),
    .store(store),
    .branch(branch),
    .jal(jal),
    .jalr(jalr),
    .imm(imm),
    .finalI(finalI),
    .finalpc(finalpc),
    .reg1(reg1),
    .reg2(reg2),
    .regD(regD),
    .reg1val(reg1val),
    .reg2val(reg2val)
  );

  //tasks for all instructions that take hazard flags

  initial clk = 0;
  always #10 clk = ~clk;

  task reset();
    rst = 1;
    stall = 0;
    jal_flush = 0;
    branch_flush = 0;
    file_val1 = '0;
    file_val2 = '0;
    inst = '0;
    pc = '0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  task send (
    input logic [31:0] inst_send, pc_send,
    input logic rt, it, lo, st, br, ja, jr,
    input logic j, b, s 
  );
    logic [4:0] reg1_exp, reg2_exp, regD_exp;
    logic [31:0] imm_exp, file_val1_exp, file_val2_exp;

    //stall val
    logic [4:0] prev_reg1, prev_reg2, prev_regD;
    logic [31:0] prev_imm, prev_file_val1, prev_file_val2, prev_finalI, prev_finalpc;
    logic prev_rt, prev_it, prev_lo, prev_st, prev_br, prev_ja, prev_jr;
    
    reg1_exp = '0;
    reg2_exp = '0;
    regD_exp = '0;
    imm_exp = '0;
    file_val1_exp = '0;
    file_val2_exp = '0;

    //im always driving regfile val as aa, bb

    //=== output predictor
    if (rt) begin
      reg1_exp = inst_send[19:15];
      reg2_exp = inst_send[24:20];
      regD_exp = inst_send[11:7];
    end else if (it || lo || jr) begin
      reg1_exp = inst_send [19:15];
      regD_exp = inst_send [11:7];
      imm_exp = {{20{inst_send[31]}}, inst_send[31:20]};
    end else if (st) begin
      reg1_exp = inst_send[19:15];
      reg2_exp = inst_send[24:20];
      imm_exp = {{20{inst_send[31]}}, inst_send[31:25], inst_send[11:7]};
    end else if (br) begin
      reg1_exp = inst_send[19:15];
      reg2_exp = inst_send[24:20];
      imm_exp = {{19{inst_send[31]}}, inst_send[31], inst_send[7], inst_send[30:25], inst_send[11:8], 1'b0};
    end else if (ja) begin
      regD_exp = inst_send[11:7];
      imm_exp = {{11{inst_send[31]}}, inst_send[31], inst_send[19:12], inst_send[20], inst_send[30:21], 1'b0};
    end else $display("ERROR: NO INSTRUCTION FLAG RAISED FOR THIS TASK");
    #0;
    prev_reg1 = reg1;
    prev_reg2 = reg2;
    prev_regD = regD;
    prev_imm = imm;
    prev_file_val1 = reg1val;
    prev_file_val2 = reg2val;
    prev_finalI = finalI;
    prev_finalpc = finalpc;
    prev_rt = rtype;
    prev_it = itype;
    prev_lo = load;
    prev_st = store;
    prev_br = branch;
    prev_ja = jal;
    prev_jr = jalr;

    #0;
    jal_flush = j;
    branch_flush = b;
    stall = s;
    inst = inst_send;
    pc = pc_send;
    #0;

    //check reg req to regfile
    if (file_reg1 != reg1_exp && !j && !b && !s) begin
      $display("Reg1 mismatch: Sent to reg file: 0x%8h Expected: 0x%8h", file_reg1, reg1_exp);
    end 
    if (file_reg2 != reg2_exp && !j && !b && !s) begin
      $display("Reg2 mismatch: Sent to reg file: 0x%8h Expected: 0x%8h", file_reg2, reg2_exp);
    end

    //drive regfile inputs
    #0;
    if (file_reg1 != '0) file_val1_exp = 32'hAA;
    if (file_reg2 != '0) file_val2_exp = 32'hBB;
    file_val1 = file_val1_exp;
    file_val2 = file_val2_exp;

    @(posedge clk); //values are now registered
    #2;
    if (j || b) begin
      if (finalI == 32'h13 
          && rtype == 0
          && itype == 1
          && load == 0
          && store == 0
          && branch == 0
          && jal == 0
          && jalr == 0
          && imm == '0
          && reg1 == '0
          && reg2 == '0
          && regD == '0
          && reg1val == '0
          && reg2val == '0) begin
         $display("PASS w HAZARD: instr = 0x%8h jal = %d branch = %d", inst_send, j, b);
          end else $display("FAIL w HAZARD: instr = 0x%8h jal = %d branch = %d", inst_send, j, b);
    end else if (s) begin
      if (finalI == prev_finalI 
          && finalpc == prev_finalpc
          && rtype == prev_rt
          && itype == prev_it
          && load == prev_lo
          && store == prev_st
          && branch == prev_br
          && jal == prev_ja
          && jalr == prev_jr
          && imm == prev_imm
          && reg1 == prev_reg1
          && reg2 == prev_reg2
          && regD == prev_regD
          && reg1val == prev_file_val1
          && reg2val == prev_file_val2) begin
         $display("PASS w STALL: instr = 0x%8h finalI = 0x%8h", inst_send, finalI);
         
          end else $display("FAIL w STALL: instr = 0x%8h", inst_send);
    end
    else begin
      if (finalI == inst_send 
          && rtype == rt
          && itype == it
          && load == lo
          && store == st
          && branch == br
          && jal == ja
          && jalr == jr
          && imm == imm_exp
          && reg1 == reg1_exp
          && reg2 == reg2_exp
          && regD == regD_exp
          && reg1val == file_val1_exp
          && reg2val == file_val2_exp) begin
         $display("PASS: instr = 0x%8h", inst_send);
    end else begin 
      $display("FAIL: instr = 0x%8h", inst_send);
      $display("exp rtype: %d actual rtype: %d", rt, rtype);
      $display("exp itype: %d actual itype: %d", it, itype);
      $display("exp load: %d actual load: %d", lo, load);
      $display("exp store: %d actual store: %d", st, store);
      $display("exp branch: %d actual rtype: %d", br, branch);
      $display("exp jal: %d actual jal: %d", ja, jal);
      $display("exp jalr: %d actual jalr: %d", jr, jalr);
      $display("exp imm: %8h actual imm: %8h", imm_exp, imm);
      $display("exp reg1val: %8h actual reg1val: %8h", file_val1_exp, reg1val);
      $display("exp reg2val: %8h actual reg2val: %8h", file_val2_exp, reg2val);
      $display("exp reg1: %d actual reg1: %d", reg1_exp, reg1);
      $display("exp reg2: %d actual reg2: %d", reg2_exp, reg2);
      $display("exp regD: %d actual regD: %d", regD_exp, regD);
    end
    end
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_decode);
    reset();

    //==== test cases
    
    //every instruction type without hazards
    send (32'h007302b3, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0); //add x5, x6, x7
    send (32'h40020633, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0); //sub x12, x4, x0
    send (32'h00447033, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0); //and x0, x8, x4
    send (32'h01618413, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0); //addi x8, x3, 22
    send (32'h0ff2e193, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0); //ori x3, x5, 0xFF
    send (32'h00449113, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0); //slli x2, x9, 0x4
    send (32'h00412903, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0); //lw x18, 4(x2)
    send (32'h00c4a283, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0); //lw x5, 12(x9)
    send (32'h00002003, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0); //lw x0, 0(x0)
    send (32'h00312623, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0); //sw x3, 12(x2)
    send (32'h01c92223, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0); //sw x28, 4(x18)
    send (32'h01802423, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0); //sw x24, 8(x0)
    send (32'hfe8104e3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0); //beq x2, x8, branch1
    send (32'hfe7016e3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0); //bne x0, x7, branch2
    send (32'hfea2cee3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0); //blt x5, x10, branch3
    send (32'hfddff46f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0); //jal x8, branch1
    send (32'hfe1ff06f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0); //jal x0, branch2
    send (32'hff1fff6f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0); //jal x30, branch3
    send (32'h00040467, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0); //jalr x8, 0(x8)
    send (32'h00498267, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0); //jalr x4, 4(x19)
    send (32'h01060d67, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0); //jalr x26, 16(x12)

    //every hazard
    send (32'h007302b3, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0); //add x5, x6, x7
    send (32'h40020633, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0); //sub x12, x4, x0
    send (32'h00447033, 32'hcc, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1); //and x0, x8, x4
    send (32'h01618413, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0); //addi x8, x3, 22
    send (32'h0ff2e193, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0); //ori x3, x5, 0xFF
    send (32'h00449113, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1); //slli x2, x9, 0x4
    send (32'h00412903, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0); //lw x18, 4(x2)
    send (32'h00c4a283, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0); //lw x5, 12(x9)
    send (32'h00002003, 32'hcc, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1); //lw x0, 0(x0)
    send (32'h00312623, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0); //sw x3, 12(x2)
    send (32'h01c92223, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0); //sw x28, 4(x18)
    send (32'h01802423, 32'hcc, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1); //sw x24, 8(x0)
    send (32'hfe8104e3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0); //beq x2, x8, branch1
    send (32'hfe7016e3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0); //bne x0, x7, branch2
    send (32'hfea2cee3, 32'hcc, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1); //blt x5, x10, branch3
    send (32'hfddff46f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0); //jal x8, branch1
    send (32'hfe1ff06f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0); //jal x0, branch2
    send (32'hff1fff6f, 32'hcc, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1); //jal x30, branch3
    send (32'h00040467, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0); //jalr x8, 0(x8)
    send (32'h00498267, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0); //jalr x4, 4(x19)
    send (32'h01060d67, 32'hdd, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1); //jalr x26, 16(x12)

    send (32'h00498267, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0); //jalr x4, 4(x19)
    send (32'h01060d67, 32'hcc, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0); //jalr x26, 16(x12)
    //multicycle stall
    send (32'h00412903, 32'hAA, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1); //lw x18, 4(x2)
    send (32'hff1fff6f, 32'hbb, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1); //jal x30, branch3
    send (32'h00449113, 32'hcc, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1); //slli x2, x9, 0x4

    #20;
    $finish;
  end
endmodule