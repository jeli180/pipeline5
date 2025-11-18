module fetch (
  input logic clk, rst,

  //cache signals
  input logic cache_ack,
  input logic [31:0] inst,
  output logic addr_ready,
  output logic [31:0] addr,

  //hazard signals
  input logic stall, jal, branch,
  input logic [31:0] j_target, b_target,

  //to decode
  output logic [31:0] final_pc,
  output logic [31:0] final_inst
);

  //stalls are from lw being fetched while instruction behind in EX needs lw regD, can be multiple cycles

  typedef enum logic [2:0]{
    SEND,
    WAIT,
    SEND_O,
    WAIT_ACK,
    WAIT_O,
  } state_t;

  state_t next_state, state;
  logic [31:0] next_pc, pc;
  logic [31:0] next_finalI, finalI;
  logic [31:0] nop;
  logic [31:0] next_target, target;

  assign nop = 32'h00000013;
  assign final_inst = finalI;
  assign final_pc = pc;

  always_comb begin
    next_state = state;
    addr_ready = 1'b0;
    next_pc = pc;
    next_finalI = nop;
    next_target = target;
    addr = '0;

    case (state) 

      //send cache requests and latch outputs if hit (one cycle state)
      SEND: begin
        if (jal) begin //jal has prio over everything
          addr = j_target;
          addr_ready = 1'b1;
          next_target = j_target;
        end else if (branch) begin //branch and stall can never be at the same time, 
          addr = b_target;
          addr_ready = 1'b1;
          next_target = b_target;
        end else if (!stall) begin //if stall, no instr requested from cache
          addr = pc + 4;
          addr_ready = 1'b1;
        end

        //if stall, then cache_ack will never go high since no request
        if (cache_ack && jal) begin //jal hit
          next_pc = j_target;
          next_finalI = inst;
        end else if (cache_ack && branch) begin //branch hit
          next_pc = b_target;
          next_finalI = inst;
        end else if (cache_ack) begin //PC + 4 hit
          next_pc = pc + 4;
          next_finalI = inst;
        end else if (stall && !jal) begin //if stall, no cache requests, repeat SEND state
          next_pc = pc;
          next_finalI = finalI;
        end else if (jal | branch) begin //jal/branch misses
          next_state = WAIT_O;
        end else begin //normal misses
          next_state = WAIT;
        end
      end

      //normal miss state, jal and branch override the instruction getting fetched. While waiting noop and same PC are latched for decode stage
      WAIT: begin
        if (jal) begin //latch both during their cycle, can't immediately use since I need to wait for cache to finish fetching
          next_target = j_target;
        end else if (branch) begin
          next_target = b_target;
        end

        if (cache_ack && (jal | branch)) begin //ignore cache values, start new cache request with jal/branch
          next_state = SEND_O;
        end else if (cache_ack && stall) begin //current is nop, stall cancels cache miss retrieval time
          next_pc = pc + 4;
          next_finalI = inst;
          next_state = SEND;
        end else if (jal | branch) begin //jal or branch while cache fetching
          next_state = WAIT_ACK; //wait for cache to finish, ignore that value and start new cache request with jal/branch
        end else if (cache_ack) begin
          next_state = SEND;
          next_finalI = inst;
          next_pc = pc + 4;
        end 
        //else case is if no cache_ack, stall can be whatever. if stall high while cache is retrieving, natural stall behavior inst = nop, pc same
      end

      //ignore all hazards, get jal and branch instructions (from latched targets) as they have priority
      SEND_O: begin
        addr_ready = 1'b1;
        addr = target;

        if (cache_ack) begin
          next_finalI = inst;
          next_pc = target;
          next_state = SEND;
        end else begin
          next_state = WAIT_O; //waits only for cache data, has prio over any hazard signals
        end
      end

      //set instr to nop, pc same while waiting
      WAIT_O: begin
        if (cache_ack) begin
          next_finalI = inst;
          next_pc = target;
          next_state = SEND;
        end
      end

      //wait for cache to sent stale instruction, switch to sending jal/branch addr
      WAIT_ACK: begin
        if (cache_ack) begin
          next_state = SEND_O;
        end
      end
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= SEND;
      pc <= -4;
      finalI <= nop;
      target <= '0;
    end else begin
      state <= next_state;
      pc <= next_pc;
      finalI <= next_finalI;
      target <= next_target;
    end
  end
endmodule