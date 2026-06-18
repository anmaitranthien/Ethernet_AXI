//tx gmii to rgmii 
module rgmii_txd(
    //GMII
    input              gmii_txc , //GMII·¢ËÍÊ±ÖÓ    
    input              gmii_txen  , //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    input       [7:0]  gmii_txd    , //GMIIÊä³öÊý¾Ý        
    //RGMII
    output             rgmii_txc   , //RGMII·¢ËÍÊý¾ÝÊ±ÖÓ    
    output             rgmii_tx_ctrl, //RGMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    output      [3:0]  rgmii_txd     //RGMIIÊä³öÊý¾Ý     
    );
assign rgmii_txc = gmii_txc;

// TX CTRL DDR OUTPUT
ODDR #(
    .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
    .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
) ODDR_inst (
    .Q             (rgmii_tx_ctrl), // 1-bit DDR output
    .C             (gmii_txc),  // 1-bit clock input
    .CE            (1'b1),         // 1-bit clock enable input
    .D1            (gmii_txen),   // 1-bit data input (positive edge)
    .D2            (gmii_txen),   // 1-bit data input (negative edge)
    .R             (1'b0),         // 1-bit reset
    .S             (1'b0)          // 1-bit set
); 
genvar i;
generate for (i=0; i<4; i=i+1)  //TXD DDR OUTPUT
    begin : txd_ddr
        ODDR #(
            .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
            .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
            .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
        ) ODDR_inst (
            .Q             (rgmii_txd[i]), // 1-bit DDR output
            .C             (gmii_txc),  // 1-bit clock input
            .CE            (1'b1),         // 1-bit clock enable input
            .D1            (gmii_txd[i]),  // 1-bit data input (positive edge)
            .D2            (gmii_txd[4+i]),// 1-bit data input (negative edge)
            .R             (1'b0),         // 1-bit reset
            .S             (1'b0)          // 1-bit set
        );        
    end
endgenerate

endmodule