`define ESC_IDLE 0
`define ESC_NOT_IDLE 1

module LP_Tx_module #(parameter counter_LP01_value=1,counter_LP01_length=2,counter_LP00_value=20,counter_LP00_length=4,ulps_exit_counter_val=2000,ulps_exit_counter_width=16)
                     (input logic Tx_Rst,Tx_Clk_LP,Tx_Request_HS,Tx_end_HS,tx_request_esc,tx_lpdt,tx_ulps_esc,tx_ulps_exit,tx_valid_esc,
                     input  logic [3:0]  tx_trigger_esc,input  logic [7:0]  tx_data_esc,output logic Dp,Dn,HS_enable,tx_ready_esc);

    logic [counter_LP01_length-1:0] counter_LP01;
    logic [counter_LP00_length-1:0] counter_LP00;
    logic esc_flag,Dp_esc,Dn_esc;
    
    tx_escape #(.ulps_exit_counter_val(ulps_exit_counter_val),.ulps_exit_counter_width(ulps_exit_counter_width)) ESC_DUT(.clk_i(Tx_Clk_LP),.arstn(Tx_Rst),.tx_request_esc(tx_request_esc),
    .tx_lpdt(tx_lpdt),.tx_ulps_esc(tx_ulps_esc),.tx_ulps_exit(tx_ulps_exit),.tx_trigger_esc(tx_trigger_esc),.tx_data_esc(tx_data_esc),
    .tx_valid_esc(tx_valid_esc),.esc_flag(esc_flag),.tx_ready_esc(tx_ready_esc),.Dp_esc(Dp_esc),.Dn_esc(Dn_esc));

    // LP FSM
    typedef enum logic [2:0] {IDLE,ESC,SEND_LP01,SEND_LP00,SEND_HS} LP_state;
    LP_state cs,ns;

    always_ff @(posedge Tx_Clk_LP or negedge Tx_Rst) begin
                    if(!Tx_Rst)
                    counter_LP01<=0;
                    
                    else if(cs==SEND_LP01)
                    counter_LP01<=counter_LP01+1;

                    else begin
                        counter_LP01<=0;
                    end
    end

    always_ff @(posedge Tx_Clk_LP or negedge Tx_Rst) begin
                    if(!Tx_Rst)
                    counter_LP00<=0;
                    
                    else if(cs==SEND_LP00)
                    counter_LP00<=counter_LP00+1;

                    else begin
                        counter_LP00<=0;
                    end
    end

    // cs logic
    always_ff @(posedge Tx_Clk_LP or negedge Tx_Rst) begin
        if (!Tx_Rst) begin
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
            Dp=1;
            Dn=1;
            HS_enable=0;
            if(Tx_Request_HS)
            ns=SEND_LP01;
            else if(tx_request_esc)
            ns=ESC;
            else
            ns=IDLE;
            end
            
            ESC:begin
            Dp=Dp_esc;
            Dn=Dn_esc;
            HS_enable=0;
            ns=(!tx_request_esc && esc_flag==`ESC_IDLE) ? (IDLE) : (ESC);
            end

            SEND_LP01: begin
            Dp=0;
            Dn=1;
            HS_enable=0;
            if(!Tx_Request_HS)
            ns=IDLE; 
            else if(counter_LP01==counter_LP01_value)
            ns=SEND_LP00;
            else
            ns=SEND_LP01;
            end

            SEND_LP00: begin
            Dp=0;
            Dn=0;
            HS_enable=0;
            if(!Tx_Request_HS)
            ns=IDLE;
            else if(counter_LP00==counter_LP00_value)
            ns=SEND_HS;
            else
            ns=SEND_LP00;
            end

            SEND_HS: begin
            Dp=1;
            Dn=1;
            
            if(!Tx_Request_HS && Tx_end_HS) begin
            ns=IDLE;
            HS_enable=0;
            end
            else begin
            ns=SEND_HS;
            HS_enable=1;
            end
            end
            
            default: begin
            ns=IDLE;
            Dp=1;
            Dn=1;
            HS_enable=0;
            end
        endcase
    end

endmodule