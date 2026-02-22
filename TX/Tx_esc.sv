`define ESC_IDLE 0
`define ESC_NOT_IDLE 1
`timescale 1ns/1ps
module tx_escape #(
  // Timing in system-clock cycles (set per your clk frequency)
  parameter int ulps_exit_counter_val     = 2000,   // >= TLPX (e.g., 50ns @10ns clk => 5)
  parameter int ulps_exit_counter_width   = 16  // >= 
) (
  input  logic        clk_i,       // system clock driving this controller
  input  logic        arstn,

  // Requests from protocol/controller
  input  logic        tx_request_esc, // request to enter Escape
  input  logic        tx_lpdt,        // choose LP data transmission inside Escape
  input  logic        tx_ulps_esc,    // choose ULPS entry inside Escape
  input  logic        tx_ulps_exit,    // Exit from ULPS
  input  logic [3:0]  tx_trigger_esc, // one-hot trigger request (bit 0..3)
  input  logic [7:0]  tx_data_esc,
  input  logic        tx_valid_esc,

  // Outputs
  output logic        esc_flag,
  output logic        tx_ready_esc,
  output logic        Dp_esc,Dn_esc
);


  // LP state drive helpers
  localparam logic [1:0] LP10 = 2'b10;
  localparam logic [1:0] LP01 = 2'b01;
  localparam logic [1:0] LP00 = 2'b00;

  //ESC Entry sequence
  localparam logic [7:0] LPDT_command=8'b11100001;
  localparam logic [7:0] ULPS_command=8'b00011110;
  localparam logic [7:0] TRIG0_command=8'b01100010;
  localparam logic [7:0] TRIG1_command=8'b01011101;
  localparam logic [7:0] TRIG2_command=8'b00100001;
  localparam logic [7:0] TRIG3_command=8'b10100000;
  
  // Half bit status
  localparam bit SEND_FIRST_HALF_BIT=0;
  localparam bit SEND_SECOND_HALF_BIT=1;

  // LP state register
  logic [1:0] esc_seq [4]='{LP10,LP00,LP01,LP00};

  //ESC commands register
  logic [7:0] esc_commands [6]= '{LPDT_command,ULPS_command,TRIG0_command,TRIG1_command,TRIG2_command,TRIG3_command};

  typedef enum logic [2:0] {
  IDLE     = 0,
  SEND_SEQ = 1,
  SEND_COMMAND = 2, 
  ULPS     = 3,  
  TRIG     = 4,
  LPDT     = 5
  } esc_state;
  esc_state esc_cs,esc_ns;

  typedef enum logic [1:0] {ULPS_IDLE,ULPS_ON,ULPS_EXIT} ulps_state;
  ulps_state ulps_cs,ulps_ns;

  typedef enum logic {LPDT_DATA_INVALID,LPDT_DATA_VALID} lpdt_state;
  lpdt_state lpdt_cs,lpdt_ns;

  logic [ulps_exit_counter_width-1:0] ulps_exit_counter;
  logic [1:0] seq_counter;
  logic tx_lpdt_reg;
  
  assign esc_flag = (esc_cs==IDLE) ? (`ESC_IDLE):(`ESC_NOT_IDLE);

  // seq counter
  always_ff @(posedge clk_i or negedge arstn) begin
    if (!arstn) begin
      seq_counter<=0;
    end 
    else if(esc_cs==SEND_SEQ) begin
      seq_counter<=seq_counter+1;
    end
    else
      seq_counter<=0;
  end

  //flag for sending first/second half bit;
  logic flag;
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      flag<=SEND_FIRST_HALF_BIT;
    
    else if(esc_cs==SEND_COMMAND || lpdt_cs==LPDT_DATA_VALID)
      flag<=~flag;  

    else 
      flag<=SEND_FIRST_HALF_BIT;
    
  end  

  // command counter
  logic [3:0] command_counter;
  always_ff @(posedge clk_i or negedge arstn) begin
    if (!arstn) begin
      command_counter<=0;
    end 
   
    else if(esc_cs==IDLE)
      command_counter<=0;
    
    else if(flag==SEND_SECOND_HALF_BIT)
      command_counter<=command_counter+1;

  end


  // Escape FSM

  always_ff @(posedge clk_i or negedge arstn) begin
    if (!arstn) begin
      esc_cs<=IDLE;
    end else begin
      esc_cs<=esc_ns;
    end
  end

  always_comb begin
    case (esc_cs)
      IDLE:
      begin 
        if(tx_request_esc) begin
          esc_ns=SEND_SEQ;
        end
        else
        esc_ns=IDLE;
      end
      
      SEND_SEQ: esc_ns=(seq_counter==3)? SEND_COMMAND:SEND_SEQ;
      SEND_COMMAND: begin
      
      if(command_counter==8) begin

        if (|tx_trigger_esc) begin
          esc_ns=TRIG;
        end 

        else if (tx_ulps_esc) begin
          esc_ns=ULPS;
        end
        else begin
          esc_ns=SEND_COMMAND;
        end
      end

      else if (tx_lpdt_reg && command_counter==7) begin
        esc_ns=LPDT;
      end      
      
     else begin
        esc_ns=SEND_COMMAND;
      end
    end 
      
      ULPS:esc_ns=(!tx_request_esc && (ulps_exit_counter==ulps_exit_counter_val))? (IDLE): (ULPS);
      TRIG:esc_ns=(!tx_request_esc)? (IDLE):(TRIG);
      LPDT:esc_ns=(!tx_request_esc && lpdt_cs==LPDT_DATA_INVALID)? (IDLE):(LPDT);
      
      default:
      begin
      esc_ns=IDLE;
      end
    endcase
  end

  // Command Decoder
  logic [7:0] trig_active_command;
  always_comb begin
    if (|tx_trigger_esc) begin
      case (tx_trigger_esc)
        4'b1000:trig_active_command=esc_commands[2];
        4'b0100:trig_active_command=esc_commands[3];
        4'b0010:trig_active_command=esc_commands[4];
        4'b0001:trig_active_command=esc_commands[5];
        default: begin
          trig_active_command=0;
        end
      endcase
      end
      
      else if (tx_lpdt_reg) begin
        trig_active_command=esc_commands[0];
      end

      else if(tx_ulps_esc) begin
        trig_active_command=esc_commands[1];      
      end

      else begin
        trig_active_command=0;
      end
  end



  // ULPS FSM

  // ulps counter
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      ulps_exit_counter<=0;
    
    else if (ulps_cs==ULPS_EXIT) begin
      ulps_exit_counter<=ulps_exit_counter+1;
    end
    
    else begin
      ulps_exit_counter<=0;
    end
  end

  always_ff @(posedge clk_i or negedge arstn) begin
    if (!arstn) begin
      ulps_cs<=ULPS_IDLE;
    end 
    else begin
      ulps_cs<=ulps_ns;
    end
  end

  always_comb begin
    case (ulps_cs)
      ULPS_IDLE:ulps_ns=(esc_cs==ULPS)? ULPS_ON:ULPS_IDLE;
      ULPS_ON: ulps_ns=(tx_ulps_exit) ? ULPS_EXIT:ULPS_ON;
      ULPS_EXIT:ulps_ns=(esc_cs==IDLE)?ULPS_IDLE:ULPS_EXIT;
      default: ulps_ns=ULPS_IDLE;
    endcase
  end


  // Store lpdt req in ff
  always_ff @(posedge clk_i or negedge arstn) begin
    if (!arstn) begin
      tx_lpdt_reg<=0;
    end 
    else begin
    casez ({tx_request_esc,tx_lpdt})
        2'b11: tx_lpdt_reg <= 1;
        2'b0z: tx_lpdt_reg <= 0;
    endcase
    end

  end

  // LPDT register
  logic [7:0]  tx_data_esc_reg;
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      tx_data_esc_reg<=0;

    else if (tx_ready_esc && tx_valid_esc) begin
      tx_data_esc_reg<=tx_data_esc;
    end  
  end

  // tx valid neg edge detect
  logic tx_valid_reg,tx_valid_neg_edge,tx_valid_neg_pulse;
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      tx_valid_reg<=0;
    else
    tx_valid_reg<= tx_valid_esc;  
  end

  assign tx_valid_neg_edge = tx_valid_reg & !tx_valid_esc;

   // Array of flip-flops
    logic [15-1:0] pulse_extender;
    // Generate shift register
    genvar i;
    generate
        for (i = 0; i < 15; i = i + 1) begin : extender_ff
            always @(posedge clk_i or negedge arstn) begin
                if (!arstn)
                    pulse_extender[i] <= 1'b0;
                else if (i == 0)
                    pulse_extender[i] <= tx_valid_neg_edge;
                else
                    pulse_extender[i] <= pulse_extender[i-1];
            end
        end
    endgenerate

    // OR all stages to get extended pulse
    assign tx_valid_neg_pulse = |pulse_extender | tx_valid_neg_edge;

  // LPDT FSM
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      lpdt_cs<=LPDT_DATA_INVALID;

    else
      lpdt_cs<=lpdt_ns;  

  end

  always_comb 
    begin
    case(lpdt_cs)
      LPDT_DATA_INVALID:lpdt_ns=(tx_valid_esc && esc_cs==LPDT)? LPDT_DATA_VALID:LPDT_DATA_INVALID;
      LPDT_DATA_VALID:lpdt_ns= ( (tx_valid_esc && esc_cs==LPDT) || (tx_valid_neg_pulse) ) ? LPDT_DATA_VALID:LPDT_DATA_INVALID;
      default:lpdt_ns=LPDT_DATA_INVALID;
     endcase
  end

  //serializer counter
  logic [2:0] serializer_counter;
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      serializer_counter<=0;
    
    else if(lpdt_cs==LPDT_DATA_VALID && flag==SEND_SECOND_HALF_BIT)
      serializer_counter<=serializer_counter+1;

    else if(lpdt_cs!=LPDT_DATA_VALID) begin
      serializer_counter<=0;
    end

  end

  // tx_ready
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn)
      tx_ready_esc<=0;

    else if((esc_cs==SEND_COMMAND && command_counter==6 && flag==SEND_SECOND_HALF_BIT && tx_lpdt_reg) || ((esc_cs==LPDT) && ((serializer_counter==6 && flag==SEND_SECOND_HALF_BIT && tx_valid_esc) || (!(tx_valid_neg_pulse && !pulse_extender[14]) && !tx_valid_esc))))
      tx_ready_esc<=1;

    else
      tx_ready_esc<=0;

  end

  // Dp & Dn 
  always_ff @(posedge clk_i or negedge arstn) begin
    if(!arstn) begin
    Dp_esc<=1;
    Dn_esc<=1;
    end

    else if(esc_cs!=IDLE)
      begin

      if (esc_cs==SEND_SEQ) begin
        {Dp_esc,Dn_esc}<=esc_seq[seq_counter];
      end

      else if(esc_ns==TRIG || esc_cs==TRIG) begin
          Dp_esc<=1;
          Dn_esc<=(flag==SEND_FIRST_HALF_BIT && command_counter==8)?0:1;
        end  

      else if (esc_cs==SEND_COMMAND  && command_counter!=8) begin
         if(trig_active_command[command_counter]==1) begin
          Dp_esc<=(flag==SEND_FIRST_HALF_BIT)?1:0;
          Dn_esc<=0;
          end
        else begin
          Dn_esc<=(flag==SEND_FIRST_HALF_BIT)?1:0;
          Dp_esc<=0;
          end
        end 

      else if (ulps_cs==ULPS_EXIT || (!tx_request_esc && lpdt_cs==LPDT_DATA_INVALID && esc_cs==LPDT)) begin
        Dp_esc<=1;
        Dn_esc<=0;
      end

      else if(lpdt_cs==LPDT_DATA_VALID) begin
        if(tx_data_esc_reg[serializer_counter]==1) begin
          Dp_esc<=(flag==SEND_FIRST_HALF_BIT)?1:0;
          Dn_esc<=0;
          end
        else begin
          Dn_esc<=(flag==SEND_FIRST_HALF_BIT)?1:0;
          Dp_esc<=0;
          end
      end
      else if (ulps_cs==ULPS_ON || lpdt_cs==LPDT_DATA_INVALID) begin
        Dp_esc<=0;
        Dn_esc<=0;
      end
    end

  else begin
    Dp_esc<=1;
    Dn_esc<=1;
   end

 end


endmodule
