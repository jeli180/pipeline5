module mshr (
  input logic clk, rst,

  //Dcache in
  input logic [31:0] addr_evict, addr_load, evict_data,
  input logic [4:0] regD_in,
  input logic load_valid, evict_valid, load_way_in,

  //to Dcache
  output logic [31:0] addr1, addr2, addr3, addr4, //addr1 closest in queue to wb, comb outputs
  output logic [31:0] addr_out, data_out,
  output logic [4:0] regD_out,
  output logic load_way_out, done_pulse, //registered outputs

  //Hazard
  output logic full //comb
);

  //if change, need to add addrx variables and logic, last filled logic
  localparam int NUM_REG = 4;

  typedef enum {
    IDLE,
    REQ,
    WAIT
  } wb_state;

  wb_state state, next_state;

  logic [31:0] invalid; //addr for no mshr entry 
  assign invalid = 32'hDEAD_BEEF;

  //register allocation
  logic lw [1:NUM_REG];
  logic next_lw [1:NUM_REG];
  logic valid [1:NUM_REG];
  logic next_valid [1:NUM_REG];
  logic way [1:NUM_REG];
  logic next_way [1:NUM_REG];
  logic [4:0] regD [1:NUM_REG];
  logic [4:0] next_regD [1:NUM_REG];
  logic [31:0] addr [1:NUM_REG];
  logic [31:0] next_addr [1:NUM_REG];
  logic [31:0] store_data [1:NUM_REG];
  logic [31:0] next_store_data [1:NUM_REG];

  //from wb
  logic [31:0] rdata;
  logic valid_wb;
  logic req; //DRIVE

  //nexts for registered outputs
  logic [31:0] next_addr_out, next_data_out;
  logic [4:0] next_regD_out;
  logic next_load_way_out, next_done_pulse;


  assign full = valid[NUM_REG - 1]; //if 1 or 0 registers free, then full since max reg fill is 2 per cycle
  assign addr1 = addr[1]; //if mshr entry empty, addr[i] set to invalid
  assign addr2 = addr[2];
  assign addr3 = addr[3];
  assign addr4 = addr[4];

  logic [2:0] last_filled;
  assign last_filled = valid[4] ? 3'd4 : valid[3] ? 3'd3 : valid[2] ? 3'd2 : valid[1] ? 3'd1 : 3'd0;
  
  always_comb begin
    //defaults
    next_state = state;
    req = 1'b0;
    next_addr_out = invalid;
    next_data_out = '0;
    next_regD_out = '0;
    next_load_way_out = 0;
    next_done_pulse = 0;

    for (int i = 1; i < NUM_REG + 1; i++) begin
      next_lw[i] = lw[i];
      next_valid[i] = valid[i];
      next_way[i] = way[i];
      next_regD[i] = regD[i];
      next_addr[i] = addr[i];
      next_store_data[i] = store_data[i];
    end

    case (state) 
      IDLE: begin //mshr empty
        if (load_valid || evict_valid) next_state = REQ;

        if (load_valid && evict_valid) begin
          //load goes first in queue
          next_lw[1] = 1'b1;
          next_valid[1] = 1'b1;
          next_way[1] = load_way_in;
          next_regD[1] = regD_in;
          next_addr[1] = addr_load;
          //evict goes second
          next_lw[2] = 1'b0; //technically don't need, all empty reg are reset to defaults
          next_valid[2] = 1'b1;
          next_addr[2] = addr_evict;
          next_store_data[2] = evict_data;
        end else if (load_valid) begin
          next_lw[1] = 1'b1;
          next_valid[1] = 1'b1;
          next_way[1] = load_way_in;
          next_regD[1] = regD_in;
          next_addr[1] = addr_load;
        end else if (evict_valid) begin
          next_lw[1] = 1'b0; 
          next_valid[1] = 1'b1;
          next_addr[1] = addr_evict;
          next_store_data[1] = evict_data;
        end
      end

      REQ: begin
        next_state = WAIT;
        req = 1'b1;
        //other wb inputs are defaulted to first mshr values
      end

      WAIT: begin
        if (valid_wb) begin

          //dcache outputs ONLY IF LW
          if (lw[1]) begin
            next_addr_out = addr[1];
            next_data_out = rdata;
            next_regD_out = regD[1];
            next_load_way_out = way[1];
            next_done_pulse = 1'b1;
          end

          //shift logic
          for (int i = 1; i < NUM_REG; i++) begin
            next_lw[i] = lw[i+1];
            next_valid[i] = valid[i+1];
            next_way[i] = way[i+1];
            next_regD[i] = regD[i+1];
            next_addr[i] = addr[i+1];
            next_store_data = store_data[i+1];
          end
          next_lw[NUM_REG] = 1'b0;
          next_valid[NUM_REG] = 1'b0;
          next_way[NUM_REG] = 1'b0;
          next_regD[NUM_REG] = '0;
          next_addr[NUM_REG] = invalid;
          next_store_data[NUM_REG] = '0;

          //new input (assuming no overflow), replaces last filled since shift
          if (load_valid && evict_valid) begin
            //load goes first in queue
            next_lw[last_filled] = 1'b1;
            next_valid[last_filled] = 1'b1;
            next_way[last_filled] = load_way_in;
            next_regD[last_filled] = regD_in;
            next_addr[last_filled] = addr_load;
            //evict goes second
            next_lw[last_filled + 1] = 1'b0; //technically don't need, all empty reg are reset to defaults
            next_valid[last_filled + 1] = 1'b1;
            next_addr[last_filled + 1] = addr_evict;
            next_store_data[last_filled + 1] = evict_data;
          end else if (load_valid) begin
            next_lw[last_filled] = 1'b1;
            next_valid[last_filled] = 1'b1;
            next_way[last_filled] = load_way_in;
            next_regD[last_filled] = regD_in;
            next_addr[last_filled] = addr_load;
          end else if (evict_valid) begin
            next_lw[last_filled] = 1'b0; 
            next_valid[last_filled] = 1'b1;
            next_addr[last_filled] = addr_evict;
            next_store_data[last_filled] = evict_data;
          end

          //next state logic
          if (last_filled == 1'd1 && !load_valid && !evict_valid) next_state = IDLE;
          else next_state = REQ;
        end else begin //still waiting for wishbone (no shifting)
          //new input from dcache
          if (load_valid && evict_valid) begin
            //load goes first in queue
            next_lw[last_filled + 1] = 1'b1;
            next_valid[last_filled + 1] = 1'b1;
            next_way[last_filled + 1] = load_way_in;
            next_regD[last_filled + 1] = regD_in;
            next_addr[last_filled + 1] = addr_load;
            //evict goes second
            next_lw[last_filled + 2] = 1'b0; //technically don't need, all empty reg are reset to defaults
            next_valid[last_filled + 2] = 1'b1;
            next_addr[last_filled + 2] = addr_evict;
            next_store_data[last_filled + 2] = evict_data;
          end else if (load_valid) begin
            next_lw[last_filled + 1] = 1'b1;
            next_valid[last_filled + 1] = 1'b1;
            next_way[last_filled + 1] = load_way_in;
            next_regD[last_filled + 1] = regD_in;
            next_addr[last_filled + 1] = addr_load;
          end else if (evict_valid) begin
            next_lw[last_filled + 1] = 1'b0; 
            next_valid[last_filled + 1] = 1'b1;
            next_addr[last_filled + 1] = addr_evict;
            next_store_data[last_filled + 1] = evict_data;
          end
        end
      end
      default:;
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      addr_out <= invalid;
      data_out <= invalid;
      regD_out <= '0;
      load_way_out <= 0;
      done_pulse <= 0;
      for (int i = 1; i < NUM_REG + 1; i++) begin
        lw[i] <= 0;
        valid[i] <= 0;
        way[i] <= 0;
        regD[i] <= '0;
        addr[i] <= invalid;
        store_data[i] <= '0;
      end
    end else begin
      state <= next_state;
      addr_out <= next_addr_out;
      data_out <= next_data_out;
      regD_out <= next_regD_out;
      load_way_out <= next_load_way_out;
      done_pulse <= next_done_pulse;
      for (int i = 1; i < NUM_REG + 1; i++) begin
        lw[i] <= next_lw[i];
        valid[i] <= next_valid[i];
        way[i] <= next_way[i];
        regD[i] <= next_regD[i];
        addr[i] <= next_addr[i];
        store_data[i] <= next_store_data[i];
      end
    end
  end

  wb_simulator #(
    .MEM_FILE("instruction_memory.memh"),
    .DEPTH(1024),
    .LATENCY(3)
  ) dcache_wb (
    .clk(clk),
    .rst_n(~rst),
    .req(req),
    .we(!lw[1]),
    .addr(addr[1]),
    .wdata(store_data[1]),
    //outputs
    .rdata(rdata),
    .busy(),
    .valid(valid_wb)
  );

endmodule