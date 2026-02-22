`timescale 1ns/1ps

module HS_Rx_module #(parameter counter_settle_width=10,counter_settle_val=30,sync_word=6'b011101) 
(input logic Rx_Rst,Rx_DDR_Clk_Q,HS_Dp,HS_Dn,HS_enable_no_sync,HS_start_count_no_sync,output logic Rx_Byte_Clk,Rx_end_HS,Rx_Sync_HS,Rx_Valid_HS,Rx_Active_HS,output logic [7:0] Rx_Data_HS);

    // Rx_Byte_Clk generation
    logic [1:0] clk_counter;
    
    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            clk_counter<=0;
        end 
        else 
        clk_counter<=clk_counter+1;
    end
    
    assign Rx_Byte_Clk = clk_counter[1];

    // 2-ff Synchronizer for LP signals;
    logic HS_enable_sync,HS_enable,HS_start_count_sync,HS_start_count;

    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            HS_enable_sync<=0;
        end else begin
            HS_enable_sync<=HS_enable_no_sync;
        end
    end

    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            HS_enable<=0;
        end else begin
            HS_enable<=HS_enable_sync;
        end
    end

    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            HS_start_count_sync<=0;
        end else begin
            HS_start_count_sync<=HS_start_count_no_sync;
        end
    end

    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            HS_start_count<=0;
        end else begin
            HS_start_count<=HS_start_count_sync;
        end
    end


    // Deserializer
    logic [7:0] reg_pos, reg_neg;

    // Negative edge register
    always_ff @(negedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
    if (!Rx_Rst)
        reg_neg <= 1'b0;
    else
        reg_neg <= {HS_Dp,reg_neg[7:1]};
    end

    // Positive edge register
    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
    if (!Rx_Rst)
        reg_pos <= 1'b0;
    else
        reg_pos <= {HS_Dp,reg_pos[7:1]};
    end


    // sync detector
    logic sync0,sync1,sync2,sync3,sync4,sync5,sync6,sync7,sync;
    always_comb begin
     sync7=({reg_neg[6],reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4]}==sync_word) ? 1:0;
     sync6=({reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3]}==sync_word) ? 1:0;
     sync5=({reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2]}==sync_word) ? 1:0; 
     sync4=({reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1],reg_pos[1]}==sync_word) ? 1:0;
    
     sync3=({reg_pos[7],reg_neg[6],reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4]}==sync_word) ? 1:0;
     sync2=({reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3]}==sync_word) ? 1:0;
     sync1=({reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2]}==sync_word) ? 1:0;
     sync0=({reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1]}==sync_word) ? 1:0;
     sync= sync0 | sync1 | sync2 | sync3 | sync4 | sync5 | sync6 | sync7 ;
    end

    // store sync position
    logic [7:0] sync_position;   
    always_ff @(posedge Rx_Byte_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            sync_position<=0;
        end 
        else if(sync && !Rx_Active_HS)begin
            sync_position<={sync7,sync6,sync5,sync4,sync3,sync2,sync1,sync0};
        end
    end

    // Detect data position
    logic [7:0] Data_HS;
    always_comb begin
            case (sync_position)
                8'b1000_0000:Data_HS = {reg_neg[6],reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3]};
                8'b0100_0000:Data_HS = {reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2]};
                8'b0010_0000:Data_HS = {reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1],reg_pos[1]};
                8'b0001_0000:Data_HS = {reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1],reg_pos[1],reg_neg[0],reg_pos[0]};
                
                8'b0000_1000:Data_HS = {reg_pos[7],reg_neg[6],reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3]};
                8'b0000_0100:Data_HS = {reg_pos[6],reg_neg[5],reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2]};
                8'b0000_0010:Data_HS = {reg_pos[5],reg_neg[4],reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1]};
                8'b0000_0001:Data_HS = {reg_pos[4],reg_neg[3],reg_pos[3],reg_neg[2],reg_pos[2],reg_neg[1],reg_pos[1],reg_neg[0]};
                default: Data_HS= 0;
            endcase
        end

    // Output Data
    always_ff @(posedge Rx_Byte_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            Rx_Data_HS<=0;
        end 
        else if(Rx_Active_HS) begin
            Rx_Data_HS<=Data_HS;
        end
    end

    // HS FSM
    typedef enum logic [1:0] {IDLE,RECEIVE_ZEROS,RECEIVE_SYNC,RECEIVE_PAYLOAD} HS_state;
    HS_state cs,ns;
    logic [counter_settle_width-1:0] counter_settle;
    logic Rx_end_HS_no_sync;

    // Settle counter
    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            counter_settle<=0;
        end

        else if (HS_start_count && (cs==IDLE || cs==RECEIVE_ZEROS)) begin
            counter_settle<=counter_settle+1;
        end

        else begin
            counter_settle<=0;
        end
    end

    // cs logic
    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
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
            Rx_end_HS_no_sync=1;
            if(HS_enable)
            ns=RECEIVE_ZEROS;
            else
            ns=IDLE;
            end

            RECEIVE_ZEROS: begin
            Rx_end_HS_no_sync=0;
            if(counter_settle>=counter_settle_val)
            ns=RECEIVE_SYNC;
            else
            ns=RECEIVE_ZEROS;
            end

            RECEIVE_SYNC: begin
            Rx_end_HS_no_sync=0;
            if(Rx_Active_HS)
            ns=RECEIVE_PAYLOAD;
            else
            ns=RECEIVE_SYNC;
            end

            RECEIVE_PAYLOAD: begin
            if((HS_Dp==HS_Dn) && HS_Dp==1) begin
            Rx_end_HS_no_sync=1;
            ns=HS_enable ? RECEIVE_PAYLOAD :IDLE;            
            end
            else begin
            Rx_end_HS_no_sync=0;
            ns=RECEIVE_PAYLOAD;
            end
            end
        endcase
    end

    always_ff @(posedge Rx_DDR_Clk_Q or negedge Rx_Rst) begin
        if(!Rx_Rst)
            Rx_end_HS<=0;
        else
            Rx_end_HS<=Rx_end_HS_no_sync;
    end

    always_ff @(posedge Rx_Byte_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            Rx_Active_HS<=0;
        end 
        else if(sync || (cs==RECEIVE_PAYLOAD && !((HS_Dp==HS_Dn) && HS_Dp==1))) begin
            Rx_Active_HS<=1;
        end
        else begin
            Rx_Active_HS<=0;
        end
    end

    always_ff @(posedge Rx_Byte_Clk or negedge Rx_Rst) begin
        if (!Rx_Rst) begin
            Rx_Valid_HS<=0;
        end 
        else if(cs==RECEIVE_PAYLOAD && !((HS_Dp==HS_Dn) && HS_Dp==1)) begin
            Rx_Valid_HS<=1;
        end
        else begin
            Rx_Valid_HS<=0;
        end
    end

    assign Rx_Sync_HS = Rx_Active_HS^Rx_Valid_HS;

endmodule
