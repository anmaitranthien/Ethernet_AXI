/*****************************************************************************
 * main.c  -  Chuong trinh C chay tren ARM (PS) cua Zynq
 *
 * Chuc nang: PS doc du lieu Ethernet nhan duoc thong qua bus AXI-Full,
 *            tu khoi top_axi_eth (axi_full_slave) tren PL, roi in ra UART.
 *
 * Ban do thanh ghi (offset tu BASE):
 *   reg0 (0x00): du lieu gui (huong nay chua dung)
 *   reg1 (0x04): lenh (chua dung)
 *   reg2 (0x08): co bao da nhan xong (PL ghi 1 khi co du lieu moi)
 *   reg3 (0x0C): du lieu nhan duoc tu Ethernet (4 byte/word)
 *
 * LUU Y: Kiem tra dia chi BASE trong Vivado -> Address Editor.
 *        Neu khac 0x43C00000 thi sua o dong #define duoi.
 *****************************************************************************/

#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

/* === SUA DIA CHI NAY cho khop Address Editor cua ban === */
/* Cach 1: dung truc tiep dia chi (an toan neu khong chac ten macro) */
#define ETH_AXI_BASE   0x43C00000

/* Cach 2 (tot hon): neu xparameters.h co dinh nghia, dung macro do.
 * Mo xparameters.h tim dong kieu XPAR_TOP_AXI_ETH_0_S_AXI_BASEADDR
 * roi thay vao duoi. Vi du:
 * #define ETH_AXI_BASE  XPAR_TOP_AXI_ETH_0_S_AXI_BASEADDR
 */

/* Offset cac thanh ghi */
#define REG0_TXDATA    0x00
#define REG1_CMD       0x04
#define REG2_RXDONE    0x08
#define REG3_RXDATA    0x0C

/* In 1 word 32-bit duoi dang 4 ky tu ASCII */
void print_word_as_chars(u32 data)
{
    /* du lieu xep big-endian: byte cao nhat la ky tu dau */
    char c0 = (char)((data >> 24) & 0xFF);
    char c1 = (char)((data >> 16) & 0xFF);
    char c2 = (char)((data >> 8)  & 0xFF);
    char c3 = (char)((data >> 0)  & 0xFF);

    xil_printf("Du lieu nhan (hex): 0x%08X\r\n", data);
    xil_printf("Du lieu nhan (ky tu): ");
    /* chi in ky tu in duoc (32..126) */
    if (c0 >= 32 && c0 < 127) xil_printf("%c", c0);
    if (c1 >= 32 && c1 < 127) xil_printf("%c", c1);
    if (c2 >= 32 && c2 < 127) xil_printf("%c", c2);
    if (c3 >= 32 && c3 < 127) xil_printf("%c", c3);
    xil_printf("\r\n");
}

int main()
{
    u32 rx_done;
    u32 rx_data;
    u32 last_data = 0;

    xil_printf("\r\n=================================================\r\n");
    xil_printf(" PS doc du lieu Ethernet qua AXI-Full\r\n");
    xil_printf(" Cho du lieu tu PC gui xuong board...\r\n");
    xil_printf("=================================================\r\n");

    /* Doc thu thanh ghi 1 lan de kiem tra ket noi AXI */
    rx_data = Xil_In32(ETH_AXI_BASE + REG3_RXDATA);
    xil_printf("Gia tri reg3 ban dau: 0x%08X\r\n", rx_data);

    while (1)
    {
        /* Doc co bao nhan xong (reg2) */
        rx_done = Xil_In32(ETH_AXI_BASE + REG2_RXDONE);

        if (rx_done & 0x1)
        {
            /* Co du lieu moi -> doc reg3 */
            rx_data = Xil_In32(ETH_AXI_BASE + REG3_RXDATA);

            /* Chi in khi du lieu thay doi (tranh in lap lien tuc) */
            if (rx_data != last_data)
            {
                xil_printf("\r\n--- Co du lieu Ethernet moi ---\r\n");
                print_word_as_chars(rx_data);
                last_data = rx_data;
            }
        }

        usleep(100000); /* nghi 100ms cho do tran man hinh */
    }

    return 0;
}
