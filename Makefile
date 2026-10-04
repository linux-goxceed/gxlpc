SDCC ?= sdcc
MAKEBIN ?= makebin

TARGET := gx6702-lpc
CFLAGS := -mmcs51 --model-small --iram-size 0x100 --xram-loc 0x0100 \
	--xram-size 0x0200 --code-size 0x2000 --out-fmt-ihx

SOC ?= gx6702

SUPPORTED_SOCS := gx6702 gx6706

ifeq ($(filter $(SOC),$(SUPPORTED_SOCS)),)
$(error unsupported SOC '$(SOC)' (expected one of: $(SUPPORTED_SOCS)))
endif

ifeq ($(SOC),gx6706)
	CFLAGS += -DSOC_GX6706
	TARGET := gx6706-lpc
else
	TARGET := gx6702-lpc
endif

.PHONY: all clean

all: $(TARGET).bin

$(TARGET).ihx: firmware.c mailbox.h
	$(SDCC) $(CFLAGS) -o $@ firmware.c

$(TARGET).bin: $(TARGET).ihx
	$(MAKEBIN) -p -s 0x2000 $< $@

clean:
	rm -f gx6702-lpc.asm gx6702-lpc.bin gx6702-lpc.ihx gx6702-lpc.lk \
		gx6702-lpc.lst gx6702-lpc.map gx6702-lpc.mem gx6702-lpc.rel \
		gx6702-lpc.rst gx6702-lpc.sym gx6706-lpc.asm gx6706-lpc.bin \
		gx6706-lpc.ihx gx6706-lpc.lk gx6706-lpc.lst gx6706-lpc.map \
		gx6706-lpc.mem gx6706-lpc.rel gx6706-lpc.rst gx6706-lpc.sym 