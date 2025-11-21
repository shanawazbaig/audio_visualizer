// Top-Level Module for Audio Visualizer
// DE10-Standard FPGA Board with WM8731 Audio Codec
// Real-time audio amplitude visualization on LED bar graph

module audio_visualizer_top (
    // Clock and Reset
    input wire CLOCK_50,           // 50 MHz system clock
    input wire [0:0] KEY,          // KEY[0] - Active low reset button
    
    // Audio Codec Interface
    output wire AUD_XCK,           // Audio codec master clock (12.288 MHz)
    input wire AUD_BCLK,           // Audio bit clock
    input wire AUD_ADCLRCK,        // ADC left/right clock
    input wire AUD_ADCDAT,         // Audio ADC data
    output wire AUD_DACLRCK,       // DAC left/right clock (unused)
    output wire AUD_DACDAT,        // Audio DAC data (unused)
    
    // I2C Interface for Codec Configuration
    output wire FPGA_I2C_SCLK,     // I2C clock
    inout wire FPGA_I2C_SDAT,      // I2C data
    
    // LED Display
    output wire [9:0] LEDR,        // 10 Red LEDs for amplitude bar graph
    
    // Optional: Switches for channel selection
    input wire [1:0] SW            // SW[1:0] - Channel select
);

    // Internal signals
    wire reset_n;
    wire pll_locked;
    wire i2c_ready;
    wire [23:0] left_sample;
    wire [23:0] right_sample;
    wire sample_valid;
    wire [9:0] led_level;
    
    // Reset logic - active low, synchronized with PLL lock
    assign reset_n = KEY[0] & pll_locked;
    
    // Unused DAC outputs
    assign AUD_DACLRCK = 1'b0;
    assign AUD_DACDAT = 1'b0;
    
    // LED output
    assign LEDR = led_level;
    
    // ========================================
    // PLL - Generate 12.288 MHz audio clock
    // ========================================
    pll_audio pll_inst (
        .inclk0(CLOCK_50),
        .areset(~KEY[0]),
        .c0(AUD_XCK),
        .locked(pll_locked)
    );
    
    // ========================================
    // I2C Master - Configure WM8731 Codec
    // ========================================
    reg i2c_enable;
    reg i2c_config_done;
    reg [23:0] startup_delay;
    
    // Delay I2C configuration after PLL locks
    parameter STARTUP_DELAY_CYCLES = 24'd2500000; // 50ms at 50MHz
    
    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            startup_delay <= 24'd0;
            i2c_enable <= 1'b0;
            i2c_config_done <= 1'b0;
        end else begin
            if (!i2c_config_done) begin
                if (startup_delay < STARTUP_DELAY_CYCLES) begin
                    startup_delay <= startup_delay + 1;
                    i2c_enable <= 1'b0;
                end else if (!i2c_ready) begin
                    i2c_enable <= 1'b1;
                end else begin
                    i2c_enable <= 1'b0;
                    i2c_config_done <= 1'b1;
                end
            end
        end
    end
    
    i2c_master i2c_inst (
        .clk(CLOCK_50),
        .reset_n(reset_n),
        .enable(i2c_enable),
        .ready(i2c_ready),
        .i2c_sdat(FPGA_I2C_SDAT),
        .i2c_sclk(FPGA_I2C_SCLK)
    );
    
    // ========================================
    // I2S Receiver - Capture Audio Samples
    // ========================================
    i2s_receiver i2s_inst (
        .clk(CLOCK_50),
        .reset_n(reset_n),
        .aud_bclk(AUD_BCLK),
        .aud_adclrck(AUD_ADCLRCK),
        .aud_adcdat(AUD_ADCDAT),
        .left_sample(left_sample),
        .right_sample(right_sample),
        .sample_valid(sample_valid)
    );
    
    // ========================================
    // Audio Processor - Compute Amplitude
    // ========================================
    audio_processor proc_inst (
        .clk(CLOCK_50),
        .reset_n(reset_n),
        .left_sample(left_sample),
        .right_sample(right_sample),
        .sample_valid(sample_valid),
        .channel_select(SW[1:0]),
        .led_level(led_level)
    );

endmodule
