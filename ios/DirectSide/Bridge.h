#include <stdbool.h>
void ds_start(void);
bool ds_send(const char *command);
char *ds_poll(void);
void ds_free(char *pointer);
