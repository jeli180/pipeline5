module wb_simulator #(
    parameter MEM_FILE = "memh_init.memh",
    parameter DEPTH = 1024,
    parameter LATENCY = 3
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        req,       // asserted for one cycle to start a transaction
    input  logic        we,        // 0=read, 1=write
    input  logic [31:0] addr,
    input  logic [31:0] wdata,

    output logic [31:0] rdata,
    output logic        busy,      // high while operation is in progress
    output logic        valid      // high for one cycle when read completes
);
    // --- memory ---
    logic [31:0] mem [0:DEPTH-1];
    initial $readmemh(MEM_FILE, mem);

    // --- internal state ---
    logic [$clog2(LATENCY+1)-1:0] counter;
    logic pending;
    logic [31:0] addr_reg;

    // --- behavior ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            pending <= 0;
            busy    <= 0;
            valid   <= 0;
            rdata   <= 0;
        end else begin
            valid <= 0; // default

            if (req && !busy) begin
                // new request
                pending <= 1;
                busy    <= 1;
                counter <= LATENCY - 1;
                addr_reg <= addr;

                if (we)
                    mem[addr[31:2]] <= wdata; // immediate store
            end
            else if (pending) begin
                if (counter == 0) begin
                    pending <= 0;
                    busy    <= 0;
                    valid <= 1; // one-cycle pulse
                    if (!we) begin
                        rdata <= mem[addr_reg[31:2]];
                    end
                end else begin
                    counter <= counter - 1;
                end
            end
        end
    end
endmodule
