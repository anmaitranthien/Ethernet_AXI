#============================================================================
# top_integrated.xdc - File rang buoc cho thiet ke TICH HOP (top_integrated.v)
#
# Khac voi eth_axi_all.xdc (ban Block Design):
#   - Them clock he thong eth_clk_50m noi TRUC TIEP chan K17 (mau chot fix clk_wiz)
#   - Ten cong KHONG con hau to "_0" (vi top la RTL top_integrated, khong wrap BD)
#   - Reset sys_rst_n -> M20
#   - DDR/FIXED_IO KHONG gan o day (PS tu quan ly qua design_1_wrapper)
#
# THU TU QUAN TRONG: create_clock PHAI truoc set_false_path
#============================================================================

#---------------------- Clock he thong 50MHz (MAU CHOT) ---------------------
# Noi truc tiep chan K17 -> clk_wiz ben trong khoa pha duoc
set_property PACKAGE_PIN K17 [get_ports eth_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports eth_clk_50m]

#---------------------- Reset ------------------------------------------------
set_property PACKAGE_PIN M20 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

#---------------------- PHY reset / MDIO ------------------------------------
set_property PACKAGE_PIN G17 [get_ports phy_rstn]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rstn]
set_property PACKAGE_PIN G18 [get_ports mdc]
set_property IOSTANDARD LVCMOS33 [get_ports mdc]
set_property PACKAGE_PIN G19 [get_ports mdio]
set_property IOSTANDARD LVCMOS33 [get_ports mdio]

#---------------------- Link speed LEDs -------------------------------------
set_property PACKAGE_PIN U12 [get_ports {linkspeed[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {linkspeed[1]}]
set_property PACKAGE_PIN T12 [get_ports {linkspeed[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {linkspeed[0]}]

#---------------------- RGMII clocks ----------------------------------------
set_property PACKAGE_PIN J14 [get_ports phy_txc]
set_property IOSTANDARD LVCMOS33 [get_ports phy_txc]
set_property PACKAGE_PIN L16 [get_ports phy_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rxc]

#---------------------- RGMII control ---------------------------------------
set_property PACKAGE_PIN K14 [get_ports phy_tx_ctrl]
set_property IOSTANDARD LVCMOS33 [get_ports phy_tx_ctrl]
set_property PACKAGE_PIN L17 [get_ports phy_rx_ctrl]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rx_ctrl]

#---------------------- RGMII TX data ---------------------------------------
set_property PACKAGE_PIN N16 [get_ports {phy_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_txd[0]}]
set_property PACKAGE_PIN J19 [get_ports {phy_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_txd[1]}]
set_property PACKAGE_PIN H20 [get_ports {phy_txd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_txd[2]}]
set_property PACKAGE_PIN N15 [get_ports {phy_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_txd[3]}]

#---------------------- RGMII RX data ---------------------------------------
set_property PACKAGE_PIN L20 [get_ports {phy_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_rxd[0]}]
set_property PACKAGE_PIN K19 [get_ports {phy_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_rxd[1]}]
set_property PACKAGE_PIN J18 [get_ports {phy_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_rxd[2]}]
set_property PACKAGE_PIN J20 [get_ports {phy_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {phy_rxd[3]}]

#============================================================================
# CREATE_CLOCK - PHAI dat TRUOC false_path
#============================================================================
# Clock he thong 50MHz (chu ky 20ns) tu chan K17
create_clock -period 20.000 -name eth_clk_50m [get_ports eth_clk_50m]
# Clock Ethernet thu 125MHz (chu ky 8ns) tu PHY
create_clock -period 8.000 -name phy_rxc [get_ports phy_rxc]

#============================================================================
# FALSE_PATH cho clock domain crossing (sau khi clock da duoc tao)
# Duong du lieu giua mien Ethernet (phy_rxc) va mien AXI (clk_fpga_0) da
# duoc dong bo bang 3-FF trong top_axi_eth -> bo qua kiem tra timing.
#============================================================================
set_false_path -from [get_clocks phy_rxc]    -to [get_clocks clk_fpga_0]
set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks phy_rxc]
set_false_path -from [get_clocks clk_out2_clk_wiz_0] -to [get_clocks clk_fpga_0]
set_false_path -from [get_clocks clk_fpga_0]          -to [get_clocks clk_out2_clk_wiz_0]
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_fpga_0]
set_false_path -from [get_clocks clk_fpga_0]          -to [get_clocks clk_out1_clk_wiz_0]

#============================================================================
# GHI CHU:
# - Ten cong (eth_clk_50m, phy_*, sys_rst_n) PHAI khop khai bao trong
#   top_integrated.v. Neu doi ten cong thi sua o day cho khop.
# - "clk_fpga_0" la ten clock FCLK_CLK0 cua PS - kiem tra bang report_clocks
#   sau synthesis. Neu ten khac, sua lai cho dung.
# - KHONG gan chan DDR_*/FIXED_IO_* - PS tu lo qua design_1_wrapper.
#============================================================================
