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
    input logic j_s, b_s, s_s, js_s, jb_s, j_w, b_w, s_w, js_w, jb_w, 
    input logic [31:0] jtarg_s, btarg_s, jtarg_w, btarg_w
  );
    //this is send_pulse cycle
    @(posedge clk);
    jal = j_s || js_s || jb_s;
    branch = b_s || jb_s;
    stall = s_s || js_s;
    if (j_s || js_s || jb_s) j_target = jtarg_s;
    if (b_s || jb_s) b_target = btarg_s;

    @(posedge clk);
    //first wait cycle (if hit this is ack cycle)
    if (j_w || jb_w || js_w) begin
      jal = 1'b1;
      j_target = jtarg_w;
    end else begin 
      jal = 0;
      j_target = '0;
    end
    if (b_w || jb_w) begin
      branch = 1'b1;
      b_target = btarg_w;
    end else begin
      branch = 0;
      b_target = 0;
    end

    if (s_w || js_w) begin
      stall = 1'b1;
    end else begin
      stall = 0;
    end

    do begin
      @(posedge clk);
      jal = 0;
      branch = 0;
      stall = 0;
      j_target = '0;
      b_target = '0;
    end while (final_inst == 32'h00000013);
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_fetch);
    reset();
    //====== test cases

    //normal behavior hit/miss
    for (int i = 0; i < 24; i++) begin
      trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
      if (final_inst != final_pc) begin
        $display("[%0t] WRONG INST: pc=0x%08h inst=0x%08h", $time, final_pc, final_inst);
      end else begin
        $display("[%0t] CORRECT INST: pc=0x%08h inst=0x%08h", $time, final_pc, final_inst);
      end
    end

    //======== hazards on send_pulse cycle WRONG RIGHT ISN'T ACCURATE LOOK AT SPECIFIC VALS
    //jal to hit on send
    trans(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32'd68, '0, '0, '0); 
    if (!(final_inst == final_pc == 32'h44)) begin
        $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x44 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //jal to miss on send
    trans(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32'd8, '0, '0, '0); 
    if (!(final_inst == final_pc == 32'h8)) begin
        $display("[%0t] WRONG INST: exp=0x8 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x8 final_pc/final_inst=0x%08h", $time, final_pc);
    end

    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);

    //branch to hit on send
    trans(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '0, 32'd4, '0, '0);
    if (!(final_inst == final_pc == 32'h4)) begin
        $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x4 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //branch to miss on send
    trans(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, '0, 32'd68, '0, '0);
    if (!(final_inst == final_pc == 32'h44)) begin
        $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x44 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    //stall
    trans(0, 0, 1, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    //jb to hit on send
    trans(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 32'd72, 32'd68, '0, '0);
    if (!(final_inst == final_pc == 32'h48)) begin
        $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x48 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //js to hit on send
    trans(0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 32'd72, 32'd68, '0, '0);
    if (!(final_inst == final_pc == 32'h48)) begin
        $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x48 final_pc/final_inst=0x%08h", $time, final_pc);
    end

    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);

    //======= hazards on ack_hit cycle
    //jal to hit
    trans(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '0, '0, 32'd68, '0); 
    if (!(final_inst == final_pc == 32'h44)) begin
        $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x44 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //jal to miss
    trans(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '0, '0, 32'd8, '0); 
    if (!(final_inst == final_pc == 32'h8)) begin
        $display("[%0t] WRONG INST: exp=0x8 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x8 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    //branch to hit
    trans(0, 0, 0, 0, 0, 0, 1, 0, 0, 0, '0, '0, '0, 32'd4);
    if (!(final_inst == final_pc == 32'h4)) begin
        $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x4 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //branch to miss
    trans(0, 0, 0, 0, 0, 0, 1, 0, 0, 0, '0, '0, '0, 32'd68);
    if (!(final_inst == final_pc == 32'h44)) begin
        $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x44 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    //stall
    trans(0, 0, 0, 0, 0, 0, 0, 1, 0, 0, '0, '0, '0, '0);

    //jb to hit
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, '0, '0, 32'd72, 32'd68);
    if (!(final_inst == final_pc == 32'h48)) begin
        $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x48 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    //js to hit
    trans(0, 0, 0, 0, 0, 0, 0, 0, 1, 0, '0, '0, 32'd72, 32'd68);
    if (!(final_inst == final_pc == 32'h48)) begin
        $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    end else begin
        $display("[%0t] CORRECT INST: exp=0x48 final_pc/final_inst=0x%08h", $time, final_pc);
    end
    
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);

    $display("[%0t] JAL then x", $time);
    //repeated hazards (should ignore everything except first) test first hazard on send cycle and wait cycle
    // jal then jal (hit)
    trans(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 32'd68, '0, 32'd72, '0);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //jal then jal (miss)
    trans(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 32'd4, '0, 32'd72, '0);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);

    //jal then branch (hit)
    trans(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 32'd8, '0, '0, 32'd72);
    $display("[%0t] WRONG INST: exp=0x8 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //jal then branch (miss)
    trans(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 32'd68, '0, '0, 32'd8);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //jal then stall (hit)
    trans(1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 32'd72, '0, '0, '0);
    $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //jal then stall (miss)
    trans(1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 32'd12, '0, '0, '0);
    $display("[%0t] WRONG INST: exp=0xc final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    trans(1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 32'd68, '0, '0, '0);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);    

    $display("[%0t] BRANCH then x", $time);
    //branch then jal (hit)
    trans(0, 1, 0, 0, 0, 1, 0, 0, 0, 0, '0, 32'd68, 32'd72, '0);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //branch then jal (miss)
    trans(0, 1, 0, 0, 0, 1, 0, 0, 0, 0, '0, 32'd4, 32'd72, '0);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //branch then branch (hit)
    trans(0, 1, 0, 0, 0, 0, 1, 0, 0, 0, '0, 32'd8, '0, 32'd72);
    $display("[%0t] WRONG INST: exp=0x8 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //branch then branch (miss)
    trans(0, 1, 0, 0, 0, 0, 1, 0, 0, 0, '0, 32'd68, '0, 32'd8);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //branch then stall (hit)
    trans(0, 1, 0, 0, 0, 0, 0, 1, 0, 0, '0, 32'd72, '0, '0);
    $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //branch then stall (miss)
    trans(0, 1, 0, 0, 0, 0, 0, 1, 0, 0, '0, 32'd12, '0, '0);
    $display("[%0t] WRONG INST: exp=0xc final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    trans(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, 32'd64, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0);
    trans(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '0, '0, '0, '0); 

    $display("[%0t] STALL then x", $time);
    //stall first
    //stall then jal (hit)
    trans(0, 0, 1, 0, 0, 1, 0, 0, 0, 0, '0, '0, 32'd72, '0);
    $display("[%0t] WRONG INST: exp=0x48 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //stall then jal (miss)
    trans(0, 0, 1, 0, 0, 1, 0, 0, 0, 0, '0, '0, 32'd4, '0);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    //stall then branch (hit)
    trans(0, 0, 1, 0, 0, 0, 1, 0, 0, 0, '0, '0, '0, 32'd4);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //stall then branch (miss)
    trans(0, 0, 1, 0, 0, 0, 1, 0, 0, 0, '0, '0, '0, 32'd68);
    $display("[%0t] WRONG INST: exp=0x44 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //stall then stall 
    trans(0, 0, 1, 0, 0, 0, 0, 1, 0, 0, '0, '0, '0, '0);
    $display("[%0t] REPORT: final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);
    //stall then stall (miss)
    trans(0, 0, 1, 0, 0, 0, 0, 1, 0, 0, '0, '0, '0, '0);
    $display("[%0t] REPORT: final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);


    //works up to here need to test deep hazard repeats (only need 1)
    //test miss case first (WAIT_ACK) state
    @(posedge clk);
    //no hazard so pc + 4 instruction request
    @(posedge clk);
    //first wait cycle
    jal = 1'b1;
    j_target = 32'd4; //miss

    @(posedge clk); //WAIT_ACK state to recieve stale instructions and send req from earlier cycle
    jal = 1'b1;
    j_target = 32'd68; //should be ignored

    do begin
      @(posedge clk);
      jal = 0;
      branch = 0;
      stall = 0;
      j_target = '0;
      b_target = '0;
    end while (final_inst == 32'h00000013);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    @(posedge clk);
    branch = 1'b1;
    b_target = 32'd4; //hit

    @(posedge clk); //SEND_O cycle
    jal = 1'b1;
    j_target = 32'd68; //should be ignored

    do begin
      @(posedge clk);
      jal = 0;
      branch = 0;
      stall = 0;
      j_target = '0;
      b_target = '0;
    end while (final_inst == 32'h00000013);
    $display("[%0t] WRONG INST: exp=0x4 final_pc=0x%08h final_inst = 0x%08h", $time, final_pc, final_inst);

    #20;
    $finish;
  end
endmodule