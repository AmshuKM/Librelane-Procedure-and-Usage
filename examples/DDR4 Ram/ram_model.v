module ddr4_sdram_model #(
    parameter ADDR_WIDTH = 14,
    parameter BG_WIDTH   = 2,
    parameter BA_WIDTH   = 2,
    parameter DATA_WIDTH = 16,
    parameter T_CL       = 4,       // CAS Read Latency in clock cycles
    parameter T_CWL      = 3,       // CAS Write Latency in clock cycles
    parameter MEM_DEPTH  = 1024     // Synthesizable memory size per bank
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  cs_n,
    input  wire                  act_n,
    input  wire                  ras_n_a16,
    input  wire                  cas_n_a15,
    input  wire                  we_n_a14,
    input  wire [BG_WIDTH-1:0]   bg,
    input  wire [BA_WIDTH-1:0]   ba,
    input  wire [ADDR_WIDTH-1:0] addr,
    inout  wire [DATA_WIDTH-1:0] dq
);

    // JEDEC Command Decoding
    localparam CMD_ACT   = 4'b0000;
    localparam CMD_PRE   = 4'b0100;
    localparam CMD_WRITE = 4'b0101;
    localparam CMD_READ  = 4'b0110;
    localparam CMD_NOP   = 4'b1111;

    wire [3:0] cmd = cs_n ? CMD_NOP :
                     (!act_n) ? CMD_ACT :
                     (!ras_n_a16 && cas_n_a15 && !we_n_a14) ? CMD_PRE :
                     (ras_n_a16 && !cas_n_a15 && !we_n_a14) ? CMD_WRITE :
                     (ras_n_a16 && !cas_n_a15 && we_n_a14)  ? CMD_READ : CMD_NOP;

    // Bank Row Tracking
    localparam NUM_BANKS = (1 << (BG_WIDTH + BA_WIDTH));
    reg [ADDR_WIDTH-1:0] open_row [0:NUM_BANKS-1];
    reg [NUM_BANKS-1:0]  bank_active;

    wire [BG_WIDTH+BA_WIDTH-1:0] bank_idx = {bg, ba};

    // Internal Memory Array
    reg [DATA_WIDTH-1:0] mem_array [0:MEM_DEPTH-1];

    // Read Data Pipeline & Tristate Control
    reg [DATA_WIDTH-1:0] rd_data_pipe [0:T_CL];
    reg [T_CL:0]         rd_oe_pipe;
    reg [DATA_WIDTH-1:0] dq_out;
    reg                  dq_oe;

    assign dq = dq_oe ? dq_out : {DATA_WIDTH{1'bz}};

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_active <= {NUM_BANKS{1'b0}};
            rd_oe_pipe  <= {(T_CL+1){1'b0}};
            dq_oe       <= 1'b0;
            dq_out      <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < NUM_BANKS; i = i + 1) begin
                open_row[i] <= {ADDR_WIDTH{1'b0}};
            end
        end else begin
            // Shift read latency pipeline
            for (i = 0; i < T_CL; i = i + 1) begin
                rd_data_pipe[i+1] <= rd_data_pipe[i];
                rd_oe_pipe[i+1]   <= rd_oe_pipe[i];
            end
            rd_oe_pipe[0] <= 1'b0;

            // Execute DDR4 Commands
            case (cmd)
                CMD_ACT: begin
                    bank_active[bank_idx] <= 1'b1;
                    open_row[bank_idx]    <= addr;
                end

                CMD_PRE: begin
                    if (addr[10]) begin // Precharge All
                        bank_active <= {NUM_BANKS{1'b0}};
                    end else begin
                        bank_active[bank_idx] <= 1'b0;
                    end
                end

                CMD_READ: begin
                    if (bank_active[bank_idx]) begin
                        rd_data_pipe[0] <= mem_array[{bank_idx, addr[5:0]} % MEM_DEPTH];
                        rd_oe_pipe[0]   <= 1'b1;
                    end
                end

                CMD_WRITE: begin
                    if (bank_active[bank_idx]) begin
                        mem_array[{bank_idx, addr[5:0]} % MEM_DEPTH] <= dq;
                    end
                end

                default: ;
            endcase

            // Drive bus on read valid
            dq_oe  <= rd_oe_pipe[T_CL];
            dq_out <= rd_data_pipe[T_CL];
        end
    end

endmodule
