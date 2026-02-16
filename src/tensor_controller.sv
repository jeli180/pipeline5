module tensor_controller (
  input logic clk, rst,

  //mmio interface
  //everything is acked/sent on the next cycle
  input logic mmio_req, mmio_lw,
  input logic [31:0] mmio_addr, mmio_data_write,
  output logic mmio_ack,
  output logic [31:0] mmio_data_read,

  //tensor mem (read only)
  //rdata comes the cycle after ren/raddr cycle
  output logic ren,
  output logic [31:0] raddr,
  input logic [31:0] rdata,

  //array interface
  output logic clear, en,
  output logic [7:0] row_input [0:3],
  output logic [7:0] col_input [0:3],
  input logic [31:0] output_col1 [0:3],
  input logic [31:0] output_col2 [0:3],
  input logic [31:0] output_col3 [0:3],
  input logic [31:0] output_col4 [0:3]
);

  localparam logic [31:0] B1_MEM_START = 57600;
  localparam logic [31:0] W2_MEM_START = 57664;
  localparam logic [31:0] B2_MEM_START = 57728;

  //shift state machine
  //transition from IDLE to REQ controlled by control statemachine
  typedef enum {
    IDLE_S,
    REQ,
    WAIT,
    CLEAR,
    L2_FILL
  } state_shift;

  state_shift stateS, next_stateS;

  //control statemachine
  typedef enum {
    IDLE_C,
    WAIT_FILL_1,
    SHIFT_1,
    STALL_1,
    LAST_1,
    STORE_1,
    BIAS_1,
    RELU,
    QUANT,
    WAIT_FILL_2,
    SHIFT_2,
    LAST_2,
    STORE_2,
    BIAS_2,
    CLASS_SEND,
    RESET
  } state_control;

  state_control stateC, next_stateC;

  //8 lsb of weight is input to row_input[0]
  //8 lsb of col_bus is input of col_input[0]
  logic [31:0] col_shift [0:15]; 
  logic [31:0] next_col_shift [0:15];
  logic [31:0] row_shift [0:3];
  logic [31:0] next_row_shift [0:3];
  logic [4:0] unvalid, next_unvalid; //tracks first empty index of shifter (0 means empty)
  logic next_en, next_clear;

  //output store
  logic [31:0] layer1_1 [0:63];
  logic [31:0] layer1_2 [0:63];
  logic [31:0] layer1_3 [0:63];
  logic [31:0] layer1_4 [0:63];
  logic [31:0] layer2_1 [0:2];
  logic [31:0] layer2_2 [0:2];
  logic [31:0] layer2_3 [0:2];
  logic [31:0] layer2_4 [0:2];

  logic [31:0] next_layer1_1 [0:63];
  logic [31:0] next_layer1_2 [0:63];
  logic [31:0] next_layer1_3 [0:63];
  logic [31:0] next_layer1_4 [0:63];
  logic [31:0] next_layer2_1 [0:2];
  logic [31:0] next_layer2_2 [0:2];
  logic [31:0] next_layer2_3 [0:2];
  logic [31:0] next_layer2_4 [0:2];

  //counters (always point to mem addr rdata in the current cycle is from (so need to req ct + 1))
  logic [11:0] next_col_ct, col_ct; //goes to 3600
  logic [3:0] next_row4_ct, row4_ct; //goes to 16
  logic [5:0] next_ct2, ct2; //used by L2_FILL in shift state machine

  //cpu interface signals/reg
  logic next_mmio_ack;
  logic [31:0] next_mmio_data_read;
  logic [31:0] next_pixel_data, pixel_data;
  logic req_status, next_req_status;
  logic [4:0] next_shift, shift;
  logic [31:0] next_shape, shape;

  /* REG MAP
    - cpu writes pixel data to h8
    - cpu polls req status from h8 (if we want the next pixel data, set h8 to 1 else 0)

  */
  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : input_assigns
      assign col_input[i] = col_shift[0][i * 8 + 7 : i * 8];
      assign row_input[i] = row_shift[0][i * 8 + 7 : i * 8];
    end
  endgenerate

  always_comb begin
    //async defaults
    ren = 0;
    raddr = '0;

    //sync defaults
    next_stateS = stateS;
    next_stateC = stateC;
          
    for (int i = 0; i < 16; i++) begin
      next_col_shift[i] = col_shift[i];
    end

    for (int i = 0; i < 4; i++) begin
      next_row_shift[i] = row_shift[i];
    end

    next_unvalid = unvalid;
    next_en = en;
    next_clear = 0;

    for (int i = 0; i < 64; i++) begin
      next_layer1_1[i] = layer1_1[i];
      next_layer1_2[i] = layer1_2[i];
      next_layer1_3[i] = layer1_3[i];
      next_layer1_4[i] = layer1_4[i];
    end

    for (int i = 0; i < 3; i++) begin
      next_layer2_1[i] = layer2_1[i];
      next_layer2_2[i] = layer2_2[i];
      next_layer2_3[i] = layer2_3[i];
      next_layer2_4[i] = layer2_4[i];
    end

    next_col_ct = col_ct;
    next_row4_ct = row4_ct;
    next_ct2 = ct2;
    next_mmio_ack = 0;
    next_mmio_data_read = '0;
    next_pixel_data = pixel_data;
    next_req_status = req_status;
    next_shift = shift;
    next_shape = shape;

    //cpu interface logic (registers offset by mmio) 
    if (mmio_req) begin
      next_mmio_ack = 1'b1;
      if (mmio_addr == 32'h8 && !mmio_lw) next_pixel_data = mmio_data_write;
      else if (mmio_addr == 32'h8 && mmio_lw) next_mmio_data_read = {30'b0, req_status};
      else if (mmio_addr == 32'hC && !mmio_lw) next_shift = mmio_data_write;
      else if (mmio_addr == 32'h4 && mmio_lw) next_mmio_data_read = shape;
    end

    case (stateC) 
      IDLE_C: begin
        if (mmio_req && mmio_addr == 32'h4 && !mmio_lw) begin
          next_stateS = REQ;
          next_req_status = 1'b1;
          next_stateC = WAIT_FILL_1;
          next_clear = 1'b1;
          ren = 1'b1;
          raddr = '0;
        end 
      end
      WAIT_FILL_1: begin
        next_row_shift[0] = {24'b0, rdata[7:0]};
        next_row_shift[1] = {16'b0, rdata[15:8], 8'b0};
        next_row_shift[2] = {8'b0, rdata[23:16], 16'b0};
        next_row_shift[3] = {rdata[31:24], 24'b0};
        if (unvalid != '0) begin
          next_stateC = SHIFT_1;
          ren = 1'b1;
          raddr = row4_ct * 3600 + 32'd1;
          next_col_ct = 12'd1;
          next_en = 1'b1;
        end
      end
      SHIFT_1: begin
        //USE COUNTERS FOR KNOWING WHEN FIRST LAYER IS DONE
        //counter to 3600 for each block of 4 rows (3600 col in W1)
        //counter to 16 incrementing through 4 row blocks (64 rows)

        //shift row
        next_row_shift[0] = {row_shift[1][31:8], rdata[7:0]};
        next_row_shift[1] = {row_shift[2][31:16], rdata[15:8], 8'b0};
        next_row_shift[2] = {row_shift[3][31:24], rdata[23:16], 16'b0};
        next_row_shift[3] = {rdata[31:24], 24'b0};

        //shift col
        for (int i = 0; i < 15; i++) begin
          next_col_shift[i] = col_shift[i+1];
        end
        next_col_shift[15] = '0;

        next_unvalid = unvalid - 5'd1;

        if (unvalid >= 5'd2) begin
          //set row shift regs using rdata and set next row logic to shift right
          //set en high and set next col logic as shift right
          //req tensor_mem again
          next_en = 1'b1;

          //req tensor_mem using counters and check status
          if (col_ct >= 12'd3599) begin //next cycle will be last elements input into tensor
          //don't need to req more from tensor mem or increment counter
            next_stateC = LAST_1;
            next_col_ct = '0;
          end else begin
            ren = 1'b1;
            raddr = row4_ct * 3600 + col_ct + 1;
            next_col_ct = col_ct + 1;
          end
        end else begin //unvalid = 1
          //if col_ct = 3599, current rdata is last input, but missing the corresponding last input
          //shift everything (valid row data, invalid col data) but next_en = 0
          //transition to STALL_1
          next_en = 1'b0;
          next_stateC = STALL_1;
        end
      end
      STALL_1: begin
        //waits for unvalid to move off 0 and sets next_en = 1'b1
        //in STALL_1, if ct = 3599, then go directly to LAST_1, if not then go to SHIFT_1 and req/incr ct
        next_en = 1'b0;
        if (unvalid != '0) begin
          next_en = 1'b1;
          if (col_ct == 12'd3599) begin
            next_stateC = LAST_1;
            next_col_ct = '0;
          end else begin
            next_stateC = SHIFT_1;
            ren = 1'b1;
            raddr = row4_ct * 3600 + col_ct + 1'b1;
            next_col_ct = col_ct + 1'b1;
          end
        end
      end
      LAST_1: begin //last array inputs for the 4row block on this cycle
        //add logic to wait until col inputs propogate through array (~4 cycles)
        //use col_ct
        if (col_ct >= 12'd3) begin
          next_en = 1'b0;
          next_stateC = STORE_1;
        end else begin
          next_en = 1'b1;
          next_col_ct = col_ct + 12'd1;

          //row shift logic
          next_row_shift[3] = '0;
          for (int i = 0; i < 3) begin
            next_row_shift[i] = row_shift[i + 1];
          end
        end
      end
      STORE_1: begin
        //store the outputs of each MAC and process row4_ct
        //clear macs
        for (int i = 0; i < 4; i++) begin
          next_layer1_1[row4_ct * 4 + i] = output_col1[i];
          next_layer1_2[row4_ct * 4 + i] = output_col2[i];
          next_layer1_3[row4_ct * 4 + i] = output_col3[i];
          next_layer1_4[row4_ct * 4 + i] = output_col4[i];
        end
        next_clear = 1'b1;
        next_row4_ct = row4_ct + 4'd1;
        next_col_ct = '0;
        
        if (row4_ct == 4'd15) begin //all layer 1 outputs stored, move on to processing
          next_row4_ct = '0;
          next_stateC = BIAS_1;
          next_stateS = CLEAR; //cpu tracks the data it sends, should know it has sent everything and start poll for classes
        
          //req first bias vector elements to set up BIAS_1 
          ren = 1'b1;
          raddr = B1_MEM_START;
        end else begin
          //req to set up WAIT_FILL_1
          ren = 1'b1;
          raddr = row4_ct * 3600 + 3600;
          next_stateC = WAIT_FILL_1;
        end
      end
      BIAS_1: begin
        //use col_ct to read 64 32b bias values from tensor_mem
        //first bias element is already in rdata since we reqed in STORE_1
        next_layer1_1[col_ct] = layer1_1[col_ct] + rdata;
        next_layer1_2[col_ct] = layer1_2[col_ct] + rdata;
        next_layer1_3[col_ct] = layer1_3[col_ct] + rdata;
        next_layer1_4[col_ct] = layer1_4[col_ct] + rdata;
        if (col_ct < 63) begin
          //req for next BIAS_1
          ren = 1'b1;
          raddr = B1_MEM_START + col_ct + 1;
          next_col_ct = col_ct + 1;
        end else begin //col_ct = 63
          //last bias element in rdata, so don't rereq
          next_stateC = RELU;
          next_col_ct = '0;
        end
      end   
      RELU: begin
        for (int i = 0; i < 64; i++) begin
          next_layer1_1[i] = layer1_1[i][31] ? '0 : layer1_1[i];
          next_layer1_2[i] = layer1_2[i][31] ? '0 : layer1_2[i];
          next_layer1_3[i] = layer1_3[i][31] ? '0 : layer1_3[i];
          next_layer1_4[i] = layer1_4[i][31] ? '0 : layer1_4[i];
        end
        next_stateC = QUANT;
      end
      QUANT: begin
        for (int i = 0; i < 64; i++) begin
          next_layer1_1[i] = ((layer1_1[i] + (32'd1 << (shift - 1))) >> shift) > 32'd127 ? 32'd127 : ((layer1_1[i] + (32'd1 << (shift - 1))) >> shift);
          next_layer1_2[i] = ((layer1_2[i] + (32'd1 << (shift - 1))) >> shift) > 32'd127 ? 32'd127 : ((layer1_2[i] + (32'd1 << (shift - 1))) >> shift);
          next_layer1_3[i] = ((layer1_3[i] + (32'd1 << (shift - 1))) >> shift) > 32'd127 ? 32'd127 : ((layer1_3[i] + (32'd1 << (shift - 1))) >> shift);
          next_layer1_4[i] = ((layer1_4[i] + (32'd1 << (shift - 1))) >> shift) > 32'd127 ? 32'd127 : ((layer1_4[i] + (32'd1 << (shift - 1))) >> shift);
        end
        next_stateS = L2_FILL;
        next_stateC = WAIT_FILL_2;

        //req for WAIT_FILL_2
        ren = 1'b1;
        raddr = W2_MEM_START;
      end
      WAIT_FILL_2: begin 
        next_row_shift[0] = {24'b0, rdata[7:0]};
        next_row_shift[1] = {16'b0, rdata[15:8], 8'b0};
        next_row_shift[2] = {8'b0, rdata[23:16], 16'b0};
        next_row_shift[3] = '0;
        if (unvalid != '0) begin
          next_stateC = SHIFT_2;
          ren = 1'b1;
          raddr = W2_MEM_START + 32'd1;
          next_col_ct = 12'd1;
          next_en = 1'b1;
        end
      end
      SHIFT_2: begin
        //row 4 of systolic array not used due to dim of WEIGHT vector (only 3 classes)
        next_row_shift[0] = {24'b0, rdata[7:0]};
        next_row_shift[1] = {16'b0, rdata[15:8], 8'b0};
        next_row_shift[2] = {8'b0, rdata[23:16], 16'b0};

        for (int i = 0; i < 3; i++) begin
          next_col_shift[i] = col_shift[i+1];
        end
        next_col_shift[3] = '0;

        next_unvalid = unvalid - 5'd1;

        next_en = 1'b1;
        if (col_ct >= 12'd63) begin
          next_stateC = LAST_2;
          next_col_ct = '0;
        end else begin
          ren = 1'b1;
          raddr = W2_MEM_START + col_ct + 1;
          next_col_ct = col_ct + 1;
        end
      end
      LAST_2: begin
        if (col_ct >= 12'd2) begin
          next_en = 1'b0;
          next_stateC = STORE_2;
          next_col_ct = '0;
        end else begin
          next_en = 1'b1;
          next_col_ct = col_ct + 12'd1;
        end
      end
      STORE_2: begin
        for (int i = 0; i < 3; i++) begin
          next_layer2_1[i] = output_col1[i];
          next_layer2_2[i] = output_col2[i];
          next_layer2_3[i] = output_col3[i];
          next_layer2_4[i] = output_col4[i];
        end
        next_clear = 1'b1;
        next_stateC = BIAS_2;
        next_stateS = CLEAR;

        ren = 1'b1;
        raddr = B2_MEM_START;
      end
      BIAS_2: begin
        //use col_ct to read 3 32b bias values from tensor_mem
        //first bias element is in rdata
        next_layer2_1[col_ct] = layer2_1[col_ct] + rdata;
        next_layer2_2[col_ct] = layer2_2[col_ct] + rdata;
        next_layer2_3[col_ct] = layer2_3[col_ct] + rdata;
        next_layer2_4[col_ct] = layer2_4[col_ct] + rdata;
        if (col_ct < 2) begin
          ren = 1'b1;
          raddr = B2_MEM_START + col_ct + 1;
          next_col_ct = col_ct + 1;
        end else begin 
          next_stateC = CLASS_SEND;
        end
      end
      CLASS_SEND: begin
        //layer2_x[0] is circle, [1] is square, [2] is line
        //first 3 bits is col1, 100 is circle, 010 is square, 001 is line
        //in equal cases, circle has highest prio, line has lowest
        if ($signed(layer2_1[0]) >= $signed(layer2_1[1]) && $signed(layer2_1[0]) >= $signed(layer2_1[2])) next_shape[2:0] = 3'b100;
        else if ($signed(layer2_1[1]) > $signed(layer2_1[0]) && $signed(layer2_1[1]) >= $signed(layer2_1[2])) next_shape[2:0] = 3'b010;
        else next_shape[2:0] = 3'b001;

        if ($signed(layer2_2[0]) >= $signed(layer2_2[1]) && $signed(layer2_2[0]) >= $signed(layer2_2[2])) next_shape[5:3] = 3'b100;
        else if ($signed(layer2_2[1]) > $signed(layer2_2[0]) && $signed(layer2_2[1]) >= $signed(layer2_2[2])) next_shape[5:3] = 3'b010;
        else next_shape[5:3] = 3'b001;

        if ($signed(layer2_3[0]) >= $signed(layer2_3[1]) && $signed(layer2_3[0]) >= $signed(layer2_3[2])) next_shape[8:6] = 3'b100;
        else if ($signed(layer2_3[1]) > $signed(layer2_3[0]) && $signed(layer2_3[1]) >= $signed(layer2_3[2])) next_shape[8:6] = 3'b010;
        else next_shape[8:6] = 3'b001;

        if ($signed(layer2_4[0]) >= $signed(layer2_4[1]) && $signed(layer2_4[0]) >= $signed(layer2_4[2])) next_shape[11:9] = 3'b100;
        else if ($signed(layer2_4[1]) > $signed(layer2_4[0]) && $signed(layer2_4[1]) >= $signed(layer2_4[2])) next_shape[11:9] = 3'b010;
        else next_shape[11:9] = 3'b001;

        next_shape[31] = 1'b1; //make bus valid

        next_stateC = RESET;
      end
      RESET: begin
        if (mmio_addr == 32'h4 && !mmio_lw) begin //clear everything and return to IDLE
          next_stateS = IDLE_S;
          next_stateC = IDLE_C;
          
          for (int i = 0; i < 16; i++) begin
            next_col_shift[i] = '0;
          end

          for (int i = 0; i < 4; i++) begin
            next_row_shift[i] = '0;
          end

          next_unvalid = '0;
          next_en = '0;
          next_clear = '0;

          for (int i = 0; i < 64; i++) begin
            next_layer1_1[i] = '0;
            next_layer1_2[i] = '0;
            next_layer1_3[i] = '0;
            next_layer1_4[i] = '0;
          end

          for (int i = 0; i < 3; i++) begin
            next_layer2_1[i] = '0;
            next_layer2_2[i] = '0;
            next_layer2_3[i] = '0;
            next_layer2_4[i] = '0;
          end

          next_col_ct = '0;
          next_row4_ct = '0;
          next_ct2 = '0;
          next_mmio_ack = 0;
          next_mmio_data_read = '0;
          next_pixel_data = '0;
          next_req_status = 0;
          //shift is left since it will likely be used again
          next_shape = '0;
        end
      end
      default:;
    endcase

    //goes under stateC to overwrite
    case (stateS)
      REQ: begin
        if (mmio_req && mmio_addr == 32'h8 && !mmio_lw) begin
          if (unvalid == '0) begin //shifter empty
            //transfer data into shifter
            for (int j = 0; j < 8; j++) begin
              next_col_shift[j] = {7'b0, mmio_data_write[3 * 8 + j], 
                                       7'b0, mmio_data_write[2 * 8 + j], 
                                       7'b0, mmio_data_write[8 + j], 
                                       7'b0, mmio_data_write[j]};
            end
            next_unvalid = 5'd8;
            //keep req high for next data
            next_req_status = 1'b1;
            //stay in REQ
          end else if (unvalid <= 5'd9) begin //shifter has at least 1 element and space for the new data
            for (int j = 0; j < 8; j++) begin
              next_col_shift[unvalid - 1 + j] = {7'b0, mmio_data_write[3 * 8 + j], 
                                                 7'b0, mmio_data_write[2 * 8 + j], 
                                                 7'b0, mmio_data_write[8 + j], 
                                                 7'b0, mmio_data_write[j]};
            end
            next_unvalid = unvalid + 5'd7;
            next_req_status = 1'b1;
          end else begin
            next_req_status = 1'b0;
            next_stateS = WAIT;
          end
        end else begin
          next_req_status = 1'b1;
        end
      end
      WAIT: begin //wait until there is enough space in shift reg to transfer pixel data in
        if (unvalid <= 5'd9) begin //should never be below 5'd9
          for (int i = 0; i < 8; i++) begin
            next_col_shift[unvalid - 1 + i] = {7'b0, pixel_data[3 * 8 + i], 
                                               7'b0, pixel_data[2 * 8 + i], 
                                               7'b0, pixel_data[8 + i], 
                                               7'b0, pixel_data[i]};
          end
          next_unvalid = unvalid + 5'd7;
          next_req_status = 1'b1;
          next_stateS = REQ;
        end
      end
      CLEAR: begin
        for (int j = 0; j < 16; j++) begin
          next_col_shift[j] = '0;
        end
        next_req_status = 1'b0;
        next_unvalid = '0;
      end
      L2_FILL: begin
        //use first 8 bits of layer1_1, 2, 3, 4 to fill col_shift (have been quantized)
        //ct2 tracks index of layer1_x, should be the value used in the current cycle
        if (ct2 < 64) begin //stop shifting in new data when all inputs are used up
          if (unvalid == '0) begin //starting case (should never be 0 after)
            next_col_shift[0] = {layer1_4[ct2][7:0], layer1_3[ct2][7:0], layer1_2[ct2][7:0], layer1_1[ct2][7:0]};
            next_col_shift[1] = {layer1_4[ct2 + 1][7:0], layer1_3[ct2 + 1][7:0], layer1_2[ct2 + 1][7:0], layer1_1[ct2 + 1][7:0]};
            next_col_shift[2] = {layer1_4[ct2 + 2][7:0], layer1_3[ct2 + 2][7:0], layer1_2[ct2 + 2][7:0], layer1_1[ct2 + 2][7:0]};
            next_ct2 = ct2 + 3;
            next_unvalid = 3;
          end else if (unvalid == 2) begin //technically unvalid isn't needed since it remains 2 and never dips to 0
            //currently col_shift idx 0, 1 both valid, stateC will shift idx 1 to 0 on next cycle
            //so we set next idx 1 to new data and keep unvalid = 2
            next_col_shift[1] = {layer1_4[ct2][7:0], layer1_3[ct2][7:0], layer1_2[ct2][7:0], layer1_1[ct2][7:0]};
            next_unvalid = 2;
            next_ct2 = ct2 + 1;
          end
        end
      end
      default:;
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      stateS <= IDLE_S;
      stateC <= IDLE_C;
            
      for (int i = 0; i < 16; i++) begin
        col_shift[i] <= '0;
      end

      for (int i = 0; i < 4; i++) begin
        row_shift[i] <= '0;
      end

      unvalid <= '0;
      en <= 0;
      clear <= 0;

      for (int i = 0; i < 64; i++) begin
        layer1_1[i] <= '0;
        layer1_2[i] <= '0;
        layer1_3[i] <= '0;
        layer1_4[i] <= '0;
      end

      for (int i = 0; i < 3; i++) begin
        layer2_1[i] <= '0;
        layer2_2[i] <= '0;
        layer2_3[i] <= '0;
        layer2_4[i] <= '0;
      end

      col_ct <= '0;
      row4_ct <= '0;
      ct2 <= '0;
      mmio_ack <= '0;
      mmio_data_read <= '0;
      pixel_data <= '0;
      req_status <= '0;
      shift <= '0;
      shape <= '0;
    end else begin
      stateS <= next_stateS;
      stateC <= next_stateC;
            
      for (int i = 0; i < 16; i++) begin
        col_shift[i] <= next_col_shift[i];
      end

      for (int i = 0; i < 4; i++) begin
        row_shift[i] <= next_row_shift[i];
      end

      unvalid <= next_unvalid;
      en <= next_en;
      clear <= next_clear;

      for (int i = 0; i < 64; i++) begin
        layer1_1[i] <= next_layer1_1[i];
        layer1_2[i] <= next_layer1_2[i];
        layer1_3[i] <= next_layer1_3[i];
        layer1_4[i] <= next_layer1_4[i];
      end

      for (int i = 0; i < 3; i++) begin
        layer2_1[i] <= next_layer2_1[i];
        layer2_2[i] <= next_layer2_2[i];
        layer2_3[i] <= next_layer2_3[i];
        layer2_4[i] <= next_layer2_4[i];
      end

      col_ct <= next_col_ct;
      row4_ct <= next_row4_ct;
      ct2 <= next_ct2;
      mmio_ack <= next_mmio_ack;
      mmio_data_read <= next_mmio_data_read;
      pixel_data <= next_pixel_data;
      req_status <= next_req_status;
      shift <= next_shift;
      shape <= next_shape;
    end
  end
endmodule