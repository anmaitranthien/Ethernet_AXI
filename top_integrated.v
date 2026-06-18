//=============================================================================
// top_integrated.v  -  MODULE TOP TICH HOP (1 bitstream duy nhat)
//
// Muc dich: gop Ethernet + AXI4-Full + PS trong CUNG MOT thiet ke, khac phuc
//   loi clk_wiz khong khoa pha khi Ethernet bi wrap vao Block Design.
//
// Y tuong khac phuc (DA XAC DINH tu qua trinh debug):
//   - Loi cu: khi top_axi_eth nam TRONG Block Design, xung eth_clk di qua
//     nhieu tang (port BD -> wrapper -> IP) nen clk_wiz khong nhan duoc xung
//     truc tiep tu chan vat ly -> khong khoa pha (log bao "Removing redundant
//     IBUF ... not directly connected to top level port").
//   - Cach sua: dat top.v RTL nay LAM TOP THAT. clk_wiz (ben trong top_axi_eth)
//     nhan xung eth_clk_50m noi TRUC TIEP tu chan K17 (top-level port) -> lock.
//   - Block Design chi chua PS (ZYNQ7), xuat giao dien M_AXI_GP0 ra ngoai
//     duoi dang external interface. top.v noi M_AXI_GP0 <-> S_AXI cua top_axi_eth.
//
// Cach noi M_AXI an toan (tranh noi 35 day tay):
//   - Trong Block Design, giu AXI SmartConnect, xuat M00_AXI ra external.
//   - design_1_wrapper se co cac cong M00_AXI_* . Noi chung vao S_AXI_* o day.
//   - Ten cong duoi day theo chuan Vivado sinh ra cho 1 master AXI4 32-bit,
//     ADDR width 6 (khop axi_full_slave). Neu Vivado sinh ten/khac width,
//     chinh lai cho khop (xem ghi chu cuoi file).
//=============================================================================
module top_integrated
(
    // ---- Xung he thong 50 MHz, noi TRUC TIEP chan K17 ----
    input              eth_clk_50m,   // K17 - QUAN TRONG: top-level port truc tiep
    input              sys_rst_n,     // nut reset (tich cuc thap)

    // ---- Chan vat ly Ethernet (RGMII + MDIO) ----
    input              phy_rxc,
    input              phy_rx_ctrl,
    input       [3:0]  phy_rxd,
    output             phy_txc,
    output             phy_tx_ctrl,
    output      [3:0]  phy_txd,
    output             phy_rstn,
    output      [1:0]  linkspeed,
    output             mdc,
    inout              mdio,

    // ---- Chan DDR + FIXED_IO cua PS (do design_1_wrapper quan ly) ----
    inout       [14:0] DDR_addr,
    inout       [2:0]  DDR_ba,
    inout              DDR_cas_n,
    inout              DDR_ck_n,
    inout              DDR_ck_p,
    inout              DDR_cke,
    inout              DDR_cs_n,
    inout       [3:0]  DDR_dm,
    inout       [31:0] DDR_dq,
    inout       [3:0]  DDR_dqs_n,
    inout       [3:0]  DDR_dqs_p,
    inout              DDR_odt,
    inout              DDR_ras_n,
    inout              DDR_reset_n,
    inout              DDR_we_n,
    inout              FIXED_IO_ddr_vrn,
    inout              FIXED_IO_ddr_vrp,
    inout       [53:0] FIXED_IO_mio,
    inout              FIXED_IO_ps_clk,
    inout              FIXED_IO_ps_porb,
    inout              FIXED_IO_ps_srstb
);

    //=========================================================================
    // 1) Day AXI noi giua PS (qua SmartConnect, M00_AXI) va top_axi_eth (S_AXI)
    //=========================================================================
    wire                          axi_aclk;      // FCLK_CLK0 tu PS (50 MHz)
    wire                          axi_aresetn;   // peripheral_aresetn tu PS

    wire [5:0]   m_axi_awaddr;
    wire [7:0]   m_axi_awlen;
    wire [2:0]   m_axi_awsize;
    wire [1:0]   m_axi_awburst;
    wire         m_axi_awvalid;
    wire         m_axi_awready;
    wire [31:0]  m_axi_wdata;
    wire [3:0]   m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    wire         m_axi_wready;
    wire [1:0]   m_axi_bresp;
    wire         m_axi_bvalid;
    wire         m_axi_bready;
    wire [5:0]   m_axi_araddr;
    wire [7:0]   m_axi_arlen;
    wire [2:0]   m_axi_arsize;
    wire [1:0]   m_axi_arburst;
    wire         m_axi_arvalid;
    wire         m_axi_arready;
    wire [31:0]  m_axi_rdata;
    wire [1:0]   m_axi_rresp;
    wire         m_axi_rlast;
    wire         m_axi_rvalid;
    wire         m_axi_rready;

    //=========================================================================
    // 2) Block Design chi chua PS - xuat M00_AXI external
    //    (Ten instance/cong theo wrapper Vivado sinh ra; chinh cho khop neu khac)
    //=========================================================================
    design_1_wrapper u_ps (
        // DDR + FIXED_IO
        .DDR_addr(DDR_addr), .DDR_ba(DDR_ba), .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n), .DDR_ck_p(DDR_ck_p), .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n), .DDR_dm(DDR_dm), .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n), .DDR_dqs_p(DDR_dqs_p), .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n), .DDR_reset_n(DDR_reset_n), .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn), .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio), .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb), .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        // Clock + reset xuat ra cho PL
        .FCLK_CLK0(axi_aclk),
        .peripheral_aresetn(axi_aresetn),
        // M00_AXI external (sau SmartConnect, da la AXI4)
        .M00_AXI_awaddr(m_axi_awaddr),   .M00_AXI_awlen(m_axi_awlen),
        .M00_AXI_awsize(m_axi_awsize),   .M00_AXI_awburst(m_axi_awburst),
        .M00_AXI_awvalid(m_axi_awvalid), .M00_AXI_awready(m_axi_awready),
        .M00_AXI_wdata(m_axi_wdata),     .M00_AXI_wstrb(m_axi_wstrb),
        .M00_AXI_wlast(m_axi_wlast),     .M00_AXI_wvalid(m_axi_wvalid),
        .M00_AXI_wready(m_axi_wready),
        .M00_AXI_bresp(m_axi_bresp),     .M00_AXI_bvalid(m_axi_bvalid),
        .M00_AXI_bready(m_axi_bready),
        .M00_AXI_araddr(m_axi_araddr),   .M00_AXI_arlen(m_axi_arlen),
        .M00_AXI_arsize(m_axi_arsize),   .M00_AXI_arburst(m_axi_arburst),
        .M00_AXI_arvalid(m_axi_arvalid), .M00_AXI_arready(m_axi_arready),
        .M00_AXI_rdata(m_axi_rdata),     .M00_AXI_rresp(m_axi_rresp),
        .M00_AXI_rlast(m_axi_rlast),     .M00_AXI_rvalid(m_axi_rvalid),
        .M00_AXI_rready(m_axi_rready)
    );

    //=========================================================================
    // 3) Khoi Ethernet + AXI slave. clk_wiz BEN TRONG nhan eth_clk_50m TRUC TIEP
    //    tu chan K17 (top-level) -> KHOA PHA DUOC (khac phuc loi cu).
    //=========================================================================
    top_axi_eth u_eth_axi (
        // Ethernet - eth_clk noi TRUC TIEP chan K17
        .eth_clk     (eth_clk_50m),    // <<< MAU CHOT: xung tu top-level port
        .eth_rst_n   (sys_rst_n),
        .phy_rxc     (phy_rxc),
        .phy_rx_ctrl (phy_rx_ctrl),
        .phy_rxd     (phy_rxd),
        .phy_txc     (phy_txc),
        .phy_tx_ctrl (phy_tx_ctrl),
        .phy_txd     (phy_txd),
        .phy_rstn    (phy_rstn),
        .linkspeed   (linkspeed),
        .mdc         (mdc),
        .mdio        (mdio),
        // AXI - noi voi M00_AXI cua PS
        .S_AXI_ACLK    (axi_aclk),
        .S_AXI_ARESETN (axi_aresetn),
        .S_AXI_AWADDR  (m_axi_awaddr),
        .S_AXI_AWLEN   (m_axi_awlen),
        .S_AXI_AWSIZE  (m_axi_awsize),
        .S_AXI_AWBURST (m_axi_awburst),
        .S_AXI_AWVALID (m_axi_awvalid),
        .S_AXI_AWREADY (m_axi_awready),
        .S_AXI_WDATA   (m_axi_wdata),
        .S_AXI_WSTRB   (m_axi_wstrb),
        .S_AXI_WLAST   (m_axi_wlast),
        .S_AXI_WVALID  (m_axi_wvalid),
        .S_AXI_WREADY  (m_axi_wready),
        .S_AXI_BRESP   (m_axi_bresp),
        .S_AXI_BVALID  (m_axi_bvalid),
        .S_AXI_BREADY  (m_axi_bready),
        .S_AXI_ARADDR  (m_axi_araddr),
        .S_AXI_ARLEN   (m_axi_arlen),
        .S_AXI_ARSIZE  (m_axi_arsize),
        .S_AXI_ARBURST (m_axi_arburst),
        .S_AXI_ARVALID (m_axi_arvalid),
        .S_AXI_ARREADY (m_axi_arready),
        .S_AXI_RDATA   (m_axi_rdata),
        .S_AXI_RRESP   (m_axi_rresp),
        .S_AXI_RLAST   (m_axi_rlast),
        .S_AXI_RVALID  (m_axi_rvalid),
        .S_AXI_RREADY  (m_axi_rready)
    );

endmodule

//=============================================================================
// GHI CHU QUAN TRONG khi dung file nay:
//
// 1) Ten cong cua design_1_wrapper PHAI khop voi ten Vivado sinh ra. Sau khi
//    sua Block Design (xuat M00_AXI + FCLK_CLK0 + peripheral_aresetn external),
//    mo file design_1_wrapper.v de xem ten cong chinh xac, roi sua lai cho khop.
//    Vi du Vivado co the dat ten "M00_AXI_0_awaddr" thay vi "M00_AXI_awaddr".
//
// 2) Cach xuat M00_AXI ra external trong Block Design:
//    - Mo BD, click chuot phai len cong M00_AXI cua axi_smc -> Make External.
//    - Tuong tu cho FCLK_CLK0 va peripheral_aresetn (cong cua rst_ps7).
//    - Generate Output Products -> Create HDL Wrapper (chon "let Vivado manage").
//
// 3) Dat top_integrated.v lam Top module (Set as Top).
//
// 4) XDC: gan eth_clk_50m -> K17, sys_rst_n -> nut reset, cac chan phy_* theo
//    bang gan chan cu (eth_axi_all.xdc). DDR/FIXED_IO khong can gan (PS tu lo).
//=============================================================================
