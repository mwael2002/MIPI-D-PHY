`timescale 1ns/1ps

class data_in;
  rand logic [7:0] b;

endclass

module RX_tb;
    
    logic Rx_Rst,Rx_DDR_Clk_Q,Rx_LP_Clk,Dp,Dn,Rx_Byte_Clk,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS;
    logic [7:0] Rx_Data_HS;
    data_in val;
    RX DUT (
        .Rx_Rst       (Rx_Rst),
        .Rx_DDR_Clk_Q   (Rx_DDR_Clk_Q),
        .Rx_LP_Clk    (Rx_LP_Clk),
        .Dp           (Dp),
        .Dn           (Dn),
        .Rx_Byte_Clk  (Rx_Byte_Clk),
        .Rx_Sync_HS   (Rx_Sync_HS),
        .Rx_Valid_HS  (Rx_Valid_HS),
        .Rx_Active_HS (Rx_Active_HS),
        .Rx_Data_HS   (Rx_Data_HS)
    );


    initial begin
      Rx_DDR_Clk_Q = 0;
      Rx_LP_Clk = 0;
    
    end
        // Separate always blocks for each clock
    always begin
        #2.5 Rx_DDR_Clk_Q = ~Rx_DDR_Clk_Q;
    end

    always begin
        #50 Rx_LP_Clk = ~Rx_LP_Clk;
    end

    initial begin
    val=new();
    Rx_Rst=0;
    Dp=1;
    Dn=1;
    #4;
    Rx_Rst=1;
    repeat (3)
    @(negedge Rx_LP_Clk);

    Dp=0;
    @(negedge Rx_LP_Clk);
    Dn=0;    
    
    repeat(3)
    @(negedge Rx_LP_Clk);
    Dn=1;
    
    repeat (24)
    @(posedge Rx_DDR_Clk_Q);
    
    #1.25;
    Dp=0; Dn=1;
    #7.5 Dp=1; Dn=0;
    #7.5 Dp=0; Dn=1;
    #2.5; Dp=1; Dn=0;
    #2.5;

    
    repeat (80) begin 
    assert(val.randomize);
    for(int i=0;i<8;i=i+1) begin
    Dp=val.b[i];
    Dn=~Dp;
    #2.5;
    end
    end
    Dn=Dp;
    Dp=~Dp;
    #150;
    Dp=1;
    Dn=1;
    repeat(5)
    @(posedge Rx_LP_Clk);

    $stop;
end
endmodule