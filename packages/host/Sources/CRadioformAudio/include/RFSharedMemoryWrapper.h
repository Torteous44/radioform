#ifndef RF_SHARED_MEMORY_WRAPPER_H
#define RF_SHARED_MEMORY_WRAPPER_H

#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

// Wrapper for shm_open (which is variadic and unavailable in Swift)
static inline int rf_shm_open(const char* name, int oflag, mode_t mode) {
    return shm_open(name, oflag, mode);
}

// Wrapper for shm_unlink
static inline int rf_shm_unlink(const char* name) {
    return shm_unlink(name);
}

#ifdef __cplusplus
}
#endif

#endif // RF_SHARED_MEMORY_WRAPPER_H
