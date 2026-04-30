module dcache_wrapper (
  input logic clk, rst,

  input logic [4:0] regD_in,
  input logic [31:0] addr_in, store_data,
  input logic send_pulse, lw,
  output logic hit_ack, miss_send,
  output logic [4:0] regD_out,
  output logic [31:0] load_data,

  output logic load_done_stall, passive_stall
);

  logic [31:0] addr1, addr2, addr3, addr4, mshr_addr_out, mshr_data_out;
  logic [4:0] mshr_regD_out, mshr_regD_in;
  logic mshr_done_pulse, load_way_out, load_valid, evict_valid, load_way_in;
  logic [31:0] addr_evict, addr_load, evict_data;
  logic mshr_full;

  dcache dcache_inst (
    .clk(clk),
    .rst(rst),

    .regD_in(regD_in),
    .addr_in(addr_in),
    .store_data(store_data),
    .send_pulse(send_pulse),
    .lw(lw),
    .hit_ack(hit_ack),
    .miss_send(miss_send),
    .regD_out(regD_out),
    .load_data(load_data),

    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),

    .addr1(addr1),
    .addr2(addr2),
    .addr3(addr3),
    .addr4(addr4),
    .mshr_regD_out(mshr_regD_out),
    .mshr_addr_out(mshr_addr_out),
    .mshr_data_out(mshr_data_out),
    .mshr_done_pulse(mshr_done_pulse),
    .load_way_out(load_way_out),
    .addr_evict(addr_evict),
    .addr_load(addr_load),
    .evict_data(evict_data),
    .mshr_regD_in(mshr_regD_in),
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),

    .mshr_full(mshr_full)
  );

  mshr mshr_inst (
    .clk(clk),
    .rst(rst),

    .addr_evict(addr_evict),
    .addr_load(addr_load),
    .evict_data(evict_data),
    .regD_in(mshr_regD_in),
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),

    .addr1(addr1),
    .addr2(addr2),
    .addr3(addr3),
    .addr4(addr4),
    .addr_out(mshr_addr_out),
    .data_out(mshr_data_out),
    .regD_out(mshr_regD_out),
    .load_way_out(load_way_out),
    .done_pulse(mshr_done_pulse),
    .full(mshr_full)
  );

endmodule