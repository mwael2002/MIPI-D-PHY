`define ddr_clk_freq_ghz 0.2


`define calc_HS_settle(clk_freq_ghz) \
    $ceil(( (50.0 + 6 / (2.0 * (clk_freq_ghz))) * (clk_freq_ghz) ))



module RX(input logic Rx_Rst,Rx_DDR_Clk_Q,Rx_LP_Clk,Dp,Dn,output logic Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS,rx_valid_esc,rx_ulps_esc,
                     output logic [7:0]  rx_data_esc,Rx_Data_HS,output logic [3:0]  rx_trigger_esc);
    
    logic HS_enable,HS_start_count,Rx_end_HS,ff1, ff2,ff11, ff22;


    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= 1'b1;
            ff2 <= ff1;
        end
    end

    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            ff11 <= 1'b0;
            ff22 <= 1'b0;
        end else begin
            ff11 <= 1'b1;
            ff22 <= ff11;
        end
    end

    HS_Rx_module #(.counter_settle_width(10),.counter_settle_val(`calc_HS_settle(`ddr_clk_freq_ghz)-1),.sync_word(6'b101110)) 
    HS_RX (.Rx_Rst(ff2),.Rx_DDR_Clk_Q(Rx_DDR_Clk_Q),.HS_Dp(Dp),.HS_Dn(Dn),.HS_enable_no_sync(HS_enable),.HS_start_count_no_sync(HS_start_count),
    .Rx_Byte_Clk(Rx_Byte_Clk),.Rx_end_HS(Rx_end_HS),.Rx_Sync_HS(Rx_Sync_HS),.Rx_Valid_HS(Rx_Valid_HS),.Rx_Active_HS(Rx_Active_HS),.Rx_Data_HS(Rx_Data_HS));

    LP_Rx_module LP_RX(.Rx_Rst(ff22),.Rx_LP_Clk(Rx_LP_Clk),.LP_Dp(Dp),.LP_Dn(Dn),.Rx_end_HS_no_sync(Rx_end_HS),.HS_enable(HS_enable),.HS_start_count(HS_start_count),
    .rx_esc_active(rx_esc_active),.rx_data_esc(rx_data_esc),.rx_valid_esc(rx_valid_esc),.rx_trigger_esc(rx_trigger_esc),.rx_ulps_esc(rx_ulps_esc));

endmodule