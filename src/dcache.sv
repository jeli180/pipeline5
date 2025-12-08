module dcache (
  input logic clk, rst,

  //CPU
  input logic [4:0] regD_in,
  input logic [31:0] addr_in, store_data,
  input logic send_pulse, lw, //sw is low
  output logic hit_ack, miss_send //both pulses, store dependent registers (lw reg) on miss_send
  output logic [4:0] regD_out,
  output logic [31:0] load_data,

  //Dcache hazard signals to CPU
  output logic load_done_stall, //pulse when mshr entry completes, if lw send to CPU/stall 1 cycle, miss_done not raised for SW completion
  output logic passive_stall, //raise when mshr reg file full and CPU sends another a miss or there is addr dependency against mshr entry | CPU stalls while mshr_full

  //MSHR 
  input logic [31:0] addr1, addr2, addr3, addr4, addr5, addr6, addr7, addr8, //track the 2 addr of every mshr entry
  input logic [4:0] mshr_regD_out,
  input logic [31:0] mshr_addr_out, mshr_data_out,
  input logic mshr_done_pulse, mshr_done_lw, way_out,
  output logic [31:0] mshr_addr_evict, mshr_addr_main, evict_data, main_data,
  output logic [4:0] mshr_regD_in,
  output logic mshr_send_pulse, mshr_lw_in, way_in, //load is high

  //MSHR Hazard
  input logic mshr_full //raised and lowered combinationally by mshr reg
);

  //if mshr_full is lowered because a sw is processed, only mshr send will be high and CPU doesn't need to stall the extra cycle
  //don't need dirty bit, since everything is written back no matter what, each mshr has 2 wishbones

  /*
  handle cases in order of prio:
    mshr done  
    - (sends everything to CPU) and raises load_done_stall as pulse DON'T SERVICE HITS AND MISSES AS NEXT CYCLE INSTRUCTIONS WILL BE SAME DUE TO STALL
    no mshr load done is 2nd in prio
    - check for addr dependencies against input register, raise addr_dep if yes and skip rest, else addr_dep = 0
    - if hit, process as normal
    - if miss, and mshr full, raise full_stall (full stall already being on also takes this branch, as the miss instruction is kept in place)
    - if miss and mshr NOT full, raise miss_send, send data to mshr reg same cycle

    In addition to the mshr related stuff, also handle normal Dcache behavior
  */

  //64 set 2 way allocation
  logic [31:0] data [0:63][0:1];
  logic [23:0] tag [0:63][0:1];
  logic valid [0:63][0:1];
  //logic dirty [0:63][0:1];

  logic [31:0] next_data [0:63][0:1];
  logic [23:0] next_tag [0:63][0:1];
  logic next_valid [0:63][0:1];
  //logic next_dirty [0:63][0:1];

  logic mru [0:63]; //most recently used way in a set
  logic next_mru[0:63];

  //hazard
  logic full_stall, addr_dep;
  assign passive_stall = full_stall | addr_dep;

  assign cur_set = addr_in[7:2];
  assign miss_set = mshr_addr_out[7:2];
  assign cur_tag = addr_in[31:8];
  assign miss_tag = mshr_data_out[31:8];

  always_comb begin
    //cache values default to the same
    for (int s = 0; s < 64; s++) begin
      next_mru[s] = mru[s];
      for (int w = 0; w < 2; w++) begin
        next_data[s][w] <= data[s][w];
        next_tag[s][w] <= tag[s][w];
        next_valid[s][w] = valid[s][w];
        //next_dirty[s][w] = dirty[s][w];
      end
    end

    //CPU defaults
    hit_ack = 0;
    miss_send = 0;
    regD_out = '0;
    load_data = '0;

    //Hazard to CPU
    load_done_stall = 0;
    full_stall = 0;
    addr_dep = 0;

    //MSHR defaults
    mshr_addr_evict = '0;
    mshr_addr_main = '0;
    evict_data = '0;
    main_data = '0;
    mshr_regD_in = '0;
    mshr_send_pulse = 0;
    mshr_lw_in = 0;    
    way_in = 0;

    if (mshr_done_pulse) begin //mshr done / send to CPU / replace cache val
      //cache replacement
      next_data[miss_set][way_out] = mshr_data_out;
      next_tag[miss_set][way_out] = miss_tag;
      next_valid[miss_set][way_out] = 1'b1;
      //next_dirty[miss_set][way_out] = 1'b0;
      if (mshr_done_lw) begin //inject load instructions into pipeline
        //CPU outputs
        load_done_stall = 1'b1;
        regD_out = mshr_regD_out;
        load_data = mshr_data_out;
      end else begin //store done
        full_stall = 1'b1; //stall to preserve instruction sent by CPU for next cycle
      end
    end else if (send_pulse) begin //normal behavior (service CPU requests)
      if (regD_in == addr1 || regD_in == addr2 || regD_in == addr3 || regD_in == addr4 
      || regD_in == addr5 || regD_in == addr6 || regD_in == addr7 || regD_in == addr8) begin
        addr_dep = 1'b1; //stall CPU
      end else if (cur_tag == tag[set][1] && valid[cur_set][1]) begin //check way1 hit
        next_mru[cur_set] = 1'b1;
        hit_ack = 1'b1;
        if (lw) begin
          load_data = data[cur_set][1];
          regD_out = regD_in; //may not need
        end else begin
          next_data[cur_set][1] = store_data;
          //next_dirty[cur_set][1] = 1'b1;
        end
      end else if (cur_tag == tag[cur_set][0] && valid[cur_set][0]) begin //check way0 hit
        next_mru[cur_set] = 1'b0;
        hit_ack = 1'b1;
        if (lw) begin
          load_data = data[cur_set][0];
          regD_out = regD_in; //may not need
        end else begin
          next_data[cur_set][0] = store_data;
          //next_dirty[cur_set][0] = 1'b1;
        end
      end else if (mshr_full) begin
        full_stall = 1'b1;
      end else begin
        //make CPU store dependent register
        miss_send = 1'b1;
        //to mshr
        mshr_lw_in = lw;
        mshr_addr_evict = {tag[cur_set][!mru[cur_set]], cur_set, 2'b0};
        mshr_addr_main = addr_in;
        mshr_regD_in = regD_in;
        evict_data = data[cur_set][!mru[cur_set]];
        main_data = store_data;
        way_in = !mru[cur_set];
        mshr_send_pulse = 1'b1; //pulse
        //make cache line invalid while mshr fetching
        next_valid[cur_set][!mur[cur_set]] = 1'b0;
      end
    end 
  end   

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < 64; i++) begin
        mru[i] <= 0;
        for (int j = 0; j < 2; j++) begin
          data[i][j] <= '0;
          tag[i][j] <= '0;
          valid[i][j] <= 0;
          //dirty [i][j] <= 0;
        end
      end
    end else begin
      for (int i = 0; i < 64; i++) begin
        mru[i] <= next_mru[i];
        for (int j = 0; j < 2; j++) begin
          data[i][j] <= next_data[i][j];
          tag[i][j] <= next_tag[i][j];
          valid[i][j] <= next_valid[i][j];
          //dirty[i][j] <= next_dirty[i][j];
        end
      end
    end
  end
endmodule