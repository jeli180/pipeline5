module systolic_array #(
  parameter int ROW_DIM = 4
) (
  input logic clk, rst,
  input logic en, clear,
  // input logic signed [7:0] row_input [0:3],
  // input logic signed [7:0] col_input [0:3],

  // output logic signed [31:0] output_col1 [0:3],
  // output logic signed [31:0] output_col2 [0:3],
  // output logic signed [31:0] output_col3 [0:3],
  // output logic signed [31:0] output_col4 [0:3]

  input logic signed [7:0] row0_in, row1_in, row2_in, row3_in,
  input logic signed [7:0] col0_in, col1_in, col2_in, col3_in,
  output logic signed [31:0] mac00, mac01, mac02, mac03, //col then row
  output logic signed [31:0] mac10, mac11, mac12, mac13,
  output logic signed [31:0] mac20, mac21, mac22, mac23,
  output logic signed [31:0] mac30, mac31, mac32, mac33
);

  //seperate generates for each column since outputs don't support indexing through col
  //cannot use generate since Icarus doesn't support indexing unpacked arrays
  
  logic signed [7:0] col1_input1, col1_input2, col1_input3, col1_input4;
  logic signed [7:0] col2_input1, col2_input2, col2_input3, col2_input4;
  logic signed [7:0] col3_input1, col3_input2, col3_input3, col3_input4;
  logic signed [7:0] col4_input1, col4_input2, col4_input3, col4_input4;

  logic signed [7:0] next_col1_input2, next_col1_input3, next_col1_input4;
  logic signed [7:0] next_col2_input2, next_col2_input3, next_col2_input4;
  logic signed [7:0] next_col3_input2, next_col3_input3, next_col3_input4;
  logic signed [7:0] next_col4_input2, next_col4_input3, next_col4_input4;

  assign col1_input1 = (rst || clear) ? '0 : col0_in;
  assign col2_input1 = (rst || clear) ? '0 : col1_in;
  assign col3_input1 = (rst || clear) ? '0 : col2_in;
  assign col4_input1 = (rst || clear) ? '0 : col3_in;

  //FOR TEST
  // logic signed [7:0] test_row0, test_row1, test_row2, test_row3;
  // logic signed [7:0] test_col0, test_col1, test_col2, test_col3;

  // assign test_row0 = row_input[0];
  // assign test_row1 = row_input[1];
  // assign test_row2 = row_input[2];
  // assign test_row3 = row_input[3];

  // assign test_col0 = col_input[0];
  // assign test_col1 = col_input[1];
  // assign test_col2 = col_input[2];
  // assign test_col3 = col_input[3];

  always_comb begin
    next_col1_input2 = col1_input2;
    next_col2_input2 = col2_input2;
    next_col3_input2 = col3_input2;
    next_col4_input2 = col4_input2;

    next_col1_input3 = col1_input3;
    next_col2_input3 = col2_input3;
    next_col3_input3 = col3_input3;
    next_col4_input3 = col4_input3;

    next_col1_input4 = col1_input4;
    next_col2_input4 = col2_input4;
    next_col3_input4 = col3_input4;
    next_col4_input4 = col4_input4;

    if (clear) begin
      next_col1_input2 = '0;
      next_col2_input2 = '0;
      next_col3_input2 = '0;
      next_col4_input2 = '0;

      next_col1_input3 = '0;
      next_col2_input3 = '0;
      next_col3_input3 = '0;
      next_col4_input3 = '0;

      next_col1_input4 = '0;
      next_col2_input4 = '0;
      next_col3_input4 = '0;
      next_col4_input4 = '0;
    end else if (en) begin
      next_col1_input2 = col1_input1;
      next_col2_input2 = col2_input1;
      next_col3_input2 = col3_input1;
      next_col4_input2 = col4_input1;

      next_col1_input3 = col1_input2;
      next_col2_input3 = col2_input2;
      next_col3_input3 = col3_input2;
      next_col4_input3 = col4_input2;

      next_col1_input4 = col1_input3;
      next_col2_input4 = col2_input3;
      next_col3_input4 = col3_input3;
      next_col4_input4 = col4_input3;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      col1_input2 <= '0;
      col1_input3 <= '0;
      col1_input4 <= '0;
      col2_input2 <= '0;
      col2_input3 <= '0;
      col2_input4 <= '0;
      col3_input2 <= '0;
      col3_input3 <= '0;
      col3_input4 <= '0;
      col4_input2 <= '0;
      col4_input3 <= '0;
      col4_input4 <= '0;
    end else begin
      col1_input2 <= next_col1_input2;
      col1_input3 <= next_col1_input3;
      col1_input4 <= next_col1_input4;
      col2_input2 <= next_col2_input2;
      col2_input3 <= next_col2_input3;
      col2_input4 <= next_col2_input4;
      col3_input2 <= next_col3_input2;
      col3_input3 <= next_col3_input3;
      col3_input4 <= next_col3_input4;
      col4_input2 <= next_col4_input2;
      col4_input3 <= next_col4_input3;
      col4_input4 <= next_col4_input4;
    end
  end

  //===== Col 1 MACs

  mac unit11(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row0_in),
    .col_input(col1_input1),
    .accumulate(mac00) //change output_colX for different gen loop
  );

  mac unit12(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row1_in),
    .col_input(col1_input2),
    .accumulate(mac01) //change output_colX for different gen loop
  );

  mac unit13(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row2_in),
    .col_input(col1_input3),
    .accumulate(mac02) //change output_colX for different gen loop
  );

  mac unit14(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row3_in),
    .col_input(col1_input4),
    .accumulate(mac03) //change output_colX for different gen loop
  );

  //===== Col 2 MACs

  mac unit21(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row0_in),
    .col_input(col2_input1),
    .accumulate(mac10) //change output_colX for different gen loop
  );

  mac unit22(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row1_in),
    .col_input(col2_input2),
    .accumulate(mac11) //change output_colX for different gen loop
  );

  mac unit23(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row2_in),
    .col_input(col2_input3),
    .accumulate(mac12) //change output_colX for different gen loop
  );

  mac unit24(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row3_in),
    .col_input(col2_input4),
    .accumulate(mac13) //change output_colX for different gen loop
  );

  //===== Col 3 MACs

  mac unit31(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row0_in),
    .col_input(col3_input1),
    .accumulate(mac20) //change output_colX for different gen loop
  );

  mac unit32(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row1_in),
    .col_input(col3_input2),
    .accumulate(mac21) //change output_colX for different gen loop
  );

  mac unit33(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row2_in),
    .col_input(col3_input3),
    .accumulate(mac22) //change output_colX for different gen loop
  );

  mac unit34(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row3_in),
    .col_input(col3_input4),
    .accumulate(mac23) //change output_colX for different gen loop
  );

  //===== Col 4 MACs

  mac unit41(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row0_in),
    .col_input(col4_input1),
    .accumulate(mac30) //change output_colX for different gen loop
  );

  mac unit42(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row1_in),
    .col_input(col4_input2),
    .accumulate(mac31) //change output_colX for different gen loop
  );

  mac unit43(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row2_in),
    .col_input(col4_input3),
    .accumulate(mac32) //change output_colX for different gen loop
  );

  mac unit44(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row3_in),
    .col_input(col4_input4),
    .accumulate(mac33) //change output_colX for different gen loop
  );

  /* generate version that isn't supported


  //generate for first column
  genvar i;
  generate
    begin : col1_logic
      logic signed [7:0] col_shifter1 [0:ROW_DIM - 1]; //shifts col inputs down on each en cycle
      assign col_shifter1[0] = (rst || clear) ? '0 : col_input[0]; //change col_input index for different gen loop

      for (i = 0; i < ROW_DIM; i++) begin : mac_gen1
        mac unit(
          .clk(clk),
          .rst(rst),
          .clear(clear),
          .en(en),
          .row_input(row_input[i]),
          .col_input(col_shifter1[i]),
          .accumulate(output_col1[i]) //change output_colX for different gen loop
        );
      end

      always_ff @(posedge clk or posedge rst) begin
        if (rst || clear) begin
          col_shifter1[3] <= '0;
          col_shifter1[2] <= '0;
          col_shifter1[1] <= '0;
        end else if (en) begin
          col_shifter1[3] <= col_shifter1[2];
          col_shifter1[2] <= col_shifter1[1];
          col_shifter1[1] <= col_shifter1[0];
        end
      end
    end
  endgenerate

  //generate for column 2
  generate
    begin : col2_logic
      logic signed [7:0] col_shifter2 [0:ROW_DIM - 1]; //shifts col inputs down on each en cycle
      assign col_shifter2[0] = (rst || clear) ? '0 : col_input[1];

      for (i = 0; i < ROW_DIM; i++) begin : mac_gen2
        mac unit(
          .clk(clk),
          .rst(rst),
          .clear(clear),
          .en(en),
          .row_input(row_input[i]),
          .col_input(col_shifter2[i]),
          .accumulate(output_col2[i])
        );
      end

      always_ff @(posedge clk or posedge rst) begin
        if (rst || clear) begin
          col_shifter2[3] <= '0;
          col_shifter2[2] <= '0;
          col_shifter2[1] <= '0;
        end else if (en) begin
          col_shifter2[3] <= col_shifter2[2];
          col_shifter2[2] <= col_shifter2[1];
          col_shifter2[1] <= col_shifter2[0];
        end
      end
    end
  endgenerate

  //generate for column 3
  generate
    begin : col3_logic
      logic signed [7:0] col_shifter3 [0:ROW_DIM - 1]; //shifts col inputs down on each en cycle
      assign col_shifter3[0] = (rst || clear) ? '0 : col_input[2];

      for (i = 0; i < ROW_DIM; i++) begin : mac_gen3
        mac unit(
          .clk(clk),
          .rst(rst),
          .clear(clear),
          .en(en),
          .row_input(row_input[i]),
          .col_input(col_shifter3[i]),
          .accumulate(output_col3[i])
        );
      end

      always_ff @(posedge clk or posedge rst) begin
        if (rst || clear) begin
          col_shifter3[3] <= '0;
          col_shifter3[2] <= '0;
          col_shifter3[1] <= '0;
        end else if (en) begin
          col_shifter3[3] <= col_shifter3[2];
          col_shifter3[2] <= col_shifter3[1];
          col_shifter3[1] <= col_shifter3[0];
        end
      end
    end
  endgenerate

  //generate for column 4
  generate
    begin : col4_logic
      logic signed [7:0] col_shifter4 [0:ROW_DIM - 1]; //shifts col inputs down on each en cycle
      assign col_shifter4[0] = (rst || clear) ? '0 : col_input[3];

      for (i = 0; i < ROW_DIM; i++) begin : mac_gen4
        mac unit(
          .clk(clk),
          .rst(rst),
          .clear(clear),
          .en(en),
          .row_input(row_input[i]),
          .col_input(col_shifter4[i]),
          .accumulate(output_col4[i])
        );
      end

      always_ff @(posedge clk or posedge rst) begin
        if (rst || clear) begin
          col_shifter4[3] <= '0;
          col_shifter4[2] <= '0;
          col_shifter4[1] <= '0;
        end else if (en) begin
          col_shifter4[3] <= col_shifter4[2];
          col_shifter4[2] <= col_shifter4[1];
          col_shifter4[1] <= col_shifter4[0];
        end
      end
    end
  endgenerate

  */
  
endmodule