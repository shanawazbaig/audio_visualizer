// I2S Receiver Module
// Receives 24-bit audio samples from WM8731 codec
// Synchronizes BCLK, LRCLK, and ADCDAT
// Outputs left and right channel samples with valid pulse

module i2s_receiver (
    input wire clk,                  // System clock (50 MHz)
    input wire reset_n,              // Active-low reset
    input wire aud_bclk,             // Audio bit clock from codec
    input wire aud_adclrck,          // ADC left/right clock
    input wire aud_adcdat,           // Audio data from ADC
    output reg [23:0] left_sample,   // Left channel sample
    output reg [23:0] right_sample,  // Right channel sample
    output reg sample_valid          // Pulse when new samples ready
);

    // Synchronize external signals to system clock domain
    reg [2:0] bclk_sync;
    reg [2:0] lrclk_sync;
    reg [2:0] adcdat_sync;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bclk_sync <= 3'b0;
            lrclk_sync <= 3'b0;
            adcdat_sync <= 3'b0;
        end else begin
            bclk_sync <= {bclk_sync[1:0], aud_bclk};
            lrclk_sync <= {lrclk_sync[1:0], aud_adclrck};
            adcdat_sync <= {adcdat_sync[1:0], aud_adcdat};
        end
    end
    
    // Edge detection for BCLK
    wire bclk_rising = (bclk_sync[2:1] == 2'b01);
    wire bclk_falling = (bclk_sync[2:1] == 2'b10);
    
    // Edge detection for LRCLK (channel switch)
    wire lrclk_rising = (lrclk_sync[2:1] == 2'b01);
    wire lrclk_falling = (lrclk_sync[2:1] == 2'b10);
    
    // Shift register for incoming data
    reg [23:0] shift_reg;
    reg [4:0] bit_count;
    reg current_channel;  // 0 = left, 1 = right
    reg prev_lrclk;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_reg <= 24'b0;
            bit_count <= 5'd0;
            left_sample <= 24'b0;
            right_sample <= 24'b0;
            sample_valid <= 1'b0;
            current_channel <= 1'b0;
            prev_lrclk <= 1'b0;
        end else begin
            sample_valid <= 1'b0;  // Default to low
            prev_lrclk <= lrclk_sync[2];
            
            // Detect channel change
            if (lrclk_rising || lrclk_falling) begin
                // Store completed sample
                if (bit_count == 24) begin
                    if (current_channel == 0) begin
                        // Just finished left channel
                        left_sample <= shift_reg;
                    end else begin
                        // Just finished right channel
                        right_sample <= shift_reg;
                        sample_valid <= 1'b1;  // Both channels ready
                    end
                end
                
                // Switch channel and reset counter
                current_channel <= lrclk_sync[2];
                bit_count <= 5'd0;
                shift_reg <= 24'b0;
            end
            
            // Shift in data on BCLK rising edge
            // I2S data is MSB first, valid after BCLK falling edge, sampled on rising edge
            // This follows standard I2S timing where data is stable during rising edge
            else if (bclk_rising) begin
                if (bit_count < 24) begin
                    shift_reg <= {shift_reg[22:0], adcdat_sync[2]};
                    bit_count <= bit_count + 1;
                end
            end
        end
    end

endmodule
