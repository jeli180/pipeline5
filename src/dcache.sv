module dcache (
  input logic clk, rst,

  //CPU
  input logic [4:0] regD_in,
  input logic [31:0] addr_in, store_data,
  input logic send_pulse, lw, //sw is low
  output logic hit_ack, miss_send, //both pulses, store dependent registers (lw reg) on miss_send
  output logic [4:0] regD_out,
  output logic [31:0] load_data,

  //Dcache hazard signals to CPU
  output logic load_done_stall, //pulse when mshr entry completes, if lw send to CPU/stall 1 cycle, miss_done not raised for SW completion
  output logic passive_stall, //raise when mshr reg file full and CPU sends another a miss or there is addr dependency against mshr entry | CPU stalls while mshr_full

  //MSHR 
  input logic [31:0] addr1, addr2, addr3, addr4, //track the 2 addr of every mshr entry
  input logic [4:0] mshr_regD_out,
  input logic [31:0] mshr_addr_out, mshr_data_out,
  input logic mshr_done_pulse, load_way_out,
  output logic [31:0] addr_evict, addr_load, evict_data,
  output logic [4:0] mshr_regD_in,
  output logic load_valid, evict_valid, load_way_in, //load is high

  //MSHR Hazard
  input logic mshr_full //all mshr outputs are sequential
);

  //mshr outputs only load data, store misses are handled before
  /*
  handle cases in order of prio:
    mshr done  
    - (sends everything to CPU) and raises load_done_stall as pulse DON'T SERVICE HITS AND MISSES AS NEXT CYCLE INSTRUCTIONS WILL BE SAME DUE TO STALL
    no mshr load done is 2nd in prio
    - check for addr dependencies against input register, raise addr_dep if yes and skip rest, else addr_dep = 0
    - if hit, process as normal
    - if miss, and mshr full, and no store miss with no mshr use, raise full_stall (full stall already being on also takes this branch, as the miss instruction is kept in place)
    - if miss and mshr NOT full, raise miss_send, send data to mshr reg same cycle

    In addition to the mshr related stuff, also handle normal Dcache behavior
  */

  /*
    new dcache to fix comb loop:
    - make all outputs to cpu registered, so 1 cycle delay 
  */

  //need to manually add/take away ack and store miss 1 cycle branches depending on num_ways val
  localparam int NUM_SETS = 64;
  localparam int NUM_WAYS = 2;
  localparam int SET_BITS = 6;
  localparam int TAG_BITS = 24;

  //64 set 2 way allocation
  logic [31:0] data [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic [TAG_BITS-1:0] tag [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic valid [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic dirty [0:NUM_SETS-1][0:NUM_WAYS-1];

  logic [31:0] next_data [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic [TAG_BITS-1:0] next_tag [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic next_valid [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic next_dirty [0:NUM_SETS-1][0:NUM_WAYS-1];

  logic mru [0:NUM_SETS-1]; //most recently used way in a set
  logic next_mru[0:NUM_SETS-1];

  //hazard
  logic full_stall, addr_dep;
  assign passive_stall = full_stall | addr_dep;

  logic [SET_BITS-1:0] cur_set, miss_set;
  logic [TAG_BITS-1:0] cur_tag, miss_tag;

  assign cur_set = addr_in[SET_BITS+1:2];
  assign miss_set = mshr_addr_out[SET_BITS+1:2];
  assign cur_tag = addr_in[31:32-TAG_BITS];
  assign miss_tag = mshr_addr_out[31:32-TAG_BITS];

  //registered cpu outputs
  logic next_full_stall, next_addr_dep, next_hit_ack, next_miss_send, next_load_done_stall;
  logic [4:0] next_regD_out;
  logic [31:0] next_load_data;

  always_comb begin
    //cache values default to the same
    for (int s = 0; s < NUM_SETS; s++) begin
      next_mru[s] = mru[s];
      for (int w = 0; w < NUM_WAYS; w++) begin
        next_data[s][w] = data[s][w];
        next_tag[s][w] = tag[s][w];
        next_valid[s][w] = valid[s][w];
        next_dirty[s][w] = dirty[s][w];
      end
    end

    //CPU defaults
    next_hit_ack = 0;
    next_miss_send = 0;
    next_regD_out = '0;
    next_load_data = '0;

    //Hazard to CPU
    next_load_done_stall = 0;
    next_full_stall = 0;
    next_addr_dep = 0;

    //MSHR defaults
    addr_evict = '0;
    addr_load = '0;
    evict_data = '0;
    mshr_regD_in = '0;
    load_valid = 0;
    evict_valid = 0;
    load_way_in = 0;

    //IF MSHR DONE PULSE AND SEND PULSE SAME CYCLE
    //mem goes into rec state whenever it reqs dcache but dcache might not have processed send pulse since mshr_done_pulse has prio over it
    //solution is to have load_done_stall logic in rec state, and req dcache again (next_state = req) if load_done_stall since ex outputs will be the same
    
    if (mshr_done_pulse) begin //mshr done / send to CPU / replace cache val
      //cache replacement
      next_data[miss_set][load_way_out] = mshr_data_out;
      next_tag[miss_set][load_way_out] = miss_tag;
      next_valid[miss_set][load_way_out] = 1'b1;
      next_mru[miss_set] = load_way_out;
      next_dirty[miss_set][load_way_out] = 1'b0;
      
      //inject load instructions into pipeline
      next_load_done_stall = 1'b1;
      next_regD_out = mshr_regD_out;
      next_load_data = mshr_data_out;
    end else if (send_pulse) begin //normal behavior (service CPU requests), if add more ways add more hit branches
      if (addr_in == addr1 || addr_in == addr2 || addr_in == addr3 || addr_in == addr4) begin
        next_addr_dep = 1'b1; //stall CPU
      end else if (cur_tag == tag[cur_set][1] && valid[cur_set][1]) begin //check way1 hit
        next_mru[cur_set] = 1'b1;
        next_hit_ack = 1'b1;
        if (lw) begin
          next_load_data = data[cur_set][1];
          next_regD_out = regD_in; //may not need
        end else begin
          next_data[cur_set][1] = store_data;
          next_dirty[cur_set][1] = 1'b1;
        end
      end else if (cur_tag == tag[cur_set][0] && valid[cur_set][0]) begin //check way0 hit
        next_mru[cur_set] = 1'b0;
        next_hit_ack = 1'b1;
        if (lw) begin
          next_load_data = data[cur_set][0];
          next_regD_out = regD_in; //may not need
        end else begin
          next_data[cur_set][0] = store_data;
          next_dirty[cur_set][0] = 1'b1;
        end
      //can only be miss now
      end else if (mshr_full) begin
        //store misses to nonvalid or clean lines don't use mshr
        if (!lw && (!dirty[cur_set][0] || !valid[cur_set][0])) begin //check way0
          next_data[cur_set][0] = store_data;
          next_valid[cur_set][0] = 1'b1;
          next_dirty[cur_set][0] = 1'b1;
          next_tag[cur_set][0] = cur_tag;
          next_mru[cur_set] = 1'b0;
          next_hit_ack = 1'b1;
        end else if (!lw && (!dirty[cur_set][1] || !valid[cur_set][1])) begin //check way1
          next_data[cur_set][1] = store_data;
          next_valid[cur_set][1] = 1'b1;
          next_dirty[cur_set][1] = 1'b1;
          next_tag[cur_set][1] = cur_tag;
          next_mru[cur_set] = 1'b1;
          next_hit_ack = 1'b1;
        end else begin
          next_full_stall = 1'b1;
        end
      end else begin //send stuff to MSHR
        //make CPU store dependent register
        if (lw) begin
          next_miss_send = 1'b1; //tells CPU to continue, if current is a lw CPU stores current reg for dependency logic
          load_valid = 1'b1; //pulse
          load_way_in = !mru[cur_set];
          addr_load = addr_in;
          mshr_regD_in = regD_in;
          next_dirty[cur_set][!mru[cur_set]] = 1'b0;
          next_valid[cur_set][!mru[cur_set]] = 1'b0; //prevent loading potentially stale data or storing to line that will be replaced
        end else begin //store miss automatically replaces line
          next_hit_ack = 1'b1;
          next_data[cur_set][!mru[cur_set]] = store_data;
          next_tag[cur_set][!mru[cur_set]] = cur_tag;
          next_valid[cur_set][!mru[cur_set]] = 1'b1;
          next_dirty[cur_set][!mru[cur_set]] = 1'b1;
          next_mru[cur_set] = !mru[cur_set];
        end
        
        //eviction handling
        if (dirty[cur_set][!mru[cur_set]] && valid[cur_set][!mru[cur_set]]) begin
          evict_valid = 1'b1;
          addr_evict = {tag[cur_set][!mru[cur_set]], cur_set, 2'b0};
          evict_data = data[cur_set][!mru[cur_set]];
        end
      end
    end 
  end   

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < NUM_SETS; i++) begin
        mru[i] <= 0;
        for (int j = 0; j < NUM_WAYS; j++) begin
          data[i][j] <= '0;
          tag[i][j] <= '0;
          valid[i][j] <= 0;
          dirty [i][j] <= 0;
        end
      end
      load_done_stall <= 0;
      full_stall <= 0;
      addr_dep <= 0;
      hit_ack <= 0;
      miss_send <= 0;
      load_data <= '0;
      regD_out <= '0;
    end else begin
      for (int i = 0; i < NUM_SETS; i++) begin
        mru[i] <= next_mru[i];
        for (int j = 0; j < NUM_WAYS; j++) begin
          data[i][j] <= next_data[i][j];
          tag[i][j] <= next_tag[i][j];
          valid[i][j] <= next_valid[i][j];
          dirty[i][j] <= next_dirty[i][j];
        end
      end
      load_done_stall <= next_load_done_stall;
      full_stall <= next_full_stall;
      addr_dep <= next_addr_dep;
      hit_ack <= next_hit_ack;
      miss_send <= next_miss_send;
      load_data <= next_load_data;
      regD_out <= next_regD_out;
    end
  end
endmodule