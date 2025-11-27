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
  input logic [31:0] target, result, store_data,
  input logic [4:0] regD,

  //to wb (registered)
  output logic regwriteF, jalF, //jal on for either jal or jalr
  output logic [4:0] regDF,
  output logic [31:0] targetF, regdataF,

  //mmio (comb to allow for same cycle data reads)
  output logic req_pulse, rw, //1 is read, 0 is write
  output logic [31:0] addr, data_write,
  input logic [31:0] data_read,
  input logic dack
);

  typedef enum {
    IDLE,
    STALL
  } state_t;

  //internal
  state_t next_state, state;
  logic [31:0] final_back; //final regval back to ex

  //nexts for output to wb
  logic next_regwriteF, next_jalF;
  logic [4:0] next_regDF;
  logic [31:0] next_targetF, next_regdataF;

  assign regD_val_ex = final_back;

  always_comb begin

    //default to passthrough for next_state logic (no mem access)

    //could be changed in logic (important)
    //hazard
    branch_flush = 0;
    final_back = result;
    stall = 0;
    //mmio
    req_pulse = 0;
    rw = load;
    addr = result;
    data_write = store_data;
    next_state = state;
    //data for regfile
    next_regdataF = result;

    //no change unless jal_flush
    //to wb
    next_regwriteF = regwrite;
    next_jalF = jal | jalr;
    next_regDF = regD;
    next_targetF = target;
    //hazard related
    regD_ex = regD;
    regwrite_ex = regwrite;
    b_target = target;

    //case to determine next outputs to wb, whether to req from mmio
    case (state)
      IDLE: begin
        if (jal_flush) begin //nexts are nops
          final_back = '0;
          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
          regD_ex = '0;
          regwrite_ex = 0;
          b_target = '0;
        end else if (branch_cond) begin //branch and stall prio never overlap
          branch_flush = 1'b1;
        end else if (load || store) begin //need to start stalling immediately to prevent earlier updating
          stall = 1'b1;
          //request mmio, alot of the fields filled in defaults, mmio only polls on req_pulse
          req_pulse = 1'b1;
          if (dack) begin //dcache hit, or data fetched combinationally
            stall = 1'b0; //lift stall, since same cycle its like if stall was never raised
            if (load) begin 
              final_back = data_read; //send back mmio fetched val
              next_regdataF = data_read; //switch sent data to wb
            end
          end else begin //if stall, send nop to wb
            next_state = STALL;
            next_regwriteF = 0;
            next_jalF = 0;
            next_regDF = '0;
            next_targetF = '0;
            next_regdataF = '0;
          end
        end
      end
      STALL: begin
        stall = 1'b1; //stall default high
        if (dack) begin
          stall = 1'b0;
          next_state = IDLE;
          if (load) begin 
            final_back = data_read;
            next_regdataF = data_read;
          end
        end else begin //default to nop when stall, and stay in STALL phase
          next_regwriteF = 0;
          next_jalF = 0;
          next_regDF = '0;
          next_targetF = '0;
          next_regdataF = '0;
        end
      end
      default:;
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin //reset to nop
      state <= IDLE;
      regwriteF <= 0;
      jalF <= 0;
      regDF <= '0;
      targetF <= '0;
      regdataF <= '0;
    end else begin
      state <= next_state;
      regwriteF <= next_regwriteF;
      jalF <= next_jalF;
      regDF <= next_regDF;
      targetF <= next_targetF;
      regdataF <= next_regdataF;
    end
  end
endmodule