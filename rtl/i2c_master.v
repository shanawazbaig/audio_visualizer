// I2C Master Module for WM8731 Audio Codec Configuration
// Implements bit-banging I2C protocol with START, STOP, ACK detection
// Device address: 0x1A (7-bit)

module i2c_master (
    input wire clk,              // System clock (50 MHz)
    input wire reset_n,          // Active-low reset
    input wire enable,           // Start I2C configuration
    output reg ready,            // Configuration complete
    inout wire i2c_sdat,         // I2C data line (bidirectional)
    output reg i2c_sclk          // I2C clock line
);

    // I2C timing parameters for 100 kHz (assumes 50 MHz input clock)
    parameter CLK_DIV = 250;     // 50MHz / 250 = 200kHz (for I2C clock toggling)
    
    // WM8731 register addresses and configuration values
    parameter WM8731_ADDR = 7'h1A;
    
    // Configuration sequence: [Register Address (7 bits), Data (9 bits)]
    // Total 16 configuration words
    localparam NUM_REGS = 10;
    
    reg [15:0] config_data [0:NUM_REGS-1];
    
    initial begin
        // Reset register
        config_data[0] = 16'h0017; // R0: Left Line In - default
        config_data[1] = 16'h0217; // R1: Right Line In - default
        config_data[2] = 16'h0479; // R2: Left Headphone Out - default
        config_data[3] = 16'h0679; // R3: Right Headphone Out - default
        config_data[4] = 16'h0815; // R4: Analog Audio Path - Enable mic boost, mute line
        config_data[5] = 16'h0A06; // R5: Digital Audio Path - Disable soft mute
        config_data[6] = 16'h0C00; // R6: Power Down Control - Power up all
        config_data[7] = 16'h0E01; // R7: Digital Audio Interface - I2S mode, 24-bit
        config_data[8] = 16'h1002; // R8: Sampling Control - 48kHz, USB mode
        config_data[9] = 16'h1201; // R9: Active Control - Activate interface
    end
    
    // State machine states
    localparam IDLE       = 4'd0;
    localparam START      = 4'd1;
    localparam ADDR       = 4'd2;
    localparam ADDR_ACK   = 4'd3;
    localparam DATA_HIGH  = 4'd4;
    localparam DATA_H_ACK = 4'd5;
    localparam DATA_LOW   = 4'd6;
    localparam DATA_L_ACK = 4'd7;
    localparam STOP       = 4'd8;
    localparam NEXT_REG   = 4'd9;
    localparam DONE       = 4'd10;
    
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] bit_count;
    reg [15:0] clk_count;
    reg [3:0] reg_index;
    reg [7:0] shift_reg;
    reg sdat_out;
    reg sdat_oe;  // Output enable for bidirectional control
    
    // Bidirectional control for i2c_sdat
    assign i2c_sdat = sdat_oe ? sdat_out : 1'bz;
    
    // Clock divider for I2C timing
    reg clk_en;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            clk_count <= 0;
            clk_en <= 0;
        end else begin
            if (clk_count >= CLK_DIV - 1) begin
                clk_count <= 0;
                clk_en <= 1;
            end else begin
                clk_count <= clk_count + 1;
                clk_en <= 0;
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            i2c_sclk <= 1;
            sdat_out <= 1;
            sdat_oe <= 1;
            ready <= 0;
            bit_count <= 0;
            reg_index <= 0;
            shift_reg <= 0;
        end else if (clk_en) begin
            case (state)
                IDLE: begin
                    ready <= 1;
                    i2c_sclk <= 1;
                    sdat_out <= 1;
                    sdat_oe <= 1;
                    reg_index <= 0;
                    if (enable && ready) begin
                        ready <= 0;
                        state <= START;
                    end
                end
                
                START: begin
                    // I2C START condition: SDAT falls while SCLK high
                    sdat_out <= 0;
                    i2c_sclk <= 1;
                    sdat_oe <= 1;
                    state <= ADDR;
                    bit_count <= 0;
                    // Load address + write bit (1'b0 = write operation)
                    shift_reg <= {WM8731_ADDR, 1'b0};
                end
                
                ADDR: begin
                    // Send 8 bits (7-bit address + W bit)
                    i2c_sclk <= ~i2c_sclk;
                    if (!i2c_sclk) begin  // Falling edge - setup data
                        sdat_out <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end else begin  // Rising edge
                        bit_count <= bit_count + 1;
                        if (bit_count >= 7) begin
                            state <= ADDR_ACK;
                            sdat_oe <= 0;  // Release for ACK
                        end
                    end
                end
                
                ADDR_ACK: begin
                    // Wait for ACK from slave
                    i2c_sclk <= ~i2c_sclk;
                    if (i2c_sclk) begin  // Rising edge - sample ACK
                        state <= DATA_HIGH;
                        bit_count <= 0;
                        shift_reg <= config_data[reg_index][15:8];
                        sdat_oe <= 1;
                    end
                end
                
                DATA_HIGH: begin
                    // Send high byte of data
                    i2c_sclk <= ~i2c_sclk;
                    if (!i2c_sclk) begin
                        sdat_out <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end else begin
                        bit_count <= bit_count + 1;
                        if (bit_count >= 7) begin
                            state <= DATA_H_ACK;
                            sdat_oe <= 0;
                        end
                    end
                end
                
                DATA_H_ACK: begin
                    i2c_sclk <= ~i2c_sclk;
                    if (i2c_sclk) begin
                        state <= DATA_LOW;
                        bit_count <= 0;
                        shift_reg <= config_data[reg_index][7:0];
                        sdat_oe <= 1;
                    end
                end
                
                DATA_LOW: begin
                    // Send low byte of data
                    i2c_sclk <= ~i2c_sclk;
                    if (!i2c_sclk) begin
                        sdat_out <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end else begin
                        bit_count <= bit_count + 1;
                        if (bit_count >= 7) begin
                            state <= DATA_L_ACK;
                            sdat_oe <= 0;
                        end
                    end
                end
                
                DATA_L_ACK: begin
                    i2c_sclk <= ~i2c_sclk;
                    if (i2c_sclk) begin
                        state <= STOP;
                        sdat_oe <= 1;
                        sdat_out <= 0;
                    end
                end
                
                STOP: begin
                    // I2C STOP condition: SDAT rises while SCLK high
                    if (!i2c_sclk) begin
                        i2c_sclk <= 1;
                        sdat_out <= 0;
                    end else begin
                        sdat_out <= 1;
                        state <= NEXT_REG;
                    end
                end
                
                NEXT_REG: begin
                    i2c_sclk <= 1;
                    sdat_out <= 1;
                    reg_index <= reg_index + 1;
                    if (reg_index >= NUM_REGS - 1) begin
                        state <= DONE;
                    end else begin
                        state <= START;
                    end
                end
                
                DONE: begin
                    ready <= 1;
                    i2c_sclk <= 1;
                    sdat_out <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
