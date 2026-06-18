/*********************************
MDIO SIMPLE READ WRITE
GET LINK STATE
******************************/
module mdio_read_write(
    input                clk           ,
    input                rst_n         ,
    input                rst_trig , //Èí¸´Î»´¥·¢ÐÅºÅ
    input                done       , //¶ÁÐ´Íê³É
    input        [15:0]  read_data    , //¶Á³öµÄÊý¾Ý
    input                read_ack     , //¶ÁÓ¦´ðÐÅºÅ 0:Ó¦´ð 1:Î´Ó¦´ð
    output  reg          mdio_triger       , //´¥·¢¿ªÊ¼ÐÅºÅ
    output  reg          write_read      , //µÍµçÆ½Ð´£¬¸ßµçÆ½¶Á
    output  reg  [4:0]   reg_addr       , //¼Ä´æÆ÷µØÖ·
    output  reg  [15:0]  write_data    , //Ð´Èë¼Ä´æÆ÷µÄÊý¾Ý
    output       [1:0]   state_led             //LEDµÆÖ¸Ê¾ÒÔÌ«ÍøÁ¬½Ó×´Ì¬
    );

parameter SOFT_RESET_CMD=16'hB100;
parameter REG_BMCR=5'h00;
parameter REG_BMSR=5'h01;
parameter REG_PHYSR=5'h11;
//reg define
reg          rst_trig_d0;    
reg          rst_trig_d1;    
(*mark_debug="true"*)reg          rst_trig_flag;   //soft_rst_trigÐÅºÅ´¥·¢±êÖ¾
(*mark_debug="true"*)reg  [23:0]  timer_cnt;       //¶¨Ê±¼ÆÊýÆ÷ 
reg          timer_done;      //¶¨Ê±Íê³ÉÐÅºÅ
reg          start_next;      //¿ªÊ¼¶ÁÏÂÒ»¸ö¼Ä´æÆ÷±êÖÂ
(*mark_debug="true"*)reg          read_next;       //´¦ÓÚ¶ÁÏÂÒ»¸ö¼Ä´æÆ÷µÄ¹ý³Ì
(*mark_debug="true"*)reg          link_error;      //Á´Â·¶Ï¿ª»òÕß×ÔÐ­ÉÌÎ´Íê³É
(*mark_debug="true"*)reg  [2:0]   flow_cnt;        //Á÷³Ì¿ØÖÆ¼ÆÊýÆ÷ 
(*mark_debug="true"*)reg  [1:0]   speed_status;    //Á¬½ÓËÙÂÊ 
//wire define
wire         pos_rst_trig;    //rst_trig posedge
//rst_trig  posedge
assign pos_rst_trig = ~rst_trig_d1 & rst_trig_d0;
//Î´Á¬½Ó»òÁ¬½ÓÊ§°ÜÊ±led¸³Öµ00
// 01:10Mbps  10:100Mbps  11:1000Mbps 00£ºÆäËûÇé¿ö
assign state_led = link_error ? 2'b00: speed_status;
//¸´Î»´òÁ½ÅÄ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        rst_trig_d0 <= 1'b0;
        rst_trig_d1 <= 1'b0;
    end
    else begin
        rst_trig_d0 <= rst_trig;
        rst_trig_d1 <= rst_trig_d0;
    end
end

//counter
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        timer_cnt <= 1'b0;
        timer_done <= 1'b0;
    end
    else begin
        if(timer_cnt == 24'd1_000_000 - 1'b1) begin
            timer_done <= 1'b1;
            timer_cnt <= 1'b0;
        end
        else begin
            timer_done <= 1'b0;
            timer_cnt <= timer_cnt + 1'b1;
        end
    end
end    

//¸´Î»PHY²¢ÇÒ¶¨Ê±¶ÁÈ¡×´Ì¬
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        flow_cnt <= 3'd0;
        rst_trig_flag <= 1'b0;
        speed_status <= 2'b00;
        mdio_triger <= 1'b0; 
        write_read <= 1'b0; 
        reg_addr <= 1'b0;       
        write_data <= 1'b0; 
        start_next <= 1'b0; 
        read_next <= 1'b0; 
        link_error <= 1'b0;
    end
    else begin
        mdio_triger <= 1'b0; 
        if(pos_rst_trig)                      
            rst_trig_flag <= 1'b1;             //À­¸ßÈí¸´Î»´¥·¢±êÖ¾
        case(flow_cnt)
            2'd0 : begin
                if(rst_trig_flag) begin        //softreset mdio module
                    mdio_triger <= 1'b1; 
                    write_read <= 1'b0; 
                    reg_addr <=REG_BMCR; 
                    write_data <= SOFT_RESET_CMD;    //Bit[15]=1'b1,±íÊ¾Èí¸´Î»
                    flow_cnt <= 3'd1;
                end
                else if(timer_done) begin      //¶¨Ê±Íê³É,»ñÈ¡ÒÔÌ«ÍøÁ¬½Ó×´Ì¬
                    mdio_triger <= 1'b1; 
                    write_read <= 1'b1; 
                    reg_addr <= REG_BMSR; 
                    flow_cnt <= 3'd2;
                end
                else if(start_next) begin       //»ñÈ¡ÒÔÌ«ÍøÍ¨ÐÅËÙ¶È
                    mdio_triger <= 1'b1; 
                    write_read <= 1'b1; 
                    reg_addr <= REG_PHYSR; 
                    flow_cnt <= 3'd2;
                    start_next <= 1'b0; 
                    read_next <= 1'b1; 
                end
            end    
            2'd1 : begin
                if(done) begin              //MDIO½Ó¿ÚÈí¸´Î»Íê³É
                    flow_cnt <= 3'd0;
                    rst_trig_flag <= 1'b0;
                end
            end
            2'd2 : begin                       
                if(done) begin              //MDIO½Ó¿Ú¶Á²Ù×÷Íê³É
                    if(read_ack == 1'b0 && read_next == 1'b0) //¶ÁµÚÒ»¸ö¼Ä´æÆ÷
                        flow_cnt <= 3'd3;                      //¶ÁµÚÏÂÒ»¸ö¼Ä´æÆ÷
                    else if(read_ack == 1'b0 && read_next == 1'b1)begin 
                        read_next <= 1'b0;
                        flow_cnt <= 3'd4;
                    end
                    else begin
                        flow_cnt <= 3'd0;
                     end
                end    
            end
            2'd3 : begin                     
                flow_cnt <= 3'd0;          //Á´Â·Á¬½ÓÍê³ÉÇÒ×ÔÐ­ÉÌÍê³É
                if(read_data[5] == 1'b1 && read_data[2] == 1'b1)begin
                    start_next <= 1;
                    link_error <= 0;
                end
                else begin
                    link_error <= 1'b1;  
               end           
            end
            3'd4: begin
                flow_cnt <= 3'd0;
                if(read_data[15:14] == 2'b10)
                    speed_status <= 2'b11; //1000Mbps
                else if(read_data[15:14] == 2'b01) 
                    speed_status <= 2'b10; //100Mbps 
                else if(read_data[15:14] == 2'b00) 
                    speed_status <= 2'b01; //10Mbps
                else
                    speed_status <= 2'b00; //erro
            end
        endcase
    end    
end    
    
endmodule
