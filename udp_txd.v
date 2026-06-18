//UDP TX DATA module
module udp_txd(    
    input                clk        , //Ê±ÖÓÐÅºÅ
    input                rst_n      , //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§
    input                tx_start_en, //ÒÔÌ«Íø¿ªÊ¼·¢ËÍÐÅºÅ
    input        [31:0]  tx_data    , //ÒÔÌ«Íø´ý·¢ËÍÊý¾Ý  
    input        [15:0]  tx_byte_num, //ÒÔÌ«Íø·¢ËÍµÄÓÐÐ§×Ö½ÚÊý
    input        [47:0]  destination_mac    , //·¢ËÍµÄÄ¿±êMACµØÖ·
    input        [31:0]  destination_ip     , //·¢ËÍµÄÄ¿±êIPµØÖ·    
    input        [31:0]  crc_data   , //CRCÐ£ÑéÊý¾Ý
    input         [7:0]  crc_next   , //CRCÏÂ´ÎÐ£ÑéÍê³ÉÊý¾Ý
    output  reg          tx_done    , //ÒÔÌ«Íø·¢ËÍÍê³ÉÐÅºÅ
    output  reg          tx_request     , //¶ÁÊý¾ÝÇëÇóÐÅºÅ
    output  reg          gmii_txen , //GMIIÊä³öÊý¾ÝÓÐÐ§ÐÅºÅ
    output  reg  [7:0]   gmii_txd   , //GMIIÊä³öÊý¾Ý
    output  reg          crc_en     , //CRC¿ªÊ¼Ð£ÑéÊ¹ÄÜ
    output  reg          crc_clear      //CRCÊý¾Ý¸´Î»ÐÅºÅ 
    );

//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10};  
//destination mac ff_ff_ff_ff_ff_ff
parameter  DEST_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//destination ip 192.168.1.100     
parameter  DEST_IP    = {8'd192,8'd168,8'd1,8'd5};  

localparam state_idle      = 7'b000_0001; //³õÊ¼×´Ì¬£¬µÈ´ý¿ªÊ¼·¢ËÍÐÅºÅ
localparam state_check_sum = 7'b000_0010; //IPÊ×²¿Ð£ÑéºÍ
localparam state_preamble  = 7'b000_0100; //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
localparam state_eth_head  = 7'b000_1000; //·¢ËÍÒÔÌ«ÍøÖ¡Í·
localparam state_ip_head   = 7'b001_0000; //·¢ËÍIPÊ×²¿+UDPÊ×²¿
localparam state_tx_data   = 7'b010_0000; //·¢ËÍÊý¾Ý
localparam state_crc       = 7'b100_0000; //·¢ËÍCRCÐ£ÑéÖµ

localparam  ETH_TYPE     = 16'h0800  ;  //ÒÔÌ«ÍøÐ­ÒéÀàÐÍ IPÐ­Òé
//ÒÔÌ«ÍøÊý¾Ý×îÐ¡46¸ö×Ö½Ú£¬IPÊ×²¿20¸ö×Ö½Ú+UDPÊ×²¿8¸ö×Ö½Ú
//ËùÒÔÊý¾ÝÖÁÉÙ46-20-8=18¸ö×Ö½Ú
localparam  MIN_DATA_NUM = 16'd18    ;    

//reg define
reg  [6:0]   cur_state      ;
reg  [6:0]   next_state     ;
                            
reg  [7:0]   preamble[7:0]  ; //Ç°µ¼Âë
reg  [7:0]   eth_head[13:0] ; //ÒÔÌ«ÍøÊ×²¿
reg  [31:0]  ip_head[6:0]   ; //IPÊ×²¿ + UDPÊ×²¿
                            
reg          start_en_d0    ;
reg          start_en_d1    ;
reg  [15:0]  tx_data_num    ; //·¢ËÍµÄÓÐÐ§Êý¾Ý×Ö½Ú¸öÊý
reg  [15:0]  total_num      ; //×Ü×Ö½ÚÊý
reg          trig_tx_en     ;
reg  [15:0]  udp_num        ; //UDP×Ö½ÚÊý
reg          skip_en        ; //¿ØÖÆ×´Ì¬Ìø×ªÊ¹ÄÜÐÅºÅ
reg  [4:0]   cnt            ;
reg  [31:0]  check_buffer   ; //Ê×²¿Ð£ÑéºÍ
reg  [1:0]   tx_bit_sel     ;
reg  [15:0]  data_cnt       ; //·¢ËÍÊý¾Ý¸öÊý¼ÆÊýÆ÷
reg          tx_done_reg      ;
reg  [4:0]   real_add_cnt   ; //ÒÔÌ«ÍøÊý¾ÝÊµ¼Ê¶à·¢µÄ×Ö½ÚÊý
                                    
//wire define                       
wire         pos_start_en    ;//¿ªÊ¼·¢ËÍÊý¾ÝÉÏÉýÑØ
wire [15:0]  real_tx_data_num;//Êµ¼Ê·¢ËÍµÄ×Ö½ÚÊý(ÒÔÌ«Íø×îÉÙ×Ö½ÚÒªÇó)

assign  pos_start_en = (~start_en_d1) & start_en_d0;
assign  real_tx_data_num = (tx_data_num >= MIN_DATA_NUM) 
                           ? tx_data_num : MIN_DATA_NUM; 
                           
//²Étx_start_enµÄÉÏÉýÑØ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        start_en_d0 <= 1'b0;
        start_en_d1 <= 1'b0;
    end    
    else begin
        start_en_d0 <= tx_start_en;
        start_en_d1 <= start_en_d0;
    end
end 

//¼Ä´æÊý¾ÝÓÐÐ§×Ö½Ú
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        tx_data_num <= 16'd0;
        total_num <= 16'd0;
        udp_num <= 16'd0;
    end
    else begin
        if(pos_start_en && cur_state==state_idle) begin
            //Êý¾Ý³¤¶È
            tx_data_num <= tx_byte_num;        
            //IP³¤¶È£ºÓÐÐ§Êý¾Ý+IPÊ×²¿³¤¶È            
            total_num <= tx_byte_num + 16'd28;  
            //UDP³¤¶È£ºÓÐÐ§Êý¾Ý+UDPÊ×²¿³¤¶È            
            udp_num <= tx_byte_num + 16'd8;               
        end    
    end
end

//´¥·¢·¢ËÍÐÅºÅ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) 
        trig_tx_en <= 1'b0;
    else
        trig_tx_en <= pos_start_en;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)cur_state <=state_idle;  
    else cur_state <= next_state;
end

always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle     : begin                               //µÈ´ý·¢ËÍÊý¾Ý
            if(skip_en)                
                next_state =state_check_sum;
            else
                next_state =state_idle;
        end  
       state_check_sum: begin                               //IPÊ×²¿Ð£Ñé
            if(skip_en)
                next_state =state_preamble;
            else
                next_state =state_check_sum;    
        end                             
       state_preamble : begin                               //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
            if(skip_en)
                next_state =state_eth_head;
            else
                next_state =state_preamble;      
        end
       state_eth_head : begin                               //·¢ËÍÒÔÌ«ÍøÊ×²¿
            if(skip_en)
                next_state =state_ip_head;
            else
                next_state =state_eth_head;      
        end              
       state_ip_head : begin                                //·¢ËÍIPÊ×²¿+UDPÊ×²¿               
            if(skip_en)
                next_state =state_tx_data;
            else
                next_state =state_ip_head;      
        end
       state_tx_data : begin                                //·¢ËÍÊý¾Ý                  
            if(skip_en)
                next_state =state_crc;
            else
                next_state =state_tx_data;      
        end
       state_crc: begin                                     //·¢ËÍCRCÐ£ÑéÖµ
            if(skip_en)
                next_state =state_idle;
            else
                next_state =state_crc;      
        end
        default : next_state =state_idle;   
    endcase
end                      

//TX DATA
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0; 
        cnt <= 5'd0;
        check_buffer <= 32'd0;
        ip_head[1][31:16] <= 16'd0;
        tx_bit_sel <= 2'b0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        gmii_txd <= 8'd0;
        tx_request <= 1'b0;
        tx_done_reg <= 1'b0; 
        data_cnt <= 16'd0;
        real_add_cnt <= 5'd0;    
        //Ç°µ¼Âë 7¸ö8'h55 + 1¸ö8'hd5
        preamble[0] <= 8'h55;                 
        preamble[1] <= 8'h55;
        preamble[2] <= 8'h55;
        preamble[3] <= 8'h55;
        preamble[4] <= 8'h55;
        preamble[5] <= 8'h55;
        preamble[6] <= 8'h55;
        preamble[7] <= 8'hd5;
        //Ä¿µÄMACµØÖ·
        eth_head[0] <= DEST_MAC[47:40];
        eth_head[1] <= DEST_MAC[39:32];
        eth_head[2] <= DEST_MAC[31:24];
        eth_head[3] <= DEST_MAC[23:16];
        eth_head[4] <= DEST_MAC[15:8];
        eth_head[5] <= DEST_MAC[7:0];
        //Ô´MACµØÖ·
        eth_head[6] <= MY_MAC[47:40];
        eth_head[7] <= MY_MAC[39:32];
        eth_head[8] <= MY_MAC[31:24];
        eth_head[9] <= MY_MAC[23:16];
        eth_head[10] <= MY_MAC[15:8];
        eth_head[11] <= MY_MAC[7:0];
        //ÒÔÌ«ÍøÀàÐÍ
        eth_head[12] <= ETH_TYPE[15:8];
        eth_head[13] <= ETH_TYPE[7:0];        
    end
    else begin
        skip_en <= 1'b0;
        tx_request <= 1'b0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        tx_done_reg <= 1'b0;
        case(next_state)
           state_idle     : begin
                if(trig_tx_en) begin
                    skip_en <= 1'b1; 
                    //°æ±¾ºÅ4 Ê×²¿³¤¶È5(µ¥Î»:32bit,20byte/4=5)
                    ip_head[0] <= {8'h45,8'h00,total_num};   
                    //16Î»±êÊ¶£¬Ã¿´Î·¢ËÍÀÛ¼Ó1      
                    ip_head[1][31:16] <= ip_head[1][31:16] + 1'b1; 
                    //bit[15:13]: 010±íÊ¾²»·ÖÆ¬
                    ip_head[1][15:0] <= 16'h4000;    
                    //Ð­Òé£º17(udp)                  
                    ip_head[2] <= {8'h40,8'd17,16'h0};   
                    //Ô´IPµØÖ·               
                    ip_head[3] <= MY_IP;
                    //Ä¿µÄIPµØÖ·    
                    if(destination_ip != 32'd0) ip_head[4] <= destination_ip;
                    else ip_head[4] <= DEST_IP;       
                    //16Î»Ô´¶Ë¿ÚºÅ£º1234  16Î»Ä¿µÄ¶Ë¿ÚºÅ£º1234                      
                    ip_head[5] <= {16'd1234,16'd1234};  
                    //16Î»udp³¤¶È£¬16Î»udpÐ£ÑéºÍ              
                    ip_head[6] <= {udp_num,16'h0000};  
                    //¸üÐÂMACµØÖ·
                    if(destination_mac != 48'b0) begin
                        //Ä¿µÄMACµØÖ·
                        eth_head[0] <= destination_mac[47:40];
                        eth_head[1] <= destination_mac[39:32];
                        eth_head[2] <= destination_mac[31:24];
                        eth_head[3] <= destination_mac[23:16];
                        eth_head[4] <= destination_mac[15:8];
                        eth_head[5] <= destination_mac[7:0];
                    end
                end    
            end                                                       
           state_check_sum: begin                           //IPÊ×²¿Ð£Ñé
                cnt <= cnt + 5'd1;
                if(cnt == 5'd0) begin                   
                    check_buffer <= ip_head[0][31:16] + ip_head[0][15:0]
                                    + ip_head[1][31:16] + ip_head[1][15:0]
                                    + ip_head[2][31:16] + ip_head[2][15:0]
                                    + ip_head[3][31:16] + ip_head[3][15:0]
                                    + ip_head[4][31:16] + ip_head[4][15:0];
                end
                else if(cnt == 5'd1)                      //¿ÉÄÜ³öÏÖ½øÎ»,ÀÛ¼ÓÒ»´Î
                    check_buffer <= check_buffer[31:16] + check_buffer[15:0];
                else if(cnt == 5'd2) begin                //¿ÉÄÜÔÙ´Î³öÏÖ½øÎ»,ÀÛ¼ÓÒ»´Î
                    check_buffer <= check_buffer[31:16] + check_buffer[15:0];
                end                             
                else if(cnt == 5'd3) begin                //°´Î»È¡·´ 
                    skip_en <= 1'b1;
                    cnt <= 5'd0;            
                    ip_head[2][15:0] <= ~check_buffer[15:0];
                end    
            end              
           state_preamble : begin                           //·¢ËÍÇ°µ¼Âë+Ö¡ÆðÊ¼½ç¶¨·û
                gmii_txen <= 1'b1;
                gmii_txd <= preamble[cnt];
                if(cnt == 5'd7) begin                        
                    skip_en <= 1'b1;
                    cnt <= 5'd0;    
                end
                else    
                    cnt <= cnt + 5'd1;                     
            end
           state_eth_head : begin                           //·¢ËÍÒÔÌ«ÍøÊ×²¿
                gmii_txen <= 1'b1;
                crc_en <= 1'b1;
                gmii_txd <= eth_head[cnt];
                if (cnt == 5'd13) begin
                    skip_en <= 1'b1;
                    cnt <= 5'd0;
                end    
                else    
                    cnt <= cnt + 5'd1;    
            end                    
           state_ip_head  : begin                           //·¢ËÍIPÊ×²¿ + UDPÊ×²¿
                crc_en <= 1'b1;
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 2'd1;
                if(tx_bit_sel == 3'd0)
                    gmii_txd <= ip_head[cnt][31:24];
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= ip_head[cnt][23:16];
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= ip_head[cnt][15:8];
                    if(cnt == 5'd6) begin
                        //ÌáÇ°¶ÁÇëÇóÊý¾Ý£¬µÈ´ýÊý¾ÝÓÐÐ§Ê±·¢ËÍ
                        tx_request <= 1'b1;                     
                    end
                end 
                else if(tx_bit_sel == 3'd3) begin
                    gmii_txd <= ip_head[cnt][7:0];  
                    if(cnt == 5'd6) begin
                        skip_en <= 1'b1;   
                        cnt <= 5'd0;
                    end    
                    else
                        cnt <= cnt + 5'd1;  
                end        
            end
           state_tx_data  : begin                           //·¢ËÍÊý¾Ý
                crc_en <= 1'b1;
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 3'd1;  
                if(data_cnt < tx_data_num - 16'd1)
                    data_cnt <= data_cnt + 16'd1;                        
                else if(data_cnt == tx_data_num - 16'd1)begin
                    //Èç¹û·¢ËÍµÄÓÐÐ§Êý¾ÝÉÙÓÚ18¸ö×Ö½Ú£¬ÔÚºóÃæÌî²¹³äÎ»
                    //²¹³äµÄÖµÎª×îºóÒ»´Î·¢ËÍµÄÓÐÐ§Êý¾Ý
                    gmii_txd <= 8'd0;
                    if(data_cnt + real_add_cnt < real_tx_data_num - 16'd1)
                        real_add_cnt <= real_add_cnt + 5'd1;  
                    else begin
                        skip_en <= 1'b1;
                        data_cnt <= 16'd0;
                        real_add_cnt <= 5'd0;
                        tx_bit_sel <= 3'd0;                        
                    end    
                end
                if(tx_bit_sel == 1'b0)
                    gmii_txd <= tx_data[31:24];
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= tx_data[23:16];                   
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= tx_data[15:8];   
                    if(data_cnt != tx_data_num - 16'd1)
                        tx_request <= 1'b1;  
                end
                else if(tx_bit_sel == 3'd3)
                    gmii_txd <= tx_data[7:0];                                                                                                
            end  
           state_crc      : begin                          //·¢ËÍCRCÐ£ÑéÖµ
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 3'd1;
                if(tx_bit_sel == 3'd0)
                    gmii_txd <= {~crc_next[0], ~crc_next[1], ~crc_next[2],~crc_next[3],
                                 ~crc_next[4], ~crc_next[5], ~crc_next[6],~crc_next[7]};
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= {~crc_data[16], ~crc_data[17], ~crc_data[18],~crc_data[19],
                                 ~crc_data[20], ~crc_data[21], ~crc_data[22],~crc_data[23]};
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= {~crc_data[8], ~crc_data[9], ~crc_data[10],~crc_data[11],
                                 ~crc_data[12], ~crc_data[13], ~crc_data[14],~crc_data[15]};                              
                end
                else if(tx_bit_sel == 3'd3) begin
                    gmii_txd <= {~crc_data[0], ~crc_data[1], ~crc_data[2],~crc_data[3],
                                 ~crc_data[4], ~crc_data[5], ~crc_data[6],~crc_data[7]};  
                    tx_done_reg <= 1'b1;
                    skip_en <= 1'b1;
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

