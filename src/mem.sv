`default_nettype none

module mem (
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
  input logic [31:0] target,
  input logic [31:0] result,
  input logic [31:0] store_data,
  input logic [4:0] regD,

  //mshr regs from execute
  input logic [4:0] reg1_ex, reg2_ex,

  //to wb (registered)
  output logic regwriteF, jalF,
  output logic [4:0] regDF,
  output logic [31:0] targetF, regdataF,

  //mmio
  output logic mmio_req, mmio_lw,
  output logic [31:0] mmio_addr, mmio_data_write,
  output logic [4:0] mmio_regD,
  input logic [31:0] mmio_data_read,
  input logic hit_ack, miss_store, load_done_stall, passive_stall,
  input logic [4:0] regD_done
);

  localparam int MSHR_REG = 4;

  typedef enum logic {
    NORMAL,
    RECIEVE
  } state_lw;

  state_lw state, next_state;

  logic dep_stall, lag_stall, mshr_empty;
  logic [2:0] last_filled;

  // 0-based arrays: entries 0,1,2,3
  logic [4:0] mshr_reg        [0:MSHR_REG-1];
  logic       mshr_valid      [0:MSHR_REG-1];
  logic [4:0] next_mshr_reg   [0:MSHR_REG-1];
  logic       next_mshr_valid [0:MSHR_REG-1];

  logic next_regwriteF, next_jalF;
  logic [4:0] next_regDF;
  logic [31:0] next_targetF, next_regdataF;
  logic load_stall_store, next_load_stall_store;

  assign last_filled =
      mshr_valid[3] ? 3'd4 :
      mshr_valid[2] ? 3'd3 :
      mshr_valid[1] ? 3'd2 :
      mshr_valid[0] ? 3'd1 :
                      3'd0;

  assign mshr_empty =
      !mshr_valid[0] &&
      !mshr_valid[1] &&
      !mshr_valid[2] &&
      !mshr_valid[3];

  assign stall = load_done_stall || passive_stall || dep_stall || lag_stall;

  always_comb begin
    // ===== defaults =====

    for (int i = 0; i < MSHR_REG; i++) begin
      next_mshr_reg[i]   = mshr_reg[i];
      next_mshr_valid[i] = mshr_valid[i];
    end

    branch_flush = 1'b0;
    b_target = 32'hDEAD_BEEF;

    dep_stall = 1'b0;
    lag_stall = 1'b0;

    mmio_req = 1'b0;
    mmio_lw = 1'b0;
    mmio_addr = 32'b0;
    mmio_data_write = 32'b0;
    mmio_regD = 5'b0;

    regD_ex = 5'b0;
    regD_val_ex = 32'b0;
    regwrite_ex = 1'b0;

    next_load_stall_store = load_done_stall;

    next_state = state;

    // wb outputs default to passthrough
    next_regwriteF = regwrite;
    next_jalF = jal || jalr;
    next_regDF = regD;
    next_targetF = target;
    next_regdataF = result;

    case (state)
      NORMAL: begin
        if (jal_flush) begin
          next_regwriteF = 1'b0;
          next_jalF = 1'b0;
          next_regDF = 5'b0;
          next_targetF = 32'b0;
          next_regdataF = 32'b0;

        end else if (load_done_stall) begin
          // completed MSHR load returns to WB, shift queue up
          for (int i = 0; i < MSHR_REG-1; i++) begin
            next_mshr_reg[i]   = mshr_reg[i + 1];
            next_mshr_valid[i] = mshr_valid[i + 1];
          end
          next_mshr_reg[MSHR_REG-1]   = 5'b11111;
          next_mshr_valid[MSHR_REG-1] = 1'b0;

          next_regwriteF = 1'b1;
          next_jalF = 1'b0;
          next_regDF = regD_done;
          next_targetF = 32'b0;
          next_regdataF = mmio_data_read;

        end else if (
            (reg1_ex == mshr_reg[0] && mshr_valid[0])
         || (reg1_ex == mshr_reg[1] && mshr_valid[1])
         || (reg1_ex == mshr_reg[2] && mshr_valid[2])
         || (reg1_ex == mshr_reg[3] && mshr_valid[3])
         || (reg2_ex == mshr_reg[0] && mshr_valid[0])
         || (reg2_ex == mshr_reg[1] && mshr_valid[1])
         || (reg2_ex == mshr_reg[2] && mshr_valid[2])
         || (reg2_ex == mshr_reg[3] && mshr_valid[3])
        ) begin
          dep_stall = 1'b1;

          next_regwriteF = 1'b0;
          next_jalF = 1'b0;
          next_regDF = 5'b0;
          next_targetF = 32'b0;
          next_regdataF = 32'b0;

        end else if (load || store) begin
          mmio_req = 1'b1;
          mmio_lw = load;
          mmio_addr = result;
          mmio_data_write = store_data;
          mmio_regD = regD;

          lag_stall = 1'b1;

          next_regwriteF = 1'b0;
          next_jalF = 1'b0;
          next_regDF = 5'b0;
          next_targetF = 32'b0;
          next_regdataF = 32'b0;

          next_state = RECIEVE;

        end else if (jal || jalr || branch_cond || regwrite) begin
          if (regwrite) begin
            regD_ex = regD;
            regD_val_ex = result;
            regwrite_ex = 1'b1;
          end

          if (jal || jalr || branch_cond) begin
            if (!mshr_empty) begin
              dep_stall = 1'b1;

              next_regwriteF = 1'b0;
              next_jalF = 1'b0;
              next_regDF = 5'b0;
              next_targetF = 32'b0;
              next_regdataF = 32'b0;
            end else begin
              branch_flush = branch_cond;
              b_target = branch_cond ? target : 32'hDEAD_BEEF;
            end
          end
        end
      end

      RECIEVE: begin
        next_state = NORMAL;

        if (load_done_stall) begin
          for (int i = 0; i < MSHR_REG-1; i++) begin
            next_mshr_reg[i]   = mshr_reg[i + 1];
            next_mshr_valid[i] = mshr_valid[i + 1];
          end
          next_mshr_reg[MSHR_REG-1]   = 5'b11111;
          next_mshr_valid[MSHR_REG-1] = 1'b0;

          next_regwriteF = 1'b1;
          next_jalF = 1'b0;
          next_regDF = regD_done;
          next_targetF = 32'b0;
          next_regdataF = mmio_data_read;

          // req mmio again
          mmio_req = 1'b1;
          mmio_lw = load;
          mmio_addr = result;
          mmio_data_write = store_data;
          mmio_regD = regD;

          next_state = RECIEVE;

        end else if (load) begin
          if (hit_ack) begin
            next_regdataF = mmio_data_read;

            regD_ex = regD;
            regD_val_ex = mmio_data_read;
            regwrite_ex = 1'b1;

          end else if (miss_store) begin
            if (last_filled < 3'd4) begin
              next_mshr_reg[last_filled[1:0]]   = regD;
              next_mshr_valid[last_filled[1:0]] = 1'b1;
            end

            if (reg1_ex == regD || reg2_ex == regD) begin
              dep_stall = 1'b1;
            end

            next_regwriteF = 1'b0;
            next_jalF = 1'b0;
            next_regDF = 5'b0;
            next_targetF = 32'b0;
            next_regdataF = 32'b0;
          end else if (passive_stall) begin
            next_regwriteF = 1'b0;
            next_jalF = 1'b0;
            next_regDF = 5'b0;
            next_targetF = 32'b0;
            next_regdataF = 32'b0;

            mmio_req = 1'b1;
            mmio_lw = load;
            mmio_addr = result;
            mmio_data_write = store_data;
            mmio_regD = regD;

            next_state = RECIEVE;
          end

        end else begin
          // store
          if (passive_stall) begin
            next_regwriteF = 1'b0;
            next_jalF = 1'b0;
            next_regDF = 5'b0;
            next_targetF = 32'b0;
            next_regdataF = 32'b0;

            mmio_req = 1'b1;
            mmio_lw = load;
            mmio_addr = result;
            mmio_data_write = store_data;
            mmio_regD = regD;

            next_state = RECIEVE;
          end
        end
      end

      default: begin
        next_state = NORMAL;
      end
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < MSHR_REG; i++) begin
        mshr_reg[i] <= 5'b0;
        mshr_valid[i] <= 1'b0;
      end

      regwriteF <= 1'b0;
      jalF <= 1'b0;
      regDF <= 5'b0;
      targetF <= 32'b0;
      regdataF <= 32'b0;
      load_stall_store <= 1'b0;

      state <= NORMAL;
    end else begin
      for (int i = 0; i < MSHR_REG; i++) begin
        mshr_reg[i] <= next_mshr_reg[i];
        mshr_valid[i] <= next_mshr_valid[i];
      end

      regwriteF <= next_regwriteF;
      jalF <= next_jalF;
      regDF <= next_regDF;
      targetF <= next_targetF;
      regdataF <= next_regdataF;
      load_stall_store <= next_load_stall_store;

      state <= next_state;
    end
  end

endmodule

`default_nettype wire