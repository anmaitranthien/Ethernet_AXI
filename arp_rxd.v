//arp rxd module
module arp_rxd
   (
    input                clk        , // 
    input                rst_n      , //¸´Î»ÐÅºÅ£¬µÍµçÆ½ÓÐÐ§                                  
    input                gmii_rxdv , //GMIIÊäÈëÊý¾ÝÓÐÐ§ÐÅºÅ
    input        [7:0]   gmii_rxd   , //GMIIÊäÈëÊý¾Ý
    output  reg          arp_rx_done, //ARP½ÓÊÕÍê³ÉÐÅºÅ
    output  reg          arp_rx_type, //ARP½ÓÊÕÀàÐÍ 0:ÇëÇó  1:Ó¦´ð
    output  reg  [47:0]  source_mac    , //½ÓÊÕµ½µÄÔ´MACµØÖ·
    output  reg  [31:0]  source_ip       //½ÓÊÕµ½µÄÔ´IPµØÖ·
    );
    
//board mac 
parameter  MY_MAC = 48'h12_34_56_78_90_ab;
//board ip 192.168.1.10
parameter MY_IP = {8'd192,8'd168,8'd1,8'd10};     
//parameter define
localparam state_idle     = 5'b0_0001; //³õÊ¼×´Ì¬£¬µÈ´ý½ÓÊÕÇ°µ¼Âë
localparam state_preamble = 5'b0_0010; //½ÓÊÕÇ°µ¼Âë×´Ì¬ 
localparam state_eth_head = 5'b0_0100; //½ÓÊÕÒÔÌ«ÍøÖ¡Í·
localparam state_arp_data = 5'b0_1000; //½ÓÊÕARPÊý¾Ý
localparam state_rx_end   = 5'b1_0000; //½ÓÊÕ½áÊø

localparam  ETH_TPYE = 16'h0806;     //ÒÔÌ«ÍøÖ¡ÀàÐÍ ARP

//reg define
reg    [4:0]   cur_state ;
reg    [4:0]   next_state;
                         
reg            skip_en   ; //¿ØÖÆ×´Ì¬Ìø×ªÊ¹ÄÜÐÅºÅ
reg            error_en  ; //½âÎö´íÎóÊ¹ÄÜÐÅºÅ
reg    [4:0]   cnt       ; //½âÎöÊý¾Ý¼ÆÊýÆ÷
reg    [47:0]  destination_mac_t ; //½ÓÊÕµ½µÄÄ¿µÄMACµØÖ·
reg    [31:0]  destination_ip_t  ; //½ÓÊÕµ½µÄÄ¿µÄIPµØÖ·
reg    [47:0]  source_mac_t ; //½ÓÊÕµ½µÄÔ´MACµØÖ·
reg    [31:0]  source_ip_t  ; //½ÓÊÕµ½µÄÔ´IPµØÖ·
reg    [15:0]  eth_type  ; //ÒÔÌ«ÍøÀàÐÍ
reg    [15:0]  op_data   ; //²Ù×÷Âë

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
       state_idle : begin                     //µÈ´ý½ÓÊÕÇ°µ¼Âë
            if(skip_en)next_state =state_preamble;
            else next_state =state_idle;    
        end
       state_preamble : begin                 //½ÓÊÕÇ°µ¼Âë
            if(skip_en) next_state =state_eth_head;
            else if(error_en)next_state =state_rx_end;    
            else next_state =state_preamble;   
        end
       state_eth_head : begin                 //½ÓÊÕÒÔÌ«ÍøÖ¡Í·
            if(skip_en)next_state =state_arp_data;
            else if(error_en)next_state =state_rx_end;
            else next_state =state_eth_head;   
        end  
       state_arp_data : begin                  //½ÓÊÕARPÊý¾Ý
            if(skip_en)next_state =state_rx_end;
            else if(error_en)next_state =state_rx_end;
            else next_state =state_arp_data;   
        end                  
       state_rx_end : begin                   //½ÓÊÕ½áÊø
            if(skip_en)next_state =state_idle;
            else next_state =state_rx_end;          
        end
        default : next_state =state_idle;
    endcase                                          
end    

//Ê±ÐòµçÂ·ÃèÊö×´Ì¬Êä³ö,½âÎöÒÔÌ«ÍøÊý¾Ý
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0;
        error_en <= 1'b0;
        cnt <= 5'd0;
        destination_mac_t <= 48'd0;
        destination_ip_t <= 32'd0;
        source_mac_t <= 48'd0;
        source_ip_t <= 32'd0;        
        eth_type <= 16'd0;
        op_data <= 16'd0;
        arp_rx_done <= 1'b0;
        arp_rx_type <= 1'b0;
        source_mac <= 48'd0;
        source_ip <= 32'd0;
    end
    else begin
        skip_en <= 1'b0;
        error_en <= 1'b0;  
        arp_rx_done <= 1'b0;
        case(next_state)
           state_idle : begin                                  //¼ì²âµ½µÚÒ»¸ö8'h55
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
                        destination_mac_t <= {destination_mac_t[39:0],gmii_rxd};
                    else if(cnt == 5'd6) begin
                        //ÅÐ¶ÏMACµØÖ·ÊÇ·ñÎª¿ª·¢°åMACµØÖ·»òÕß¹«¹²µØÖ·
                        if((destination_mac_t != MY_MAC)
                            && (destination_mac_t != 48'hff_ff_ff_ff_ff_ff))           
                            error_en <= 1'b1;
                    end
                    else if(cnt == 5'd12) 
                        eth_type[15:8] <= gmii_rxd;          //ÒÔÌ«ÍøÐ­ÒéÀàÐÍ
                    else if(cnt == 5'd13) begin
                        eth_type[7:0] <= gmii_rxd;
                        cnt <= 5'd0;
                        if(eth_type[15:8] == ETH_TPYE[15:8]  //ÅÐ¶ÏÊÇ·ñÎªARPÐ­Òé
                            && gmii_rxd == ETH_TPYE[7:0])
                            skip_en <= 1'b1; 
                        else
                            error_en <= 1'b1;                       
                    end        
                end  
            end
           state_arp_data : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd6) 
                        op_data[15:8] <= gmii_rxd;           //²Ù×÷Âë       
                    else if(cnt == 5'd7)
                        op_data[7:0] <= gmii_rxd;
                    else if(cnt >= 5'd8 && cnt < 5'd14)      //Ô´MACµØÖ·
                        source_mac_t <= {source_mac_t[39:0],gmii_rxd};
                    else if(cnt >= 5'd14 && cnt < 5'd18)     //Ô´IPµØÖ·
                        source_ip_t<= {source_ip_t[23:0],gmii_rxd};
                    else if(cnt >= 5'd24 && cnt < 5'd28)     //Ä¿±êIPµØÖ·
                        destination_ip_t <= {destination_ip_t[23:0],gmii_rxd};
                    else if(cnt == 5'd28) begin
                        cnt <= 5'd0;
                        if(destination_ip_t == MY_IP) begin       //ÅÐ¶ÏÄ¿µÄIPµØÖ·ºÍ²Ù×÷Âë
                            if((op_data == 16'd1) || (op_data == 16'd2)) begin
                                skip_en <= 1'b1;
                                arp_rx_done <= 1'b1;
                                source_mac <= source_mac_t;
                                source_ip <= source_ip_t;
                                source_mac_t <= 48'd0;
                                source_ip_t <= 32'd0;
                                destination_mac_t <= 48'd0;
                                destination_ip_t <= 32'd0;
                                if(op_data == 16'd1)         
                                    arp_rx_type <= 1'b0;     //ARP request
                                else
                                    arp_rx_type <= 1'b1;     //ARP ack
                            end
                            else
                                error_en <= 1'b1;
                        end 
                        else
                            error_en <= 1'b1;
                    end
                end                                
            end
           state_rx_end : begin     
                cnt <= 5'd0;
                //rx one packet done  
                if(gmii_rxdv == 1'b0 && skip_en == 1'b0)
                    skip_en <= 1'b1; 
            end    
            default : ;
        endcase                                                        
    end
end

endmodule