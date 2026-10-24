#include <stdbool.h>
typedef char *(*DSAnisetteGenerate)(void);
typedef void (*DSAnisetteRelease)(char *);
bool ds_set_anisette_callback(DSAnisetteGenerate generate, DSAnisetteRelease release);
void ds_start(void);
bool ds_send(const char *command);
char *ds_poll(void);
void ds_free(char *pointer);
