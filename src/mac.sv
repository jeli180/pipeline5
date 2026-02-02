module mac (
  input logic clk, rst,
  input logic clear, en,
  input logic [8:0] row_input, col_input,
  output logic [31:0] accumulate
);
  /*
    SPEC:
     - freeze output when en is low
     - do mac when en high
     - if clear high don't do mac, next cycle accumulate is 0 and resume
       mac if en high on next cycle
  */

endmodule