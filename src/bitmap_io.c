//
// Created by powerofdark on 09.05.2020.
//

#include "bitmap_io.h"
#include "utilities.h"
#include "errors.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int new_1bpp_bitmap(uint32_t width, uint32_t height, struct BitmapDescriptor** descPtr) {
    // allocate descriptor
    struct BitmapDescriptor* desc = override_descriptor(descPtr);

    uint32_t rowSize = dword_align(row_bytes(width));
    uint32_t fileSize = BMP_MIN_LENGTH + rowSize*height;

    desc->Width = width;
    desc->Height = height;
    desc->RowSize = rowSize;
    desc->FileSize = fileSize;

    byte_t* data = calloc(1, fileSize + BUFFER_SAFETY_PAD);
    if (!data) {
        return -ERR_MEMORY_ALLOC;
    }

    struct BitmapHeader* header = (struct BitmapHeader*) data;
    header_from_descriptor(desc, header);

    return 0;
}

int read_bitmap(const char* path, struct BitmapDescriptor** descPtr) {
    // allocate descriptor
    struct BitmapDescriptor* desc = override_descriptor(descPtr);

    FILE* f = fopen(path, "rb");
    if (!f)
        return -ERR_SRC_NOTFOUND;

    byte_t buf[6];
    uint32_t read = fread(buf, sizeof(byte_t), sizeof(buf), f);
    uint32_t fileSize = *(uint32_t*)(buf+2);
    if (read != sizeof(buf) || *(uint16_t*)buf != BMP_PREAMBLE || fileSize <= BMP_MIN_LENGTH) {
        fclose(f);
        return -ERR_SRC_INVALID;
    }

    byte_t* data = calloc(1, fileSize + BUFFER_SAFETY_PAD);

    if(!data) {
        fclose(f);
        return -ERR_MEMORY_ALLOC;
    }

    // read bitmap into the allocated buffer
    read += fread(data + sizeof(buf), sizeof(byte_t), fileSize - sizeof(buf), f);
    fclose(f);


    if (read != fileSize) {
        free(data);
        return -ERR_SRC_INVALID;
    }
    // verify bitmap data
    struct BitmapHeader* header = (struct BitmapHeader*) data;
    if(header->Bpp != 1) {
        free(data);
        return -ERR_SRC_BPP;
    }
    if(header->Width < 0 || header->Height < 0) {
        free(data);
        return -ERR_SRC_INVALID;
    }

    // fill first 6 bytes
    memcpy(data, buf, sizeof(buf));

    // fill the descriptor
    desc->HeaderPtr = header;
    desc->FileSize = fileSize;
    desc->DataPtr = data + header->DataOffset;
    desc->Width = header->Width;
    desc->Height = header->Height;
    desc->RowSize = dword_align(row_bytes(header->Width));

    return 0;
}

int write_bitmap(const char* path, struct BitmapDescriptor* desc) {
    if(!desc)
        return -ERR_DST_INVALID;

    FILE* f = fopen(path, "wb");
    if (!f) {
        return -ERR_DST_INVALID;
    }

    uint32_t written = fwrite((byte_t*)desc->HeaderPtr, sizeof(byte_t), desc->FileSize, f);
    fclose(f);
    if (written != desc->FileSize) {
        return -ERR_DST_INVALID;
    }

    return 0;
}