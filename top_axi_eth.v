//=============================================================================
// top_axi_eth.v
// Module dinh KET HOP: giu nguyen Ethernet echo + them AXI-Full de PS doc
// du lieu nhan duoc.
//
// Y tuong:
//   - Phan Ethernet (udp_loop_top logic) van tu dong echo nhu cu.
//   - Moi khi nhan duoc 1 word du lieu (rxd_wr_en), ta "re nhanh" du lieu do
//     dua sang khoi AXI slave qua tin hieu rx_data_in/rx_done_in.
//   - PS doc thanh ghi reg3 (du lieu) va reg2 (co bao nhan) qua AXI-Full.
//
// Luu y dong bo clock: du lieu Ethernet o mien gmii_rxc, AXI o mien S_AXI_ACLK.
// Ban toi gian nay dung mot tang flip-flop dong bo (2-FF) cho tin hieu rx_done.
// De chac chan hon co the dung FIFO bat dong bo - se ghi chu o bao cao.
//=============================================================================
module top_axi_eth #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    // ----- Chan vat ly Ethernet (giong udp_loop_top) -----
    input              eth_clk   ,  // 50MHz
    input              eth_rst_n ,
    input              phy_rxc   ,
    input              phy_rx_ctrl,
    input       [3:0]  phy_rxd   ,
    output             phy_txc   ,
    output             phy_tx_ctrl,
    output      [3:0]  phy_txd   ,
    output             phy_rstn  ,
    output      [1:0]  linkspeed ,
    output             mdc       ,
    inout              mdio      ,

    // ----- Bus AXI4-Full (PS noi vao day) -----
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [7:0]                    S_AXI_AWLEN,
    input  wire [2:0]                    S_AXI_AWSIZE,
    input  wire [1:0]                    S_AXI_AWBURST,
    input  wire                          S_AXI_AWVALID,
    output wire                          S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WLAST,
    input  wire                          S_AXI_WVALID,
    output wire                          S_AXI_WREADY,
    output wire [1:0]                    S_AXI_BRESP,
    output wire                          S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [7:0]                    S_AXI_ARLEN,
    input  wire [2:0]                    S_AXI_ARSIZE,
    input  wire [1:0]                    S_AXI_ARBURST,
    input  wire                          S_AXI_ARVALID,
    output wire                          S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0]                    S_AXI_RRESP,
    output wire                          S_AXI_RLAST,
    output wire                          S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    //=========================================================================
    // 1) KHOI ETHERNET - giu nguyen logic echo (instance udp_loop_top)
    //    udp_loop_top da tu xu ly echo + in hoa, ta khong sua.
    //    Ta can lay tin hieu rxd_wr_en / rxd_wr_data ra ngoai de re nhanh.
    //    => Can them 2 output vao udp_loop_top (xem ghi chu ben duoi).
    //=========================================================================
    wire        rxd_wr_en_w;
    wire [31:0] rxd_wr_data_w;

    udp_loop_top u_eth (
        .clk        (eth_clk),
        .rst_n      (eth_rst_n),
        .phy_rxc    (phy_rxc),
        .phy_rx_ctrl(phy_rx_ctrl),
        .phy_rxd    (phy_rxd),
        .phy_txc    (phy_txc),
        .phy_tx_ctrl(phy_tx_ctrl),
        .phy_txd    (phy_txd),
        .phy_rstn   (phy_rstn),
        .linkspeed  (linkspeed),
        .mdc        (mdc),
        .mdio       (mdio),
        // 2 cong moi can them vao udp_loop_top:
        .rxd_wr_en_o   (rxd_wr_en_w),
        .rxd_wr_data_o (rxd_wr_data_w)
    );

    //=========================================================================
    // 2) DONG BO du lieu nhan tu mien Ethernet (phy_rxc/eth) sang mien AXI
    //    Bat tin hieu rxd_wr_en, lay 1 word du lieu, dong bo 2-FF sang AXI clk.
    //=========================================================================
    reg [31:0] rx_data_lat;       // chot du lieu nhan (mien eth)
    reg        rx_flag_eth;       // bao co du lieu moi (mien eth)

    always @(posedge phy_rxc or negedge eth_rst_n) begin
        if (~eth_rst_n) begin
            rx_data_lat <= 32'd0;
            rx_flag_eth <= 1'b0;
        end else if (rxd_wr_en_w) begin
            rx_data_lat <= rxd_wr_data_w;  // chot word du lieu cuoi
            rx_flag_eth <= ~rx_flag_eth;   // dao bit moi khi co word moi (toggle)
        end
    end

    // Dong bo toggle flag sang mien AXI bang 3 flip-flop
    reg flag_s1, flag_s2, flag_s3;
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (~S_AXI_ARESETN) begin
            flag_s1 <= 1'b0; flag_s2 <= 1'b0; flag_s3 <= 1'b0;
        end else begin
            flag_s1 <= rx_flag_eth;
            flag_s2 <= flag_s1;
            flag_s3 <= flag_s2;
        end
    end
    // Phat hien thay doi (co word moi) o mien AXI
    wire rx_done_edge = (flag_s2 ^ flag_s3);

    // SUA LOI CDC (phat hien qua mo phong): chot du lieu TRUOC khi phat hien
    // canh, roi tre co rx_done 1 nhip. Dam bao rx_data_axi da on dinh truoc
    // khi axi_full_slave chot vao reg3 (neu khong, reg3 bi tre 1 word).
    reg [31:0] rx_data_axi;
    reg        rx_done_axi;
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (~S_AXI_ARESETN) begin
            rx_data_axi <= 32'd0;
            rx_done_axi <= 1'b0;
        end else begin
            if (rx_done_edge) rx_data_axi <= rx_data_lat; // chot data truoc
            rx_done_axi <= rx_done_edge;                  // co tre 1 nhip
        end
    end

    //=========================================================================
    // 3) KHOI AXI-FULL SLAVE (tu viet) - PS doc du lieu nhan
    //=========================================================================
    wire [31:0] tx_data_unused;
    wire        tx_start_unused;

    axi_full_slave #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) u_axi (
        .tx_data_reg (tx_data_unused),   // huong nay chua dung (giu echo)
        .tx_start    (tx_start_unused),
        .rx_data_in  (rx_data_axi),      // du lieu Ethernet nhan duoc
        .rx_done_in  (rx_done_axi),      // co bao nhan xong (mien AXI)

        .S_AXI_ACLK   (S_AXI_ACLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWADDR (S_AXI_AWADDR),
        .S_AXI_AWLEN  (S_AXI_AWLEN),
        .S_AXI_AWSIZE (S_AXI_AWSIZE),
        .S_AXI_AWBURST(S_AXI_AWBURST),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),
        .S_AXI_WSTRB  (S_AXI_WSTRB),
        .S_AXI_WLAST  (S_AXI_WLAST),
        .S_AXI_WVALID (S_AXI_WVALID),
        .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),
        .S_AXI_BVALID (S_AXI_BVALID),
        .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR),
        .S_AXI_ARLEN  (S_AXI_ARLEN),
        .S_AXI_ARSIZE (S_AXI_ARSIZE),
        .S_AXI_ARBURST(S_AXI_ARBURST),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),
        .S_AXI_RRESP  (S_AXI_RRESP),
        .S_AXI_RLAST  (S_AXI_RLAST),
        .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY)
    );

endmodule
