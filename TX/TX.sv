`define ddr_clk_freq_ghz 0.2
`define lp_clk_freq_ghz 0.01
`define n        1

`define calc_HS_prepare(clk_freq_ghz) \
int'(( (40.0 + 4 / (2.0 * (clk_freq_ghz))) * (clk_freq_ghz) )+0.49999)

`define calc_HS_zeros(ddr_clk_freq_ghz) \
int'(( (155.0 + 10.0 / (2.0 * (ddr_clk_freq_ghz)) - ((`calc_HS_prepare(ddr_clk_freq_ghz)) / (ddr_clk_freq_ghz))) * (ddr_clk_freq_ghz) )+0.49999)

`define calc_HS_trail(n, ddr_clk_freq_ghz) \
    (((((n) * 8) / (2.0 * (ddr_clk_freq_ghz))) >= (60.0 + ((n) * 4.0) / (2.0 * (ddr_clk_freq_ghz)))) ? \
        int'(((n) * 8 / (2.0 * (ddr_clk_freq_ghz))) * (ddr_clk_freq_ghz)) : \
     int'(((60.0 + ((n) * 4.0 / (2.0 * (ddr_clk_freq_ghz)))) * (ddr_clk_freq_ghz))+0.49999))
     
`define calc_ULPS_EXIT(clk_freq_ghz) \
    int'(clk_freq_ghz*1000000)


module TX(input logic Tx_Rst,Tx_DDR_Clk_HS,Tx_Clk_LP,Tx_Request_HS,tx_request_esc,tx_lpdt,tx_ulps_esc,tx_ulps_exit,tx_valid_esc,
          input  logic [3:0]  tx_trigger_esc,input logic [7:0] Tx_Data_HS,tx_data_esc,output logic Tx_Dp,Tx_Dn,Tx_ready_HS,Tx_Byte_Clk_HS,tx_ready_esc);

        logic LP_Tx_Dp,LP_Tx_Dn,HS_Tx_Dp,HS_Tx_Dn,Tx_enable_HS,Tx_end_HS,ff1, ff2;

    // Use asynchronous reset in sensitivity list
    always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
        if (!Tx_Rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= 1'b1;
            ff2 <= ff1;
        end
    end

        LP_Tx_module #(.counter_LP01_value(0),.counter_LP01_length(2),.counter_LP00_value(`calc_HS_prepare(`lp_clk_freq_ghz)-1),.counter_LP00_length(10),
                       .ulps_exit_counter_val(`calc_ULPS_EXIT(`lp_clk_freq_ghz)),.ulps_exit_counter_width(16))
                      LP_TX (.Tx_Rst(ff2),.Tx_Clk_LP(Tx_Clk_LP),.Tx_Request_HS(Tx_Request_HS),.Tx_end_HS(Tx_end_HS),.Dp(LP_Tx_Dp),.Dn(LP_Tx_Dn),.HS_enable(Tx_enable_HS),
                             .tx_request_esc(tx_request_esc),.tx_lpdt(tx_lpdt),.tx_ulps_esc(tx_ulps_esc),.tx_ulps_exit(tx_ulps_exit),.tx_valid_esc(tx_valid_esc),
                             .tx_trigger_esc(tx_trigger_esc),.tx_data_esc(tx_data_esc),.tx_ready_esc(tx_ready_esc));

        HS_Tx_module #(.Data_length(8),.counter_serial_width(2),.sync_word(8'b10111000),.counter_zeros_width(10),.counter_zeros_val(`calc_HS_zeros(`ddr_clk_freq_ghz)-1),
        .counter_trail_width(10),.counter_trail_val(`calc_HS_trail(`n,`ddr_clk_freq_ghz)-1))
        HS_TX (Tx_Request_HS,ff2,Tx_DDR_Clk_HS,Tx_enable_HS,Tx_Data_HS,HS_Tx_Dp,HS_Tx_Dn,Tx_ready_HS,Tx_end_HS,Tx_Byte_Clk_HS);


        always_comb begin
            if (Tx_enable_HS) begin
                Tx_Dp=HS_Tx_Dp;
                Tx_Dn=HS_Tx_Dn;
            end else begin
                Tx_Dp=LP_Tx_Dp;
                Tx_Dn=LP_Tx_Dn;
            end
        end

endmodule

