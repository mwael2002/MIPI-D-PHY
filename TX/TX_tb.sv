`timescale 1ns/1ps

module TX_tb;
    
    logic Tx_Rst,Tx_DDR_Clk_HS,Tx_Byte_Clk_HS,Tx_Clk_LP,Tx_Request_HS,Tx_Dp,Tx_Dn,Tx_ready_HS,tx_request_esc;
    logic [7:0] Tx_Data_HS;

    TX DUT_TX(.Tx_Rst(Tx_Rst),.Tx_DDR_Clk_HS(Tx_DDR_Clk_HS),.Tx_Request_HS(Tx_Request_HS),.Tx_Data_HS(Tx_Data_HS),.Tx_Dp(Tx_Dp),.Tx_Dn(Tx_Dn),
    .Tx_ready_HS(Tx_ready_HS),.Tx_Clk_LP(Tx_Clk_LP),.Tx_Byte_Clk_HS(Tx_Byte_Clk_HS),.tx_request_esc(tx_request_esc));


    initial begin
      Tx_DDR_Clk_HS = 0;
      Tx_Clk_LP = 0;
    end
        // Separate always blocks for each clock
    always begin
        #2.5 Tx_DDR_Clk_HS <= ~Tx_DDR_Clk_HS;
    end

    always begin
        #50 Tx_Clk_LP <= ~Tx_Clk_LP;
    end

    initial begin
      Tx_Request_HS =0;
      Tx_Rst =0;
      Tx_Data_HS = $random;
      tx_request_esc=0;
      
      @(negedge Tx_Clk_LP);
      Tx_Rst =1;

      Tx_Request_HS=1;
      @(posedge Tx_ready_HS);
      @(posedge Tx_Byte_Clk_HS);

      repeat(21) begin
        Tx_Data_HS = $random;
        @(posedge Tx_Byte_Clk_HS);
      end
      
      @(negedge Tx_Byte_Clk_HS);  
      Tx_Request_HS=0;
      @(posedge Tx_Clk_LP);
      @(negedge Tx_Clk_LP);
      
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
      @(posedge Tx_Clk_LP);

      $stop;
    end

endmodule