//
// Created by powerofdark on 09.05.2020.
//

#ifndef ROTATE_BITMAP_IO_H
#define ROTATE_BITMAP_IO_H

#include <stdint.h>
#include "structures.h"
/**
 * Creates a new 1bpp bitmap
 * @param width bitmap width
 * @param height bitmap height
 * @param descPtr ref-pointer to the target image descriptor
 * @return 0 if success, error code otherwise
 */
int new_1bpp_bitmap(uint32_t width, uint32_t height, struct BitmapDescriptor** descPtr);
/**
 * Reads 1bpp bitmap from given path
 * @param path bitmap path
 * @param descPtr ref-pointer to the target image descriptor
 * @return 0 if success, error code otherwise
 */
int read_bitmap(const char* path, struct BitmapDescriptor** descPtr);
/**
 * Saves bitmap to a given path
 * @param path output path
 * @param desc pointer to the target image descriptor
 * @return 0 if success, error code otherwise
 */
int write_bitmap(const char* path, struct BitmapDescriptor* desc);

#endif //ROTATE_BITMAP_IO_H
