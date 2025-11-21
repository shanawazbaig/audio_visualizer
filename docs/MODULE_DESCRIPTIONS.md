# Module Descriptions

## System Architecture

The Audio Visualizer system consists of five main modules integrated in a top-level design:

```
┌─────────────────────────────────────────────────────────────┐
│                  audio_visualizer_top                        │
│                                                               │
│  ┌──────────┐    ┌───────────┐    ┌─────────────┐          │
│  │   PLL    │───▶│ I2C Master│───▶│   WM8731    │          │
│  │ 12.288MHz│    │           │    │   Codec     │          │
│  └──────────┘    └───────────┘    └──────┬──────┘          │
│                                           │                  │
│                                     ┌─────▼─────┐           │
│                                     │    I2S    │           │
│                                     │  Receiver │           │
│                                     └─────┬─────┘           │
│                                           │                  │
│                                     ┌─────▼─────┐           │
│                                     │   Audio   │           │
│                                     │ Processor │           │
│                                     └─────┬─────┘           │
│                                           │                  │
│                                     ┌─────▼─────┐           │
│                                     │    LED    │           │
│                                     │   Array   │           │
│                                     └───────────┘           │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. audio_visualizer_top.v

**Purpose**: Top-level module that integrates all sub-modules and manages board-level I/O

**Key Features:**
- Instantiates and connects all sub-modules
- Manages reset logic synchronized with PLL lock
- Controls I2C configuration startup sequence
- Maps physical pins to logical signals

**Ports:**
- **Inputs**: CLOCK_50, KEY[0], AUD_BCLK, AUD_ADCLRCK, AUD_ADCDAT, SW[1:0]
- **Outputs**: AUD_XCK, LEDR[9:0], AUD_DACLRCK, AUD_DACDAT
- **Inouts**: FPGA_I2C_SDAT

**Parameters:**
- `STARTUP_DELAY_CYCLES`: 2,500,000 cycles (50ms delay before I2C init)

**State Management:**
- Implements startup delay after PLL lock
- Triggers one-time I2C configuration
- Monitors configuration completion

---

## 2. pll_audio.v

**Purpose**: Clock generator for audio master clock

**Functionality:**
- Generates 12.288 MHz audio master clock from 50 MHz input
- Provides PLL lock signal for system initialization
- Feeds AUD_XCK output to WM8731 codec

**Implementation Notes:**
- **Current**: Simplified placeholder divider for initial testing
- **Production**: Should be replaced with Intel ALTPLL IP core
- **Configuration**: Input 50 MHz → Output 12.288 MHz
- **Ratio**: Division by ~4.069

**Ports:**
- `inclk0`: 50 MHz input clock
- `areset`: Asynchronous reset
- `c0`: 12.288 MHz output clock
- `locked`: PLL lock indicator

**How to Generate ALTPLL:**
1. Open Quartus IP Catalog
2. Select "ALTPLL" under "Basic Functions > Clocks"
3. Set input frequency: 50 MHz
4. Set output c0: 12.288 MHz
5. Enable locked output
6. Generate and replace this module

---

## 3. i2c_master.v

**Purpose**: Configures WM8731 audio codec via I2C protocol

**Key Features:**
- Bit-banging I2C master implementation
- FSM-based state machine
- Automatic multi-register configuration sequence
- ACK detection (receives but doesn't verify)

**I2C Protocol Implementation:**
- **Clock**: ~100 kHz (derived from 50 MHz system clock)
- **Address**: 7-bit device address 0x1A + R/W bit
- **Data**: 16-bit configuration words (7-bit reg + 9-bit data)
- **Sequence**: START → ADDR+W → ACK → DATA_HIGH → ACK → DATA_LOW → ACK → STOP

**Configuration Registers:**
Configures 10 WM8731 registers in sequence:
1. R0: Left Line In
2. R1: Right Line In
3. R2: Left Headphone Out
4. R3: Right Headphone Out
5. R4: Analog Path (mic boost enabled)
6. R5: Digital Path
7. R6: Power Control
8. R7: Digital Interface Format (I2S, 24-bit)
9. R8: Sampling Rate (48 kHz)
10. R9: Active Control (enable interface)

**State Machine States:**
- IDLE: Waiting for enable signal
- START: Generate I2C START condition
- ADDR: Send device address + write bit
- ADDR_ACK: Wait for address ACK
- DATA_HIGH: Send upper byte
- DATA_H_ACK: Wait for data ACK
- DATA_LOW: Send lower byte
- DATA_L_ACK: Wait for data ACK
- STOP: Generate I2C STOP condition
- NEXT_REG: Advance to next register
- DONE: Configuration complete

**Ports:**
- `clk`: System clock (50 MHz)
- `reset_n`: Active-low reset
- `enable`: Start configuration
- `ready`: Configuration complete flag
- `i2c_sclk`: I2C clock output
- `i2c_sdat`: I2C bidirectional data

---

## 4. i2s_receiver.v

**Purpose**: Receives and deserializes I2S audio data from WM8731

**Key Features:**
- Clock domain crossing synchronization (3-stage)
- Edge detection for BCLK and LRCLK
- 24-bit serial-to-parallel shift register
- Separate left and right channel outputs
- Sample valid pulse generation

**I2S Protocol Details:**
- **Format**: Philips I2S standard
- **Word length**: 24 bits
- **Channel**: LRCLK low = left, high = right
- **Data timing**: MSB first, valid on BCLK rising edge
- **Frame**: 64 BCLK cycles per L+R sample pair

**Synchronization:**
- All external signals synchronized to system clock
- 3-stage synchronizer prevents metastability
- Edge detection on synchronized signals

**Operation:**
1. Synchronize BCLK, LRCLK, ADCDAT to system clock
2. Detect LRCLK transitions (channel switching)
3. Shift in 24 bits on each BCLK rising edge
4. Store completed sample when channel switches
5. Assert sample_valid when both channels ready

**Ports:**
- `clk`: System clock (50 MHz)
- `reset_n`: Active-low reset
- `aud_bclk`: Audio bit clock input (~3.072 MHz)
- `aud_adclrck`: Left/right clock input (~48 kHz)
- `aud_adcdat`: Serial audio data input
- `left_sample[23:0]`: Parallel left channel output
- `right_sample[23:0]`: Parallel right channel output
- `sample_valid`: Pulse when new samples ready

---

## 5. audio_processor.v

**Purpose**: Processes audio samples and generates LED visualization

**Key Features:**
- Absolute value computation for amplitude
- Multiple channel selection modes
- Peak hold with decay algorithm
- 10-level LED bar graph mapping
- Configurable thresholds

**Channel Selection Modes:**
- `00`: Left channel only
- `01`: Right channel only
- `10`: Average of both channels
- `11`: Maximum of both channels

**Processing Pipeline:**
1. **Input Selection**: Choose channel based on switches
2. **Absolute Value**: Convert signed to magnitude
3. **Peak Detection**: Track and hold peak values
4. **Peak Decay**: Gradual decrease over time
5. **Threshold Mapping**: Map amplitude to LED pattern

**Peak Hold Algorithm:**
- Captures peak amplitude
- Holds for ~0.1 seconds (4800 samples at 48 kHz)
- Gradual decay after hold time
- Provides more visible LED response

**LED Threshold Levels:**
Uses upper 10 bits of 24-bit sample [23:14]:
- 10 LEDs: amplitude > 800
- 9 LEDs: amplitude > 700
- 8 LEDs: amplitude > 600
- 7 LEDs: amplitude > 500
- 6 LEDs: amplitude > 400
- 5 LEDs: amplitude > 300
- 4 LEDs: amplitude > 200
- 3 LEDs: amplitude > 100
- 2 LEDs: amplitude > 50
- 1 LED: amplitude > 25
- 0 LEDs: amplitude ≤ 25

**Ports:**
- `clk`: System clock
- `reset_n`: Active-low reset
- `left_sample[23:0]`: Left channel input
- `right_sample[23:0]`: Right channel input
- `sample_valid`: New sample available
- `channel_select[1:0]`: Channel mode selection
- `led_level[9:0]`: LED bar graph output

**Parameters:**
- `PEAK_DECAY_TIME`: 4800 samples (~0.1s at 48kHz)

---

## Signal Flow

### Initialization Sequence:
1. System reset released
2. PLL locks and generates 12.288 MHz
3. 50ms startup delay
4. I2C configuration sequence (10 registers)
5. WM8731 codec activates
6. Audio processing begins

### Audio Processing Flow:
1. Microphone → WM8731 ADC
2. WM8731 → I2S data stream (BCLK, LRCLK, ADCDAT)
3. I2S Receiver → 24-bit samples (L+R)
4. Audio Processor → amplitude calculation
5. LED mapping → LEDR[9:0]

### Clock Domains:
- **System Domain (50 MHz)**: All processing and control
- **Audio Domain (12.288 MHz)**: WM8731 master clock
- **I2S Domain (~3 MHz)**: Audio bit clock (asynchronous)

---

## Timing Characteristics

### I2C Configuration:
- **Total time**: ~50ms startup delay + ~10ms config = ~60ms
- **Per register**: ~1ms (including overheads)

### Audio Latency:
- **Sample period**: 20.8 μs (48 kHz)
- **I2S synchronization**: 2-3 system clock cycles
- **Processing**: <1 clock cycle
- **Total latency**: <1ms

### LED Update Rate:
- Updates at audio sample rate: 48 kHz
- Visible persistence due to peak hold algorithm
- Decay smoothing prevents flickering

---

## Debug and Testing

### Recommended Debug Signals (SignalTap):
- `i2c_inst/state` - Monitor I2C state machine
- `i2c_inst/ready` - Configuration completion
- `i2s_inst/bit_count` - I2S shift counter
- `i2s_inst/sample_valid` - Sample timing
- `proc_inst/amplitude` - Computed amplitude
- `proc_inst/peak_hold` - Peak tracking
- `led_level` - LED output pattern

### Test Points:
- Verify PLL output: 12.288 MHz on AUD_XCK
- Check I2C traffic: SCLK ~100 kHz, proper START/STOP
- Monitor I2S clocks: BCLK ~3 MHz, LRCLK ~48 kHz
- Observe LED response to audio input

---

## Future Enhancements

### Possible Improvements:
1. **FFT-based frequency visualization**
2. **Multiple visualization modes** (VU meter, spectrum, etc.)
3. **Adjustable threshold calibration**
4. **Audio recording to on-board SDRAM**
5. **VGA output for graphical display**
6. **USB audio interface**
7. **Advanced peak detection algorithms**
8. **Multi-band visualization**
