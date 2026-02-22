// -----------------------------------------------------------------------------
// D-PHY Receiver Escape Mode Module (Interface Definition)
// Implements reception of LPDT (Low-Power Data Transmission),
// Trigger Mode, and ULPS detection.
// -----------------------------------------------------------------------------
// Reference: MIPI D-PHY v1.2, PPI (Protocol to PHY Interface)
// -----------------------------------------------------------------------------
module rx_escape (
    input  logic        arstn,        // active-low reset
    input  logic        clk,      

    // -------------------------------------------------------------------------
    // Inputs from the LP pad drivers / analog front end
    // -------------------------------------------------------------------------
    input  logic        Dp,Dp_reg,    
    input  logic        Dn,Dn_reg, 
    input  logic        rx_esc_active,
    // -------------------------------------------------------------------------
    // Outputs to Protocol Layer (PPI)
    // -------------------------------------------------------------------------
    // LPDT data reception
    output logic [7:0]  rx_data_esc,   // received byte
    output logic        rx_valid_esc,  // asserted when a valid byte is present

    // Trigger detection
    output logic [3:0]  rx_trigger_esc, // one-hot, Trigger[0..3] detected

    // ULPS detection
    output logic        rx_ulps_esc
);


  //ESC Cmd sequence
  localparam logic [7:0] LPDT_command=8'b11100001;
  localparam logic [7:0] ULPS_command=8'b00011110;
  localparam logic [7:0] TRIG0_command=8'b01100010;
  localparam logic [7:0] TRIG1_command=8'b01011101;
  localparam logic [7:0] TRIG2_command=8'b00100001;
  localparam logic [7:0] TRIG3_command=8'b10100000;
  
  // Half bit status
  localparam bit SEND_FIRST_HALF_BIT=0;
  localparam bit SEND_SECOND_HALF_BIT=1;

  //ESC commands register
  logic [7:0] esc_commands [6]= '{LPDT_command,ULPS_command,TRIG0_command,TRIG1_command,TRIG2_command,TRIG3_command};

  typedef enum logic [2:0] {LP11,LP10,LP00,LP01,LP002} esc_entry_state;
  esc_entry_state esc_entry_cs,esc_entry_ns;

    // ESC entry seq FSM
    always_ff @(posedge clk or negedge arstn) begin
    if(!arstn)
        esc_entry_cs<=LP11;
    else
        esc_entry_cs<=esc_entry_ns;
    end  

    always_comb begin
        case (esc_entry_cs)
            LP11:esc_entry_ns=(rx_esc_active) ? LP10:LP11;
            LP10: begin
            case({Dp,Dn})
            2'b00:esc_entry_ns=LP00;
            2'b11:esc_entry_ns=LP11;
            default:esc_entry_ns=LP10;
            endcase
            end
            LP00: begin
            case({Dp,Dn})
            2'b01:esc_entry_ns=LP01;
            2'b11:esc_entry_ns=LP11;
            default:esc_entry_ns=LP00;
            endcase
            end
            LP01: begin
            case({Dp,Dn})
            2'b00:esc_entry_ns=LP002;
            2'b11:esc_entry_ns=LP11;
            default:esc_entry_ns=LP01;
            endcase
            end
            LP002: begin
            esc_entry_ns=(rx_esc_active)? LP002:LP11;
            end     
            default: begin
                esc_entry_ns=LP11;
            end
        endcase
    end

    // Negative & Positice Edge detectors 
    logic pos_edge_det_Dp,pos_edge_det_Dn,neg_edge_det_Dp,neg_edge_det_Dn;;
    assign pos_edge_det_Dp = Dp && !Dp_reg;
    assign pos_edge_det_Dn = Dn && !Dn_reg;

    assign neg_edge_det_Dp = !Dp && Dp_reg;
    assign neg_edge_det_Dn = !Dn && Dn_reg;

    // Shift register & Counter for cmd detection
    logic [7:0] cmd_shift_reg;
    logic [2:0] cmd_counter;

    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn) begin
            cmd_shift_reg<=0;
            end
        else if (esc_entry_cs==LP002 && (pos_edge_det_Dn || pos_edge_det_Dp)) begin
            cmd_shift_reg<={pos_edge_det_Dp,cmd_shift_reg[7:1]};
        end
    end

    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn) begin
            cmd_counter<=0;
            end
        else if (esc_entry_cs==LP002 && (pos_edge_det_Dn || pos_edge_det_Dp)) begin
            cmd_counter<=cmd_counter+1;
        end

        else if ((Dp && Dn) || ( (!Dp && !Dn) && !(neg_edge_det_Dn || neg_edge_det_Dp) ) ) begin
            cmd_counter<=0;    
        end

    end

  // ESC Mode state
  typedef enum logic [2:0] {IDLE,ESC_TRIG,ESC_LPDT,ESC_ULPS} esc_mode;
  esc_mode esc_mode_cs,esc_mode_ns;

  always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        esc_mode_cs<=IDLE;
    end 
    else begin
        esc_mode_cs<=esc_mode_ns;    
    end
  end

   always_comb begin
    case (esc_mode_cs)
        IDLE: begin
        case (cmd_shift_reg)
            LPDT_command:esc_mode_ns=ESC_LPDT;
            ULPS_command:esc_mode_ns=ESC_ULPS;
            TRIG0_command:esc_mode_ns=ESC_TRIG;
            TRIG1_command:esc_mode_ns=ESC_TRIG;
            TRIG2_command:esc_mode_ns=ESC_TRIG;
            TRIG3_command:esc_mode_ns=ESC_TRIG;
            default: begin
            esc_mode_ns=IDLE;
            end
        endcase
        end
        ESC_TRIG:esc_mode_ns=(rx_esc_active)?ESC_TRIG:IDLE;
        ESC_LPDT:esc_mode_ns=(rx_esc_active)?ESC_LPDT:IDLE;
        ESC_ULPS:esc_mode_ns=(rx_esc_active)?ESC_ULPS:IDLE;
        default: begin
            esc_mode_ns=IDLE;
        end
    endcase
   end 

    // Outputs
    assign rx_data_esc = cmd_shift_reg;
    
    always_ff @(posedge clk or negedge arstn) begin
    if (!arstn)
        rx_ulps_esc <= 1'b0;
    else
        rx_ulps_esc <= (esc_mode_cs == ESC_ULPS);
    end

    
    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn)
            rx_valid_esc<=0;
        else if  (esc_mode_cs==ESC_LPDT && ((cmd_counter==7 && (pos_edge_det_Dn || pos_edge_det_Dp)) || (cmd_counter==0 && (neg_edge_det_Dn || neg_edge_det_Dp))) ) begin
            rx_valid_esc<=1;
        end
        else
            rx_valid_esc<=0;
    end

    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn)
            rx_trigger_esc<=0;
        else if (esc_mode_cs==IDLE && esc_mode_ns==ESC_TRIG) begin
            case (cmd_shift_reg)
            TRIG0_command:rx_trigger_esc<=4'b1000;
            TRIG1_command:rx_trigger_esc<=4'b0100;
            TRIG2_command:rx_trigger_esc<=4'b0010;
            TRIG3_command:rx_trigger_esc<=4'b0001;
        endcase
        end
        else if (!rx_esc_active) begin
            rx_trigger_esc<=0;
        end
    end 
endmodule
