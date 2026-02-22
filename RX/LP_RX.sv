module LP_Rx_module (input logic Rx_Rst,Rx_LP_Clk,LP_Dp,LP_Dn,Rx_end_HS_no_sync,output logic HS_enable,HS_start_count,rx_esc_active,rx_valid_esc,rx_ulps_esc,
                     output logic [7:0]  rx_data_esc,output logic [3:0]  rx_trigger_esc);

    // registers for storing past value of Dp & Dn
    logic LP_Dp_reg,LP_Dn_reg;

    rx_escape rx_esc_dut(.arstn(Rx_Rst),.clk(Rx_LP_Clk),.Dp(LP_Dp),.Dp_reg(LP_Dp_reg),.Dn(LP_Dn),.Dn_reg(LP_Dn_reg),.rx_esc_active(rx_esc_active),
                              .rx_data_esc(rx_data_esc),.rx_valid_esc(rx_valid_esc),.rx_trigger_esc(rx_trigger_esc),.rx_ulps_esc(rx_ulps_esc));

    // 2-ff synchronizer
    logic Rx_end_HS_sync,Rx_end_HS;
    
    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
    if (!Rx_Rst) begin
        Rx_end_HS_sync<=0;
    end 
    else begin
        Rx_end_HS_sync<=Rx_end_HS_no_sync;
        end
    end
    
    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            Rx_end_HS<=0;
        end
         else begin
            Rx_end_HS<=Rx_end_HS_sync;
        end
    end


    always_ff@(posedge Rx_LP_Clk or negedge Rx_Rst) begin
    if (!Rx_Rst) begin
        LP_Dp_reg<=0;
        LP_Dn_reg<=0;
    end 
    else begin
        LP_Dp_reg<=LP_Dp;
        LP_Dn_reg<=LP_Dn;    
    end
    end

    // LP Rx FSM
    typedef enum logic [2:0] {IDLE,RECEIVE_LP01,RECEIVE_LP00,RECEIVE_HS,RECEIVE_ESC} LP_Rx_state;
    LP_Rx_state cs,ns;
    logic HS_enable_no_sync,HS_start_count_no_sync;

    // cs logic
    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            cs<=IDLE;
        end
        else begin
            cs<=ns;
        end
    end


    // ns & out logic
    always_comb begin
        case (cs)
            
            IDLE: begin
            HS_enable_no_sync=0;
            HS_start_count_no_sync=0;
            if((!LP_Dp&&LP_Dp_reg)) begin
                ns=RECEIVE_LP01;
                rx_esc_active=0;
            end
            else if((!LP_Dn&&LP_Dn_reg)) begin
                ns=RECEIVE_ESC;
                rx_esc_active=1;
            end
            else 
            begin
                ns=IDLE;
                rx_esc_active=0;
            end
            end

            RECEIVE_ESC: begin
            HS_enable_no_sync=0;
            HS_start_count_no_sync=0;
            if(LP_Dp && LP_Dn) begin
                rx_esc_active=0;
                ns=IDLE;
            end
            else 
            begin
                rx_esc_active=1;
                ns=RECEIVE_ESC;
            end
            end

            RECEIVE_LP01: begin
            HS_enable_no_sync=0;
            rx_esc_active=0;
            if((!LP_Dn&&LP_Dn_reg)) begin
            ns=RECEIVE_LP00;
            HS_start_count_no_sync=1;
            end
            else begin
            ns=RECEIVE_LP01;
            HS_start_count_no_sync=0;
            end
            end

            RECEIVE_LP00: begin
            HS_start_count_no_sync=1;
            rx_esc_active=0;
            if((LP_Dn&&!LP_Dn_reg)) begin
            ns=RECEIVE_HS;
            HS_enable_no_sync=1;
            end
            else begin
            ns=RECEIVE_LP00;
            HS_enable_no_sync=0;
            end
            end                

            RECEIVE_HS: begin
            HS_start_count_no_sync=1;
            rx_esc_active=0;
            if(Rx_end_HS && LP_Dp && LP_Dn) begin
            ns=IDLE;
            HS_enable_no_sync=0;
            end
            else begin
            ns=RECEIVE_HS;
            HS_enable_no_sync=1;
            end
            end                   

            default: begin
            ns=IDLE;
            HS_enable_no_sync=0;
            rx_esc_active=0;
            HS_start_count_no_sync=0;
            end
        endcase
    end

    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
        if(!Rx_Rst)
            HS_start_count<=0;
        else
            HS_start_count<=HS_start_count_no_sync;
    end

    always_ff @(posedge Rx_LP_Clk or negedge Rx_Rst) begin
        if(!Rx_Rst)
            HS_enable<=0;
        else
            HS_enable<=HS_enable_no_sync;
    end

endmodule
