`default_nettype none
// Empty top module

module top (
  // I/O ports
  input  logic hz100, reset,
  input  logic [20:0] pb,
  output logic [7:0] right,
         ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  inout wire [7:0] lcd_db,
  output logic red, green, blue,

  // UART ports
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
);

  logic req, lw, hit_ack, miss_store, load_done_stall, passive_stall;
  logic [31:0] addr, data_write, data_read, ca_addr_in, ca_write_data, ca_read_data;
  logic [4:0] regD_in, regD_done, ca_regD_in, ca_regD_out;
  logic ca_req, ca_lw, ca_hit, ca_miss_send, ca_load_done_stall, ca_passive_stall;

  logic dp_req, dp_lw, dp_ack;
  logic [31:0] dp_addr, dp_write_data, dp_read_data;

  logic clk;
  assign clk = hz100;

  // Unused right LEDs/control pins
  assign right[7:5] = 3'b000;

  // Tie off unused external outputs
  assign red    = 1'b0;
  assign green  = 1'b0;
  assign blue   = 1'b0;
  assign txdata = 8'h00;
  assign txclk  = 1'b0;
  assign rxclk  = 1'b0;

  cpu_wrapper cpu (
    .clk(clk),
    .rst(reset),
    .req(req),
    .lw(lw),
    .addr(addr),
    .data_write(data_write),
    .regD_out(regD_in),
    .hit_ack(hit_ack),
    .miss_store(miss_store),
    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),
    .regD_done(regD_done),
    .data_read(data_read)
  );

  mmio mmio_inst (
    .req(req),
    .lw(lw),
    .addr(addr),
    .data_write(data_write),
    .regD_in(regD_in),

    .hit_ack(hit_ack),
    .miss_store(miss_store),
    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),
    .regD_done(regD_done),
    .data_read(data_read),

    .ca_regD_in(ca_regD_in),
    .ca_addr_in(ca_addr_in),
    .ca_write_data(ca_write_data),
    .ca_req(ca_req),
    .ca_lw(ca_lw),

    .ca_hit(ca_hit),
    .ca_miss_send(ca_miss_send),
    .ca_load_done_stall(ca_load_done_stall),
    .ca_passive_stall(ca_passive_stall),
    .ca_regD_out(ca_regD_out),
    .ca_read_data(ca_read_data),

    .dp_req(dp_req),
    .dp_lw(dp_lw),
    .dp_addr(dp_addr),
    .dp_write_data(dp_write_data),

    .dp_ack(dp_ack),
    .dp_read_data(dp_read_data),

    .tc_req(),
    .tc_lw(),
    .tc_addr(),
    .tc_data_write(),

    .tc_ack('0),
    .tc_read_data('0)
  );

  dpu dp (
    .clk(clk),
    .rst(reset),
    .req(dp_req),
    .load(dp_lw),
    .addr(dp_addr),
    .write_data(dp_write_data),
    .ack(dp_ack),
    .read_data(dp_read_data),

    .rd(right[0]),
    .wr(right[1]),
    .rs(right[3]),
    .cs(right[2]),

    .interrupt(pb[1]),

    .db(lcd_db)
  );
  
endmodule
