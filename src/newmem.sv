module newmem (
  input logic clk, rst,

  //register back to execute (comb)
  output logic [4:0] regD_ex,
  output logic [31:0] regD_val_ex,
  output logic regwrite_ex,

  //hazard
  input logic jal_flush,
  output logic branch_flush,
  output logic [31:0] b_target,
  output logic stall,

  //from execute (stays the same during stall)
  input logic regwrite, load, store, jal, jalr, branch_cond,
  input logic [31:0] target, //jal, jalr, or branch pc target
  input logic [31:0] result, //either mem addr for lw/sw, rd val for rtype/itype/jal/jalr
  input logic [31:0] store_data,
  input logic [4:0] regD,

  //mshr regs from execute
  input logic [4:0] reg1_ex, reg2_ex,

  //to wb (registered)
  output logic regwriteF, jalF, //jal on for either jal or jalr
  output logic [4:0] regDF,
  output logic [31:0] targetF, regdataF,

  //mmio (comb to allow for same cycle data reads)
  output logic mmio_req, mmio_lw, //1 is read, 0 is write
  output logic [31:0] mmio_addr, mmio_data_write,
  output logic [4:0] mmio_regD,
  input logic [31:0] mmio_data_read,
  input logic hit_ack, miss_store, load_done_stall, passive_stall, //control signals, only 1 high 
  input logic [4:0] regD_done
);

  localparam int MSHR_REG = 4;

  logic dep_stall, mshr_empty;
  logic [2:0] last_filled;

  logic [4:0] mshr_reg [1:MSHR_REG]; //tracks regs in mshr for dependency stalling
  logic mshr_valid [1:MSHR_REG]; //tracks whether corresponding mshr reg is valid 
  logic [4:0] next_mshr_reg [1:MSHR_REG]; 
  logic next_mshr_valid [1:MSHR_REG];  

  logic next_regwriteF, next_jalF;
  logic [4:0] next_regDF;
  logic [31:0] next_targetF, next_regdataF;

  assign last_filled = mshr_valid[4] ? 3'd4 : mshr_valid[3] ? 3'd3 : mshr_valid[2] ? 3'd2 : mshr_valid[1] ? 3'd1 : 3'd0;
  assign mshr_empty = !mshr_valid[1] && !mshr_valid[2] && !mshr_valid[3] && !mshr_valid[4];
  assign stall = load_done_stall || passive_stall || dep_stall;

  /*
    functionality:
    - flush if jal
    - stall gen
    - branch flush/target gen
      - if branch or jal, raise stall until mshr_empty high before raising the hazard
    - store 4 mshr regs, if reg1, reg2 from ex match any, stall
      - the cycle dep_stall is raised, reg val and reg ID will be in WB registers, so no need to do anything extra
    - register forwarding
  */


  always_comb begin

    //===== defaults =====\\

    //mshr shift reg stays the same
    for (int i = 1; i < MSHR_REG + 1; i++) begin
      next_mshr_reg[i] = mshr_reg[i];
      next_mshr_valid[i] = mshr_valid[i];
    end
    
    branch_flush = 1'b0;
    b_target = 32'hDEAD_BEEF;

    dep_stall = 1'b0;

    mmio_req = 0;
    mmio_lw = 0;
    mmio_addr = '0;
    mmio_data_write = '0;
    mmio_regD = '0;

    regD_ex = '0;
    regD_val_ex = '0;
    regwrite_ex = 0;

    //wb outputs default to passthrough
    next_regwriteF = regwrite;
    next_jalF = jal || jalr;
    next_regDF = regD;
    next_targetF = target;
    next_regdataF = result;

    //===== behavior =====\\

    //flush if jal_flush hazard, mshr reg guaranteed empty
    if (jal_flush) begin

      next_regwriteF = 0;
      next_jalF = 0;
      next_regDF = '0;
      next_targetF = '0;
      next_regdataF = '0;

    end else if (load_done_stall) begin

      //inject instruction and shift registers up
      for (int i = 1; i < MSHR_REG; i++) begin
        next_mshr_reg[i] = mshr_reg[i + 1];
        next_mshr_valid[i] = mshr_valid[i + 1];
      end
      next_mshr_reg[MSHR_REG] = 5'b11111; //invalid reg
      next_mshr_valid[MSHR_REG] = 1'b0;

      next_regwriteF = 1'b1;
      next_jalF = 1'b0;
      next_regDF = regD_done;
      next_targetF = 1'b0;
      next_regdataF = mmio_data_read;

    end else if (
       (reg1_ex == mshr_reg[1] && mshr_valid[1]) 
    || (reg1_ex == mshr_reg[2] && mshr_valid[2])
    || (reg1_ex == mshr_reg[3] && mshr_valid[3])
    || (reg1_ex == mshr_reg[4] && mshr_valid[4])
    || (reg2_ex == mshr_reg[1] && mshr_valid[1])
    || (reg2_ex == mshr_reg[2] && mshr_valid[2])
    || (reg2_ex == mshr_reg[3] && mshr_valid[3])
    || (reg2_ex == mshr_reg[4] && mshr_valid[4])
    ) begin
      
      dep_stall = 1'b1; //stall pipeline

      //send nop instead of current instructions, as that will create duplicate(s) of the stalled instruction
      next_regwriteF = 0;
      next_jalF = 0;
      next_regDF = '0;
      next_targetF = '0;
      next_regdataF = '0;

      //pipeline stops stalling when correct reg is in wb, so wb will forward val back

    end else if (load || store) begin
      
      //req mmio
      mmio_req = 1'b1;
      mmio_lw = load;
      mmio_addr = result;
      mmio_data_write = store_data;
      mmio_regD = regD;

      if (load) begin
        //if load hit, jal will forward the register back

        //act on hit_ack, miss_send, passive_stall
        if (hit_ack) begin
          next_regdataF = mmio_data_read;
          
          regD_ex = regD;
          regD_val_ex = mmio_data_read;
          regwrite_ex = 1'b1;
        
        end else if (miss_store) begin //if load miss, dep_stall will be raised since it enters mshr_reg on next cycle
          if (last_filled < MSHR_REG) begin //should never be wrong
            next_mshr_reg[last_filled + 1] = regD; //mshr_reg never overflows since actual mshr guards against overflow with stall
            next_mshr_valid[last_filled + 1] = 1'b1;
          end

          if (reg1_ex == regD || reg2_ex == regD) dep_stall = 1'b1;

          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
        end else if (passive_stall) begin
          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
        end
      end else begin //store
        //don't act on store hit(default outputs to wb are fine), miss_send will never be high on store
        if (passive_stall) begin
          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
        end
      end

    end else if (jal || jalr || branch_cond || regwrite) begin
      
      //all regwrite instructions will have regdata, can send back
      //stalling for hazards doesn't affect since the send back regdata won't be used until stall lifted
      if (regwrite) begin
        regD_ex = regD;
        regD_val_ex = result;
        regwrite_ex = 1'b1;
      end

      //wait for mshr empty, at which cpu stops stalling when last out mshr instruction in wb
      if (jal || jalr || branch_cond) begin
        if (!mshr_empty) begin
          dep_stall = 1'b1;

          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
        end else begin
          branch_flush = branch_cond;
          b_target = branch_cond ? target : 32'hDEAD_BEEF;

          //default pass throughs are fine
        end
      end
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 1; i < MSHR_REG + 1; i++) begin
        mshr_reg[i] <= '0;
        mshr_valid[i] <= 0;
      end

      regwriteF <= 0;
      jalF <= 0;
      regDF <= '0;
      targetF <= '0;
      regdataF <= '0;
    end else begin
      for (int i = 1; i < MSHR_REG + 1; i++) begin
        mshr_reg[i] <= next_mshr_reg[i];
        mshr_valid[i] <= next_mshr_valid[i];
      end

      regwriteF <= next_regwriteF;
      jalF <= next_jalF;
      regDF <= next_regDF;
      targetF <= next_targetF;
      regdataF <= next_regdataF;
    end
  end

endmodule