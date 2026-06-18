//eth control module
module eth_ctrl(
    input              clk       ,    //ÏµÍ³Ê±ÖÓ
    input              rst_n     ,    //ÏµÍ³¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§ 
    //arp port                                 
    input              arp_rx_done,   //ARP½ÓÊÕÍê³ÉÐÅºÅ
    input              arp_rx_type,   //ARP½ÓÊÕÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    output             arp_tx_en,     //ARP·¢ËÍÊ¹ÄÜÐÅºÅ
    output             arp_tx_type,   //ARP·¢ËÍÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    input              arp_tx_done,   //ARP·¢ËÍÍê³ÉÐÅºÅ
    input              arp_gmii_txen,//ARP GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ 
    input     [7:0]    arp_gmii_txd,  //ARP GMIIÊä³öÊý¾Ý
    //UDP  data input
    input              udp_gmii_txen,//UDP GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ  
    input     [7:0]    udp_gmii_txd,  //UDP GMIIÊä³öÊý¾Ý   
    //gmii tx data 
    output             gmii_txen,    //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ 
    output    [7:0]    gmii_txd       //UDP GMIIÊä³öÊý¾Ý 
    );

//indicate whitch protocal
reg        protocol; //Ð­ÒéÇÐ»»ÐÅºÅ

assign arp_tx_en = arp_rx_done && (arp_rx_type == 1'b0);
assign arp_tx_type = 1'b1;   //arp type fixed                               
assign gmii_txen = protocol ? udp_gmii_txen : arp_gmii_txen;
assign gmii_txd = protocol ? udp_gmii_txd : arp_gmii_txd;

//¸ù¾ÝARP·¢ËÍÊ¹ÄÜ/Íê³ÉÐÅºÅ,ÇÐ»»GMIIÒý½Å
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)           protocol <= 1'b1;
    else if(arp_tx_en)   protocol <= 1'b0;
    else if(arp_tx_done) protocol <= 1'b1;
end

endmodule