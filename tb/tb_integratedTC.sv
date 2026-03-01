`timescale 1ns/1ps
module tb_integratedTC;
  //send hardcoded circle, line, square pixel data in software
  //load weights based on mlp model outputs
  //check if inference model worked by writing final shape bus to register, checking

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

  //dcache
  logic ca_req, ca_lw, ca_hit, ca_miss, ca_load_done_stall, ca_passive_stall;
  logic [4:0] ca_regD_in, ca_regD_out;
  logic [31:0] ca_addr, ca_write_data, ca_read_data;

  //mshr
  logic load_valid, evict_valid, load_way_in, mshr_done_pulse, load_way_out, mshr_full;
  logic [4:0] mshr_regD_in, mshr_regD_out;
  logic [31:0] evict_addr, load_addr, evict_data, mshr_addr_out, mshr_data_out, mshr_addr1, mshr_addr2, mshr_addr3, mshr_addr4;

  //mmio
  logic mmio_req, mmio_lw, mmio_hit, mmio_miss, mmio_load_done_stall, mmio_passive_stall;
  logic [4:0] mmio_regD_in, mmio_regD_out;
  logic [31:0] mmio_addr, mmio_write_data, mmio_read_data;

  //tensor mem
  logic tm_wen, tm_ren;
  logic [31:0] tm_write_data, tm_waddr, tm_raddr, tm_read_data;

  //tensor controller
  logic tc_req, tc_lw, tc_ack;
  logic [31:0] tc_addr, tc_data_write, tc_read_data;

  //systolic array
  logic sa_clear, sa_en;
  logic [7:0] sa_row_input [0:3];
  logic [7:0] sa_col_input [0:3];
  logic [31:0] sa_output1 [0:3];
  logic [31:0] sa_output2 [0:3];
  logic [31:0] sa_output3 [0:3];
  logic [31:0] sa_output4 [0:3];

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
    .dp_req(),
    .dp_lw(),
    .dp_addr(),
    .dp_write_data(),

    //from dpu
    .dp_ack('0),
    .dp_read_data('0),

    //to tensor mem
    .tm_wen(tm_wen),
    .tm_write_data(tm_write_data),
    .tm_addr(tm_waddr),

    //to tc
    .tc_req(tc_req),
    .tc_lw(tc_lw),
    .tc_addr(tc_addr),
    .tc_data_write(tc_data_write),

    //from tensor controller
    .tc_ack(tc_ack),
    .tc_read_data(tc_read_data)
  );

  tensor_mem tm (
    .clk(clk),
    .rst(rst),

    //writes from CPU (blocked rn), reads from tensor controller
    .wen(tm_wen),
    .ren(tm_ren),
    .waddr(tm_waddr),
    .raddr(tm_raddr),
    .wdata(tm_write_data),
    .rdata(tm_read_data)
  );

  tensor_controller tc (
    .clk(clk),
    .rst(rst),

    //from mmio
    .mmio_req(tc_req),
    .mmio_lw(tc_lw),
    .mmio_addr(tc_addr),
    .mmio_data_write(tc_data_write),

    //to mmio
    .mmio_ack(tc_ack),
    .mmio_data_read(tc_read_data),

    //to tensor mem
    .ren(tm_ren),
    .raddr(tm_raddr),

    //from tensor mem
    .rdata(tm_read_data),

    //to systolic array
    .clear(sa_clear),
    .en(sa_en),
    .row_input(sa_row_input),
    .col_input(sa_col_input),

    //from systolic array
    .output_col1(sa_output1),
    .output_col2(sa_output2),
    .output_col3(sa_output3),
    .output_col4(sa_output4)
  );

  systolic_array #() sa0 (
    .clk(clk),
    .rst(rst),

    //from tc
    .en(sa_en),
    .clear(sa_clear),
    .row_input(sa_row_input),
    .col_input(sa_col_input),

    //to tc
    .output_col1(sa_output1),
    .output_col2(sa_output2),
    .output_col3(sa_output3),
    .output_col4(sa_output4)
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
    while(1) begin
      for (int i = 0; i < 200; i++) begin
        @(posedge clk);
      end
      $display("200 cycles passed");
    end
  end

  initial begin
    $dumpfile("sim/waves.vcd");
    $dumpvars(0, tb_integratedTC);
    reset();

    $display("SIM begin");

    do begin
      @(posedge clk);
      @(negedge clk);
    end while (!(file_wen && file_regD == 5'd31));

    //shape supposed to be Q1 = circle, square, line, circle
    if (file_write_data[31] && (&file_write_data[15:12])) $display("Shape data valid: %08h", file_write_data);
    else $display("ERROR: Shape data invalid: %08h", file_write_data);
    
    if (file_write_data[2:0] == 3'b100) $display("Q1 PASS: Circle");
    else if (file_write_data[2:0] == 3'b010) $display("Q1 FAIL: Square");
    else if (file_write_data[2:0] == 3'b001) $display("Q1 FAIL: Line");
    else $display("Q1 FAIL: INVALID");

    if (file_write_data[5:3] == 3'b100) $display("Q2 FAIL: Circle");
    else if (file_write_data[5:3] == 3'b010) $display("Q2 PASS: Square");
    else if (file_write_data[5:3] == 3'b001) $display("Q2 FAIL: Line");
    else $display("Q2 FAIL: INVALID");

    if (file_write_data[8:6] == 3'b100) $display("Q3 FAIL: Circle");
    else if (file_write_data[8:6] == 3'b010) $display("Q3 FAIL: Square");
    else if (file_write_data[8:6] == 3'b001) $display("Q3 PASS: Line");
    else $display("Q3 FAIL: INVALID");

    if (file_write_data[11:9] == 3'b100) $display("Q4 PASS: Circle");
    else if (file_write_data[11:9] == 3'b010) $display("Q4 FAIL: Square");
    else if (file_write_data[11:9] == 3'b001) $display("Q4 FAIL: Line");
    else $display("Q4 FAIL: INVALID");

    @(posedge clk);
    @(posedge clk);

    $finish;
  end
endmodule


