`timescale 1ns/1ps

module tb_tx_escape;

  // Clock period 
  localparam CLK_PERIOD = 100;

  // DUT signals
  logic Rstn,DDR_Clk_HS,DDR_Clk_HS_Q,Clk_LP,Tx_Request_HS,Tx_ready_HS,Tx_Byte_Clk_HS,tx_request_esc,tx_valid_esc,tx_lpdt,tx_ulps_esc,tx_ulps_exit,tx_ready_esc;
  logic Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS,rx_valid_esc,rx_ulps_esc;
  logic [7:0]  Tx_Data_HS,tx_data_esc,rx_data_esc,Rx_Data_HS;
  logic [3:0]  rx_trigger_esc,tx_trigger_esc;

  // Instantiate DUT
  Top DUT(Rstn,DDR_Clk_HS,DDR_Clk_HS_Q,Clk_LP,Tx_Request_HS,tx_request_esc,tx_lpdt,tx_ulps_esc,tx_ulps_exit,tx_valid_esc,Tx_Data_HS,
           tx_data_esc,tx_trigger_esc,Tx_ready_HS,Tx_Byte_Clk_HS,Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS,rx_valid_esc,rx_ulps_esc,
           tx_ready_esc,rx_data_esc,Rx_Data_HS,rx_trigger_esc);

  // Clock generation: 20 MHz (50 ns period)
  initial begin
    Clk_LP = 0;
    forever #(CLK_PERIOD/2) Clk_LP = ~Clk_LP;
  end

  // Stimulus
  initial begin
    // Initialize signals
    Rstn          = 0;
    tx_request_esc = 0;
    tx_lpdt        = 0;
    tx_ulps_esc    = 0;
    tx_ulps_exit   = 0;
    tx_trigger_esc = 4'b0000;
    tx_data_esc    = 8'h00;
    tx_valid_esc   = 0;
    Tx_Request_HS  = 0;

    // Wait 2 clock cycles with reset low
    #(2*CLK_PERIOD);
    Rstn = 1; // release reset

    // Wait one clock cycle after initialization
    #(3*CLK_PERIOD);

    // Drive trigger + request
    tx_request_esc = 1;
    tx_lpdt = 1;  
    tx_valid_esc=1;
    tx_data_esc=$random;
    #(CLK_PERIOD);
    tx_lpdt=0;

    repeat(15) begin
    @(negedge tx_ready_esc);
    tx_data_esc=$random;
    end
    #(CLK_PERIOD+0.01);
    tx_valid_esc=0;
    #(20*CLK_PERIOD) tx_valid_esc=1;

    repeat(15) begin
    @(posedge tx_ready_esc);
    tx_data_esc=$random;
    end
    #(CLK_PERIOD+0.01);
    tx_valid_esc=0;
    #(16*CLK_PERIOD);
    tx_request_esc = 0;
    #(4*CLK_PERIOD);

    // TRIG TEST
    // Drive trigger + request
    tx_request_esc = 1;
    tx_trigger_esc = 4'b0100;  // Set bit 0 high

    // Hold it for 5 clock cycles
    #(25*CLK_PERIOD);

    // Deassert again
    tx_request_esc = 0;
    tx_trigger_esc = 4'b0000;

    #(2*CLK_PERIOD);

    // ULPS TEST 

    tx_request_esc = 1;
    tx_ulps_esc = 1;
    // Hold it for 25 clock cycles
    #(50*CLK_PERIOD);
    
    tx_ulps_esc = 0;
    tx_ulps_exit=1;
    #(9000*CLK_PERIOD);
    // Deassert again
    tx_request_esc = 0;
    #(1100*CLK_PERIOD);
    tx_trigger_esc = 4'b0000;

    #(5*CLK_PERIOD);

    $stop;
  end

endmodule
