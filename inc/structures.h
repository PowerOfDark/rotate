//
// Created by powerofdark on 09.05.2020.
//

#ifndef ROTATE_STRUCTURES_H
#define ROTATE_STRUCTURES_H

#include <stdint.h>

extern const uint16_t BMP_PREAMBLE;
extern const uint32_t BMP_INFO_LENGTH;
extern const uint32_t BMP_MIN_LENGTH;
extern const uint32_t BMP_DATA_OFFSET;
extern const uint32_t BUFFER_SAFETY_PAD;

typedef uint32_t color_t;
typedef uint8_t byte_t;

struct BitmapHeader {
    uint16_t Preamble;
    uint32_t FileSize;
    uint32_t Reserved;
    uint32_t DataOffset;
    uint32_t InfoLength;
    int32_t Width;
    int32_t Height;
    int16_t Planes;
    int16_t Bpp;
    uint32_t Compression;
    uint32_t ImageSize;
    uint32_t Xppm;
    uint32_t Yppm;
    uint32_t ColorsUsed;
    uint32_t ColorsNeeded;
    color_t Color1;
    color_t Color2;
} __attribute__((packed));

struct BitmapDescriptor {
    struct BitmapHeader* HeaderPtr;
    uint32_t FileSize;
    byte_t* DataPtr;
    uint32_t Width;
    uint32_t Height;
    uint32_t RowSize;
} __attribute__((packed));

#endif //ROTATE_STRUCTURES_H
