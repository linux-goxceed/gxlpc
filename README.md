# NationalChip GoXceed LPC firmware

This repository contains an SDCC-built firmware image for the NationalChip low-power
controller (an MCS-51/8051 core) within GoXceed SoC's such as the GX6702 used in the always-on LPC domain. 
It replaces parts of the vendor panel logic with an open implementation for display, RTC,
alarm, and soft-standby behavior.

## What it provides

- Text display and brightness control
- AUX output handling for the TM1650/HD2015 panel
- Scrollable message support
- RTC timekeeping with clock display modes
- One-shot alarm support
- Destructive standby and RTC wake paths for soft suspend
- HDMI CEC wake/sleep path for HDMI-CEC enabled displays (both sides)


## Supported SoC's

Currently only GX6702 and GX6706 are supported and tested, chances are it will work on other 
NationalChip SoC's as they reuse IP blocks across generations but may need
modifications to run it on other SoC's.

## Build

Install SDCC and run:

```sh
make
```

This will by default build for GX6702, to build for GX6706, run:
```sh
make SOC=gx6706
```

The build output is `gx6702-lpc.bin` (or `gx6706-lpc.bin` for GX6706), which is limited to the GX6702/GX6706
programming-port maximum of 8 KiB.

## Documentation

See [DOCUMENTATION.md](DOCUMENTATION.md) for the mailbox ABI, hardware notes,
implementation history, and the U-Boot command interface.
