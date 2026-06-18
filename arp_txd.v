//arp txd module
module arp_txd( 
    input                clk        , //Ê±ÖÓÐÅºÅ
    input                rst_n      , //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§
    
    input                arp_tx_en  , //ARP·¢ËÍÊ¹ÄÜÐÅºÅ
    input                arp_tx_type, //ARP·¢ËÍÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    input        [47:0]  destination_mac    , //·¢ËÍµÄÄ¿±êMACµØÖ·
    input        [31:0]  destination_ip     , //·¢ËÍµÄÄ¿±êIPµØÖ·
    input        [31:0]  crc_data   , //CRCÐ£ÑéÊý¾Ý
    input         [7:0]  crc_next   , //CRCÏÂ´ÎÐ£ÑéÍê³ÉÊý¾Ý
    output  reg          tx_done    , //ÒÔÌ«Íø·¢ËÍÍê³ÉÐÅºÅ
    output  reg          gmii_txen , //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    output  reg  [7:0]   gmii_txd   , //GMIIÊä³öÊý¾Ý
    output  reg          crc_en     , //CRC¿ªÊ¼Ð£ÑéÊ¹ÄÜ
    output  reg          crc_clear      //CRCÊý¾Ý¸´Î»ÐÅºÅ 
    );

//parameter define
//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10}; 
//destination mac ff_ff_ff_ff_ff_ff
parameter  DEST_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//destination ip 192.168.1.100     
parameter  DEST_IP    = {8'd192,8'd168,8'd1,8'd5};  

localparam state_idle      = 'b0_0001; //³õÊ¼×´Ì¬£¬µÈ´ý¿ªÊ¼·¢ËÍÐÅºÅ
localparam state_preamble  = 'b0_0010; //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
localparam state_eth_head  = 'b0_0100; //·¢ËÍÒÔÌ«ÍøÖ¡Í·
localparam state_arp_data  = 'b0_1000; //
localparam state_crc       = 'b1_0000; //·¢ËÍCRCÐ£ÑéÖµ

localparam  ETH_TYPE     = 'h0806 ; //ÒÔÌ«ÍøÖ¡ÀàÐÍ ARPÐ­Òé
localparam  HD_TYPE      = 'h0001 ; //Ó²¼þÀàÐÍ ÒÔÌ«Íø
localparam  PROTOCOL_TYPE= 'h0800 ; //ÉÏ²ãÐ­ÒéÎªIPÐ­Òé
//ÒÔÌ«ÍøÊý¾Ý×îÐ¡Îª46¸ö×Ö½Ú,²»×ã²¿·ÖÌî³äÊý¾Ý
localparam  MIN_DATA_NUM = 'd46   ;    

//reg define
reg  [4:0]  cur_state     ;
reg  [4:0]  next_state    ;
                          
reg  [7:0]  preamble[7:0] ; //Ç°µ¼Âë+SFD
reg  [7:0]  eth_head[13:0]; //ÒÔÌ«ÍøÊ×²¿
reg  [7:0]  arp_data[27:0]; //ARPÊý¾Ý
                            
reg         tx_en_d0      ; //arp_tx_enÐÅºÅÑÓÊ±
reg         tx_en_d1      ; 
reg         skip_en       ; //¿ØÖÆ×´Ì¬Ìø×ªÊ¹ÄÜÐÅºÅ
reg  [5:0]  cnt           ; 
reg  [4:0]  data_cnt      ; //·¢ËÍÊý¾Ý¸öÊý¼ÆÊýÆ÷
reg         tx_done_reg     ; 
                                
//wire define                   
wire        pos_tx_en     ; //arp_tx_enÐÅºÅÉÏÉýÑØ

assign  pos_tx_en = (~tx_en_d1) & tx_en_d0;
                           
//¶Ôarp_tx_enÐÅºÅÑÓÊ±´òÅÄÁ½´Î,ÓÃÓÚ²Éarp_tx_enµÄÉÏÉýÑØ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        tx_en_d0 <= 1'b0;
        tx_en_d1 <= 1'b0;
    end    
    else begin
        tx_en_d0 <= arp_tx_en;
        tx_en_d1 <= tx_en_d0;
    end
end 

//(Èý¶ÎÊ½×´Ì¬»ú)Í¬²½Ê±ÐòÃèÊö×´Ì¬×ªÒÆ
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <=state_idle;  
    else
        cur_state <= next_state;
end

//×éºÏÂß¼­ÅÐ¶Ï×´Ì¬×ªÒÆÌõ¼þ
always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle : begin                     //¿ÕÏÐ×´Ì¬
            if(skip_en)                
                next_state =state_preamble;
            else
                next_state =state_idle;
        end                          
       state_preamble : begin                 //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
            if(skip_en)
                next_state =state_eth_head;
            else
                next_state =state_preamble;      
        end
       state_eth_head : begin                 //·¢ËÍÒÔÌ«ÍøÊ×²¿
            if(skip_en)
                next_state =state_arp_data;
            else
                next_state =state_eth_head;      
        end              
       state_arp_data : begin                 //·¢ËÍARPÊý¾Ý                      
            if(skip_en)
                next_state =state_crc;
            else
                next_state =state_arp_data;      
        end
       state_crc: begin                       //·¢ËÍCRCÐ£ÑéÖµ
            if(skip_en)
                next_state =state_idle;
            else
                next_state =state_crc;      
        end
        default : next_state =state_idle;   
    endcase
end                      

//Ê±ÐòµçÂ·ÃèÊö×´Ì¬Êä³ö£¬·¢ËÍÒÔÌ«ÍøÊý¾Ý
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0; 
        cnt <= 6'd0;
        data_cnt <= 5'd0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        gmii_txd <= 8'd0;
        tx_done_reg <= 1'b0; 
        
        //³õÊ¼»¯Êý×é    
        //Ç°µ¼Âë 7¸ö8'h55 + 1¸ö8'hd5 
        preamble[0] <= 8'h55;                
        preamble[1] <= 8'h55;
        preamble[2] <= 8'h55;
        preamble[3] <= 8'h55;
        preamble[4] <= 8'h55;
        preamble[5] <= 8'h55;
        preamble[6] <= 8'h55;
        preamble[7] <= 8'hd5;
        //ÒÔÌ«ÍøÖ¡Í· 
        eth_head[0] <= DEST_MAC[47:40];      //Ä¿µÄMACµØÖ·
        eth_head[1] <= DEST_MAC[39:32];
        eth_head[2] <= DEST_MAC[31:24];
        eth_head[3] <= DEST_MAC[23:16];
        eth_head[4] <= DEST_MAC[15:8];
        eth_head[5] <= DEST_MAC[7:0];        
        eth_head[6] <= MY_MAC[47:40];    //Ô´MACµØÖ·
        eth_head[7] <= MY_MAC[39:32];    
        eth_head[8] <= MY_MAC[31:24];    
        eth_head[9] <= MY_MAC[23:16];    
        eth_head[10] <= MY_MAC[15:8];    
        eth_head[11] <= MY_MAC[7:0];     
        eth_head[12] <= ETH_TYPE[15:8];     //ÒÔÌ«ÍøÖ¡ÀàÐÍ
        eth_head[13] <= ETH_TYPE[7:0];      
        //ARPÊý¾Ý                           
        arp_data[0] <= HD_TYPE[15:8];       //Ó²¼þÀàÐÍ
        arp_data[1] <= HD_TYPE[7:0];
        arp_data[2] <= PROTOCOL_TYPE[15:8]; //ÉÏ²ãÐ­ÒéÀàÐÍ
        arp_data[3] <= PROTOCOL_TYPE[7:0];
        arp_data[4] <= 8'h06;               //Ó²¼þµØÖ·³¤¶È,6
        arp_data[5] <= 8'h04;               //Ð­ÒéµØÖ·³¤¶È,4
        arp_data[6] <= 8'h00;               //OP,²Ù×÷Âë 8'h01£ºARPÇëÇó 8'h02:ARPÓ¦´ð
        arp_data[7] <= 8'h01;
        arp_data[8] <= MY_MAC[47:40];    //·¢ËÍ¶Ë(Ô´)MACµØÖ·
        arp_data[9] <= MY_MAC[39:32];
        arp_data[10] <= MY_MAC[31:24];
        arp_data[11] <= MY_MAC[23:16];
        arp_data[12] <= MY_MAC[15:8];
        arp_data[13] <= MY_MAC[7:0];
        arp_data[14] <= MY_IP[31:24];    //·¢ËÍ¶Ë(Ô´)IPµØÖ·
        arp_data[15] <= MY_IP[23:16];
        arp_data[16] <= MY_IP[15:8];
        arp_data[17] <= MY_IP[7:0];
        arp_data[18] <= DEST_MAC[47:40];     //½ÓÊÕ¶Ë(Ä¿µÄ)MACµØÖ·
        arp_data[19] <= DEST_MAC[39:32];
        arp_data[20] <= DEST_MAC[31:24];
        arp_data[21] <= DEST_MAC[23:16];
        arp_data[22] <= DEST_MAC[15:8];
        arp_data[23] <= DEST_MAC[7:0];  
        arp_data[24] <= DEST_IP[31:24];      //½ÓÊÕ¶Ë(Ä¿µÄ)IPµØÖ·
        arp_data[25] <= DEST_IP[23:16];
        arp_data[26] <= DEST_IP[15:8];
        arp_data[27] <= DEST_IP[7:0];
    end
    else begin
        skip_en <= 1'b0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        tx_done_reg <= 1'b0;
        case(next_state)
           state_idle : begin
                if(pos_tx_en) begin
                    skip_en <= 1'b1;  
                    //Èç¹ûÄ¿±êMACµØÖ·ºÍIPµØÖ·ÒÑ¾­¸üÐÂ,Ôò·¢ËÍÕýÈ·µÄµØÖ·
                    if((destination_mac != 48'b0) || (destination_ip != 32'd0)) begin
                        eth_head[0] <= destination_mac[47:40];
                        eth_head[1] <= destination_mac[39:32];
                        eth_head[2] <= destination_mac[31:24];
                        eth_head[3] <= destination_mac[23:16];
                        eth_head[4] <= destination_mac[15:8];
                        eth_head[5] <= destination_mac[7:0];  
                        arp_data[18] <= destination_mac[47:40];
                        arp_data[19] <= destination_mac[39:32];
                        arp_data[20] <= destination_mac[31:24];
                        arp_data[21] <= destination_mac[23:16];
                        arp_data[22] <= destination_mac[15:8];
                        arp_data[23] <= destination_mac[7:0];  
                        arp_data[24] <= destination_ip[31:24];
                        arp_data[25] <= destination_ip[23:16];
                        arp_data[26] <= destination_ip[15:8];
                        arp_data[27] <= destination_ip[7:0];
                    end
                    if(arp_tx_type == 1'b0)
                        arp_data[7] <= 8'h01;            //ARPÇëÇó 
                    else 
                        arp_data[7] <= 8'h02;            //ARPÓ¦´ð
                end    
            end                                                                   
           state_preamble : begin                          //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
                gmii_txen <= 1'b1;
                gmii_txd <= preamble[cnt];
                if(cnt == 6'd7) begin                        
                    skip_en <= 1'b1;
                    cnt <= 1'b0;    
                end
                else    
                    cnt <= cnt + 1'b1;                     
            end
           state_eth_head : begin                          //·¢ËÍÒÔÌ«ÍøÊ×²¿
                gmii_txen <= 1'b1;
                crc_en <= 1'b1;
                gmii_txd <= eth_head[cnt];
                if (cnt == 6'd13) begin
                    skip_en <= 1'b1;
                    cnt <= 1'b0;
                end    
                else    
                    cnt <= cnt + 1'b1;    
            end                    
           state_arp_data : begin                          //·¢ËÍARPÊý¾Ý  
                crc_en <= 1'b1;
                gmii_txen <= 1'b1;
                //ÖÁÉÙ·¢ËÍ46¸ö×Ö½Ú
                if (cnt == MIN_DATA_NUM - 1'b1) begin    
                    skip_en <= 1'b1;
                    cnt <= 1'b0;
                    data_cnt <= 1'b0;
                end    
                else    
                    cnt <= cnt + 1'b1;  
                if(data_cnt <= 6'd27) begin
                    data_cnt <= data_cnt + 1'b1;
                    gmii_txd <= arp_data[data_cnt];
                end    
                else
                    gmii_txd <= 8'd0;                    //Padding,Ìî³ä0
            end
           state_crc      : begin                          //·¢ËÍCRCÐ£ÑéÖµ
                gmii_txen <= 1'b1;
                cnt <= cnt + 1'b1;
                if(cnt == 6'd0)
                    gmii_txd <= {~crc_next[0], ~crc_next[1], ~crc_next[2],~crc_next[3],
                                 ~crc_next[4], ~crc_next[5], ~crc_next[6],~crc_next[7]};
                else if(cnt == 6'd1)
                    gmii_txd <= {~crc_data[16], ~crc_data[17], ~crc_data[18],
                                 ~crc_data[19], ~crc_data[20], ~crc_data[21], 
                                 ~crc_data[22],~crc_data[23]};
                else if(cnt == 6'd2) begin
                    gmii_txd <= {~crc_data[8], ~crc_data[9], ~crc_data[10],
                                 ~crc_data[11],~crc_data[12], ~crc_data[13], 
                                 ~crc_data[14],~crc_data[15]};                              
                end
                else if(cnt == 6'd3) begin
                    gmii_txd <= {~crc_data[0], ~crc_data[1], ~crc_data[2],~crc_data[3],
                                 ~crc_data[4], ~crc_data[5], ~crc_data[6],~crc_data[7]};  
                    tx_done_reg <= 1'b1;
                    skip_en <= 1'b1;
                    cnt <= 1'b0;
                end                                                                                                                                            
            end                          
            default :;  
        endcase                                             
    end
end            

//·¢ËÍÍê³ÉÐÅºÅ¼°crcÖµ¸´Î»ÐÅºÅ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        tx_done <= 1'b0;
        crc_clear <= 1'b0;
    end
    else begin
        tx_done <= tx_done_reg;
        crc_clear <= tx_done_reg;
    end
end

endmodule