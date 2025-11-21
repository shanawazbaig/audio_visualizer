// Audio Amplitude Processor
// Computes absolute amplitude from audio samples
// Maps amplitude to 10-bit LED pattern for visualization

module audio_processor (
    input wire clk,                    // System clock
    input wire reset_n,                // Active-low reset
    input wire [23:0] left_sample,     // Left channel audio sample
    input wire [23:0] right_sample,    // Right channel audio sample
    input wire sample_valid,           // New sample available
    input wire [1:0] channel_select,   // 00=left, 01=right, 10=avg, 11=max
    output reg [9:0] led_level         // LED bar graph output
);

    // Take absolute value of signed sample
    function [23:0] abs_value;
        input [23:0] sample;
        begin
            abs_value = sample[23] ? (~sample + 1) : sample;
        end
    endfunction
    
    // Average two samples
    function [23:0] avg_samples;
        input [23:0] s1, s2;
        reg [24:0] sum;
        begin
            sum = {1'b0, s1} + {1'b0, s2};
            avg_samples = sum[24:1];  // Divide by 2
        end
    endfunction
    
    // Max of two samples
    function [23:0] max_samples;
        input [23:0] s1, s2;
        begin
            max_samples = (s1 > s2) ? s1 : s2;
        end
    endfunction
    
    reg [23:0] amplitude;
    reg [23:0] peak_hold;
    reg [15:0] peak_decay_counter;
    
    // Peak hold decay time (about 0.1 seconds at 48kHz sample rate)
    parameter PEAK_DECAY_TIME = 4800;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            amplitude <= 24'b0;
            peak_hold <= 24'b0;
            peak_decay_counter <= 16'b0;
            led_level <= 10'b0;
        end else if (sample_valid) begin
            // Select channel and compute amplitude
            case (channel_select)
                2'b00: amplitude <= abs_value(left_sample);
                2'b01: amplitude <= abs_value(right_sample);
                2'b10: amplitude <= abs_value(avg_samples(left_sample, right_sample));
                2'b11: amplitude <= max_samples(abs_value(left_sample), abs_value(right_sample));
            endcase
            
            // Peak hold with decay
            if (amplitude > peak_hold) begin
                peak_hold <= amplitude;
                peak_decay_counter <= 16'b0;
            end else if (peak_decay_counter >= PEAK_DECAY_TIME) begin
                peak_hold <= peak_hold - (peak_hold >> 8);  // Slow decay
                peak_decay_counter <= 16'b0;
            end else begin
                peak_decay_counter <= peak_decay_counter + 1;
            end
            
            // Map amplitude to LED levels (using peak for better visibility)
            // 24-bit sample, use upper bits for comparison
            // Thresholds set for typical microphone input levels
            case (1'b1)
                (peak_hold[23:14] > 10'd800): led_level <= 10'b1111111111;  // All 10 LEDs
                (peak_hold[23:14] > 10'd700): led_level <= 10'b0111111111;  // 9 LEDs
                (peak_hold[23:14] > 10'd600): led_level <= 10'b0011111111;  // 8 LEDs
                (peak_hold[23:14] > 10'd500): led_level <= 10'b0001111111;  // 7 LEDs
                (peak_hold[23:14] > 10'd400): led_level <= 10'b0000111111;  // 6 LEDs
                (peak_hold[23:14] > 10'd300): led_level <= 10'b0000011111;  // 5 LEDs
                (peak_hold[23:14] > 10'd200): led_level <= 10'b0000001111;  // 4 LEDs
                (peak_hold[23:14] > 10'd100): led_level <= 10'b0000000111;  // 3 LEDs
                (peak_hold[23:14] > 10'd50):  led_level <= 10'b0000000011;  // 2 LEDs
                (peak_hold[23:14] > 10'd25):  led_level <= 10'b0000000001;  // 1 LED
                default:                       led_level <= 10'b0000000000;  // No LEDs
            endcase
        end
    end

endmodule
