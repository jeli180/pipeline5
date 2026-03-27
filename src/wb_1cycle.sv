module wb_1cycle #(
    parameter MEM_FILE = "memh_init.memh",
    parameter DEPTH = 1024
)(
    input  logic        clk,
    input  logic        rst,

    input  logic        ren,       // asserted for one cycle to start a transaction
    input  logic [31:0] addr,

    output logic [31:0] rdata
);
    // --- memory ---
    logic [31:0] mem [0:DEPTH-1];
    initial $readmemh(MEM_FILE, mem);

    logic [31:0] next_rdata;

    always_comb begin
      next_rdata = '0;
      if (ren) next_rdata = mem[addr];
    end

    always_ff @(posedge clk or posedge rst) begin
      if (rst) rdata <= '0;
      else rdata <= next_rdata;
    end

endmodule