module ddr4_subsystem_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        user_req,
    input  wire        user_cmd,
    input  wire [13:0] user_row,
    input  wire [1:0]  user_bg,
    input  wire [1:0]  user_ba,
    input  wire [13:0] user_col,
    input  wire [15:0] user_wdata,
    output wire        user_ready,
    output wire [15:0] user_rdata,
    output wire        user_rdata_valid
);

    wire        cs_n, act_n, ras_n, cas_n, we_n;
    wire [1:0]  bg, ba;
    wire [13:0] addr;
    wire [15:0] dq;

    ddr4_controller #(
        .ADDR_WIDTH(14), .BG_WIDTH(2), .BA_WIDTH(2), .DATA_WIDTH(16),
        .T_RCD(3), .T_CL(4), .T_RP(3)
    ) u_controller (
        .clk(clk), .rst_n(rst_n),
        .user_req(user_req), .user_cmd(user_cmd), .user_row(user_row),
        .user_bg(user_bg), .user_ba(user_ba), .user_col(user_col),
        .user_wdata(user_wdata), .user_ready(user_ready),
        .user_rdata(user_rdata), .user_rdata_valid(user_rdata_valid),
        .ddr4_cs_n(cs_n), .ddr4_act_n(act_n), .ddr4_ras_n(ras_n),
        .ddr4_cas_n(cas_n), .ddr4_we_n(we_n), .ddr4_bg(bg),
        .ddr4_ba(ba), .ddr4_addr(addr), .ddr4_dq(dq)
    );

    ddr4_sdram_model #(
        .ADDR_WIDTH(14), .BG_WIDTH(2), .BA_WIDTH(2), .DATA_WIDTH(16),
        .T_CL(4), .T_CWL(3), .MEM_DEPTH(1024)
    ) u_sdram (
        .clk(clk), .rst_n(rst_n),
        .cs_n(cs_n), .act_n(act_n), .ras_n_a16(ras_n),
        .cas_n_a15(cas_n), .we_n_a14(we_n), .bg(bg),
        .ba(ba), .addr(addr), .dq(dq)
    );

endmodule
