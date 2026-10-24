#include <stddef.h>
#include <stdint.h>
typedef struct Handle DSMacADI;
typedef struct { uint8_t *ptr; size_t len; } AdiBuf;
int32_t adi_open(const uint8_t *, size_t, DSMacADI **);
void adi_close(DSMacADI *);
size_t adi_last_error(char *, size_t);
void adi_buf_free(AdiBuf);
int32_t adi_set_host_uuid(DSMacADI *, const uint8_t *);
int32_t adi_store_export(DSMacADI *, AdiBuf *);
int32_t adi_store_import(DSMacADI *, const uint8_t *, size_t);
int32_t adi_headers(DSMacADI *, int64_t, AdiBuf *, AdiBuf *, uint64_t *);
int32_t adi_provisioning_begin(DSMacADI *, int64_t, const uint8_t *, size_t, AdiBuf *, uint32_t *);
int32_t adi_provisioning_finish(DSMacADI *, int64_t, uint32_t, const uint8_t *, size_t, const uint8_t *, size_t, uint64_t);
int32_t adi_sync(DSMacADI *, int64_t, const uint8_t *, size_t, AdiBuf *, AdiBuf *);
int32_t adi_update_routing(DSMacADI *, int64_t, uint64_t);
