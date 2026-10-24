#include <stdbool.h>
#include "MacADI.h"
typedef char *(*DSAnisetteGenerate)(void);
typedef void (*DSAnisetteRelease)(char *);
bool ds_set_anisette_callback(DSAnisetteGenerate generate, DSAnisetteRelease release);
typedef char *(*DSAnisetteResync)(const char *);
bool ds_set_anisette_resync_callback(DSAnisetteResync resync);
void ds_start(void);
bool ds_send(const char *command);
char *ds_poll(void);
void ds_free(char *pointer);
