module mac (
  input logic clk, rst,
  input logic clear, en,
  input logic signed [7:0] row_input, col_input,
  output logic signed [31:0] accumulate
);
  /*
    SPEC:
     - freeze output when en is low
     - do mac when en high
     - if clear high don't do mac, next cycle accumulate is 0 and resume
       mac if en high on next cycle
  */

  logic signed [31:0] next_accumulate;
  logic signed [15:0] prod;

  always_comb begin
    prod = row_input * col_input;
    if (clear) next_accumulate = '0;
    else if (en) next_accumulate = accumulate + {{16{prod[15]}}, prod};
    else next_accumulate = accumulate;
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) accumulate <= '0;
    else accumulate <= next_accumulate;
  end

endmodule