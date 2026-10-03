# GX6702 LPC / 8051 low-power controller documentation

This document summarizes the current GX6702 firmware implementation for the
always-on LPC/8051 domain. It focuses on the practical interfaces exposed to
U-Boot, the mailbox ABI, the recovered hardware mapping, and the key behavior
observed during bring-up and testing.

## Project overview

The firmware in this repository targets the GX6702 low-power controller, an
MCS-51/8051-based companion core used in the panel/LPC domain. The open image
provides a documented implementation of the display, RTC, alarm, and standby
logic that the vendor firmware previously handled in binary form.

## Current capabilities

The current firmware supports:

- Text display updates and brightness control
- AUX0..AUX3 output handling for the TM1650 compatible front panel (including clones such as HD2015)
- Scrollable message presentation
- RTC timekeeping and `HH:MM` / `HH:MM:SS` display behavior
- A one-shot alarm with arm, trigger, and acknowledge/cancel paths
- Destructive soft-standby entry with button, IR, or RTC wake support

## Implementation history

The ABI evolution is summarized below:

- ABI 1.0: initial cold-start tested image with text, brightness, AUX control,
  mailbox acknowledgement, and responsive U-Boot operation.
- ABI 1.1: added scrolling and mailbox-position handling.
- ABI 1.2: added vendor-derived Timer 1 timekeeping and `HH:MM` display mode.
- ABI 1.3: added a sequence-numbered one-shot software alarm.
- ABI 1.4: corrected the interpretation of the stock wake counter and stabilized
  the destructive standby path.
- ABI 1.5: reuses the mailbox wake-seconds and alarm fields for soft-standby
  RTC cold-boot support (`gxlp sleep for` and `gxlp sleep until`).
- ABI 1.6: adds suspend-control bit 3, which keeps SFR `0x93` bit 1 clear so
  the 8051 RTC, front panel and IR decoder remain clocked during CK610 STOP.
- ABI 1.7: makes intentional wake atomic by setting SFR `0x93` bits 1 and 2
  together, producing the required cold-boot transition from live-8051 mode.
- ABI 1.8: adds HDMI CEC. Shared `cecmode` is the 32-bit word at offset `0x90`
  (`0xa4d00090`). Mailbox `+104` is the opcode, `+105` the sequence, and `+106`
  the firmware ack. Suspend with mode 1 or 2 posts System Standby (`0x36`).
  Mode 1 posts Image View On (`0x04`) before a panel, IR, or RTC cold boot.
  The image does not post standby when it starts. CEC is not a CK610 wake source.
- ABI 1.9: adds a RAM-only wake block at `+108`. The panel byte is the TM1650
  scan code (`0` keeps `0x4f`). `+109` is the sequence, `+110` the ack, `+111`
  the extra-IR count, and `+112..+119` up to four little-endian NEC codes.
  Loading the LPC image clears this block.

## Hardware recovered from the vendor image

- HD2015/TM1650 CLK: 8051 P1.5, logical GPIO 13
- HD2015/TM1650 DAT: 8051 P1.6, logical GPIO 14
- P1 GPIO mux/output registers: SFR `0x9f` and SFR `0x9b`
- PMU power-cut control: logical GPIO 12 / P1.4, active level 0
- Required GPIO-domain setup: SFR `0x93 = 1`
- TM1650 control address: `0x48`
- TM1650 grid addresses: `0x68`, `0x6a`, `0x6c`, `0x6e`

## Mailbox ABI 1.9

The 8051 XDATA mailbox starts at offset `0x0100`, which maps to CK610 address
`0xa4d00100`.

| Offset | Owner | Meaning |
| ---: | --- | --- |
| `+0` | CK610/8051 | Update bit; CK610 sets bit 0, 8051 clears it |
| `+1..+4` | CK610 | Four raw seven-segment bytes |
| `+5` | CK610 | Raw TM1650 control byte |
| `+6` | CK610 | AUX0..AUX3 mask, routed to grid dot outputs |
| `+7` | CK610 | Reserved; write zero |
| `+8` | 8051 | Status: `0x42` booting, `0xa5` ready |
| `+9..+10` | 8051 | ABI major/minor (`1.9`) |
| `+11` | 8051 | Capabilities: display, brightness, AUX, scrolling, RTC, alarm, suspend |
| `+12` | 8051 | Acknowledged-update counter |
| `+13` | 8051 | Last error; currently zero |
| `+14..+15` | 8051 | Reserved |
| `+16` | CK610 | Encoded message length, maximum 32 characters |
| `+17` | CK610 | Scrolling flags; bit 0 enables scrolling |
| `+18` | CK610 | Approximate scroll-period units |
| `+19` | 8051 | Current scrolling position |
| `+20..+51` | CK610 | Encoded segment stream |
| `+52` | CK610 | RTC control: bit 0 clock display, bit 1 set-time valid |
| `+53` | CK610 | Set-time sequence; a changed value requests a new time |
| `+54..+56` | CK610 | Set hour, minute, second in binary |
| `+57..+59` | CK610 | Reserved |
| `+60..+62` | 8051 | Current hour, minute, second |
| `+63` | 8051 | RTC status: running, clock display, valid time |
| `+64..+65` | 8051 | 16-bit day counter since the last set-time request |
| `+66` | 8051 | Acknowledged set-time sequence |
| `+67` | 8051 | RTC/alarm snapshot generation; even is stable, odd is busy |
| `+68` | CK610 | Alarm control: bit 0 arms a one-shot alarm; zero cancels |
| `+69` | CK610 | Alarm sequence; a changed value applies arm/cancel |
| `+70..+72` | CK610 | Alarm hour, minute, second in binary |
| `+73..+75` | CK610 | Reserved |
| `+76` | 8051 | Alarm status: bit 0 armed, bit 1 active |
| `+77..+79` | 8051 | Configured alarm hour, minute, second |
| `+80` | 8051 | Acknowledged alarm sequence |
| `+81` | 8051 | Wrapping trigger counter |
| `+82..+83` | 8051 | Reserved |
| `+84` | CK610 | Suspend control: bit 0 request, bit 1 RTC wake (with bit 2), bit 2 soft standby, bit 3 keep 8051 clocked |
| `+85` | CK610 | Suspend sequence; a changed value requests evaluation |
| `+86..+87` | CK610 | Destructive guards, exactly `0x47`, `0x58` |
| `+88..+91` | CK610 | Reserved; `0` = TM1650 wake key (default `0x4f`), rest zero |
| `+92` | 8051 | Suspend status: bit 0 prepared, bit 1 rejected |
| `+93` | 8051 | Acknowledged suspend sequence |
| `+94` | 8051 | Suspend error code |
| `+95` | 8051 | Reserved |
| `+96..+99` | CK610/8051 | Soft-standby wake countdown seconds (LE); `0` uses an armed absolute alarm |
| `+104` | CK610 | CEC opcode. ABI 1.8. A changed `+105` posts it; `0` only acks |
| `+105` | CK610 | CEC sequence |
| `+106` | 8051 | Acknowledged CEC sequence |
| `+107` | — | Reserved; write zero |
| `+108` | CK610 | ABI 1.9 panel wake scan code; `0` keeps `0x4f` |
| `+109` | CK610 | Wake-config sequence; a changed value applies `+108` and `+112..+119` |
| `+110` | 8051 | Acknowledged wake-config sequence |
| `+111` | CK610 | Extra NEC count, 0..4 |
| `+112..+119` | CK610 | Up to four extra little-endian NEC codes |

`cecmode` is not in this mailbox. It is the 32-bit word at shared offset `0x90`
(`0xa4d00090`). Mode 0 leaves P0.5 alone. Mode 1 or 2 connects P0.5 to the LPC
CEC engine.

## Firmware behavior

### Display and text rendering

Messages of four characters or fewer use the direct static path. Longer
messages scroll automatically on the 8051; the first four characters appear
immediately, the window advances left, and four blank positions separate
repeats. Dots modify the preceding character and do not consume one of the 32
visible positions.

### RTC and alarm

The RTC follows the vendor implementation: Timer 1 runs in 16-bit mode from
the 27 MHz LPC clock, reloads `0xa828` at roughly 100 Hz, and rolls a binary
`HH:MM:SS` counter after 100 ticks. Clock-display mode renders `HH:MM` and
blinks the confirmed AUX1 colon once per second. Timekeeping continues when
clock display is disabled.

The alarm compares its binary `HH:MM:SS` against the RTC after each one-second
increment. A match disarms the one-shot, increments the trigger counter, and
keeps the alert latched until it is acknowledged. The panel alternates between
the clock and `ALrt`; on the `ALrt` phase it forces the green status-bar group
and power indicator on.

### Standby and suspend

Normal display, RTC, and alarm commands do not disturb the CK610. ABI 1.6 bit 3
supports a live-8051 soft-standby path: CK610 executes STOP from on-chip SRAM,
but both LPC power-control bits remain clear. The physical power button, a
matching IR power code, or an RTC wake can then request a cold boot.

For live-8051 standby, the firmware writes zero to the vendor automatic-
suspend counter at XDATA `0x0004`, shows `HH:MM` with the power indicator,
keeps SFR `0x93` bits 1 and 2 clear, and continues its Timer1/panel loop. It
preserves the stock GPIO 11 retention state and applies the LXDVB501
`powercut="12,0"` setup. An accepted panel, IR or RTC wake event publishes the
suspend reason and asserts bit 2 to cold-boot the main SoC. With no wake
override, either stock power press cold-boots: `0x4f` (released `0x0f`) or
`0x77` (released `0x37`). The released codes are not wake events. HD2015 is
read with command `0x49`. FD650B is read with command `0x4F`; command `0x49`
is not a key read on that chip and latches a dim mode byte, so the firmware
probes `0x4F` once and then uses only the command that answered.

ABI 1.8 CEC follows that same wake. With `cecmode` 1 or 2, entering standby
posts System Standby (`0x36`). With mode 1, the wake path posts Image View On
(`0x04`) and then cold-boots. Mode 0 does not touch the CEC pin. A CEC frame
does not cold-boot the CK610 by itself. The `+108` wake block is RAM-only and
is cleared each time the LPC image is loaded.

### Front-panel input/output

IR is NEC on GPIO0 / P0.0. Raw `(addr << 8) | cmd` values differ across
NationalChip remotes even when they share the same eCos `keymap.xml` content.
The tested LXDVB104 panel maps the AUX bits as follows:

| AUX bit / mask | LXDVB104 function |
| ---: | --- |
| AUX0 / `0x1` | Unconnected or not visibly exposed |
| AUX1 / `0x2` | Clock separator `:` |
| AUX2 / `0x4` | Complete green status-bar group |
| AUX3 / `0x8` | Power light |

Mask `0x6` lights both the clock separator and the status-bar group.

## U-Boot command interface

The documented U-Boot commands are:

```text
hd2015             # auto-start open LPC if needed; display boot
hd2015 1234        # update four static digits
hd2015 "test 123"  # scroll up to 32 encoded characters
hd2015 -w 1234     # explicit update form
hd2015 -b 0..8     # off through maximum brightness
hd2015 -i 0..15    # raw AUX0..AUX3 bit mask
hd2015 -c 0|1      # clock separator
hd2015 -s 0|1      # complete green status-bar group
hd2015 -p 0|1      # power light
hd2015 -k 0|1      # disable/enable clock display without stopping time
gxlp rtc          # read current 8051 time/status
gxlp rtc 12:34:56 # set time and enter HH:MM clock mode
gxlp alarm 12:35:00 # arm a one-shot alarm
gxlp alarm off    # acknowledge/cancel alarm
gxlp sleep button # DESTRUCTIVE: indefinite standby; button/IR cold-boots
gxlp sleep until 07:00 # DESTRUCTIVE: sleep now; cold-boot at RTC time
gxlp sleep for 60  # DESTRUCTIVE: sleep now; cold-boot after 60s
gxlp sleep after 30 # wait 30s awake, then indefinite soft standby
gxlp keys         # probe TM1650 keyscan + NEC IR
gxlp start        # diagnostic: force open LPC reload
gxlp vendor panel # diagnostic: patched vendor image
gxlp vendor autosuspend 15 # diagnostic stock oracle
gxlp dump         # diagnostic: shared XDATA snapshot
```

Important notes:

- Plain `hd2015 [text]` owns the display path and auto-starts the open LPC
  image when it is not already running.
- RTC, alarm, and soft-standby logic live under `gxlp`.
- Destructive standby is irreversible and should be used only with care.
- The `gxlp vendor autosuspend` path is a reverse-engineering oracle rather than
  a normal feature.

## Reverse-engineering notes

The earlier analysis found that the vendor firmware uses a destructive suspend
path that is not a simple post-suspend wake timer. The open firmware therefore
focuses on the same board-specific power-cut setup and the CK610 handoff
sequence, rather than on a conventional wake-delay model.

Notable observations from the investigation:

- The vendor wake-counter semantics are not a post-suspend wake delay; they are
  an embedded awake-time counter.
- The destructive suspend entry depends on the CK610 STOP handoff and related
  platform state, not just the 8051-side register writes.
- The board-specific power-cut setup uses the LXDVB501 `powercut="12,0"`
  configuration.
- The LPC domain can survive a main-CPU/DTR reset, so a running 8051 image
  should not be replaced during a warm reset; cold-power the box first.

## Practical caveats

- `hd2015 -S button` requires ABI 1.4 suspend capability and both destructive
  guard bytes before the 8051 will accept the request.
- If button wake fails, remove power, restart the Python BootROM flasher if
  needed, and re-upload U-Boot from a true cold state.
- The display cache starts as `boot`, so indicator-only or brightness-only
  commands issued before the first text update do not republish four blank
  segment bytes.
