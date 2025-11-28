`timescale 1ns/1ps
module tb_icache;
  logic [31:0] addr;
  logic send_pulse, clk, rst, ack;
  logic [31:0] inst;

  icache dut (
    .addr(addr), 
    .send_pulse(send_pulse), 
    .clk(clk), 
    .rst(rst), 
    .inst(inst), 
    .ack(ack)
  );

  initial clk = 0;
  always #10 clk = ~clk;

  task reset();
    rst = 1;
    addr = '0;
    send_pulse = 0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask
  //========= REQUIRES INSTRUCTIONS.MEM FILE TO HAVE INSTRUCTIONS MATCHING THEIR ADDR
  task trans (
    input logic [31:0] addr_in
  );
    //TASK IS CALLED AFTER DATA TRANSFER CYCLE, SO SEND_PULSE AND ACK ARE LOW
    //HIT MISS TERMINAL PRINTING IS INCORRECT, MORE HITS THAN IT SAYS
    logic [31:0] inst_rec;
    send_pulse = 1;
    addr = addr_in;
    #0;
    @(posedge clk);
    #0;
    @(posedge clk);
    if (ack) begin
      inst_rec = inst;
      if (inst_rec == addr_in) begin
        $display("[%0t] HIT/PASS: addr=0x%08h inst=0x%08h", $time, addr_in, inst_rec);
      end else begin
        $display("[%0t] HIT/FAIL: addr=0x%08h expected=0x%08h got=0x%08h", $time, addr_in, addr_in, inst_rec);
      end
      @(posedge clk);
      send_pulse = 0;
    end else begin
      do begin
        @(posedge clk);
        send_pulse = 0;
      end while (!ack);
      inst_rec = inst;
      if (inst_rec == addr_in) begin
        $display("[%0t] MISS/PASS: addr=0x%08h inst=0x%08h", $time, addr_in, inst_rec);
      end else begin
        $display("[%0t] MISS/FAIL: addr=0x%08h expected=0x%08h got=0x%08h", $time, addr_in, addr_in, inst_rec);
      end
      @(posedge clk);
    end
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_icache);
    
    reset();
    //needs 12 cycles to fill completely
    //first 3 cycles
    trans(32'h0); //miss
    //should be hits
    trans(32'h4);
    trans(32'h8);

    //should be one hit above
    trans(32'd12);
    trans(32'd8);
    trans(32'd4);
    trans(32'd24);
    trans(32'd60);

    //flush cache
    trans(32'd64);
    trans(32'd56); //should still be hit
    trans(32'd52);
    trans(32'd72);
    trans(32'd160);
    trans(32'd144);
    trans(32'd8);
    trans(32'd8);
    trans(32'd12);
    trans(32'd12);
    trans(32'd12);
    trans(32'd16);
    trans(32'd20);

    #20;
    $finish;
  end
endmodule