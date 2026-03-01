module systolic_array #(
  parameter int ROW_DIM = 4
) (
  input logic clk, rst,
  input logic en, clear,
  input logic signed [7:0] row_input [0:3],
  input logic signed [7:0] col_input [0:3],

  output logic signed [31:0] output_col1 [0:3],
  output logic signed [31:0] output_col2 [0:3],
  output logic signed [31:0] output_col3 [0:3],
  output logic signed [31:0] output_col4 [0:3]
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

  assign col1_input1 = (rst || clear) ? '0 : col_input[0];
  assign col2_input1 = (rst || clear) ? '0 : col_input[1];
  assign col3_input1 = (rst || clear) ? '0 : col_input[2];
  assign col4_input1 = (rst || clear) ? '0 : col_input[3];

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
    .row_input(row_input[0]),
    .col_input(col1_input1),
    .accumulate(output_col1[0]) //change output_colX for different gen loop
  );

  mac unit12(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[1]),
    .col_input(col1_input2),
    .accumulate(output_col1[1]) //change output_colX for different gen loop
  );

  mac unit13(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[2]),
    .col_input(col1_input3),
    .accumulate(output_col1[2]) //change output_colX for different gen loop
  );

  mac unit14(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[3]),
    .col_input(col1_input4),
    .accumulate(output_col1[3]) //change output_colX for different gen loop
  );

  //===== Col 2 MACs

  mac unit21(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[0]),
    .col_input(col2_input1),
    .accumulate(output_col2[0]) //change output_colX for different gen loop
  );

  mac unit22(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[1]),
    .col_input(col2_input2),
    .accumulate(output_col2[1]) //change output_colX for different gen loop
  );

  mac unit23(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[2]),
    .col_input(col2_input3),
    .accumulate(output_col2[2]) //change output_colX for different gen loop
  );

  mac unit24(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[3]),
    .col_input(col2_input4),
    .accumulate(output_col2[3]) //change output_colX for different gen loop
  );

  //===== Col 3 MACs

  mac unit31(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[0]),
    .col_input(col3_input1),
    .accumulate(output_col3[0]) //change output_colX for different gen loop
  );

  mac unit32(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[1]),
    .col_input(col3_input2),
    .accumulate(output_col3[1]) //change output_colX for different gen loop
  );

  mac unit33(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[2]),
    .col_input(col3_input3),
    .accumulate(output_col3[2]) //change output_colX for different gen loop
  );

  mac unit34(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[3]),
    .col_input(col3_input4),
    .accumulate(output_col3[3]) //change output_colX for different gen loop
  );

  //===== Col 4 MACs

  mac unit41(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[0]),
    .col_input(col4_input1),
    .accumulate(output_col4[0]) //change output_colX for different gen loop
  );

  mac unit42(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[1]),
    .col_input(col4_input2),
    .accumulate(output_col4[1]) //change output_colX for different gen loop
  );

  mac unit43(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[2]),
    .col_input(col4_input3),
    .accumulate(output_col4[2]) //change output_colX for different gen loop
  );

  mac unit44(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    .en(en),
    .row_input(row_input[3]),
    .col_input(col4_input4),
    .accumulate(output_col4[3]) //change output_colX for different gen loop
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