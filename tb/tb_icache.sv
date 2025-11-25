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

  task cache_transaction (
    input logic [31:0] addr_in
  );
    //TASK IS CALLED AFTER DATA TRANSFER CYCLE, SO SEND_PULSE AND ACK ARE LOW
    logic [31:0] inst_rec;
    send_pulse = 1;
    addr = addr_in;
    #0;
    if (ack) begin
      inst_rec = inst;
      if (inst_rec == addr_in) begin
        $display("[%0t] PASS: addr=0x%08h inst=0x%08h", $time, addr_in, inst_rec);
      end else begin
        $display("[%0t] FAIL: addr=0x%08h expected=0x%08h got=0x%08h", $time, addr_in, addr_in, inst_rec);
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
        $display("[%0t] PASS: addr=0x%08h inst=0x%08h", $time, addr_in, inst_rec);
      end else begin
        $display("[%0t] FAIL: addr=0x%08h expected=0x%08h got=0x%08h", $time, addr_in, addr_in, inst_rec);
      end
      @(posedge clk);
    end
  endtask

  initial begin
    $dumpfile("waves.vcd");   // MUST match $wave in the script
    $dumpvars(0, tb_icache);     // use your top tb module name here
    
    reset();

    $finish;
  end
endmodule