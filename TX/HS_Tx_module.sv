module HS_Tx_module #(parameter Data_length=8,counter_serial_width=2,sync_word=8'b00011101,counter_zeros_width=5,counter_zeros_val=20,counter_trail_width=5,counter_trail_val=20)
(input logic Tx_Request_HS,Tx_Rst,Tx_DDR_Clk_HS,Tx_enable_HS,input logic [Data_length-1:0] Tx_Data_HS,output logic Dp,Dn,Tx_ready_HS,Tx_end_HS,Tx_Byte_Clk_HS);
    
        // Divide DDR clk by 4
        logic [1:0] clk_counter;
        
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                clk_counter<=0;
            end 
            else 
            clk_counter<=clk_counter+1;
        end
        
        assign Tx_Byte_Clk_HS = clk_counter[1];


        // HS FSM
        typedef enum logic [2:0] {IDLE,SEND_ZEROS,SEND_SYNC,SEND_PAYLOAD,SEND_TRAIL} HS_state;
        HS_state cs,ns;
        logic [7:0] Tx_Data_HS_reg,parallel_data;
        logic [counter_zeros_width-1:0] counter_zeros;
        logic [counter_trail_width-1:0] counter_trail;
        logic [1:0] counter_payload_sync;
        logic Tx_ready_HS_reg;

        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst)
                counter_payload_sync<=0;
            else if(cs==SEND_SYNC || cs==SEND_PAYLOAD)
                counter_payload_sync<=counter_payload_sync+1;    
            else
                counter_payload_sync<=0;
        end

        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst)
                counter_zeros<=0;
            else if(cs==SEND_ZEROS)
                counter_zeros<=counter_zeros+1;    
            else
                counter_zeros<=0;
        end

        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst)
                counter_trail<=0;
            else if(cs==SEND_TRAIL)
                counter_trail<=counter_trail+1;    
            else
                counter_trail<=0;
        end

        // Sampling Data & Tx_HS_ready logic
        always_ff @(posedge Tx_Byte_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                Tx_Data_HS_reg<=0;
            end 
            else begin
                Tx_Data_HS_reg<=Tx_Data_HS;
            end
        end

        always_ff @(posedge Tx_Byte_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                Tx_ready_HS<=0;
            end 
            else if((counter_zeros>=counter_zeros_val || cs==SEND_PAYLOAD || cs==SEND_SYNC) && Tx_Request_HS) begin
                Tx_ready_HS<=1;
            end
            else
                Tx_ready_HS<=0;
        end

        // Pipeline Tx Ready reg
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                Tx_ready_HS_reg<=0;
            end
            else begin
                Tx_ready_HS_reg<=Tx_ready_HS;
            end
        end

        // cs logic
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                cs<=IDLE;
            end
            else begin
                cs<=ns;
            end
        end

        // ns logic
        always_comb begin
            case (cs)
                
                IDLE: begin
                Tx_end_HS=1;
                if(Tx_enable_HS && Tx_Request_HS)
                ns=SEND_ZEROS;
                else
                ns=IDLE;
                end

                SEND_ZEROS: begin
                Tx_end_HS=0;
                if(!Tx_Request_HS) begin
                ns=IDLE;
                end
                else if(Tx_ready_HS) begin
                ns=SEND_SYNC;
                end
                else begin
                ns=SEND_ZEROS;
                end
                end

                SEND_SYNC: begin
                Tx_end_HS=0;
                if(!Tx_Request_HS) begin
                ns=IDLE;
                end
                else if(counter_payload_sync==3) begin
                ns=SEND_PAYLOAD;
                end
                else begin
                ns=SEND_SYNC;
                end                
                end

                SEND_PAYLOAD: begin
                Tx_end_HS=0;
                if(counter_payload_sync==3 && !Tx_Request_HS) begin
                ns=SEND_TRAIL;
                end
                else begin
                ns=SEND_PAYLOAD;
                end
                end
                
                SEND_TRAIL: begin
                if(counter_trail==counter_trail_val) begin
                ns=IDLE;
                Tx_end_HS=1;
                end
                else begin
                ns=SEND_TRAIL;
                Tx_end_HS=0;
                end
                end

                default: begin
                    ns=IDLE;
                    Tx_end_HS=0;
                end
            endcase
        end


        // out logic
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst) begin
                parallel_data<=8'b0000_0000;
            end
            else if(ns==IDLE) begin
                parallel_data<=8'b0000_0000;
            end
            else if(ns==SEND_ZEROS) begin
                parallel_data<=0;
            end
            else if(ns==SEND_SYNC) begin
                parallel_data<=sync_word;
            end
            else if(ns==SEND_PAYLOAD) begin
                parallel_data<=Tx_Data_HS_reg;
            end
            else if(ns==SEND_TRAIL) begin
                parallel_data<={8{~Tx_Data_HS_reg[7]}};
            end
        end
        

        // Serialize Data 
        logic [1:0] counter_serial;
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
            if (!Tx_Rst)
                counter_serial<=0;
            else if(Tx_ready_HS_reg)
                counter_serial<=counter_serial+1;
            else
                counter_serial<=0;    
        end

        // Dual edge ff
        logic q_pos, q_neg;
        logic [2:0] concat;

        assign concat = {counter_serial,1'b0};
        // Negative edge flip-flop
        always_ff @(negedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
        if (!Tx_Rst)
            q_neg <= 1'b0;
        else
            q_neg <= parallel_data[concat]^q_pos;
        end

        // Positive edge flip-flop
        always_ff @(posedge Tx_DDR_Clk_HS or negedge Tx_Rst) begin
        if (!Tx_Rst)
            q_pos <= 1'b0;
        else
            q_pos <= parallel_data[concat+1]^q_neg;
        end

        // Output logic  XOR of both FFs
        assign  Dp= (Tx_enable_HS)  ? (q_pos ^ q_neg) : 1'bz ;
        assign Dn=(Tx_enable_HS)  ? !(q_pos ^ q_neg) : 1'bz ;

        

endmodule