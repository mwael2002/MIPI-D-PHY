module Top(input logic Rstn,DDR_Clk_HS,DDR_Clk_HS_Q,Clk_LP,Tx_Request_HS,tx_request_esc,tx_lpdt,tx_ulps_esc,tx_ulps_exit,tx_valid_esc,input logic [7:0] Tx_Data_HS,
           tx_data_esc,input  logic [3:0]  tx_trigger_esc,output logic Tx_ready_HS,Tx_Byte_Clk_HS,Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS,rx_valid_esc,rx_ulps_esc,
           tx_ready_esc,output logic [7:0]  rx_data_esc,Rx_Data_HS,output logic [3:0]  rx_trigger_esc);

logic Dp,Dn;

TX Transmitter(.Tx_Rst(Rstn),.Tx_DDR_Clk_HS(DDR_Clk_HS),.Tx_Clk_LP(Clk_LP),.Tx_Request_HS(Tx_Request_HS),.Tx_Data_HS(Tx_Data_HS),.Tx_Dp(Dp),.Tx_Dn(Dn),.Tx_ready_HS(Tx_ready_HS),
.Tx_Byte_Clk_HS(Tx_Byte_Clk_HS),.tx_request_esc(tx_request_esc),.tx_lpdt(tx_lpdt),.tx_ulps_esc(tx_ulps_esc),.tx_ulps_exit(tx_ulps_exit),.tx_valid_esc(tx_valid_esc),
 .tx_data_esc(tx_data_esc),.tx_trigger_esc(tx_trigger_esc),.tx_ready_esc(tx_ready_esc));

RX Receiver(.Rx_Rst(Rstn),.Rx_DDR_Clk_Q(DDR_Clk_HS_Q),.Rx_LP_Clk(Clk_LP),.Dp(Dp),.Dn(Dn),.Rx_Byte_Clk(Rx_Byte_Clk),
            .Rx_Sync_HS(Rx_Sync_HS),.Rx_Valid_HS(Rx_Valid_HS),.Rx_Active_HS(Rx_Active_HS),.Rx_Data_HS(Rx_Data_HS),.rx_valid_esc(rx_valid_esc),.rx_ulps_esc(rx_ulps_esc),
            .rx_data_esc(rx_data_esc),.rx_trigger_esc(rx_trigger_esc));

endmodule