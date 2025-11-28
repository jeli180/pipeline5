`timescale 1ns/1ps
module tb_fetch;

  logic clk, rst;

  //cache (not driving)
  logic cache_ack, addr_ready;
  logic [31:0] inst, addr;

  //hazard (driving)
  logic stall, jal, branch;
  logic [31:0] j_target, b_target;

  //to decode (monitor)
  logic [31:0] final_inst, final_pc;

  fetch dut (
    .clk(clk),
    .rst(rst),

    //cache signals
    .cache_ack(cache_ack),
    .inst(inst),
    .addr_ready(addr_ready),
    .addr(addr),

    //hazard
    .stall(stall),
    .jal(jal),
    .branch(branch),
    .j_target(j_target),
    .b_target(b_target),

    //to decode
    .final_pc(final_pc),
    .final_inst(final_inst)
  );

  icache i0 (
    .addr(addr),
    .send_pulse(addr_ready),
    .clk(clk),
    .rst(rst),
    .inst(inst),
    .ack(cache_ack)
  );

  initial clk = 0;
  always #10 clk = ~clk;

  task reset();
    rst = 1;
    stall = 0;
    jal = 0;
    branch = 0;
    j_target = '0;
    b_target = '0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  //nop = 0x13

  task trans (
    //input logic jflush, bflush, stall, js, jb, jmiss, bmiss, smiss,
    //input logic [31:0] jtarg, btarg
  );
    do begin
      @(posedge clk);
    end while (final_inst == 32'h00000013);
    if (final_inst != final_pc) begin
      $display("[%0t] WRONG INST: pc=0x%08h inst=0x%08h", $time, final_pc, final_inst);
    end else begin
      $display("[%0t] CORRECT INST: pc=0x%08h inst=0x%08h", $time, final_pc, final_inst);
    end
  endtask

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_fetch);
    reset();
    //====== test cases
    //normal behavior hit/miss
    //jal flush normal/during a miss
    //branch flush normal/during a miss
    //stall normal/during a miss
    //jal + stall
    //jal + branch
    repeat (10) trans();

    #20;
    $finish;
  end
endmodule