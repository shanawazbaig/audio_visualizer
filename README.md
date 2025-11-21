# audio_visualizer
a quartus project on FPGA to visualize audio strength from line in
Below is a **clear, structured, engineering-grade Project Implementation Plan** for your FPGA Audio Visualizer project.
You can use this in your **lab report, project documentation, or viva presentation**.

---

# ✅ **PROJECT IMPLEMENTATION PLAN**

**Title:** Real-Time Audio Visualizer on FPGA Using WM8731 Audio Codec (DE10-Standard)

---

# 1. **Project Overview**

The objective is to design and implement a real-time audio amplitude visualizer on the DE10-Standard FPGA board.
The system captures live audio from the MIC-IN port through the WM8731 codec, processes the I²S digital audio stream inside the FPGA, computes amplitude, and displays it on LEDR[9:0].

---

# 2. **Implementation Stages**

---

## **Stage 1: Requirements Analysis**

### Tasks:

* Understand WM8731 codec datasheet
* Review DE10-Standard board schematic and pin assignments
* Confirm required FPGA interfaces:

  * I²C (to configure codec)
  * I²S (to receive audio samples)
  * MCLK (AUD_XCK) from FPGA → codec
  * LED outputs

### Deliverables:

* Pin mapping table (verified from manual)
* List of required FPGA modules
* Sample rate and clock plan (e.g., 48 kHz audio)

---

## **Stage 2: System Architecture Design**

### Tasks:

* Develop block diagram consisting of:

  * **PLL block** → generate AUD_XCK
  * **I²C Master** → write WM8731 registers
  * **I²S Receiver** → decode BCLK/LRCLK/ADCDAT
  * **Audio Processing** → absolute amplitude
  * **LED Visualizer** → map amplitude to LEDs
  * **Top-level integration**

### Deliverables:

* Architecture diagram
* Module interface definitions
* Top-level entity port list

---

## **Stage 3: Module Development**

### 3.1 PLL Clock Generator

* Use Intel ALTPLL IP
* Input: CLOCK_50
* Output: 12.288 MHz → AUD_XCK
* Connect pin AH30 for XCK

### 3.2 I²C Master Module

* FSM-based bit-banging or Avalon I²C IP
* Implement:

  * START, STOP, ACK check
  * 7-bit device address (0x1A)
  * WM8731 configuration sequence

    * Power-up sequence
    * Mic boost enable
    * ADC enable
    * I²S mode, 24-bit
    * Sample rate settings
    * Activate codec

### 3.3 I²S Receiver

* Synchronize BCLK, LRCLK, SD
* Shift 24-bit samples MSB-first
* Identify Left/Right channel
* Generate "sample_valid" pulse
* Output:

  * left_sample[23:0]
  * right_sample[23:0]

### 3.4 Audio Amplitude Processor

* Compute absolute value
* Compare against thresholds
* Generate 10-bit level pattern for LEDs

### 3.5 Top-Level Integration

* Instantiate all modules
* Wire pin-level signals
* Route module outputs to LEDR

### Deliverables:

* Verified Verilog modules for each block
* Synthesizable top-level design

---

## **Stage 4: Pin Assignment & Constraints**

### Tasks:

* Apply correct .qsf assignments for:

  * CLOCK_50
  * KEY0_n
  * AUD_BCLK
  * AUD_ADCLRCK
  * AUD_ADCDAT
  * I2C_SCLK
  * I2C_SDAT
  * LEDR[9:0]
  * AUD_XCK (PLL output)

* Apply .sdc timing:

  ```tcl
  create_clock -name CLOCK_50 -period 20.0 [get_ports CLOCK_50]
  ```

### Deliverables:

* Final `.qsf` and `.sdc` files

---

## **Stage 5: Simulation (Optional but Recommended)**

### Functional simulation:

* I²C register transaction testbench
* I²S sample shift-in simulation
* LED mapping from sample amplitude
* PLL functional simulation (a_stub model)

### Deliverables:

* Simulation waveforms for key modules

---

## **Stage 6: Hardware Testing**

### Step-by-step:

1. **Program FPGA** with .sof
2. Check **PLL output** on AUD_XCK using oscilloscope
3. Check **I²C traffic** using:

   * Oscilloscope
   * Logic analyzer
   * SignalTap
4. Confirm codec ACKs
5. Verify BCLK and LRCLK are running
6. Tap the microphone and observe LEDs
7. Tune thresholds if LEDs too sensitive / weak

### Deliverables:

* Captured oscilloscope screenshots (I2C, BCLK, ADCDAT, LRCLK)
* LED test video

---

## **Stage 7: Optimization**

### Tasks:

* Stability tuning: add sample averaging
* Implement peak-hold LED behavior
* Add switch to choose between:

  * Left / Right / Average
* Add FFT-based visualizer (optional advanced)

### Deliverables:

* Final improved FPGA bitstream
* Updated document

---

# 3. **Timeline (Simple Gantt-style)**

| Week | Task                                  |
| ---- | ------------------------------------- |
| 1    | Requirements, pin study, architecture |
| 2    | PLL + I²C Master implementation       |
| 3    | I²S receiver + testing                |
| 4    | Audio processing + LEDs               |
| 5    | Hardware integration & debugging      |
| 6    | Documentation & Optimization          |

---

# 4. **Expected Output**

* Working real-time audio visualizer
* LEDs respond to microphone input
* Stable and accurate I²S decoding
* Fully documented FPGA system

---

# 5. **Tools Used**

* Intel Quartus Prime Lite
* Intel Platform Designer (if using I²C IP)
* SignalTap Logic Analyzer
* DE10-Standard FPGA board
* Oscilloscope (optional but useful)

---

# 6. **Project Files**

* `audio_visualizer.qpf` - Quartus project file
* `audio_visualizer.qsf` - Pin assignments and settings
* `audio_visualizer.sdc` - Timing constraints
* `rtl/` - Verilog source files
  * `audio_visualizer_top.v` - Top-level module
  * `i2c_master.v` - I²C configuration module
  * `i2s_receiver.v` - I²S audio receiver
  * `audio_processor.v` - Audio amplitude processor
  * `pll_audio.v` - PLL clock generator (generated IP)

---

# 7. **Quick Start**

1. Open `audio_visualizer.qpf` in Quartus Prime
2. Compile the project
3. Program the FPGA with the generated `.sof` file
4. Connect a microphone to the MIC-IN port
5. Observe the LED bar graph responding to audio amplitude
