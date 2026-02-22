`timescale 1ns/1ps

module HS_tb;
    
  logic Rstn,DDR_Clk_HS,DDR_Clk_HS_Q,Tx_Byte_Clk_HS,Clk_LP,Tx_Request_HS,Tx_ready_HS,Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS;
  logic [7:0] Tx_Data_HS,Rx_Data_HS;

  Top DUT (
      .Rstn          (Rstn),
      .DDR_Clk_HS    (DDR_Clk_HS),
      .DDR_Clk_HS_Q  (DDR_Clk_HS_Q),
      .Clk_LP        (Clk_LP),
      .Tx_Request_HS (Tx_Request_HS),
      .Tx_Data_HS    (Tx_Data_HS),
      .Tx_ready_HS   (Tx_ready_HS),
      .Tx_Byte_Clk_HS(Tx_Byte_Clk_HS),
      .Rx_Byte_Clk   (Rx_Byte_Clk),
      .Rx_Sync_HS    (Rx_Sync_HS),
      .Rx_Valid_HS   (Rx_Valid_HS),
      .Rx_Active_HS  (Rx_Active_HS),
      .Rx_Data_HS    (Rx_Data_HS)
  );

    initial begin
      DDR_Clk_HS = 0;
      DDR_Clk_HS_Q=0;
      Clk_LP = 0;
    end
        // Separate always blocks for each clock
    always begin
        #2.5 DDR_Clk_HS = ~DDR_Clk_HS;
    end

    always begin
        #50 Clk_LP = ~Clk_LP;
    end

    always@(*) begin
      DDR_Clk_HS_Q = #1.25 DDR_Clk_HS;
    end


    initial begin
      Tx_Request_HS =0;
      Rstn =0;
      Tx_Data_HS = $random;
    
      @(negedge Clk_LP);
      Rstn =1;

      repeat (2)
      @(negedge Clk_LP);

      Tx_Request_HS=1;
      @(posedge Tx_ready_HS);
      @(posedge Tx_Byte_Clk_HS);

      repeat(21) begin
        Tx_Data_HS = $random;
        @(posedge Tx_Byte_Clk_HS);
      end
      
      @(negedge Tx_Byte_Clk_HS);  
      Tx_Request_HS=0;
      repeat(4)
      @(negedge Clk_LP);
      
      Tx_Request_HS=1;
      Tx_Data_HS = $random;
      @(posedge Tx_ready_HS);
      @(posedge Tx_Byte_Clk_HS);

      repeat(15) begin
        Tx_Data_HS = $random;
        @(posedge Tx_Byte_Clk_HS);
      end
      @(negedge Tx_Byte_Clk_HS); 
      Tx_Request_HS=0;
      repeat(2)
      @(posedge Clk_LP);

      $stop;
    end

endmodule