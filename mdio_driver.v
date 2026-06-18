/**************************************
MDIO DRIVER
*************************************/

module mdio_driver
    (
    input                clk       , //Ê±ÖÓÐÅºÅ
    input                rst_n     , //¸´Î»ÐÅºÅ,µÍµçÆ½ÓÐÐ§
    input                mdio_triger   , //´¥·¢¿ªÊ¼ÐÅºÅ
    input                write_read  , //µÍµçÆ½Ð´£¬¸ßµçÆ½¶Á
    input        [4:0]   reg_addr   , //¼Ä´æÆ÷µØÖ·
    input        [15:0]  write_data, //Ð´Èë¼Ä´æÆ÷µÄÊý¾Ý
    output  reg          done   , //¶ÁÐ´Íê³É
    output  reg  [15:0]  read_data, //¶Á³öµÄÊý¾Ý
    output  reg          read_ack , //¶ÁÓ¦´ðÐÅºÅ 0:Ó¦´ð 1:Î´Ó¦´ð
    output  reg          divid_clk   , //Çý¶¯Ê±ÖÓ
    
    output  reg          phy_mdc   , //PHY¹ÜÀí½Ó¿ÚµÄÊ±ÖÓÐÅºÅ
    inout                phy_mdio    //PHY¹ÜÀí½Ó¿ÚµÄË«ÏòÊý¾ÝÐÅºÅ
    );
localparam  PHY_ADDR = 5'b00001;//PHYµØÖ·
localparam  CLK_DIVIDE  = 6'd10;//·ÖÆµÏµÊý


localparam state_idle    = 6'b00_0001;  //¿ÕÏÐ×´Ì¬
localparam state_pre     = 6'b00_0010;  //·¢ËÍPRE(Ç°µ¼Âë)
localparam state_start   = 6'b00_0100;  //¿ªÊ¼×´Ì¬,·¢ËÍST(¿ªÊ¼)+OP(²Ù×÷Âë)
localparam state_addr    = 6'b00_1000;  //Ð´µØÖ·,·¢ËÍPHYµØÖ·+¼Ä´æÆ÷µØÖ·
localparam state_wr_data = 6'b01_0000;  //TA+Ð´Êý¾Ý
localparam state_rd_data = 6'b10_0000;  //TA+¶ÁÊý¾Ý

//reg define
reg    [5:0]  now_state ;
reg    [5:0]  next_state;

reg    [5:0]  clk_cnt   ;  //·ÖÆµ¼ÆÊý                      
reg   [15:0]  wr_data_t ;  //»º´æÐ´¼Ä´æÆ÷µÄÊý¾Ý
reg    [4:0]  addr_t    ;  //»º´æ¼Ä´æÆ÷µØÖ·
reg    [6:0]  cnt       ;  //¼ÆÊýÆ÷
reg           state_done   ;  //×´Ì¬¿ªÊ¼Ìø×ªÐÅºÅ
reg    [1:0]  op_code   ;  //²Ù×÷Âë  2'b01(Ð´)  2'b10(¶Á)                  
reg           mdio_dir  ;  //MDIOÊý¾Ý(SDA)·½Ïò¿ØÖÆ
reg           mdio_out  ;  //MDIOÊä³öÐÅºÅ
reg   [15:0]  rd_data_reg ;  //»º´æ¶Á¼Ä´æÆ÷Êý¾Ý

//wire 
wire   [5:0]  clk_divide ; //PHY_CLKµÄ·ÖÆµÏµÊý

assign phy_mdio = mdio_dir ? mdio_out : 1'bz; //¿ØÖÆË«Ïòio·½Ïò

//·ÖÆµ·ÖÆµÏµÊý³ýÒÔ2
assign clk_divide = CLK_DIVIDE >> 1;

//·ÖÆµµÃµ½dri_clkÊ±ÖÓ
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        divid_clk <=  1'b0;
        clk_cnt <= 1'b0;
    end
    else if(clk_cnt == clk_divide[5:1] - 1'd1) begin
        clk_cnt <= 1'b0;
        divid_clk <= ~divid_clk;
    end
    else
        clk_cnt <= clk_cnt + 1'b1;
end

//²úÉúPHY_MDCÊ±ÖÓ
always @(posedge divid_clk or negedge rst_n) begin
    if(!rst_n)
        phy_mdc <= 1'b1;
    else if(cnt[0] == 1'b0)
        phy_mdc <= 1'b1;
    else    
        phy_mdc <= 1'b0;  
end

//×´Ì¬»ú
always @(posedge divid_clk or negedge rst_n) begin
    if(!rst_n)
        now_state <= state_idle;
    else
        now_state <= next_state;
end  

//×´Ì¬»ú×ª»»Ìõ¼þ
always @(*) begin
    next_state = state_idle;
    case(now_state)
        state_idle : begin
            if(mdio_triger)
                next_state = state_pre;
            else 
                next_state = state_idle;   
        end  
        state_pre : begin
            if(state_done)
                next_state = state_start;
            else
                next_state = state_pre;
        end
        state_start : begin
            if(state_done)
                next_state = state_addr;
            else
                next_state = state_start;
        end
        state_addr : begin
            if(state_done) begin
                if(op_code == 2'b01)                //MDIO½Ó¿ÚÐ´²Ù×÷  
                    next_state = state_wr_data;
                else
                    next_state = state_rd_data;        //MDIO½Ó¿Ú¶Á²Ù×÷  
            end
            else
                next_state = state_addr;
        end
        state_wr_data : begin
            if(state_done)
                next_state = state_idle;
            else
                next_state = state_wr_data;
        end        
        state_rd_data : begin
            if(state_done)
                next_state = state_idle;
            else
                next_state = state_rd_data;
        end                                                                          
        default : next_state = state_idle;
    endcase
  end

//×´Ì¬Êä³ö
always @(posedge divid_clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        cnt <= 5'd0;
        op_code <= 1'b0;
        addr_t <= 1'b0;
        wr_data_t <= 1'b0;
        rd_data_reg <= 1'b0;
        done <= 1'b0;
        state_done <= 1'b0; 
        read_data <= 1'b0;
        read_ack <= 1'b1;
        mdio_dir <= 1'b0;
        mdio_out <= 1'b1;
    end
    else begin
        state_done <= 1'b0 ;                            
        cnt     <= cnt +1'b1 ;          
        case(now_state)
            state_idle : begin
                mdio_out <= 1'b1;                     
                mdio_dir <= 1'b0;                     
                done <= 1'b0;                     
                cnt <= 7'b0;  
                if(mdio_triger) begin
                    op_code <= {write_read,~write_read}; //OP_CODE: 2'b01(Ð´)  2'b10(¶Á) 
                    addr_t <= reg_addr;
                    wr_data_t <= write_data;
                    read_ack <= 1'b1;
                end     
            end 
            state_pre : begin                          //·¢ËÍÇ°µ¼Âë:32¸ö1bit 
                mdio_dir <= 1'b1;                   //ÇÐ»»MDIOÒý½Å·½Ïò:Êä³ö
                mdio_out <= 1'b1;                   //MDIOÒý½ÅÊä³ö¸ßµçÆ½
                if(cnt == 7'd62) 
                    state_done <= 1'b1;
                else if(cnt == 7'd63)
                    cnt <= 7'b0;
            end            
            state_start  : begin
                case(cnt)
                    7'd1 : mdio_out <= 1'b0;        //·¢ËÍ¿ªÊ¼ÐÅºÅ 2'b01
                    7'd3 : mdio_out <= 1'b1; 
                    7'd5 : mdio_out <= op_code[1];  //·¢ËÍ²Ù×÷Âë
                    7'd6 : state_done <= 1'b1;
                    7'd7 : begin
                               mdio_out <= op_code[0];
                               cnt <= 7'b0;  
                           end    
                    default : ;
                endcase
            end    
            state_addr : begin
                case(cnt)
                    7'd1 : mdio_out <= PHY_ADDR[4]; //·¢ËÍPHYµØÖ·
                    7'd3 : mdio_out <= PHY_ADDR[3];
                    7'd5 : mdio_out <= PHY_ADDR[2];
                    7'd7 : mdio_out <= PHY_ADDR[1];  
                    7'd9 : mdio_out <= PHY_ADDR[0];
                    7'd11: mdio_out <= addr_t[4];  //·¢ËÍ¼Ä´æÆ÷µØÖ·
                    7'd13: mdio_out <= addr_t[3];
                    7'd15: mdio_out <= addr_t[2];
                    7'd17: mdio_out <= addr_t[1];  
                    7'd18: state_done <= 1'b1;
                    7'd19: begin
                               mdio_out <= addr_t[0]; 
                               cnt <= 7'd0;
                           end    
                    default : ;
                endcase                
            end    
            state_wr_data : begin
                case(cnt)
                    7'd1 : mdio_out <= 1'b1;         //·¢ËÍTA,Ð´²Ù×÷(2'b10)
                    7'd3 : mdio_out <= 1'b0;
                    7'd5 : mdio_out <= wr_data_t[15];//·¢ËÍÐ´¼Ä´æÆ÷Êý¾Ý
                    7'd7 : mdio_out <= wr_data_t[14];
                    7'd9 : mdio_out <= wr_data_t[13];
                    7'd11: mdio_out <= wr_data_t[12];
                    7'd13: mdio_out <= wr_data_t[11];
                    7'd15: mdio_out <= wr_data_t[10];
                    7'd17: mdio_out <= wr_data_t[9];
                    7'd19: mdio_out <= wr_data_t[8];
                    7'd21: mdio_out <= wr_data_t[7];
                    7'd23: mdio_out <= wr_data_t[6];
                    7'd25: mdio_out <= wr_data_t[5];
                    7'd27: mdio_out <= wr_data_t[4];
                    7'd29: mdio_out <= wr_data_t[3];
                    7'd31: mdio_out <= wr_data_t[2];
                    7'd33: mdio_out <= wr_data_t[1];
                    7'd35: mdio_out <= wr_data_t[0];
                    7'd37: begin
                        mdio_dir <= 1'b0;
                        mdio_out <= 1'b1;
                    end
                    7'd39: state_done <= 1'b1;           
                    7'd40: begin
                               cnt <= 7'b0;
                               done <= 1'b1;      //Ð´²Ù×÷Íê³É,À­¸ßop_doneÐÅºÅ 
                           end    
                    default : ;
                endcase    
            end
            state_rd_data : begin
                case(cnt)
                    7'd1 : begin
                        mdio_dir <= 1'b0;            //MDIOÒý½ÅÇÐ»»ÖÁÊäÈë×´Ì¬
                        mdio_out <= 1'b1;
                    end
                    7'd2 : ;                         //TA[1]Î»,¸ÃÎ»Îª¸ß×è×´Ì¬,²»²Ù×÷             
                    7'd4 : read_ack <= phy_mdio;     //TA[0]Î»,0(Ó¦´ð) 1(Î´Ó¦´ð)
                    7'd6 : rd_data_reg[15] <= phy_mdio; //½ÓÊÕ¼Ä´æÆ÷Êý¾Ý
                    7'd8 : rd_data_reg[14] <= phy_mdio;
                    7'd10: rd_data_reg[13] <= phy_mdio;
                    7'd12: rd_data_reg[12] <= phy_mdio;
                    7'd14: rd_data_reg[11] <= phy_mdio;
                    7'd16: rd_data_reg[10] <= phy_mdio;
                    7'd18: rd_data_reg[9] <= phy_mdio;
                    7'd20: rd_data_reg[8] <= phy_mdio;
                    7'd22: rd_data_reg[7] <= phy_mdio;
                    7'd24: rd_data_reg[6] <= phy_mdio;
                    7'd26: rd_data_reg[5] <= phy_mdio;
                    7'd28: rd_data_reg[4] <= phy_mdio;
                    7'd30: rd_data_reg[3] <= phy_mdio;
                    7'd32: rd_data_reg[2] <= phy_mdio;
                    7'd34: rd_data_reg[1] <= phy_mdio;
                    7'd36: rd_data_reg[0] <= phy_mdio;
                    7'd39: state_done <= 1'b1;
                    7'd40: begin
                        done <= 1'b1; //¶Á²Ù×÷Íê³É,À­¸ßop_doneÐÅºÅ          
                        read_data <= rd_data_reg;
                        rd_data_reg <= 16'd0;
                        cnt <= 7'd0;
                    end
                    default : ;
                endcase   
            end                
            default : ;
        endcase               
    end
end                    

endmodule
