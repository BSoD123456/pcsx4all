#ifndef __PSXPORT_H__
#define __PSXPORT_H__

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <sys/types.h>
#include <assert.h>
// #include <SDL.h>

///////////////////////////
// Windows compatibility //
///////////////////////////
#if defined(_WIN32) && !defined(__CYGWIN__)
// Windows lacks fsync():
static inline int fsync(int f) { return 0; }
#endif

#define	CONFIG_VERSION	0

unsigned get_ticks(void);
void wait_ticks(unsigned s);
void pad_update(void);
unsigned short pad_read(int num);

void video_blit(void *src);
void video_flip(void);
#ifdef GPU_DFXVIDEO
void video_set(unsigned short* pVideo,unsigned int width,unsigned int height);
#endif
void video_clear(void);
void port_printf(int x, int y, const char *text);
void port_printf_fg_bg(int x, int y, const char *text, int fg, int bg);

extern unsigned short *SCREEN;

int state_load(int slot);
int state_save(int slot);

void update_memcards(int load_mcd);
const char *bios_file_get();
void bios_file_set(const char *filename);
void check_spec_bios();

int SelectGame();
int GameMenu();

#endif
