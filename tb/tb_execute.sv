`timescale 1ns/1ps
module tb_execute;

  //universal
  logic clk, rst, jal_flush, branch_flush, stall, regwrite_mem, regwrite_wb;
  logic [31:0] j_target, b_target, regD_val_mem, regD_val_wb;
  logic [4:0] regD_mem, regD_wb;


  //cache
  logic [31:0] ca_addr, ca_inst;
  logic ca_addr_ready, ca_ack;

  //fetch
  logic [31:0] fe_inst, fe_pc;

  //regfile
  logic [31:0] file_val1, file_val2;
  logic [4:0] file_reg1, file_reg2;

  //decode
  logic [31:0] de_inst, de_pc, de_imm, de_reg1val, de_reg2val;
  logic [4:0] de_reg1, de_reg2, de_regD;
  logic de_rtype, de_itype, de_load, de_store, de_branch, de_jal, de_jalr;

  //execute
  logic [31:0] ex_target, ex_result, ex_store_data;
  logic [4:0] ex_regD;
  logic ex_regwrite, ex_load, ex_store, ex_jal, ex_jalr, ex_branch_cond;

  icache cac (
    .addr(ca_addr),
    .send_pulse(ca_addr_ready),
    .clk(clk),
    .rst(rst),
    .inst(ca_inst),
    .ack(ca_ack)
  );

  fetch fet (
    .clk(clk),
    .rst(rst),

    //cache signals
    .cache_ack(ca_ack),
    .inst(ca_inst),
    .addr_ready(ca_addr_ready),
    .addr(ca_addr),

    //hazard (DRIVE)
    .stall(stall),
    .jal(jal_flush),
    .branch(branch_flush),
    .j_target(j_target),
    .b_target(b_target),

    //to decode
    .final_pc(fe_pc),
    .final_inst(fe_inst)
  );

  decode dec (
    .clk(clk),
    .rst(rst),

    //hazards (DRIVE)
    .stall(stall),
    .jal_flush(jal_flush),
    .branch_flush(branch_flush),

    //from fetch
    .inst(fe_inst),
    .pc(fe_pc),

    //regfile inputs (DRIVE)
    .file_val1(file_val1),
    .file_val2(file_val2),

    //regfile outputs (monitor)
    .file_reg1(file_reg1),
    .file_reg2(file_reg2),

    //to execute (monitor)
    .rtype(de_rtype),
    .itype(de_itype),
    .load(de_load),
    .store(de_store),
    .branch(de_branch),
    .jal(de_jal),
    .jalr(de_jalr),
    .imm(de_imm),
    .finalI(de_inst),
    .finalpc(de_pc),
    .reg1(de_reg1),
    .reg2(de_reg2),
    .regD(de_regD),
    .reg1val(de_reg1val),
    .reg2val(de_reg2val)
  );

  execute DUT (
    .clk(clk),
    .rst(rst),

    //hazard (DRIVE)
    .branch_flush(branch_flush),
    .jal_flush(jal_flush),
    .stall(stall),

    //reg forwarding
    .regD_mem(regD_mem),
    .regD_wb(regD_wb),
    .regD_val_mem(regD_val_mem),
    .regD_val_wb(regD_val_wb),
    .regwrite_mem(regwrite_mem),
    .regwrite_wb(regwrite_wb),

    //from decode
    .rtype(de_rtype),
    .itype(de_itype),
    .load(de_load),
    .store(de_store),
    .branch(de_branch),
    .jal(de_jal),
    .jalr(de_jalr),
    .imm(de_imm),
    .inst(de_inst),
    .pc(de_pc),
    .reg1(de_reg1),
    .reg2(de_reg2),
    .regD(de_regD),
    .reg1val(de_reg1val),
    .reg2val(de_reg2val),

    //to mem (monitor)
    .regwrite(ex_regwrite),
    .loadF(ex_load),
    .storeF(ex_store),
    .jalF(ex_jal),
    .jalrF(ex_jalr),
    .target(ex_target),
    .result(ex_result),
    .store_data(ex_store_data),
    .branch_cond(ex_branch_cond),
    .regDF(ex_regD)
  );

  initial clk = 0;
  always #10 clk = ~clk;

  int jal_ct, branch_ct, stall_ct, jal_en, branch_en, stall_en;

  task reset();
    rst = 1;
    stall = 0;
    jal_flush = 0;
    branch_flush = 0;
    j_target = '0;
    b_target = '0;
    file_val1 = '0;
    file_val2 = '0;
    jal_ct = 0;
    branch_ct = 0;
    stall_ct = 0;
    jal_en = 1;
    branch_en = 0;
    stall_en = 0;
    regwrite_mem = 0;
    regwrite_wb = 0;
    regD_mem = '0;
    regD_wb = '0;
    regD_val_mem = '0;
    regD_val_wb = '0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  //drive hazards, j_target, b_target, file_val1, file_val2
  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_execute);
    reset();

    //test if branch conditions actually work, register forwarding
    //instructions in mem file
    /*
    add x5, x6, x7
    sub x12, x4, x0
    and x0, x8, x4
    addi x8, x3, 22
    ori x3, x5, 0xFF
    slli x2, x9, 0x4
    branch1:
    lw x18, 4(x2) 24
    lw x5, 12(x9) 28
    branch2:
    lw x0, 0(x0) 32
    sw x3, 12(x2)
    sw x28, 4(x18)
    sw x24, 8(x0)
    beq x2, x8, branch1
    branch3:
    bne x0, x7, branch2 52
    blt x5, x10, branch3
    jal x8, branch1
    jal x0, branch2
    jal x30, branch3
    jalr x8, 0(x8)
    jalr x4, 4(x19)
    jalr x26, 16(x12)

    add x5, x6, x7 pc=84
    sub x12, x4, x0
    and x0, x8, x4
    addi x8, x3, 22
    ori x3, x5, 0xFF
    slli x2, x9, 0x4
    branch4:
    lw x18, 4(x2)
    lw x5, 12(x9)
    branch5:
    lw x0, 0(x0)
    sw x3, 12(x2)
    sw x28, 4(x18)
    sw x24, 8(x0)
    beq x2, x8, branch4
    branch6:
    bne x0, x7, branch5
    blt x5, x10, branch6
    jal x8, branch4
    jal x0, branch5
    jal x30, branch6
    jalr x8, 0(x8)
    jalr x4, 4(x19)
    jalr x26, 16(x12)
    */

    regwrite_mem = 1'b1;
    regwrite_wb = 1'b1;
    regD_mem = 5'd8;
    regD_wb = 5'd5;
    regD_val_mem = 32'h30;
    regD_val_wb = 32'h40;
    //=== test cases
    //normal behavior
    $display("NO HAZARD TESTING");
    do begin
      @(posedge clk);
      if (file_reg1 == 5'b0) file_val1 = '0;
      else file_val1 = 32'h10;
      if (file_reg2 == 5'b0) file_val2 = '0;
      else file_val2 = 32'h100;
      #1;
      $display("EX OUTPUT: regwrite = %d | load = %d | store = %d | jal = %d | jalr = %d | branch_cond = %d", ex_regwrite, ex_load, ex_store, ex_jal, ex_jalr, ex_branch_cond);
      $display("target = %h | result = %h | store_data = %h | regD = %d", ex_target, ex_result, ex_store_data, ex_regD);
    end while (ex_regD != 5'd26);

    regwrite_mem = 1'b0;
    regwrite_wb = 1'b0;
    regD_mem = 5'd8;
    regD_wb = 5'd5;
    regD_val_mem = 32'h30;
    regD_val_wb = 32'h40;
    $display("HAZARD TESTING");
    //hazards
    do begin
      @(posedge clk);
      jal_flush = 0;
      j_target = '0;
      branch_flush = 0;
      b_target = '0;
      stall = 0;

      if (file_reg1 == 5'b0) file_val1 = '0;
      else file_val1 = 32'h10;
      if (file_reg2 == 5'b0) file_val2 = '0;
      else file_val2 = 32'h100;

      if (jal_en) begin
        jal_ct++;
        if (jal_ct >= 30) begin
          jal_en = 0;
          branch_en = 1;
          jal_flush = 1'b1;
          j_target = 32'd84;
          $display("JAL FLUSH CYCLE");
        end
      end else if (branch_en) begin
        branch_ct++;
        if (branch_ct >= 30) begin
          branch_en = 0;
          stall_en = 1;
          branch_flush = 1'b1;
          b_target = 32'd84;
          $display("BRANCH FLUSH CYCLE");
        end
      end else if (stall_en) begin
        stall_ct++;
        if (stall_ct >= 30) begin
          stall = 1'b1;
          $display("STALL START");
        end
        if (stall_ct >= 33) begin
          stall = 1'b0;
          stall_en = 0;
          $display("STALL END");
        end
      end

      #1;
      $display("EX OUTPUT: regwrite = %d | load = %d | store = %d | jal = %d | jalr = %d | branch_cond = %d", ex_regwrite, ex_load, ex_store, ex_jal, ex_jalr, ex_branch_cond);
      $display("target = %h | result = %h | store_data = %h | regD = %d", ex_target, ex_result, ex_store_data, ex_regD);
    end while (ex_regD != 5'd26);
    #20;
    $finish;
  end
endmodule