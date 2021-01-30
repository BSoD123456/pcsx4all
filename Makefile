TARGET = pcsx4all/pcsx4all.dge
PORT   = sdl
#A320   = 1
#GCW0   = 1
RS97   = 1

# Using 'gpulib' adapted from PCSX Rearmed is default, specify
# USE_GPULIB=0 as param to 'make' when building to disable it.
USE_GPULIB ?= 1

#GPU = gpu_dfxvideo
#GPU = gpu_drhell
#GPU = gpu_null
GPU  = gpu_unai
SPU  = spu_pcsxrearmed

CHAINPREFIX := /home/tring/retrofw/rs97tools_master
CROSS_COMPILE := $(CHAINPREFIX)/usr/bin/mipsel-linux-

CC = $(CROSS_COMPILE)gcc
CXX = $(CROSS_COMPILE)g++
STRIP = $(CROSS_COMPILE)strip

RECOMPILER = mips

RM     = rm -f
MD     = mkdir
LD     = $(CXX)

SYSROOT     := $(shell $(CC) --print-sysroot)
SDL_CONFIG  := $(SYSROOT)/usr/bin/sdl-config
SDL_CFLAGS  := $(shell $(SDL_CONFIG) --cflags)
SDL_LIBS    := $(shell $(SDL_CONFIG) --libs)

MCD1_FILE = \"mcd001.mcr\"
MCD2_FILE = \"mcd002.mcr\"

C_ARCH = -mips32 -DDYNAREC_SKIP_DCACHE_FLUSH -DTMPFS_MIRRORING -DTMPFS_DIR=\"/tmp\" -DRS97
OPTS = -O2 -mno-fp-exceptions -mframe-header-opt -mno-check-zero-division -fno-signed-zeros -fno-trapping-math -mno-interlink-compressed -fno-caller-saves -flto

# CFLAGS = $(C_ARCH) -fno-common -mno-abicalls -fno-PIC -fdata-sections -ffunction-sections $(OPTS) -DGCW_ZERO \

CFLAGS = $(C_ARCH) -fno-common -mno-abicalls -fno-PIC -fdata-sections -ffunction-sections $(OPTS) -DGCW_ZERO \
	-Wall -Wunused -Wpointer-arith \
	-Wno-sign-compare -Wno-cast-align \
	-Isrc -Isrc/spu/$(SPU) -D$(SPU) -Isrc/gpu/$(GPU) \
	-Isrc/port/$(PORT) \
	-Isrc/plugin_lib -Isrc/port/common \
	-DXA_HACK \
	-DINLINE="static __inline__" -Dasm="__asm__ __volatile__" \
	$(SDL_CFLAGS)

# Convert plugin names to uppercase and make them CFLAG defines
CFLAGS += -D$(shell echo $(GPU) | tr a-z A-Z)
CFLAGS += -D$(shell echo $(SPU) | tr a-z A-Z)
CFLAGS += -DFORCE_MEMCPY32

ifdef RECOMPILER
CFLAGS += -DPSXREC -D$(RECOMPILER)
endif

CXXFLAGS = $(CFLAGS) -fno-exceptions -fno-rtti -nostdinc++

LDFLAGS = -nodefaultlibs -lc -lgcc -lSDL -lz -Wl,--as-needed -Wl,--gc-sections -flto -s
LDFLAGS += $(SDL_LIBS) -lSDL_mixer -lSDL_image -lrt

OBJDIRS = obj obj/gpu obj/gpu/$(GPU) obj/spu obj/spu/$(SPU) \
	  obj/recompiler obj/recompiler/$(RECOMPILER) \
	  obj/port obj/port/$(PORT) \
	  obj/plugin_lib obj/port/common

all: maketree $(TARGET)

OBJS = \
	obj/r3000a.o obj/misc.o obj/plugins.o obj/psxmem.o obj/psxhw.o \
	obj/psxcounters.o obj/psxdma.o obj/psxbios.o obj/psxhle.o obj/psxevents.o \
	obj/psxcommon.o \
	obj/plugin_lib/plugin_lib.o obj/plugin_lib/pl_sshot.o \
	obj/psxinterpreter.o \
	obj/mdec.o obj/decode_xa.o \
	obj/cdriso.o obj/cdrom.o obj/ppf.o \
	obj/sio.o obj/pad.o

ifdef RECOMPILER
OBJS += \
	obj/recompiler/mips/recompiler.o \
	obj/recompiler/mips/mips_disasm.o \
	obj/recompiler/mips/mem_mapping.o \
	obj/recompiler/mips/mips_codegen.o
endif

######################################################################
#  GPULIB from PCSX Rearmed:
#  Fixes many game incompatibilities and centralizes/improves many
#  things that once were the responsibility of individual GPU plugins.
#  NOTE: For now, only GPU Unai has been adapted.
ifeq ($(USE_GPULIB),1)
CFLAGS += -DUSE_GPULIB
OBJDIRS += obj/gpu/gpulib
OBJS += obj/gpu/$(GPU)/gpulib_if.o
OBJS += obj/gpu/gpulib/gpu.o obj/gpu/gpulib/vout_port.o
else
OBJS += obj/gpu/$(GPU)/gpu.o
endif
######################################################################

OBJS += obj/gte.o
# OBJS += obj/cheat.o
OBJS += obj/spu/$(SPU)/spu.o

OBJS += obj/port/$(PORT)/port.o
OBJS += obj/port/$(PORT)/frontend.o
# OBJS += obj/port/$(PORT)/cdrom_hacks.o

OBJS += obj/plugin_lib/perfmon.o

#******************************************
# spu_pcsxrearmed section BEGIN
#******************************************

##########
# Use a non-default SPU update frequency for these slower devices
#  to avoid audio dropouts. 0: once-per-frame (default)   5: 32-times-per-frame
#
#  On slower Dingoo A320, update 8 times per frame
CFLAGS += -DSPU_UPDATE_FREQ_DEFAULT=3
##########

##########
# Similarly, set higher XA audio update frequency for slower devices
#
#  On slower Dingoo A320, force XA to update 8 times per frame (val 4)
CFLAGS += -DFORCED_XA_UPDATES_DEFAULT=4
##########

ifeq ($(SPU),spu_pcsxrearmed)
# Specify which audio backend to use:
SOUND_DRIVERS=sdl
#SOUND_DRIVERS=alsa
#SOUND_DRIVERS=oss
#SOUND_DRIVERS=pulseaudio

# Note: obj/spu/spu_pcsxrearmed/spu.o will already have been added to OBJS
#		list previously in Makefile
OBJS += obj/spu/spu_pcsxrearmed/dma.o obj/spu/spu_pcsxrearmed/freeze.o \
	obj/spu/spu_pcsxrearmed/out.o obj/spu/spu_pcsxrearmed/nullsnd.o \
	obj/spu/spu_pcsxrearmed/registers.o
ifeq "$(ARCH)" "arm"
OBJS += obj/spu/spu_pcsxrearmed/arm_utils.o
endif
ifeq "$(HAVE_C64_TOOLS)" "1"
obj/spu/spu_pcsxrearmed/spu.o: CFLAGS += -DC64X_DSP
obj/spu/spu_pcsxrearmed/spu.o: obj/spu/spu_pcsxrearmed/spu_c64x.c
frontend/menu.o: CFLAGS += -DC64X_DSP
endif
ifneq ($(findstring oss,$(SOUND_DRIVERS)),)
obj/spu/spu_pcsxrearmed/out.o: CFLAGS += -DHAVE_OSS
OBJS += obj/spu/spu_pcsxrearmed/oss.o
endif
ifneq ($(findstring alsa,$(SOUND_DRIVERS)),)
obj/spu/spu_pcsxrearmed/out.o: CFLAGS += -DHAVE_ALSA
OBJS += obj/spu/spu_pcsxrearmed/alsa.o
LDFLAGS += -lasound
endif
ifneq ($(findstring sdl,$(SOUND_DRIVERS)),)
obj/spu/spu_pcsxrearmed/out.o: CFLAGS += -DHAVE_SDL
OBJS += obj/spu/spu_pcsxrearmed/sdl.o
endif
ifneq ($(findstring pulseaudio,$(SOUND_DRIVERS)),)
obj/spu/spu_pcsxrearmed/out.o: CFLAGS += -DHAVE_PULSE
OBJS += obj/spu/spu_pcsxrearmed/pulseaudio.o
endif
ifneq ($(findstring libretro,$(SOUND_DRIVERS)),)
obj/spu/spu_pcsxrearmed/out.o: CFLAGS += -DHAVE_LIBRETRO
endif

endif
#******************************************
# spu_pcsxrearmed END
#******************************************

CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions

#If V=1 was passed to 'make', do not hide commands:
ifdef V
	HIDECMD:=
else
	HIDECMD:=@
endif

$(TARGET): $(OBJS)
	@echo Linking $(TARGET)...
	$(HIDECMD)$(LD) $(OBJS) $(LDFLAGS) -o $@

obj/%.o: src/%.c
	@echo Compiling $<...
	$(HIDECMD)$(CC) -std=gnu99 $(CFLAGS) -c $< -o $@

obj/%.o: src/%.cpp
	@echo Compiling $<...
	$(HIDECMD)$(CXX) -std=gnu++03 $(CXXFLAGS) -c $< -o $@

obj/%.o: src/%.s
	@echo Compiling $<...
	$(HIDECMD)$(CXX) -std=gnu99 $(CFLAGS) -c $< -o $@

obj/%.o: src/%.S
	@echo Compiling $<...
	$(HIDECMD)$(CXX) -std=gnu99 $(CFLAGS) -c $< -o $@

$(sort $(OBJDIRS)):
	$(HIDECMD)$(MD) $@

maketree: $(sort $(OBJDIRS))

clean:
	$(RM) -r obj

ipk: all
	@rm -rf /tmp/.pcsx4all-ipk/ && mkdir -p /tmp/.pcsx4all-ipk/root/home/retrofw/emus/pcsx4all /tmp/.pcsx4all-ipk/root/home/retrofw/apps/gmenu2x/sections/emulators /tmp/.pcsx4all-ipk/root/home/retrofw/apps/gmenu2x/sections/emulators.systems
	@cp -r pcsx4all/pcsx4all.dge pcsx4all/pcsx4all.png pcsx4all/backdrop.png /tmp/.pcsx4all-ipk/root/home/retrofw/emus/pcsx4all
	@cp pcsx4all/pcsx4all.lnk /tmp/.pcsx4all-ipk/root/home/retrofw/apps/gmenu2x/sections/emulators
	@cp pcsx4all/ps1.pcsx4all.lnk /tmp/.pcsx4all-ipk/root/home/retrofw/apps/gmenu2x/sections/emulators.systems
	@cp pcsx4all/conffiles /tmp/.pcsx4all-ipk/
	@sed "s/^Version:.*/Version: $$(date +%Y%m%d)/" pcsx4all/control > /tmp/.pcsx4all-ipk/control
	@tar --owner=0 --group=0 -czvf /tmp/.pcsx4all-ipk/control.tar.gz -C /tmp/.pcsx4all-ipk/ control conffiles
	@tar --owner=0 --group=0 -czvf /tmp/.pcsx4all-ipk/data.tar.gz -C /tmp/.pcsx4all-ipk/root/ .
	@echo 2.0 > /tmp/.pcsx4all-ipk/debian-binary
	@ar r pcsx4all/pcsx4all.ipk /tmp/.pcsx4all-ipk/control.tar.gz /tmp/.pcsx4all-ipk/data.tar.gz /tmp/.pcsx4all-ipk/debian-binary

opk: all
	@mksquashfs \
	pcsx4all/default.retrofw.desktop \
	pcsx4all/ps1.retrofw.desktop \
	pcsx4all/pcsx4all.dge \
	pcsx4all/pcsx4all.png \
	pcsx4all/backdrop.png \
	pcsx4all/pcsx4all.opk \
	-all-root -noappend -no-exports -no-xattrs
