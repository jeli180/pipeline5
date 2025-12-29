`timescale 1ns/1ps
module tb_dcacheNB;
  
  logic clk, rst;

  //dcache - CPU
  logic lw_in, send_pulse_in, hit_ack, miss_send, load_done_stall, passive_stall;
  logic [4:0] regD_in, regD_out;
  logic [31:0] addr_in, store_data_in, load_data_out;

  //MSHR - dcache
  logic mshr_done_pulse, load_way_out, load_valid, evict_valid, load_way_in, mshr_full;
  logic [4:0] mshr_regD_out, mshr_regD_in;
  logic [31:0] addr1, addr2, addr3, addr4, mshr_addr_out, mshr_data_out, addr_evict, addr_load, evict_data;

  dcache cache_DUT (
    .clk(clk),
    .rst(rst),

    //from CPU (DRIVE)
    .regD_in(regD_in),
    .addr_in(addr_in),
    .store_data(store_data_in),
    .send_pulse(send_pulse_in),
    .lw(lw_in),

    //to CPU (MONITOR)
    .hit_ack(hit_ack),
    .miss_send(miss_send),
    .regD_out(regD_out),
    .load_data(load_data_out),

    //hazards to CPU (MONITOR)
    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),

    //from MSHR
    .addr1(addr1),
    .addr2(addr2),
    .addr3(addr3),
    .addr4(addr4),
    .mshr_regD_out(mshr_regD_out),
    .mshr_addr_out(mshr_addr_out),
    .mshr_data_out(mshr_data_out),
    .mshr_done_pulse(mshr_done_pulse),
    .load_way_out(load_way_out),

    //to MSHR
    .addr_evict(addr_evict),
    .addr_load(addr_load),
    .evict_data(evict_data),
    .mshr_regD_in(mshr_regD_in),
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),

    //hazard from MSHR
    .mshr_full(mshr_full)
  );

  mshr mshr_DUT (
    .clk(clk),
    .rst(rst),

    //from dcache
    .addr_evict(addr_evict),
    .addr_load(addr_load),
    .evict_data(evict_data),
    .regD_in(mshr_regD_in),
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),

    //to dcache
    .addr1(addr1),
    .addr2(addr2),
    .addr3(addr3),
    .addr4(addr4),
    .addr_out(mshr_addr_out),
    .data_out(mshr_data_out),
    .regD_out(mshr_regD_out),
    .load_way_out(load_way_out),
    .done_pulse(mshr_done_pulse),

    //hazard to dcache
    .full(mshr_full)
  );

  //DRIVE CPU INPUTS: regD_in, addr_in, store_data_in, send_pulse_in, lw_in

  initial clk = 0;
  always #5 clk = ~clk;

  task reset();
    rst = 1;
    regD_in = '0;
    addr_in = '0;
    store_data_in = '0;
    send_pulse_in = 0;
    lw_in = 0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  task send (
    input logic [4:0] regD,
    input logic [31:0] addr,
    input logic lw
  );
    //store_data_in hardwired to address for easier debugging
    //DRIVE CPU INPUTS: regD_in, addr_in, store_data_in, send_pulse_in, lw_in
    do begin
      @(posedge clk);
      regD_in = regD;
      addr_in = addr;
      store_data_in = addr;
      lw_in = lw;
      send_pulse_in = 1'b1;
      #1;
    end while (load_done_stall || passive_stall);

  endtask

  task lag ();
    @(posedge clk);
    regD_in = '0;
    addr_in = '0;
    store_data_in = '0;
    lw_in = 0;
    send_pulse_in = 0;
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_dcacheNB);
    reset();

    //==== Normal Behavior Test Cases ====\\

    //store miss 64-71 (inst since all lines invalid)
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h100 + i * 4, 0);
      lag();
    end

    //store miss 0-7 (inst since all lines invalid)
    //now both ways of sets 0-7 are filled, 0-7 are mru, all dirty
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h0 + i * 4, 0);
      lag();
    end

    //store hit to 0-7, mru kept the same
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h0 + i * 4, 0);
      lag();
    end

    //store miss->load hit to 128-135 (same 8 sets and 64-71 evicted)
    //full_stall should be raised when mshr filled with 4 evictions
    //128-135 are now mru, dirty
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h200 + i * 4, 0);
      lag();
      send(i, 32'h200 + i * 4, 1);
      lag();
    end

    //load miss 64-71, evict 0-7, check for full_stall and load_hit_stall
    //on specific timings where mru should be full, store to sets not 0-7 to check same cycle stores when mshr full
    //64-71 not dirty, mru
    send(12, 32'h100, 1);
    lag();
    send(13, 32'h104, 1);
    lag();
    send(14, 32'h24, 0); //invalid line so store hit
    lag();
    for (int i = 2; i < 8; i++) begin
      send(i, 32'h100 + i * 4, 1);
      lag();
    end

    //load hit 128-135 to set mru
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h200 + i * 4, 1);
      lag();
    end

    //store miss 0-7, should replace clean 64-71 data with no mshr fetch
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h0 + i * 4, 0);
      lag();
    end

    //load hit 0-7 and 128-135 to check correctness
    for (int i = 0; i < 8; i++) begin
      send(i, 32'h0 + i * 4, 1);
      lag();
      send(i, 32'h200 + i * 4, 1);
      lag();
    end

    //==== Register Dependency in MSHR Test Cases ====\\
    //current state: 0-7, 128-135 occupy both ways of set 0-7 (both dirty, 0-7 mru)

    //load/store miss 64-71, evict 128-135 (both addresses in MSHR)
    //ON TIMING WHEN ADDRESSES ARE PREDICTED TO BE IN MSHR BUT NOT FULL, LOAD/STORE TO SAME ADDR
    send(22, 32'h100, 1);
    lag();
    send(23, 32'h104, 0);
    lag();
    //mshr queue first to last: h100(load), h200(evict store), h204(evict store)
    //128 will be replaced with 64(mru) after MSHR done, 132 replaced with 68(mru) immediately
    send(24, 32'h100, 1);
    lag();
    //passive stall should be raised until h100 out of mshr, then hit is serviced

    //0-7 mostly mru, 64, 65 both mru, 130-135(not mru)

    //replace 0 with 128(mru)
    send(25, 32'h200, 0);
    lag();
    //passive stall raised until h200 done storing, then evict instruction 0

    #20;
    $finish;
  end
endmodule