//port ddr to sdr,4bit to 8bit rgmii<->gmii
module gmii_to_rgmii(
    input              refclk_200m  , //IDELAYÊ±ÖÓ
    //GMII
    output             gmii_rxc , //GMII½ÓÊÕÊ±ÖÓ
    output             gmii_rxdv  , //GMII½ÓÊÕÊý¾ÝÓÐÐ§ÐÅºÅ
    output      [7:0]  gmii_rxd    , //GMII½ÓÊÕÊý¾Ý
    output             gmii_txc , //GMII·¢ËÍÊ±ÖÓ
    input              gmii_txen  , //GMII·¢ËÍÊý¾ÝÊ¹ÄÜÐÅºÅ
    input       [7:0]  gmii_txd    , //GMII·¢ËÍÊý¾Ý            
    //RGMII 
    input              rgmii_rxc   , //RGMII½ÓÊÕÊ±ÖÓ
    input              rgmii_rx_ctrl, //RGMII½ÓÊÕÊý¾Ý¿ØÖÆÐÅºÅ
    input       [3:0]  rgmii_rxd   , //RGMII½ÓÊÕÊý¾Ý
    output             rgmii_txc   , //RGMII·¢ËÍÊ±ÖÓ    
    output             rgmii_tx_ctrl, //RGMII·¢ËÍÊý¾Ý¿ØÖÆÐÅºÅ
    output      [3:0]  rgmii_txd     //RGMII·¢ËÍÊý¾Ý          
    );

assign gmii_txc = gmii_rxc;

//RGMII RX DATA
rgmii_rxd rgmii_rxd_inst(
    .refclk_200m    (refclk_200m),
    .gmii_rxc      (gmii_rxc),
    .rgmii_rxc     (rgmii_rxc   ),
    .rgmii_rx_ctrl  (rgmii_rx_ctrl),
    .rgmii_rxd     (rgmii_rxd   ),
    .gmii_rxdv    (gmii_rxdv ),
    .gmii_rxd      (gmii_rxd   )
    );

//RGMII TX DATA
rgmii_txd rgmii_txd_inst(
    .gmii_txc      (gmii_txc ),
    .gmii_txen    (gmii_txen  ),
    .gmii_txd      (gmii_txd    ),
    .rgmii_txc     (rgmii_txc   ),
    .rgmii_tx_ctrl (rgmii_tx_ctrl),
    .rgmii_txd     (rgmii_txd   )
    );

endmodule