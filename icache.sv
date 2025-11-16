module icache (
  input logic [31:0] addr,
  input logic send_pulse, clk, rst,
  output logic [31:0] inst,
  output logic ack
);

  //state machine for rewriting cache from new origin
  typedef enum logic [1:0]{
    START_WRITE, 
    REWRITE,    
    IDLE_WRITE, 
  } write_state;

  //state machine for miss fetching with wishbone
  typedef enum logic [1:0]{
    START_WB,
    POLL,
    IDLE_WB,
  } wb_state;

  write_state next_write, write;
  wb_state next_wb, wb;

  //internal signals
  logic [58:0] data [0:15]; //{valid, 26b tag, 32b inst}
  logic [58:0] next_data [0:15];
  logic [25:0] next_origin, origin; //origin of current cache instructions

  //wishbone signals for miss fetch
  logic req_solo, valid_solo; 
  logic [31:0] rdata_solo;

  //wishbone signals for cache rewrite
  logic req, valid_0, valid_1, valid_2, valid_3;
  logic [31:0] addr_0, addr_1, addr_2, addr_3;
  logic [31:0] rdata_0, rdata_1, rdata_2, rdata_3;

  //other signals
  logic [1:0] ct, next_ct; //4 wb, ct tracks 4 cycles of transactions to fill 16 instructions
  logic [3:0] idx;
  logic [25:0] tag;
  logic ack_hit, ack_miss; //acks for when instruction is ready after hit and miss

  assign idx = addr [5:2];
  assign tag = addr [31:6];
  assign ack = ack_hit | ack_miss;

  always_comb begin
    //miss fetch signals
    ack_miss = 1'b0;
    next_wb = wb;
    req_solo = 1'b0;

    //start signals
    ack_hit = 1'b0;
    next_origin = origin;
    inst = '0;
    
    //cache rewrite signals
    req = 1'b0;
    next_ct = ct;
    next_write = write;
    addr_0 = '0;
    addr_1 = '0;
    addr_2 = '0;
    addr_3 = '0;
    next_data = data;

    //start logic
    if (send_pulse) begin
      if (data[idx][58] && tag == data[idx][57:32]) begin //hit
        inst = data[idx][31:0];
        ack_hit = 1'b1;
      end else begin //miss
        next_wb = START_WB;
        if (origin != tag || write == IDLE_WRITE) begin //if cache is not currently being rewritten in the correct frame, start rewriting
          next_write = START_WRITE;
          next_origin = tag;
        end
      end
    end

    //wb statemachine (for misses)
    case (wb)
      START_WB: begin
        req_solo = 1'b1;
        next_wb = POLL;
      end
      POLL: begin
        if (valid_solo) begin
          next_wb = IDLE_WB;
          inst = rdata_solo;
          ack_miss = 1'b1;
        end
      end
      default:;
    endcase

    //cache rewrite statemachine
    case (write)
      START_WRITE: begin
        req = 1'b1;
        addr_0 = {origin, ct, 4'b0000};
        addr_1 = {origin, ct, 4'b0100};
        addr_2 = {origin, ct, 4'b1000};
        addr_3 = {origin, ct, 4'b1100};
        next_write = REWRITE;
      end 
      REWRITE: begin
        if (valid_0 && valid_1 && valid_2 && valid_3) begin
          next_data[{ct, 2'b00}] = {1'b1, origin, rdata_0};
          next_data[{ct, 2'b01}] = {1'b1, origin, rdata_1};
          next_data[{ct, 2'b10}] = {1'b1, origin, rdata_2};
          next_data[{ct, 2'b11}] = {1'b1, origin, rdata_3};
          if (ct == 2'b11) begin //
            next_write = IDLE_WRITE;
            next_ct = '0;
          end else begin
            next_write = START_WRITE;
            next_ct = ct + 2'b01;
          end
        end
      end
      IDLE_WRITE: next_ct = 2'b00;
      default:;
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      origin <= '0;
      write <= IDLE_WRITE;
      wb <= IDLE_WB;
      ct <= '0;
      data[0] <= '0;
      data[1] <= '0;
      data[2] <= '0;
      data[3] <= '0;
      data[4] <= '0;
      data[5] <= '0;
      data[6] <= '0;
      data[7] <= '0;
      data[8] <= '0;
      data[9] <= '0;
      data[10] <= '0;
      data[11] <= '0;
      data[12] <= '0;
      data[13] <= '0;
      data[14] <= '0;
      data[15] <= '0;
    end else begin
      origin <= next_origin;
      write <= next_write;
      wb <= next_wb;
      ct <= next_ct;
      data[0] <= next_data[0];
      data[1] <= next_data[1];
      data[2] <= next_data[2];
      data[3] <= next_data[3];
      data[4] <= next_data[4];
      data[5] <= next_data[5];
      data[6] <= next_data[6];
      data[7] <= next_data[7];
      data[8] <= next_data[8];
      data[9] <= next_data[9];
      data[10] <= next_data[10];
      data[11] <= next_data[11];
      data[12] <= next_data[12];
      data[13] <= next_data[13];
      data[14] <= next_data[14];
      data[15] <= next_data[15];
    end
  end

  //solo inst to get miss instr
  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) wb_solo_inst (
    .clk(clk),
    .rst_n(~rst),
    .req(req_solo),
    .we(1'b0),
    .addr(addr),
    .wdata(32'd0),
    .rdata(rdata_solo),
    .busy(),
    .valid(valid_solo)
  );

  //cache rewrite wb
  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) wb0 (
    .clk(clk),
    .rst_n(~rst),
    .req(req),
    .we(1'b0),
    .addr(addr_0),
    .wdata(32'd0),
    .rdata(rdata_0),
    .busy(),
    .valid(valid_0)
    );

  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) wb1 (
    .clk(clk),
    .rst_n(~rst),
    .req(req),
    .we(1'b0),
    .addr(addr_1),
    .wdata(32'd0),
    .rdata(rdata_1),
    .busy(),
    .valid(valid_1)
  );

  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) wb2 (
    .clk(clk),
    .rst_n(~rst),
    .req(req),
    .we(1'b0),
    .addr(addr_2),
    .wdata(32'd0),
    .rdata(rdata_2),
    .busy(),
    .valid(valid_2)
  );

  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) wb3 (
    .clk(clk),
    .rst_n(~rst),
    .req(req),
    .we(1'b0),
    .addr(addr_3),
    .wdata(32'd0),
    .rdata(rdata_3),
    .busy(),
    .valid(valid_3)
  );

endmodule