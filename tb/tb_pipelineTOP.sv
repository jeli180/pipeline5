`timescale 1ns/1ps
module tb_pipelineTOP;

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

  //mmio (dcache)
  logic mmio_req, mmio_lw, mmio_hit, mmio_miss, load_done_stall, passive_stall;
  logic [4:0] mmio_regD_in, mmio_regD_out;
  logic [31:0] mmio_addr, mmio_write_data, mmio_read_data;

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
    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),
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

  dcache dcache0 (
    .clk(clk),
    .rst(rst),

    //from CPU
    .send_pulse(mmio_req),
    .lw(mmio_lw),
    .regD_in(mmio_regD_in),
    .addr_in(mmio_addr),
    .store_data(mmio_write_data),

    //to CPU
    .hit_ack(mmio_hit),
    .miss_send(mmio_miss),
    .regD_out(mmio_regD_out),
    .load_data(mmio_read_data),
    .load_done_stall(load_done_stall),
    .passive_stall(passive_stall),

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

  initial clk = 0;
  always #5 clk = ~clk;

  task reset();
    rst = 1;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
  endtask

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_pipelineTOP);
    reset();

    //wait until regD is 31 (wont use in code until testbench ends)
    //all testcases done in software and analyze in waveforms

    do begin
      @(posedge clk);
      $display("Current regD: %d", file_regD);
    end while (file_regD != 5'd31 && file_wen);

    for (int i = 1; i < 24; i++) begin
      @(posedge clk);
      #1;
      if (file_write_data != i) $display("ERROR | reg: %d | write data: %d", file_regD, file_write_data);
      else $display("PASS | reg: %d | write data: %d", file_regD, file_write_data);
    end
    @(posedge clk);
    @(posedge clk);

    $finish;
  end
endmodule



  