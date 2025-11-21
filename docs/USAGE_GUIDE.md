# Audio Visualizer Usage Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Hardware Setup](#hardware-setup)
3. [Software Setup](#software-setup)
4. [Programming the FPGA](#programming-the-fpga)
5. [Operation](#operation)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Features](#advanced-features)

---

## Getting Started

### Prerequisites
- **Hardware**: Terasic DE10-Standard FPGA Development Board
- **Software**: Intel Quartus Prime Lite Edition (18.1 or later)
- **Accessories**: 
  - USB Blaster cable (for programming)
  - Microphone or audio source
  - 3.5mm audio cable (if using line-in)

### Quick Start
1. Open `audio_visualizer.qpf` in Quartus
2. Compile the project (Processing → Start Compilation)
3. Program the FPGA (Tools → Programmer)
4. Connect audio input to MIC-IN
5. Observe LED bar graph responding to audio

---

## Hardware Setup

### Board Connections

#### Power
1. Connect 12V DC power supply to the board
2. Turn on the power switch
3. Verify the green power LED is illuminated

#### Audio Input
Two options for audio input:

**Option 1: Microphone Input (Recommended)**
- Connect a microphone to the **MIC-IN** (pink) 3.5mm jack
- The WM8731 codec has built-in mic boost enabled
- Optimal for voice and acoustic instruments

**Option 2: Line Input**
- Connect audio source to **LINE-IN** (blue) 3.5mm jack
- Suitable for pre-amplified audio sources
- May require adjustment to WM8731 configuration

#### Programming Connection
1. Connect USB Blaster cable between PC and board
2. The JTAG connector is located near the center of the board
3. Install USB Blaster drivers if not already installed

### Board Layout Reference

```
DE10-Standard Board (Top View)
┌────────────────────────────────────────┐
│                                        │
│  [LEDR 9-0]  ←  LED Bar Graph          │
│                                        │
│  [SW 1-0]    ←  Channel Select         │
│                                        │
│  [KEY 0]     ←  Reset Button           │
│                                        │
│  MIC-IN  🎤  ←  Microphone Input       │
│  LINE-IN 🔌  ←  Line Input             │
│  LINE-OUT 🔊 ←  Headphone Output       │
│                                        │
│  [USB]       ←  USB Blaster            │
│                                        │
└────────────────────────────────────────┘
```

---

## Software Setup

### Installing Quartus Prime

1. Download Quartus Prime Lite from Intel FPGA website
2. Install Quartus Prime and Cyclone V device support
3. Install USB Blaster II drivers (included with Quartus)

### Opening the Project

1. Launch Quartus Prime
2. File → Open Project
3. Navigate to `audio_visualizer.qpf`
4. Click Open

### Project Structure

```
audio_visualizer/
├── audio_visualizer.qpf      # Project file
├── audio_visualizer.qsf      # Settings and pin assignments
├── audio_visualizer.sdc      # Timing constraints
├── rtl/                      # Verilog source files
│   ├── audio_visualizer_top.v
│   ├── i2c_master.v
│   ├── i2s_receiver.v
│   ├── audio_processor.v
│   └── pll_audio.v
├── docs/                     # Documentation
│   ├── PIN_ASSIGNMENTS.md
│   ├── MODULE_DESCRIPTIONS.md
│   └── USAGE_GUIDE.md
└── README.md
```

---

## Programming the FPGA

### Compilation

1. **Start Compilation**:
   - Processing → Start Compilation
   - Or click the "Play" button in toolbar
   - Wait for compilation to complete (~2-5 minutes)

2. **Check Results**:
   - Look for "Quartus Prime Fitter was successful" message
   - Review timing analysis (should meet all constraints)
   - Check resource utilization in Compilation Report

3. **Compilation Outputs**:
   - `output_files/audio_visualizer.sof` - Programming file
   - Compilation report in `output_files/` directory

### Programming Steps

1. **Open Programmer**:
   - Tools → Programmer
   - Or click the "Programmer" icon

2. **Setup Hardware**:
   - Click "Hardware Setup"
   - Select "USB-Blaster [USB-0]"
   - Click "Close"

3. **Load Programming File**:
   - Click "Add File"
   - Navigate to `output_files/audio_visualizer.sof`
   - Check the "Program/Configure" checkbox

4. **Program Device**:
   - Click "Start"
   - Wait for progress bar to complete
   - Look for "100% (Successful)" message

### Verification

After programming:
1. All LEDs should turn off initially
2. Press and release KEY[0] (reset) if needed
3. Wait ~100ms for initialization
4. LEDs should respond to audio input

---

## Operation

### Basic Operation

1. **Power On**: Ensure board is powered
2. **Reset**: Press KEY[0] to reset the system
3. **Audio Input**: Speak into microphone or play audio
4. **Observe**: LED bar graph displays audio amplitude

### LED Bar Graph Interpretation

```
┌─────────────────────────────────────┐
│ LEDR[9] ██ ← Highest amplitude      │
│ LEDR[8] ██                           │
│ LEDR[7] ██                           │
│ LEDR[6] ██                           │
│ LEDR[5] ██   Medium amplitude        │
│ LEDR[4] ██                           │
│ LEDR[3] ██                           │
│ LEDR[2] ██                           │
│ LEDR[1] ██                           │
│ LEDR[0] ██ ← Lowest amplitude        │
└─────────────────────────────────────┘
```

### Channel Selection (Switches)

Use SW[1:0] to select visualization channel:

| SW[1] | SW[0] | Mode | Description |
|-------|-------|------|-------------|
| 0 | 0 | Left | Display left channel only |
| 0 | 1 | Right | Display right channel only |
| 1 | 0 | Average | Display average of both channels |
| 1 | 1 | Maximum | Display maximum of both channels |

**Recommendations:**
- For mono microphone: Use any mode (all equivalent)
- For stereo input: Use "Maximum" or "Average" mode
- For testing specific channel: Use "Left" or "Right"

### Reset Procedure

**When to reset:**
- After power-on
- If LEDs appear stuck
- After changing configuration
- For troubleshooting

**How to reset:**
1. Press and hold KEY[0]
2. Release KEY[0]
3. Wait 100ms for system initialization
4. Normal operation resumes

---

## Troubleshooting

### No LED Response

**Symptom**: LEDs don't light up with audio input

**Possible Causes & Solutions**:

1. **No Audio Input**
   - Check microphone connection
   - Verify audio cable is plugged into correct jack
   - Test with different audio source

2. **Configuration Issue**
   - Press KEY[0] to reset
   - Reprogram the FPGA
   - Check I2C signals with SignalTap

3. **Threshold Too High**
   - Increase audio volume
   - Speak louder or closer to microphone
   - Verify threshold values in `audio_processor.v`

4. **PLL Not Locked**
   - Check CLOCK_50 input
   - Verify PLL configuration
   - Monitor `pll_locked` signal

### LEDs Always On

**Symptom**: All LEDs continuously lit

**Solutions**:
- Check for noise on audio input
- Verify ground connections
- Reset the system
- Check for stuck bits in audio data path

### Erratic LED Behavior

**Symptom**: LEDs flicker randomly or don't follow audio

**Solutions**:
1. Verify I2S clock signals (BCLK, LRCLK)
2. Check clock domain crossing synchronizers
3. Increase peak hold time
4. Add averaging to audio processor

### Compilation Errors

**Common Issues**:

1. **Missing Files**
   - Verify all Verilog files are in `rtl/` directory
   - Check `.qsf` file includes all source files

2. **Pin Assignment Errors**
   - Verify pin assignments match your board revision
   - Consult DE10-Standard User Manual
   - Check for pin conflicts

3. **Timing Violations**
   - Review timing report
   - Adjust clock constraints in `.sdc` file
   - Enable physical synthesis options

### Programming Issues

**USB Blaster Not Detected**:
1. Reconnect USB cable
2. Reinstall drivers
3. Check Device Manager (Windows)
4. Try different USB port

**Programming Fails**:
1. Verify power is on
2. Check JTAG connection
3. Try different programming file
4. Update Quartus version

---

## Advanced Features

### Using SignalTap Logic Analyzer

**Setup**:
1. Tools → SignalTap II Logic Analyzer
2. Add signals to monitor:
   - `i2c_inst|state`
   - `i2s_inst|sample_valid`
   - `proc_inst|amplitude`
   - `led_level`
3. Set trigger conditions
4. Compile and program
5. Run acquisition

**Use Cases**:
- Debug I2C configuration
- Verify I2S timing
- Monitor audio samples
- Tune threshold levels

### Customizing Thresholds

Edit `rtl/audio_processor.v` to adjust LED sensitivity:

```verilog
// Original thresholds
(peak_hold[23:14] > 10'd800): led_level <= 10'b1111111111;
(peak_hold[23:14] > 10'd700): led_level <= 10'b0111111111;
// ... etc

// More sensitive (lower values)
(peak_hold[23:14] > 10'd400): led_level <= 10'b1111111111;
(peak_hold[23:14] > 10'd350): led_level <= 10'b0111111111;
// ... etc
```

After changes:
1. Save file
2. Recompile project
3. Reprogram FPGA

### Modifying Peak Hold Time

Adjust decay time in `audio_processor.v`:

```verilog
// Faster decay (shorter hold)
parameter PEAK_DECAY_TIME = 2400;  // 0.05s

// Slower decay (longer hold)
parameter PEAK_DECAY_TIME = 9600;  // 0.2s
```

### Changing Sample Rate

To use different sample rate (e.g., 96kHz):

1. Modify I2C register R8 in `i2c_master.v`:
   ```verilog
   config_data[8] = 16'h101C; // R8: 96kHz USB mode
   ```

2. Update PLL frequency for new rate:
   - 96kHz: Use 24.576 MHz
   - 32kHz: Use 8.192 MHz

3. Adjust peak decay time accordingly

### Adding Features

**Suggested Enhancements**:
1. **Stereo Visualization**: Use separate LED groups for L/R
2. **Color LEDs**: Add RGB LED support for frequency bands
3. **VGA Output**: Display waveform on monitor
4. **Recording**: Store samples to SDRAM
5. **FFT Analysis**: Frequency spectrum visualization

---

## Performance Specifications

### System Characteristics
- **Audio Codec**: WM8731
- **Sample Rate**: 48 kHz
- **Bit Depth**: 24-bit
- **Channels**: Stereo (L+R)
- **Latency**: <1ms
- **LED Update Rate**: 48 kHz

### Resource Utilization (Typical)
- **Logic Elements**: ~500 / 41,910 (<2%)
- **Registers**: ~400
- **Memory Bits**: Minimal
- **PLLs**: 1 / 6
- **I/O Pins**: 17

### Timing Performance
- **Fmax (system clock)**: >100 MHz (50 MHz required)
- **Setup Slack**: Positive
- **Hold Slack**: Positive

---

## Safety and Precautions

### Electrical
- Use proper 12V DC power supply only
- Don't hot-plug audio cables
- Avoid ESD - ground yourself before touching board

### Audio Levels
- Start with low volume, increase gradually
- Avoid extremely loud sounds near microphone
- Use appropriate gain settings

### General
- Don't block board ventilation
- Keep liquids away from electronics
- Store in anti-static bag when not in use

---

## Additional Resources

### Documentation
- WM8731 Datasheet: [Cirrus Logic website]
- DE10-Standard User Manual: [Terasic website]
- Quartus Prime Handbook: [Intel FPGA website]

### Support
- Terasic Forum: http://forum.terasic.com
- Intel FPGA Forum: https://forums.intel.com/s/topic/0TO0P000000MWIDWA4/intel-fpgas
- Project Repository: [Your GitHub URL]

### Learning Resources
- I2C Protocol Tutorial
- I2S Audio Format Specification
- FPGA Design Best Practices
- Digital Signal Processing Basics

---

## Appendix

### Test Checklist

Before first use:
- [ ] Power supply connected and correct voltage
- [ ] USB Blaster drivers installed
- [ ] Quartus project opens without errors
- [ ] Compilation completes successfully
- [ ] Programming completes successfully
- [ ] Power LED on board is lit
- [ ] Audio input connected
- [ ] Reset button (KEY[0]) tested

During operation:
- [ ] LEDs respond to audio input
- [ ] LED pattern follows amplitude changes
- [ ] Switch selection changes behavior
- [ ] Reset restores normal operation
- [ ] No LEDs stuck on/off

### Command Reference

**Quartus TCL Console Commands**:
```tcl
# Compile project
execute_flow -compile

# Program device
quartus_pgm -m jtag -o "p;output_files/audio_visualizer.sof"

# Check timing
report_timing -setup -npaths 10

# Resource utilization
report_resources
```

### Version History

- **v1.0** - Initial release with basic functionality
  - I2C configuration
  - I2S receiver
  - LED bar graph visualization
  - Peak hold algorithm
  - Channel selection

---

*For questions or issues, please refer to the project documentation or contact support.*
