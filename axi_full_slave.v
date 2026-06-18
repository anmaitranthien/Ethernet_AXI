//=============================================================================
// axi_full_slave.v
// Hien thuc day du 5 kenh: AW, W, B, AR, R + bat tay VALID/READY
// Chuc nang: cung cap 8 thanh ghi 32-bit cho PS doc/ghi qua AXI-Full.
//   reg0 (offset 0x00): PS ghi du lieu can gui (4 ky tu/word)
//   reg1 (offset 0x04): PS ghi lenh - bit0 = start gui
//   reg2 (offset 0x08): PL ghi trang thai - bit0 = da nhan xong
//   reg3 (offset 0x0C): PL ghi du lieu nhan duoc tu Ethernet
//   reg4..reg7        : du phong / mo rong
//
// Burst duoc ho tro qua con tro dia chi tang dan theo AWLEN/ARLEN.
//=============================================================================
module axi_full_slave #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6   // 2^6 = 64 byte = 16 thanh ghi
)
(
    // ----- Tin hieu nguoi dung (noi voi khoi Ethernet) -----
    output wire [31:0] tx_data_reg,   // du lieu PS muon gui (reg0)
    output wire        tx_start,      // lenh bat dau gui (reg1 bit0)
    input  wire [31:0] rx_data_in,    // du lieu nhan tu Ethernet
    input  wire        rx_done_in,    // bao da nhan xong

    // ----- Tin hieu AXI4-Full chuan -----
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,
    // Kenh dia chi ghi (AW)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [7:0]                    S_AXI_AWLEN,
    input  wire [2:0]                    S_AXI_AWSIZE,
    input  wire [1:0]                    S_AXI_AWBURST,
    input  wire                          S_AXI_AWVALID,
    output reg                           S_AXI_AWREADY,
    // Kenh du lieu ghi (W)
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WLAST,
    input  wire                          S_AXI_WVALID,
    output reg                           S_AXI_WREADY,
    // Kenh phan hoi ghi (B)
    output reg  [1:0]                    S_AXI_BRESP,
    output reg                           S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,
    // Kenh dia chi doc (AR)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [7:0]                    S_AXI_ARLEN,
    input  wire [2:0]                    S_AXI_ARSIZE,
    input  wire [1:0]                    S_AXI_ARBURST,
    input  wire                          S_AXI_ARVALID,
    output reg                           S_AXI_ARREADY,
    // Kenh du lieu doc (R)
    output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg  [1:0]                    S_AXI_RRESP,
    output reg                           S_AXI_RLAST,
    output reg                           S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    // 8 thanh ghi 32-bit
    reg [31:0] slv_reg [0:7];
    integer i;

    // Con tro dia chi cho burst
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
    reg [7:0] awlen_cnt;
    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;
    reg [7:0] arlen_cnt;
    reg write_active;
    reg read_active;

    // Chi so thanh ghi tu dia chi (chia 4 vi moi reg 4 byte)
    wire [2:0] aw_index = awaddr_reg[4:2];
    wire [2:0] ar_index = araddr_reg[4:2];

    //=========================================================================
    // KENH GHI: AW (dia chi) + W (du lieu) + B (phan hoi)
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            write_active  <= 1'b0;
            awlen_cnt     <= 8'd0;
            for (i=0;i<8;i=i+1) slv_reg[i] <= 32'd0;
            // rx_done se tu PL ghi vao reg2/reg3 ben duoi
        end else begin
            // --- Buoc 1: nhan dia chi ghi ---
            if (S_AXI_AWVALID && ~S_AXI_AWREADY && ~write_active) begin
                S_AXI_AWREADY <= 1'b1;
                awaddr_reg    <= S_AXI_AWADDR;
                awlen_cnt     <= S_AXI_AWLEN;   // so nhip burst - 1
                write_active  <= 1'b1;
                S_AXI_WREADY  <= 1'b1;          // san sang nhan du lieu
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // --- Buoc 2: nhan du lieu ghi (co the nhieu nhip - burst) ---
            if (write_active && S_AXI_WVALID && S_AXI_WREADY) begin
                // ghi vao thanh ghi tuong ung (chi cho ghi reg0..reg1, reg4..reg7)
                if (aw_index != 3'd2 && aw_index != 3'd3)
                    slv_reg[aw_index] <= S_AXI_WDATA;
                if (S_AXI_WLAST) begin
                    S_AXI_WREADY <= 1'b0;
                    write_active <= 1'b0;
                    S_AXI_BVALID <= 1'b1;       // phat phan hoi
                    S_AXI_BRESP  <= 2'b00;       // OKAY
                end else begin
                    awaddr_reg <= awaddr_reg + 3'd4; // tang dia chi cho burst
                end
            end

            // --- Buoc 3: hoan tat phan hoi B ---
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // --- PL ghi du lieu nhan duoc vao reg2/reg3 ---
            if (rx_done_in) begin
                slv_reg[3] <= rx_data_in;   // du lieu nhan
                slv_reg[2] <= 32'd1;        // co bao da nhan xong
            end
        end
    end

    //=========================================================================
    // KENH DOC: AR (dia chi) + R (du lieu)
    //=========================================================================
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RLAST   <= 1'b0;
            S_AXI_RDATA   <= 32'd0;
            read_active   <= 1'b0;
            arlen_cnt     <= 8'd0;
        end else begin
            // --- Buoc 1: nhan dia chi doc ---
            if (S_AXI_ARVALID && ~S_AXI_ARREADY && ~read_active) begin
                S_AXI_ARREADY <= 1'b1;
                araddr_reg    <= S_AXI_ARADDR;
                arlen_cnt     <= S_AXI_ARLEN;
                read_active   <= 1'b1;
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end

            // --- Buoc 2: phat du lieu doc (co the nhieu nhip - burst) ---
            if (read_active && ~S_AXI_RVALID) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RDATA  <= slv_reg[ar_index];
                S_AXI_RRESP  <= 2'b00;          // OKAY
                S_AXI_RLAST  <= (arlen_cnt == 8'd0);
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                if (arlen_cnt == 8'd0) begin
                    S_AXI_RVALID <= 1'b0;
                    S_AXI_RLAST  <= 1'b0;
                    read_active  <= 1'b0;
                end else begin
                    arlen_cnt   <= arlen_cnt - 8'd1;
                    araddr_reg  <= araddr_reg + 3'd4;
                    S_AXI_RDATA <= slv_reg[ar_index + 3'd1];
                    S_AXI_RLAST <= (arlen_cnt == 8'd1);
                end
            end
        end
    end

    //=========================================================================
    // Xuat tin hieu nguoi dung
    //=========================================================================
    assign tx_data_reg = slv_reg[0];   // du lieu PS muon gui
    assign tx_start    = slv_reg[1][0]; // bit0 cua reg1 = lenh gui

endmodule
