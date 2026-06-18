//arp module top
module arp_top(
    input                rst_n      , //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§
    //GMII
    input                gmii_rxc, //GMII½ÓÊÕÊý¾ÝÊ±ÖÓ
    input                gmii_rxdv , //GMIIÊäÈëÊý¾ÝÓÐÐ§ÐÅºÅ
    input        [7:0]   gmii_rxd   , //GMIIÊäÈëÊý¾Ý
    input                gmii_txc, //GMII·¢ËÍÊý¾ÝÊ±ÖÓ
    output               gmii_txen , //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    output       [7:0]   gmii_txd   , //GMIIÊä³öÊý¾Ý          
    //arp port
    output               arp_rx_done, //ARP½ÓÊÕÍê³ÉÐÅºÅ
    output               arp_rx_type, //ARP½ÓÊÕÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    output       [47:0]  source_mac    , //½ÓÊÕµ½Ä¿µÄMACµØÖ·
    output       [31:0]  source_ip     , //½ÓÊÕµ½Ä¿µÄIPµØÖ·    
    input                arp_tx_en  , //ARP·¢ËÍÊ¹ÄÜÐÅºÅ
    input                arp_tx_type, //ARP·¢ËÍÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    input        [47:0]  destination_mac    , //·¢ËÍµÄÄ¿±êMACµØÖ·
    input        [31:0]  desination_ip     , //·¢ËÍµÄÄ¿±êIPµØÖ·
    output               tx_done      //ÒÔÌ«Íø·¢ËÍÍê³ÉÐÅºÅ    
    );

//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10};  
//destination mac ff_ff_ff_ff_ff_ff
parameter  DEST_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//destination ip 192.168.1.100     
parameter  DEST_IP    = {8'd192,8'd168,8'd1,8'd5};  
//wire
wire           crc_en  ; //CRC¿ªÊ¼Ð£ÑéÊ¹ÄÜ
wire           crc_clear ; //CRCÊý¾Ý¸´Î»ÐÅºÅ 
wire   [7:0]   crc_d8  ; //ÊäÈë´ýÐ£Ñé8Î»Êý¾Ý
wire   [31:0]  crc_data; //CRCÐ£ÑéÊý¾Ý
wire   [31:0]  crc_next; //CRCÏÂ´ÎÐ£ÑéÍê³ÉÊý¾Ý

assign  crc_d8 = gmii_txd;

//ARP½ÓÊÕÄ£¿é    
arp_rxd 
   #(
    .MY_MAC       (MY_MAC),         //²ÎÊýÀý»¯
    .MY_IP        (MY_IP )
    )
   arp_rxd_inst(
    .clk             (gmii_rxc),
    .rst_n           (rst_n),
    .gmii_rxdv      (gmii_rxdv),
    .gmii_rxd        (gmii_rxd  ),
    .arp_rx_done     (arp_rx_done),
    .arp_rx_type     (arp_rx_type),
    .source_mac         (source_mac    ),
    .source_ip       (source_ip     )
    );                                           

//ARP TXD module
arp_txd
   #(
    .MY_MAC     (MY_MAC), //
    .MY_IP      (MY_IP ),
    .DEST_MAC       (DEST_MAC),
    .DEST_IP        (DEST_IP)
    )
   arp_txd_inst(
    .clk             (gmii_txc),
    .rst_n           (rst_n),
    .arp_tx_en       (arp_tx_en ),
    .arp_tx_type     (arp_tx_type),
    .destination_mac         (destination_mac   ),
    .destination_ip          (desination_ip    ),
    .crc_data        (crc_data  ),
    .crc_next        (crc_next[31:24]),
    .tx_done         (tx_done   ),
    .gmii_txen      (gmii_txen),
    .gmii_txd        (gmii_txd  ),
    .crc_en          (crc_en    ),
    .crc_clear         (crc_clear   )
    );     

// data packet crc ,do crc32
crc32   crc32_inst(
    .clk             (gmii_txc),                      
    .rst_n           (rst_n      ),                          
    .data_in         (crc_d8     ),            
    .crc_en          (crc_en     ),                          
    .crc_clear         (crc_clear    ),                         
    .crc_data        (crc_data   ),                        
    .crc_next        (crc_next   )                         
    );

endmodule
