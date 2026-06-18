//ETH UDP LOOPBACK
module udp_loop_top
(
    input              clk   , //system clk ,50Mhz
    input              rst_n , //system resetn
    //RGMII
    input              phy_rxc   , //rxclk
    input              phy_rx_ctrl, //rx ctrl
    input       [3:0]  phy_rxd   , //rxd[3:0]
    output             phy_txc   , //txclk
    output             phy_tx_ctrl, //
    output      [3:0]  phy_txd   , //txd[3:0]         
    output             phy_rstn,   //phy rst,active low
    
    output      [1:0]  linkspeed,
    output             mdc  , //MDIO CLK
    inout              mdio  ,  //MDIO DATA 
    //--- 2 cong moi: re nhanh du lieu nhan ra ngoai cho AXI doc ---
    output             rxd_wr_en_o   ,  // bao co word du lieu nhan
    output      [31:0] rxd_wr_data_o    // word du lieu nhan
    );
    
//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10};  
//destination mac ff_ff_ff_ff_ff_ff
parameter  DEST_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//destination ip 192.168.1.100     
parameter  DEST_IP    = {8'd192,8'd168,8'd1,8'd5};  

//wire define
wire          mdio_clk;
wire          clk_200m   ; //ÓÃÓÚIOÑÓÊ±µÄÊ±ÖÓ 
              
(*mark_debug="true"*)wire          gmii_rxc; //GMII½ÓÊÕÊ±ÖÓ
(*mark_debug="true"*)wire          gmii_rxdv ; //GMII½ÓÊÕÊý¾ÝÓÐÐ§ÐÅºÅ
(*mark_debug="true"*)wire  [7:0]   gmii_rxd   ; //GMII½ÓÊÕÊý¾Ý
(*mark_debug="true"*)wire          gmii_txc; //GMII·¢ËÍÊ±ÖÓ
(*mark_debug="true"*)wire          gmii_txen ; //GMII·¢ËÍÊý¾ÝÊ¹ÄÜÐÅºÅ
(*mark_debug="true"*)wire  [7:0]   gmii_txd   ; //GMII·¢ËÍÊý¾Ý     

(*mark_debug="true"*)wire          arp_gmii_txen; //ARP GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ 
(*mark_debug="true"*)wire  [7:0]   arp_gmii_txd  ; //ARP GMIIÊä³öÊý¾Ý
(*mark_debug="true"*)wire          arp_rx_done   ; //ARP½ÓÊÕÍê³ÉÐÅºÅ
(*mark_debug="true"*)wire          arp_rx_type   ; //ARP½ÓÊÕÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
wire  [47:0]  source_mac       ; //Ô´MACµØÖ·
wire  [31:0]  source_ip        ; //Ô´IPµØÖ·
(*mark_debug="true"*)wire          arp_tx_en     ; //ARP·¢ËÍÊ¹ÄÜÐÅºÅ
wire          arp_tx_type   ; //ARP·¢ËÍÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
wire  [47:0]  destination_mac       ; //Ä¿µÄMACµØÖ·
wire  [31:0]  desination_ip        ; //Ä¿µÄIPµØÖ·   
(*mark_debug="true"*)wire          arp_tx_done   ; //ARP Íê³É±êÖ¾

wire          udp_gmii_txen; //UDP GMII Êý¾Ý·¢ËÍÊ¹ÄÜ
wire  [7:0]   udp_gmii_txd  ; //UDP GMII·¢ËÍÊý¾Ý
wire          rxd_pkt_done  ; //UDP µ¥°ü½ÓÊÕÍê³ÉÐÅºÅ
wire          rxd_wr_en        ; //UDP ½ÓÊÕÊý¾ÝÊ¹ÄÜÐÅºÅ
wire  [31:0]  rxd_wr_data      ; //UDP ½ÓÊÕÊý¾Ý
wire  [15:0]  rxd_wr_byte_num  ; //UDP ½ÓÊÕµÄÓÐÐ§×Ö½ÚÊý µ¥Î»:×Ö½Ú
wire  [15:0]  tx_byte_num   ; //UDP ·¢ËÍµÄÓÐÐ§×Ö½ÚÊý µ¥Î»:×Ö½Ú
wire          udp_tx_done   ; //UDP ·¢ËÍÍê³ÉÐÅºÅ
wire          tx_request        ; //UDP ¶ÁÊý¾ÝÇëÇó
wire  [31:0]  tx_data       ; //UDP ´ý·¢ËÍÊý¾Ý


assign phy_rstn = rst_n;

wire iodelay_ref_clk;

assign tx_start_en = rxd_pkt_done;
assign tx_byte_num = rxd_wr_byte_num;
assign destination_mac = source_mac;
assign desination_ip = source_ip;


// clock £¬output 200M to iodelay,50Mhz to mdio module clock
clk_wiz_0 clk_wiz_inst
(
    .clk_in1   (clk   ),//input 50Mhz
    .clk_out1  (iodelay_ref_clk),  //output 200Mhz  
    .clk_out2  (mdio_clk),//output 50Mhz
    .resetn     (rst_n)
);

wire          mdio_triger    ;  //triger satrt
wire          write_read   ;  //0 is write,1 is read
wire  [4:0]   phy_reg_addr    ;  //phy reg addr
wire  [15:0]  write_data ;  //write data
wire          done    ;  //¶ÁÐ´Íê³É
wire  [15:0]  read_data ;  //readout data
wire          read_ack  ;  //read ack
wire          mdio_divid_clk    ;  //mdio clk

mdio_driver mdio_driver_inst1(
    .clk        (mdio_clk),
    .rst_n      (rst_n),
    .mdio_triger    (mdio_triger),
    .write_read   (write_read  ),   
    .reg_addr    (phy_reg_addr   ),   
    .write_data (write_data),   
    .done    (done),   
    .read_data (read_data),   
    .read_ack  (read_ack ),   
    .divid_clk  (mdio_divid_clk),    
    .phy_mdc    (mdc),   
    .phy_mdio   (mdio)   
);      

//MDIO READ WRITE CONTROL  
mdio_read_write  mdio_read_write_inst1(
    .clk           (mdio_divid_clk),  
    .rst_n         (rst_n ),  
    .rst_trig      (1'b1 ),  
    .done          (done   ),  
    .read_data     (read_data),  
    .read_ack      (read_ack ),  
    .mdio_triger   (mdio_triger   ),  
    .write_read    (write_read  ),  
    .reg_addr      (phy_reg_addr   ),  
    .write_data    (write_data),  
    .state_led     (linkspeed)
);      

//RGMII to GMII,4BIT DDR to 8BIT SDR
gmii_to_rgmii  gmii_to_rgmii_inst(
    .refclk_200m    (iodelay_ref_clk),
    .gmii_rxc      (gmii_rxc ),
    .gmii_rxdv    (gmii_rxdv),
    .gmii_rxd      (gmii_rxd),
    .gmii_txc      (gmii_txc),
    .gmii_txen    (gmii_txen),
    .gmii_txd      (gmii_txd),
    .rgmii_rxc      (phy_rxc),
    .rgmii_rx_ctrl  (phy_rx_ctrl),
    .rgmii_rxd      (phy_rxd),
    .rgmii_txc      (phy_txc),
    .rgmii_tx_ctrl  (phy_tx_ctrl),
    .rgmii_txd      (phy_txd)
    );

//ARP module
arp_top                                             
   #(
    .MY_MAC     (MY_MAC), //
    .MY_IP      (MY_IP ),
    .DEST_MAC       (DEST_MAC),
    .DEST_IP        (DEST_IP)
    )
   arp_top_inst
   (
    .rst_n         (rst_n  ),
    
    .gmii_rxc      (gmii_rxc),
    .gmii_rxdv    (gmii_rxdv ),
    .gmii_rxd      (gmii_rxd   ),
    .gmii_txc      (gmii_txc),
    .gmii_txen    (arp_gmii_txen ),
    .gmii_txd      (arp_gmii_txd),
                    
    .arp_rx_done   (arp_rx_done),
    .arp_rx_type   (arp_rx_type),
    .source_mac    (source_mac    ),
    .source_ip     (source_ip     ),
    .arp_tx_en     (arp_tx_en  ),
    .arp_tx_type   (arp_tx_type),
    .destination_mac       (destination_mac    ),
    .desination_ip        (desination_ip     ),
    .tx_done       (arp_tx_done)
    );

//UDP module
udp_top                                             
   #(
    .MY_MAC     (MY_MAC), //
    .MY_IP      (MY_IP ),
    .DEST_MAC       (DEST_MAC),
    .DEST_IP        (DEST_IP)
    )
   udp_top_inst
   (
    .rst_n         (rst_n),  
    .gmii_rxc      (gmii_rxc),           
    .gmii_rxdv     (gmii_rxdv),         
    .gmii_rxd      (gmii_rxd),                   
    .gmii_txc      (gmii_txc ), 
    .gmii_txen     (udp_gmii_txen),         
    .gmii_txd      (udp_gmii_txd), //
    .rxd_pkt_done  (rxd_pkt_done),    
    .rxd_wr_en     (rxd_wr_en),     
    .rxd_wr_data   (rxd_wr_data),         
    .rxd_wr_byte_num  (rxd_wr_byte_num),      
    .tx_start_en   (tx_start_en),        
    .tx_data       (tx_data),         
    .tx_byte_num   (tx_byte_num),  
    .destination_mac       (destination_mac),
    .destination_ip        (desination_ip),    
    .tx_done       (udp_tx_done),        
    .tx_request        (tx_request)           
    ); 


//===========================================================
// CHUYEN CHU THUONG -> CHU HOA (sinh vien tu them)
// ASCII 'a'(0x61)..'z'(0x7A) -> tru 0x20 thanh 'A'..'Z'
// Xu ly tung byte trong 32-bit (4 byte/word)
//===========================================================
wire [31:0] rxd_wr_data_upper;
function [7:0] to_upper;
    input [7:0] ch;
    begin
        if (ch >= 8'h61 && ch <= 8'h7A)   // neu la 'a'..'z'
            to_upper = ch - 8'h20;        // doi thanh 'A'..'Z'
        else
            to_upper = ch;                // ky tu khac giu nguyen
    end
endfunction

assign rxd_wr_data_upper = { to_upper(rxd_wr_data[31:24]),
                             to_upper(rxd_wr_data[23:16]),
                             to_upper(rxd_wr_data[15:8]),
                             to_upper(rxd_wr_data[7:0]) };

//sync fifo
fifo_generator_0 fifo_generator_0_inst (
    .clk      (gmii_rxc),  // input wire clk
    .rst      (~rst_n),  // input wire rst
    .din      (rxd_wr_data_upper),  // input wire [31 : 0] din (DA IN HOA)
    .wr_en    (rxd_wr_en),  // input wire wr_en
    .rd_en    (tx_request),  // input wire rd_en
    .dout     (tx_data),  // output wire [31 : 0] dout
    .full     (),            // output wire full
    .empty    ()             // output wire empty
    );    

// eth rx tx control
eth_ctrl eth_ctrl_inst(
    .clk            (gmii_rxc),
    .rst_n          (rst_n),

    .arp_rx_done    (arp_rx_done   ),
    .arp_rx_type    (arp_rx_type   ),
    .arp_tx_en      (arp_tx_en     ),
    .arp_tx_type    (arp_tx_type   ),
    .arp_tx_done    (arp_tx_done   ),
    .arp_gmii_txen (arp_gmii_txen),
    .arp_gmii_txd   (arp_gmii_txd  ),
                     
    .udp_gmii_txen (udp_gmii_txen),
    .udp_gmii_txd   (udp_gmii_txd  ),
                     
    .gmii_txen     (gmii_txen ),
    .gmii_txd       (gmii_txd )
    );
    
    


//--- Re nhanh du lieu nhan ra ngoai (cho khoi AXI doc) ---
assign rxd_wr_en_o   = rxd_wr_en;
assign rxd_wr_data_o = rxd_wr_data;

endmodule