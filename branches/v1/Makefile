PK2CMD = pk2cmd -PPIC18F2550
PROCESSOR = 18f2550
PROCESSOR_SIM = 18f2455
SDCC = /opt/local/bin/sdcc
GPLINK = /opt/local/bin/gplink
GPASM = /opt/local/bin/gpasm
GPSIM =/usr/local/bin/gpsim

all:	open_lock
sim:	open_lock_sim

open_lock: open_lock.c
	$(SDCC) \
	--verbose \
	-V \
	-mpic16 \
	--use-crt=crt0.o \
	--use-non-free \
	-p$(PROCESSOR) \
	-Wl '-m -s18f2550.lkr' \
	$<
#	-I"./" uart.o \

open_lock_master: open_lock_master.c
	$(SDCC) \
	--verbose \
	-V \
	-mpic16 \
	--use-crt=crt0.o \
	--use-non-free \
	-p$(PROCESSOR) $<

open_lock_sim: open_lock.c
	$(SDCC) \
	--verbose \
	-V \
	-mpic16 \
	--use-crt=crt0.o \
	--use-non-free \
	-p$(PROCESSOR_SIM) \
	-Wl '-m -s18f2550.lkr' \
	$<
#	-I"./" uart.o \

open_lock.hex: open_lock.o
	$(GPLINK) \
	-c \
	-o $@ \
	-m \
	-r \
	-d \
	open_lock open_lock.o crt0.o \
	$^


open_lock.o: open_lock.asm
	$(GPASM) \
	--extended \
	-pp$(PROCESSOR) \
	-c $<

open_lock.asm: open_lock.c
	$(SDCC) \
	-V \
	--verbose \
	-S \
	--debug \
	-mpic16 \
	--use-crt=crt0.o \
	--use-non-free \
	-p$(PROCESSOR) $<

clean:
	rm -f *.adb *.asm *.cod *.cof *.hex *.lst *.map *.o *.sym *.lib

sim:
	$(GPSIM) -pp$(PROCESSOR_SIM) -c open_lock.stc -s open_lock.cod open_lock.asm && killall -9 X11.bin

flash:
	$(PK2CMD) -F open_lock.hex -M

flash_master:
	$(PK2CMD) -F open_lock_master.hex -M

on:
	$(PK2CMD) -R -T

off:
	$(PK2CMD) -R

