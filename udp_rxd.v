//UDP RX DATA module
module udp_rxd(
    input                clk         ,    //Ê±ÖÓÐÅºÅ
    input                rst_n       ,    //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§
    input                gmii_rxdv  ,    //GMIIÊäÈëÊý¾ÝÓÐÐ§ÐÅºÅ
    input        [7:0]   gmii_rxd    ,    //GMIIÊäÈëÊý¾Ý
    output  reg          rxd_pkt_done,    //ÒÔÌ«Íøµ¥°üÊý¾Ý½ÓÊÕÍê³ÉÐÅºÅ
    output  reg          rxd_wr_en      ,    //ÒÔÌ«Íø½ÓÊÕµÄÊý¾ÝÊ¹ÄÜÐÅºÅ
    output  reg  [31:0]  rxd_wr_data    ,    //ÒÔÌ«Íø½ÓÊÕµÄÊý¾Ý
    output  reg  [15:0]  rxd_wr_byte_num     //ÒÔÌ«Íø½ÓÊÕµÄÓÐÐ§×ÖÊý µ¥Î»:byte     
    );

//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;     
//board ip 192.168.1.10
parameter  MY_IP  = {8'd192,8'd168,8'd1,8'd10};  

localparam state_idle     = 7'b000_0001; //³õÊ¼×´Ì¬£¬µÈ´ý½ÓÊÕÇ°µ¼Âë
localparam state_preamble = 7'b000_0010; //½ÓÊÕÇ°µ¼Âë×´Ì¬ 
localparam state_eth_head = 7'b000_0100; //½ÓÊÕÒÔÌ«ÍøÖ¡Í·
localparam state_ip_head  = 7'b000_1000; //½ÓÊÕIPÊ×²¿
localparam state_udp_head = 7'b001_0000; //½ÓÊÕUDPÊ×²¿
localparam state_rx_data  = 7'b010_0000; //½ÓÊÕÓÐÐ§Êý¾Ý
localparam state_rx_end   = 7'b100_0000; //½ÓÊÕ½áÊø

localparam  ETH_TYPE    = 16'h0800   ; //ÒÔÌ«ÍøÐ­ÒéÀàÐÍ IPÐ­Òé

//reg define
reg  [6:0]   cur_state       ;
reg  [6:0]   next_state      ;
                             
reg          skip_en         ; //¿ØÖÆ×´Ì¬Ìø×ªÊ¹ÄÜÐÅºÅ
reg          error_en        ; //½âÎö´íÎóÊ¹ÄÜÐÅºÅ
reg  [4:0]   cnt             ; //½âÎöÊý¾Ý¼ÆÊýÆ÷
reg  [47:0]  destination_mac         ; //Ä¿µÄMACµØÖ·
reg  [15:0]  eth_type        ; //ÒÔÌ«ÍøÀàÐÍ
reg  [31:0]  destination_ip          ; //Ä¿µÄIPµØÖ·
reg  [5:0]   ip_head_byte_num; //IPÊ×²¿³¤¶È
reg  [15:0]  udp_byte_num    ; //UDP³¤¶È
reg  [15:0]  data_byte_num   ; //Êý¾Ý³¤¶È
reg  [15:0]  data_cnt        ; //ÓÐÐ§Êý¾Ý¼ÆÊý    
reg  [1:0]   rxd_wr_en_cnt      ; //8bit×ª32bit¼ÆÊýÆ÷

//(Èý¶ÎÊ½×´Ì¬»ú)Í¬²½Ê±ÐòÃèÊö×´Ì¬×ªÒÆ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)cur_state <=state_idle;  
    else cur_state <= next_state;
end

//×éºÏÂß¼­ÅÐ¶Ï×´Ì¬×ªÒÆÌõ¼þ
always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle : begin                                     //µÈ´ý½ÓÊÕÇ°µ¼Âë
            if(skip_en)  next_state =state_preamble;
            else next_state =state_idle;    
        end
       state_preamble : begin                                 //½ÓÊÕÇ°µ¼Âë
            if(skip_en)  next_state =state_eth_head;
            else if(error_en) next_state =state_rx_end;    
            else next_state =state_preamble;    
        end
       state_eth_head : begin                                 //½ÓÊÕÒÔÌ«ÍøÖ¡Í·
            if(skip_en) next_state =state_ip_head;
            else if(error_en) next_state =state_rx_end;
            else next_state =state_eth_head;           
        end  
       state_ip_head : begin                                  //½ÓÊÕIPÊ×²¿
            if(skip_en)next_state =state_udp_head;
            else if(error_en) next_state =state_rx_end;
            else next_state =state_ip_head;       
        end 
       state_udp_head : begin                                 //½ÓÊÕUDPÊ×²¿
            if(skip_en)next_state =state_rx_data;
            else next_state =state_udp_head;    
        end                
       state_rx_data : begin                                  //½ÓÊÕÓÐÐ§Êý¾Ý
            if(skip_en) next_state =state_rx_end;
            else next_state =state_rx_data;    
        end                           
       state_rx_end : begin                                   //½ÓÊÕ½áÊø
            if(skip_en)next_state =state_idle;
            else next_state =state_rx_end;          
        end
        default : next_state =state_idle;
    endcase                                          
end    

//½âÎöÊý¾Ý
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0;
        error_en <= 1'b0;
        cnt <= 5'd0;
        destination_mac <= 48'd0;
        eth_type <= 16'd0;
        destination_ip <= 32'd0;
        ip_head_byte_num <= 6'd0;
        udp_byte_num <= 16'd0;
        data_byte_num <= 16'd0;
        data_cnt <= 16'd0;
        rxd_wr_en_cnt <= 2'd0;
        rxd_wr_en <= 1'b0;
        rxd_wr_data <= 32'd0;
        rxd_pkt_done <= 1'b0;
        rxd_wr_byte_num <= 16'd0;
    end
    else begin
        skip_en <= 1'b0;
        error_en <= 1'b0;  
        rxd_wr_en <= 1'b0;
        rxd_pkt_done <= 1'b0;
        case(next_state)
           state_idle : begin
                if((gmii_rxdv == 1'b1) && (gmii_rxd == 8'h55)) 
                    skip_en <= 1'b1;
            end
           state_preamble : begin
                if(gmii_rxdv) begin                         //½âÎöÇ°µ¼Âë
                    cnt <= cnt + 5'd1;
                    if((cnt < 5'd6) && (gmii_rxd != 8'h55))  //7¸ö8'h55  
                        error_en <= 1'b1;
                    else if(cnt==5'd6) begin
                        cnt <= 5'd0;
                        if(gmii_rxd==8'hd5)                  //1¸ö8'hd5
                            skip_en <= 1'b1;
                        else
                            error_en <= 1'b1;    
                    end  
                end  
            end
           state_eth_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'b1;
                    if(cnt < 5'd6) 
                        destination_mac <= {destination_mac[39:0],gmii_rxd}; //Ä¿µÄMACµØÖ·
                    else if(cnt == 5'd12) 
                        eth_type[15:8] <= gmii_rxd;          //ÒÔÌ«ÍøÐ­ÒéÀàÐÍ
                    else if(cnt == 5'd13) begin
                        eth_type[7:0] <= gmii_rxd;
                        cnt <= 5'd0;
                        //ÅÐ¶ÏMACµØÖ·ÊÇ·ñÎª¿ª·¢°åMACµØÖ·»òÕß¹«¹²µØÖ·
                        if(((destination_mac == MY_MAC) ||(destination_mac == 48'hff_ff_ff_ff_ff_ff))
                       && eth_type[15:8] == ETH_TYPE[15:8] && gmii_rxd == ETH_TYPE[7:0])            
                            skip_en <= 1'b1;
                        else
                            error_en <= 1'b1;
                    end        
                end  
            end
           state_ip_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd0)
                        ip_head_byte_num <= {gmii_rxd[3:0],2'd0};
                    else if((cnt >= 5'd16) && (cnt <= 5'd18))
                        destination_ip <= {destination_ip[23:0],gmii_rxd};   //Ä¿µÄIPµØÖ·
                    else if(cnt == 5'd19) begin
                        destination_ip <= {destination_ip[23:0],gmii_rxd}; 
                        //ÅÐ¶ÏIPµØÖ·ÊÇ·ñÎª¿ª·¢°åIPµØÖ·
                        if((destination_ip[23:0] == MY_IP[31:8])
                            && (gmii_rxd == MY_IP[7:0])) begin  
                            if(cnt == ip_head_byte_num - 1'b1) begin
                                skip_en <=1'b1;                     
                                cnt <= 5'd0;
                            end                             
                        end    
                        else begin            
                        //IP´íÎó£¬Í£Ö¹½âÎöÊý¾Ý                        
                            error_en <= 1'b1;               
                            cnt <= 5'd0;
                        end                                                  
                    end                          
                    else if(cnt == ip_head_byte_num - 1'b1) begin 
                        skip_en <=1'b1;                      //IPÊ×²¿½âÎöÍê³É
                        cnt <= 5'd0;                    
                    end    
                end                                
            end 
           state_udp_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd4)
                        udp_byte_num[15:8] <= gmii_rxd;      //½âÎöUDP×Ö½Ú³¤¶È 
                    else if(cnt == 5'd5)
                        udp_byte_num[7:0] <= gmii_rxd;
                    else if(cnt == 5'd7) begin
                        //ÓÐÐ§Êý¾Ý×Ö½Ú³¤¶È£¬£¨UDPÊ×²¿8¸ö×Ö½Ú£¬ËùÒÔ¼õÈ¥8£©
                        data_byte_num <= udp_byte_num - 16'd8;    
                        skip_en <= 1'b1;
                        cnt <= 5'd0;
                    end  
                end                 
            end          
           state_rx_data : begin         
                //½ÓÊÕÊý¾Ý£¬×ª»»³É32bit            
                if(gmii_rxdv) begin
                    data_cnt <= data_cnt + 16'd1;
                    rxd_wr_en_cnt <= rxd_wr_en_cnt + 2'd1;
                    if(data_cnt == data_byte_num - 16'd1) begin
                        skip_en <= 1'b1;                    //ÓÐÐ§Êý¾Ý½ÓÊÕÍê³É
                        data_cnt <= 16'd0;
                        rxd_wr_en_cnt <= 2'd0;
                        rxd_pkt_done <= 1'b1;               
                        rxd_wr_en <= 1'b1;                     
                        rxd_wr_byte_num <= data_byte_num;
                    end    
                    //ÏÈÊÕµ½µÄÊý¾Ý·ÅÔÚrxd_wr_dataµÄ¸ßÎ»,µ±Êý¾Ý²»ÊÇ4µÄ±¶ÊýÊ±,
                    //µÍÎ»Êý¾ÝÎªÎÞÐ§Êý¾Ý£¬¸ù¾ÝÓÐÐ§×Ö½ÚÊýÀ´ÅÐ¶Ï(rxd_wr_byte_num)
                    if(rxd_wr_en_cnt == 2'd0)
                        rxd_wr_data[31:24] <= gmii_rxd;
                    else if(rxd_wr_en_cnt == 2'd1)
                        rxd_wr_data[23:16] <= gmii_rxd;
                    else if(rxd_wr_en_cnt == 2'd2) 
                        rxd_wr_data[15:8] <= gmii_rxd;        
                    else if(rxd_wr_en_cnt==2'd3) begin
                        rxd_wr_en <= 1'b1;
                        rxd_wr_data[7:0] <= gmii_rxd;
                    end    
                end  
            end    
           state_rx_end : begin //µ¥°üÊý¾Ý½ÓÊÕÍê³É   
                if(gmii_rxdv == 1'b0 && skip_en == 1'b0)
                    skip_en <= 1'b1; 
            end    
            default : ;
        endcase                                                        
    end
end

endmodule