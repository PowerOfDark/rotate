//
// Created by powerofdark on 09.05.2020.
//

#ifndef ROTATE_UTILITIES_H
#define ROTATE_UTILITIES_H

#include <stdint.h>
#include "structures.h"

/**
 * Aligns value to DWORD (4 bytes)
 */
static inline uint32_t dword_align(uint32_t x) {
    return (x + 3u) & 0xFFFFFFFCu;
}
/**
 * Returns the number of bytes required to fit the specified number of bits
 */
static inline uint32_t row_bytes(uint32_t bits) {
    return ((bits + 31u) >> 5u) << 2u;
}

/**
 * Constructs a header based on the bitmap descriptor
 */
void header_from_descriptor(struct BitmapDescriptor* desc, struct BitmapHeader* header);
/**
 * Disposes and de-allocates the given bitmap descriptor
 * @return 0 if success
 */
int dispose_descriptor(struct BitmapDescriptor** descPtr);
/**
 * Clears data from the provided bitmap descriptor
 */
void clear_descriptor(struct BitmapDescriptor* desc);
/**
 * Prepares the given descriptor for reuse.
 */
struct BitmapDescriptor* override_descriptor(struct BitmapDescriptor** descPtr);

#endif //ROTATE_UTILITIES_H
