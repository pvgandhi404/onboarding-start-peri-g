`default_nettype none

module spi_peripheral(
    input wire clk,      // clock
    input wire rst_n,     // reset_n - active low

    input wire spi_sclk,  // Serial Clock 
    input wire spi_copi,  // Incoming serial data
    input wire spi_nCS,   // Transaction begin 

    output reg [7:0] en_reg_out_7_0,     // Enable outputs on `uo_out[7:0]`
    output reg [7:0] en_reg_out_15_8,    // Enable outputs on `uio_out[7:0]`
    output reg [7:0] en_reg_pwm_7_0,     // Enable PWM for `uo_out[7:0]`
    output reg [7:0] en_reg_pwm_15_8,    // Enable PWM for `uio_out[7:0]`
    output reg [7:0] pwm_duty_cycle     // PWM Duty Cycle ( `0x00`=0%, `0xFF`=100% )
);

reg [15:0] rx_payload = 16'b0; // store received payload

// registers for 2 stage FF  
reg [1:0] copi_sync, sclk_sync = 2'b00; 
reg [1:0] nCS_sync = = 2'b11;

reg [3:0] data_count = 0; // index of payload

// transaction flags
reg transaction_complete = 1'b1;
reg transaction_ready = 1'b0; 

// Wires to stable signals
wire copi_stable = copi_sync[1];

// Sync inputs and update flags
always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin               // reset --> set everything to 0
        en_reg_out_7_0 <= 8'h00;
        en_reg_out_15_8 <= 8'h00;
        en_reg_pwm_7_0 <= 8'h00;
        en_reg_pwm_15_8 <= 8'h00;
        pwm_duty_cycle <= 8'h00;

        copi_sync <= 2'b00;
        sclk_sync <= 2'b00;
        nCS_sync <= 2'b11;

        transaction_ready <= 1'b0; 
        transaction_complete <= 1'b1; 
        data_count <= 4'b0;

        rx_payload <= 16'b0;
    
    end else begin            
    
        // Stabilize signals 
        copi_sync <= {copi_sync[0], spi_copi};
        nCS_sync <= {nCS_sync[0], spi_nCS};
        sclk_sync <= {sclk_sync[0], spi_sclk};

        // high to low: ready for transfer
        if (nCS_sync[1] & ~nCS_sync[0] & transaction_complete) begin  
            transaction_ready <= 1;
            transaction_complete <= 0;

        // low to high: transaction complete, ensure 16 data bits received
        end else if (~nCS_sync[1] & nCS_sync[0] & ~transaction_complete & (data_count == 15)) begin 
            transaction_ready <= 0;
            transaction_complete <= 1;
            data_count <= 0;
        end 

        // Receive data and update registers
        if (transaction_ready) begin 
            if (~sclk_sync[0] & sclk_sync[1]) begin // low to high: capture data
                rx_payload <= {rx_payload[14:0], copi_stable};
                data_count <= data_count + 1;
            end 

        end else if (transaction_complete & rx_payload[15]) begin  // ignore reads (rx_payload[15] = 0) 
            case (rx_payload[14:8])
                8'h00: en_reg_out_7_0 <= rx_payload[7:0];
                8'h01: en_reg_out_15_8 <= rx_payload[7:0];
                8'h02: en_reg_pwm_7_0 <= rx_payload[7:0];
                8'h03: en_reg_pwm_15_8 <= rx_payload[7:0];
                8'h04: pwm_duty_cycle <= rx_payload[7:0];
                default: ; // Do nothing (ignore address)
            endcase
        end 
    end  
end 

endmodule 