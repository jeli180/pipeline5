module icache (
  input logic [31:0] addr,
  input logic send_pulse, clk, rst,
  output logic [31:0] inst,
  output logic ack
);

  typedef enum logic [1:0]{
    START_WRITE,    // 2'b00
    REWRITE,    // 2'b01
    IDLE_WRITE, //2'b10
  } write_state;

  typedef enum logic [1:0]{
    START_WB,
    POLL,
    IDLE_WB,
  } wb_state;

  logic [58:0] data [0:15]; //{valid, 26b tag, 32b inst}
  logic state, next_state; //1 is rewrite (cache is being rewritten with new basetag), 0 is idle
  logic [25:0] next_origin, origin;
  assign idx = addr [5:2];
  assign tag = addr [31:6];
  //ack OR assign

  write_state next_write, write;
  wb_state next_wb, wb;


  always_comb begin
    ack_hit = 1'b0;
    if (send_pulse) begin
      if (data[idx][58] && tag == data[idx][57:32]) begin //hit
        inst = data[31:0];
        ack_hit = 1'b1;
      end else begin //miss
        next_wb = START_WB;
        if (origin != tag || write_state != REWRITE) begin //already rewriting from the correct origin
          next_write = START_WRITE;
        end
      end
    end

        //drive two statemachines

wb_simulator #(
  .MEM_FILE("instruction_memory.memh"),
  .DEPTH(1024),
  .LATENCY(3)
) wb_solo_inst (
  .clk(clk),
  .rst_n(~rst),
  .req(1'b1),
  .we(1'b0),
  .addr(PC),
  .wdata(32'd0),
  .rdata(n_ins[0]),
  .busy(busy),
  .valid()
);


