`timescale 1ns/1ps
module tb_integratedDPU;
  /*
    - use mmio to drive cpu side inputs
    - cpu will store pixel data in dcache/registers and we can check register values 
    - similar to in pipeline testbench
    - the read data we send into tb_dpu will have to match the register values we expect
    - print the screen transactions, including register that is specified (if there is none indicate),
      write_data, read_data, whether the transaction was done correctly or not
  */

  logic clk, rst;

  //hazard
  logic stall, jal_flush, branch_flush;
  logic [31:0] j_target, b_target;

  //register forwarding to execute
  logic regwrite_back_mem, regwrite_back_wb;
  logic [4:0] regD_back_mem, regD_back_wb;
  logic [31:0] regDval_back_mem, regDval_back_wb;

  //register from ex to mem for MSHR
  logic [4:0] mshr_reg1_ex, mshr_reg2_ex;

  //regfile
  logic file_wen;
  logic [4:0] file_reg1, file_reg2, file_regD;
  logic [31:0] file_write_data, file_reg1val, file_reg2val;

  //icache
  logic icache_req, icache_ack;
  logic [31:0] icache_addr, icache_inst;

  //fetch
  logic [31:0] inst_fe, pc_fe;

  //decode
  logic rtype_de, itype_de, load_de, store_de, branch_de, jal_de, jalr_de;
  logic [4:0] reg1_de, reg2_de, regD_de;
  logic [31:0] imm_de, inst_de, pc_de, reg1val_de, reg2val_de;

  //execute
  logic regwrite_ex, load_ex, store_ex, jal_ex, jalr_ex, branch_cond_ex;
  logic [4:0] regD_ex;
  logic [31:0] target_ex, result_ex, store_data_ex;

  //mem
  logic regwrite_me, jal_me;
  logic [4:0] regD_me;
  logic [31:0] target_me, regdata_me;

  //mmio
  logic mmio_req, mmio_lw, mmio_hit, mmio_miss, mmio_load_done_stall, mmio_passive_stall;
  logic [4:0] mmio_regD_in, mmio_regD_out;
  logic [31:0] mmio_addr, mmio_write_data, mmio_read_data;

  //dpu
  logic dp_req, dp_lw, dp_ack, rd, wr, rs, cs, interrupt;
  logic [31:0] dp_addr, dp_write_data, dp_read_data;
  wire [7:0] db;

  //dcache
  logic ca_req, ca_lw, ca_hit, ca_miss, ca_load_done_stall, ca_passive_stall;
  logic [4:0] ca_regD_in, ca_regD_out;
  logic [31:0] ca_addr, ca_write_data, ca_read_data;

  //mshr
  logic load_valid, evict_valid, load_way_in, mshr_done_pulse, load_way_out, mshr_full;
  logic [4:0] mshr_regD_in, mshr_regD_out;
  logic [31:0] evict_addr, load_addr, evict_data, mshr_addr_out, mshr_data_out, mshr_addr1, mshr_addr2, mshr_addr3, mshr_addr4;

  icache icache0 (
    .clk(clk),
    .rst(rst),

    //from fetch
    .addr(icache_addr),
    .send_pulse(icache_req),

    //to fetch
    .inst(icache_inst),
    .ack(icache_ack)
  );

  fetch fetch0 (
    .clk(clk),
    .rst(rst),

    //to cache
    .addr_ready(icache_req),
    .addr(icache_addr),

    //from cache
    .cache_ack(icache_ack),
    .inst(icache_inst),

    //hazards from pipeline
    .stall(stall),
    .jal(jal_flush),
    .branch(branch_flush),
    .j_target(j_target),
    .b_target(b_target),

    //to decode
    .final_pc(pc_fe),
    .final_inst(inst_fe)
  );

  decode decode0(
    .clk(clk),
    .rst(rst),

    //hazards from pipeline
    .stall(stall),
    .jal_flush(jal_flush),
    .branch_flush(branch_flush),

    //from fetch
    .inst(inst_fe),
    .pc(pc_fe),

    //to regfile
    .file_reg1(file_reg1),
    .file_reg2(file_reg2),

    //from regfile
    .file_val1(file_reg1val),
    .file_val2(file_reg2val),

    //to execute
    .rtype(rtype_de),
    .itype(itype_de),
    .load(load_de),
    .store(store_de),
    .branch(branch_de),
    .jal(jal_de),
    .jalr(jalr_de),
    .imm(imm_de),
    .finalI(inst_de),
    .finalpc(pc_de),
    .reg1(reg1_de),
    .reg2(reg2_de),
    .regD(regD_de),
    .reg1val(reg1val_de),
    .reg2val(reg2val_de)
  );

  execute execute0 (
    .clk(clk),
    .rst(rst),

    //hazard
    .branch_flush(branch_flush),
    .jal_flush(jal_flush),
    .stall(stall),

    //reg forwarding
    .regD_mem(regD_back_mem),
    .regD_wb(regD_back_wb),
    .regD_val_mem(regDval_back_mem),
    .regD_val_wb(regDval_back_wb),
    .regwrite_mem(regwrite_back_mem),
    .regwrite_wb(regwrite_back_wb),
    
    //from decode
    .rtype(rtype_de),
    .itype(itype_de),
    .load(load_de),
    .store(store_de),
    .branch(branch_de),
    .jal(jal_de),
    .jalr(jalr_de),
    .imm(imm_de),
    .inst(inst_de),
    .pc(pc_de),
    .reg1(reg1_de),
    .reg2(reg2_de),
    .regD(regD_de),
    .reg1val(reg1val_de),
    .reg2val(reg2val_de),

    //to mem
    .regwrite(regwrite_ex),
    .loadF(load_ex),
    .storeF(store_ex),
    .jalF(jal_ex),
    .jalrF(jalr_ex),
    .target(target_ex),
    .result(result_ex),
    .store_data(store_data_ex),
    .branch_cond(branch_cond_ex),
    .regDF(regD_ex),

    //to mem for mshr handling
    .mshr_reg1(mshr_reg1_ex),
    .mshr_reg2(mshr_reg2_ex)
  );

  mem mem0 (
    .clk(clk),
    .rst(rst),

    //register back to execute
    .regD_ex(regD_back_mem),
    .regD_val_ex(regDval_back_mem),
    .regwrite_ex(regwrite_back_mem),
    
    //registers currently in ex (for mshr)
    .reg1_ex(mshr_reg1_ex),
    .reg2_ex(mshr_reg2_ex),

    //hazard
    .jal_flush(jal_flush),
    .branch_flush(branch_flush),
    .b_target(b_target),
    .stall(stall),

    //to mmio
    .mmio_req(mmio_req),
    .mmio_lw(mmio_lw),
    .mmio_addr(mmio_addr),
    .mmio_data_write(mmio_write_data),
    .mmio_regD(mmio_regD_in),
    
    //from mmio
    .hit_ack(mmio_hit),
    .miss_store(mmio_miss),
    .load_done_stall(mmio_load_done_stall),
    .passive_stall(mmio_passive_stall),
    .regD_done(mmio_regD_out),
    .mmio_data_read(mmio_read_data),

    //from execute
    .regwrite(regwrite_ex),
    .load(load_ex),
    .store(store_ex),
    .jal(jal_ex),
    .jalr(jalr_ex),
    .branch_cond(branch_cond_ex),
    .target(target_ex),
    .result(result_ex),
    .store_data(store_data_ex),
    .regD(regD_ex),

    //to wb
    .regwriteF(regwrite_me),
    .jalF(jal_me),
    .regDF(regD_me),
    .targetF(target_me),
    .regdataF(regdata_me)
  );

  mmio mmio0 (
    //from cpu
    .req(mmio_req),
    .lw(mmio_lw),
    .addr(mmio_addr),
    .data_write(mmio_write_data),
    .regD_in(mmio_regD_in),

    //to cpu
    .hit_ack(mmio_hit),
    .miss_store(mmio_miss),
    .load_done_stall(mmio_load_done_stall),
    .passive_stall(mmio_passive_stall),
    .regD_done(mmio_regD_out),
    .data_read(mmio_read_data),
    
    //to dcache
    .ca_regD_in(ca_regD_in),
    .ca_addr_in(ca_addr),
    .ca_write_data(ca_write_data),
    .ca_req(ca_req),
    .ca_lw(ca_lw),

    //from dcache
    .ca_hit(ca_hit),
    .ca_miss_send(ca_miss),
    .ca_load_done_stall(ca_load_done_stall),
    .ca_passive_stall(ca_passive_stall),
    .ca_regD_out(ca_regD_out),
    .ca_read_data(ca_read_data),

    //to dpu
    .dp_req(dp_req),
    .dp_lw(dp_lw),
    .dp_addr(dp_addr),
    .dp_write_data(dp_write_data),

    //from dpu
    .dp_ack(dp_ack),
    .dp_read_data(dp_read_data)
  );

  dpu dpu0 (

    //from mmio
    .req(dp_req),
    .load(dp_lw),
    .addr(dp_addr),
    .write_data(dp_write_data),

    //to mmio
    .ack(dp_ack),
    .read_data(dp_read_data),

    //to screen
    .rd(rd),
    .wr(wr),
    .rs(rs),
    .cs(cs),

    //from screen
    .interrupt(interrupt),

    //inout
    .db(db)
  )

  dcache dcache0 (
    .clk(clk),
    .rst(rst),

    //from mmio
    .send_pulse(ca_req),
    .lw(ca_lw),
    .regD_in(ca_regD_in),
    .addr_in(ca_addr),
    .store_data(ca_write_data),

    //to mmio
    .hit_ack(ca_hit),
    .miss_send(ca_miss),
    .regD_out(ca_regD_out),
    .load_data(ca_read_data),
    .load_done_stall(ca_load_done_stall),
    .passive_stall(ca_passive_stall),

    //to MSHR
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),
    .mshr_regD_in(mshr_regD_in),
    .addr_evict(evict_addr),
    .addr_load(load_addr),
    .evict_data(evict_data),

    //from MSHR
    .mshr_done_pulse(mshr_done_pulse),
    .load_way_out(load_way_out),
    .mshr_regD_out(mshr_regD_out),
    .mshr_addr_out(mshr_addr_out),
    .mshr_data_out(mshr_data_out),
    .addr1(mshr_addr1),
    .addr2(mshr_addr2),
    .addr3(mshr_addr3),
    .addr4(mshr_addr4),

    //MSHR hazard
    .mshr_full(mshr_full)
  );

  mshr mshr0 (
    .clk(clk),
    .rst(rst),

    //from dcache
    .load_valid(load_valid),
    .evict_valid(evict_valid),
    .load_way_in(load_way_in),
    .regD_in(mshr_regD_in),
    .addr_evict(evict_addr),
    .addr_load(load_addr),
    .evict_data(evict_data),

    //to dcache
    .load_way_out(load_way_out),
    .done_pulse(mshr_done_pulse),
    .regD_out(mshr_regD_out),
    .addr_out(mshr_addr_out),
    .data_out(mshr_data_out),
    .addr1(mshr_addr1),
    .addr2(mshr_addr2),
    .addr3(mshr_addr3),
    .addr4(mshr_addr4),

    //hazard to dcache
    .full(mshr_full)
  );

  writeback writeback0 (
    //hazard
    .jal_flush(jal_flush),
    .j_target(j_target),
    
    //register back to execute
    .regwrite_ex(regwrite_back_wb),
    .regD_ex(regD_back_wb),
    .regD_val_ex(regDval_back_wb),

    //to register file
    .wen(file_wen),
    .reg_num(file_regD),
    .write_data(file_write_data),

    //from mem
    .regwrite(regwrite_me),
    .jal(jal_me),
    .regD(regD_me),
    .target(target_me),
    .regdata(regdata_me)
  );

  regfile regfile0 (
    .clk(clk),
    .rst(rst),

    //from decode
    .reg1(file_reg1),
    .reg2(file_reg2),

    //to decode
    .reg1val(file_reg1val),
    .reg2val(file_reg2val),

    //from writeback
    .regwrite(file_wen),
    .regD(file_regD),
    .write_data(file_write_data)
  );

  //tri-state system for driving db on read
  //observe db directly

  logic [7:0] db_drive_val;
  logic db_drive_en;
  assign db = db_drive_en ? db_drive_val : 8'hZZ;

  logic [15:0] pixels [480:1][29:0]; 

  logic [15:0] on_data;

  //temps to store trans task outputs
  logic s_rw, burst; //read high
  logic [7:0] s_addr, s_write_data, s_read_data;


  //16 pixels represent 1 bit
  //make the buses dpu sends back to cpu count up starting from 1 - 480 (480 registers of 30 compressed pixel bits)
  //also cycle through different ON cases (also a counter starting at 1 -> all 16 pixels on bitwise = 16'hFFFF)
  //premake 14400 16b buses

  /* DRIVE/MONITOR SUMMARY
     drive(dpu inputs from screen): db, interrupt
     monitor(dpu outputs to screen): rd, wr, rs, cs, db
     monitor(cpu regfile indicators): file_wen, file_regD, file_write_data
  */

  /* FLOW
      - CPU sends initialization signal through code, print initialization to terminal
      - Call blocking transaction reporter task (print details of 1 transaction to term) 
      - 
  */

  initial clk = 0;
  always #5 clk = ~clk;

  task reset();
    rst = 1;
    db_drive_val = '0;
    db_drive_en = 0;
    interrupt = 0;
    on_data = 16'd1;

    for (int i = 1; i < 481; i++) begin
      for (int j = 0; j < 30; j++) begin
        pixels[i][j] = '0;
      end
    end

    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  function set_pixels();
    logic [31:0] ref_reg;
    for (int i = 1; i < 481; i++) begin
      ref_reg = i;
      for (int j = 0; j < 30; j++) begin
        if (ref_reg[j]) begin
          pixel[i][j] = on_data;
          if (on_data == 16'hFFFF) on_data = 16'd1;
          else on_data++;
        end else pixel[i][j] = '0;
      end
    end
  endfunction

  task trans(
    input logic [7:0] s_read,
    output logic burst, s_rw, //read high
    output logic [7:0] s_addr, s_write //if no addr sent, s_addr will be 8'hFF
  );
    /*
      - wait for transaction to start
      - if write, check if transaction is correct and report key values
      - also output these values for initial block control
      - if read, check if transaction is correct and drive hardcoded data
      - output relevant data
    */
    burst = 1'b1;
    s_rw = 1'b0;
    s_addr = 8'hDA;
    s_write = 8'hDA;

    do begin
      @(posedge clk);
      #1;
    end while (cs);

    if (!(wr && rd)) $display("ERROR on cs pull low cycle | FIRST: wr = %d | rd = %d", wr, rd);

    //extra logic if addr is being sent before the data
    if (rs) begin
      burst = 1'b0;
      @(posedge clk);
      #1;
      if (!rd || wr || !rs || cs) $display("ERROR on wr pull cycle | ADDR: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);
      
      @(posedge clk);
      #1;
      if (!rd || wr || !rs || cs) $display("ERROR on addr send cycle: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);
      s_addr = db;

      @(posedge clk);
      #1;
      if (!rd || !wr || !rs || cs) $display("ERROR in wr raise cycle | ADDR: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);
    
      @(posedge clk);
      #1;
      if (!rd || !wr || rs || !cs) $display("ERROR in rs pull/cs raise cycle | ADDR: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);

      @(posedge clk);
      #1;
      if (!rd || !wr || rs || cs) $display("ERROR in second cs pull cycle | DATA after ADDR: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);
    end 

    //data read/write logic

    @(posedge clk);
    #1;
    if (rs || cs) $display("ERROR in wr or rd pull cycle | DATA: rs = %d | cs = %d", rs, cs);
    if (!wr && rd) begin : write_data

      //1st data access cycle
      @(posedge clk);
      #1;
      s_write = db;
      if (!rd || wr || rs || cs) $display("ERROR in 1st write data access cycle: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);

      //2nd data access cycle
      @(posedge clk);
      #1;
      if (db != s_write || !rd || wr || rs || cs) $display("ERROR in 2nd write access cycle: cs = %d | wr = %d | rd = %d | rs = %d | second data = %08b", cs, wr, rd, rs, db);

    end else if (wr && !rd) begin : read_data
      s_rw = 1'b1;
      //1st access cycle
      @(posedge clk);
      db_drive_en = 1'b1;
      db_drive_val = s_read;
      #1;
      if (rd || !wr || rs || cs) $display("ERROR in 1st read data access cycle: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);

      //2nd access cycle
      @(posedge clk);
      #1;
      if (rd || !wr || rs || cs) $display("ERROR in 2nd read data access cycle: cs = %d | wr = %d | rd = %d | rs = %d", cs, wr, rd, rs);

    end else begin : error_case
      $display("ERROR in wr or rd pull cycle: wr = %d | rd = %d", wr, rd);
      @(posedge);
      #1;
      $display("ERROR followup: cs = %d | rs = %d | wr = %d | rd = %d | data = %08b", cs, rs, wr, rd, db);
      @(posedge);
      #1;
      $display("ERROR followup: cs = %d | rs = %d | wr = %d | rd = %d | data = %08b", cs, rs, wr, rd, db);
    end

    //wr or rd raise cycle
    @(posedge clk);
    db_drive_en = 1'b0;
    db_drive_val = 8'hDA;
    #1;
    if (!rd || !wr || rs || cs) $display("ERROR in wr/rd raise cycle | DATA: cs = %d | rs = %d | wr = %d | rd = %d", cs, rs, wr, rd);

    //cs and rs raise cycle
    @(posedge clk);
    #1;
    if (!rd || !wr || !rs || !cs) $display("ERROR in cs and rs raise cycle | DATA: cs = %d | rs = %d | wr = %d | rd = %d", cs, rs, wr, rd);

  endtask

  task detecth4 ();
    //detects on clock cycle it is called on
    //exits task on cycle after req cycle
    #1;
    while (!(dp_req && !dp_lw && dp_addr == 32'h4)) begin
      @(posedge clk);
      #1;
    end
    $display("CPU store to h4 (start/ack signal, no data stored)");
    @(posedge clk);
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_pipelineTOP);

    reset();
    set_pixels();

    //wait for CPU to write to h4, making dpu start initialization
    detecth4();

    //monitor initialization commands
    for (int i = 0; i < 19) begin
      trans(8'hDA, burst, s_rw, s_addr, s_write_data);
      if (!s_rw && !burst) $display("WRITE: Addr = %02h | Data = %08b", s_addr, s_write_data);
      else $display("WRONG: read = %d | burst = %d | addr = %02h | read data = %02h | write data = %08b", s_rw, burst, s_addr, 8'hDA, s_write_data);
    end

    $display("INIT sequence done, transition to CLEAR");







    $finish;
  end
endmodule
