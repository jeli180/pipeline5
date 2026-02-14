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
  
  //generate for first column
  genvar i;
  generate : col1_logic
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
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter1[j] <= '0;
        end
      end else if (en) begin
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter1[j] <= col_shifter1[j - 1];
        end
      end
    end
  endgenerate

  //generate for column 2
  generate : col2_logic
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
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter2[j] <= '0;
        end
      end else if (en) begin
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter2[j] <= col_shifter2[j - 1];
        end
      end
    end
  endgenerate

  //generate for column 3
  generate : col3_logic
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
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter3[j] <= '0;
        end
      end else if (en) begin
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter3[j] <= col_shifter3[j - 1];
        end
      end
    end
  endgenerate

  //generate for column 4
  generate : col4_logic
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
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter4[j] <= '0;
        end
      end else if (en) begin
        for (int j = 1; j < ROW_DIM; j++) begin
          col_shifter4[j] <= col_shifter4[j - 1];
        end
      end
    end
  endgenerate

endmodule