module ddr4_controller #(
    parameter ADDR_WIDTH = 14,
    parameter BG_WIDTH   = 2,
    parameter BA_WIDTH   = 2,
    parameter DATA_WIDTH = 16,
    parameter T_RCD      = 3,       // Active-to-Read/Write delay
    parameter T_CL       = 4,       // Read CAS latency
    parameter T_RP       = 3        // Precharge delay
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // User Interface
    input  wire                  user_req,
    input  wire                  user_cmd,       // 0: Read, 1: Write
    input  wire [ADDR_WIDTH-1:0] user_row,
    input  wire [BG_WIDTH-1:0]   user_bg,
    input  wire [BA_WIDTH-1:0]   user_ba,
    input  wire [ADDR_WIDTH-1:0] user_col,
    input  wire [DATA_WIDTH-1:0] user_wdata,
    output reg                   user_ready,
    output reg  [DATA_WIDTH-1:0] user_rdata,
    output reg                   user_rdata_valid,

    // DDR4 Physical Pins
    output reg                   ddr4_cs_n,
    output reg                   ddr4_act_n,
    output reg                   ddr4_ras_n,
    output reg                   ddr4_cas_n,
    output reg                   ddr4_we_n,
    output reg  [BG_WIDTH-1:0]   ddr4_bg,
    output reg  [BA_WIDTH-1:0]   ddr4_ba,
    output reg  [ADDR_WIDTH-1:0] ddr4_addr,
    inout  wire [DATA_WIDTH-1:0] ddr4_dq
);

    localparam S_IDLE     = 3'd0;
    localparam S_ACTIVATE = 3'd1;
    localparam S_TRCD     = 3'd2;
    localparam S_RW_OP    = 3'd3;
    localparam S_TCL_WAIT = 3'd4;
    localparam S_PRECHG   = 3'd5;
    localparam S_TRP_WAIT = 3'd6;

    reg [2:0] state;
    reg [3:0] timer;

    reg dq_oe_ctrl;
    reg [DATA_WIDTH-1:0] dq_out_ctrl;
    assign ddr4_dq = dq_oe_ctrl ? dq_out_ctrl : {DATA_WIDTH{1'bz}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            timer            <= 4'd0;
            user_ready       <= 1'b1;
            user_rdata_valid <= 1'b0;
            user_rdata       <= {DATA_WIDTH{1'b0}};
            ddr4_cs_n        <= 1'b1;
            ddr4_act_n       <= 1'b1;
            ddr4_ras_n       <= 1'b1;
            ddr4_cas_n       <= 1'b1;
            ddr4_we_n        <= 1'b1;
            ddr4_bg          <= {BG_WIDTH{1'b0}};
            ddr4_ba          <= {BA_WIDTH{1'b0}};
            ddr4_addr        <= {ADDR_WIDTH{1'b0}};
            dq_oe_ctrl       <= 1'b0;
            dq_out_ctrl      <= {DATA_WIDTH{1'b0}};
        end else begin
            user_rdata_valid <= 1'b0;
            ddr4_cs_n        <= 1'b0; // Default Select

            case (state)
                S_IDLE: begin
                    ddr4_cs_n  <= 1'b1; // Deselect
                    dq_oe_ctrl <= 1'b0;
                    if (user_req && user_ready) begin
                        user_ready <= 1'b0;
                        state      <= S_ACTIVATE;
                    end
                end

                S_ACTIVATE: begin
                    // DDR4 ACTIVATE Command: ACT_N=0
                    ddr4_act_n <= 1'b0;
                    ddr4_ras_n <= 1'b1;
                    ddr4_cas_n <= 1'b1;
                    ddr4_we_n  <= 1'b1;
                    ddr4_bg    <= user_bg;
                    ddr4_ba    <= user_ba;
                    ddr4_addr  <= user_row;
                    timer      <= T_RCD - 1;
                    state      <= S_TRCD;
                end

                S_TRCD: begin
                    // NOP / Deselect during tRCD wait
                    ddr4_act_n <= 1'b1;
                    ddr4_ras_n <= 1'b1;
                    ddr4_cas_n <= 1'b1;
                    ddr4_we_n  <= 1'b1;
                    if (timer == 0) begin
                        state <= S_RW_OP;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                S_RW_OP: begin
                    ddr4_act_n <= 1'b1;
                    ddr4_bg    <= user_bg;
                    ddr4_ba    <= user_ba;
                    ddr4_addr  <= user_col;

                    if (user_cmd) begin
                        // DDR4 WRITE Command: ACT_N=1, RAS=1, CAS=0, WE=0
                        ddr4_ras_n  <= 1'b1;
                        ddr4_cas_n  <= 1'b0;
                        ddr4_we_n   <= 1'b0;
                        dq_oe_ctrl  <= 1'b1;
                        dq_out_ctrl <= user_wdata;
                        state       <= S_PRECHG;
                    end else begin
                        // DDR4 READ Command: ACT_N=1, RAS=1, CAS=0, WE=1
                        ddr4_ras_n <= 1'b1;
                        ddr4_cas_n <= 1'b0;
                        ddr4_we_n  <= 1'b1;
                        dq_oe_ctrl <= 1'b0;
                        timer      <= T_CL;
                        state      <= S_TCL_WAIT;
                    end
                end

                S_TCL_WAIT: begin
                    // NOP while waiting for SDRAM model to drive DQ
                    ddr4_ras_n <= 1'b1;
                    ddr4_cas_n <= 1'b1;
                    ddr4_we_n  <= 1'b1;
                    if (timer == 0) begin
                        user_rdata       <= ddr4_dq;
                        user_rdata_valid <= 1'b1;
                        state            <= S_PRECHG;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                S_PRECHG: begin
                    // DDR4 PRECHARGE Command: ACT_N=1, RAS=0, CAS=1, WE=0
                    dq_oe_ctrl  <= 1'b0;
                    ddr4_act_n  <= 1'b1;
                    ddr4_ras_n  <= 1'b0;
                    ddr4_cas_n  <= 1'b1;
                    ddr4_we_n   <= 1'b0;
                    ddr4_addr   <= 14'b0; // Single bank precharge
                    timer       <= T_RP - 1;
                    state       <= S_TRP_WAIT;
                end

                S_TRP_WAIT: begin
                    // NOP during tRP recovery
                    ddr4_ras_n <= 1'b1;
                    ddr4_cas_n <= 1'b1;
                    ddr4_we_n  <= 1'b1;
                    if (timer == 0) begin
                        user_ready <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        timer <= timer - 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
