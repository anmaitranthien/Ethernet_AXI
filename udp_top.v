//UDP Top module
module udp_top(
    input                rst_n       , //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§
    //GMII
    input                gmii_rxc , //GMII½ÓÊÕÊý¾ÝÊ±ÖÓ
    input                gmii_rxdv  , //GMIIÊäÈëÊý¾ÝÓÐÐ§ÐÅºÅ
    input        [7:0]   gmii_rxd    , //GMIIÊäÈëÊý¾Ý
    input                gmii_txc , //GMII·¢ËÍÊý¾ÝÊ±ÖÓ    
    output               gmii_txen  , //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    output       [7:0]   gmii_txd    , //GMIIÊä³öÊý¾Ý 
    // udp port
    output               rxd_pkt_done, //ÒÔÌ«Íøµ¥°üÊý¾Ý½ÓÊÕÍê³ÉÐÅºÅ
    output               rxd_wr_en      , //ÒÔÌ«Íø½ÓÊÕµÄÊý¾ÝÊ¹ÄÜÐÅºÅ
    output       [31:0]  rxd_wr_data    , //ÒÔÌ«Íø½ÓÊÕµÄÊý¾Ý
    output       [15:0]  rxd_wr_byte_num, //ÒÔÌ«Íø½ÓÊÕµÄÓÐÐ§×Ö½ÚÊý µ¥Î»:byte     
    input                tx_start_en , //ÒÔÌ«Íø¿ªÊ¼·¢ËÍÐÅºÅ
    input        [31:0]  tx_data     , //ÒÔÌ«Íø´ý·¢ËÍÊý¾Ý  
    input        [15:0]  tx_byte_num , //ÒÔÌ«Íø·¢ËÍµÄÓÐÐ§×Ö½ÚÊý µ¥Î»:byte  
    input        [47:0]  destination_mac     , //·¢ËÍµÄÄ¿±êMACµØÖ·
    input        [31:0]  destination_ip      , //·¢ËÍµÄÄ¿±êIPµØÖ·    
    output               tx_done     , //ÒÔÌ«Íø·¢ËÍÍê³ÉÐÅºÅ
    output               tx_request        //¶ÁÊý¾ÝÇëÇóÐÅºÅ    
    );

//board mac address
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10};  
//destination mac ff_ff_ff_ff_ff_ff
parameter  DEST_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//destination ip 192.168.1.100     
parameter  DEST_IP    = {8'd192,8'd168,8'd1,8'd5};  

//wire define
wire          crc_en  ; //CRC¿ªÊ¼Ð£ÑéÊ¹ÄÜ
wire          crc_clear ; //CRCÊý¾Ý¸´Î»ÐÅºÅ 
wire  [7:0]   crc_d8  ; //ÊäÈë´ýÐ£Ñé8Î»Êý¾Ý

wire  [31:0]  crc_data; //CRCÐ£ÑéÊý¾Ý
wire  [31:0]  crc_next; //CRCÏÂ´ÎÐ£ÑéÍê³ÉÊý¾Ý

assign  crc_d8 = gmii_txd;

// UDP RXD  module
udp_rxd 
   #(
    .MY_MAC(MY_MAC),         //²ÎÊýÀý»¯
    .MY_IP(MY_IP )
    )
   udp_rx_inst(
    .clk             (gmii_rxc ),        
    .rst_n           (rst_n       ),             
    .gmii_rxdv      (gmii_rxdv  ),                                 
    .gmii_rxd        (gmii_rxd    ),       
    .rxd_pkt_done    (rxd_pkt_done),      
    .rxd_wr_en          (rxd_wr_en      ),            
    .rxd_wr_data        (rxd_wr_data    ),          
    .rxd_wr_byte_num    (rxd_wr_byte_num)       
    );                                    

//ÒÔÌ«Íø·¢ËÍÄ£¿é
udp_txd
   #(
    .MY_MAC     (MY_MAC), //
    .MY_IP      (MY_IP ),
    .DEST_MAC       (DEST_MAC),
    .DEST_IP        (DEST_IP)
    )
   udp_tx_inst(
    .clk             (gmii_txc),        
    .rst_n           (rst_n      ),             
    .tx_start_en     (tx_start_en),                   
    .tx_data         (tx_data    ),           
    .tx_byte_num     (tx_byte_num),    
    .destination_mac         (destination_mac    ),
    .destination_ip          (destination_ip     ),    
    .crc_data        (crc_data   ),          
    .crc_next        (crc_next[31:24]),
    .tx_done         (tx_done    ),           
    .tx_request          (tx_request     ),            
    .gmii_txen      (gmii_txen ),         
    .gmii_txd        (gmii_txd   ),       
    .crc_en          (crc_en     ),            
    .crc_clear         (crc_clear    )            
    );                                      

//ARP TXD module
crc32   crc32_inst(
    .clk             (gmii_txc),                      
    .rst_n           (rst_n      ),                          
    .data_in            (crc_d8     ),            
    .crc_en          (crc_en     ),                          
    .crc_clear         (crc_clear    ),                         
    .crc_data        (crc_data   ),                        
    .crc_next        (crc_next   )                         
    );

endmodule