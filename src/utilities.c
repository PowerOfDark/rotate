//
// Created by powerofdark on 09.05.2020.
//

#include "utilities.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "structures.h"


void header_from_descriptor(struct BitmapDescriptor* desc, struct BitmapHeader* header) {
    header->FileSize = desc->FileSize;
    header->Preamble = BMP_PREAMBLE;
    header->Reserved = 0;
    header->DataOffset = BMP_DATA_OFFSET;
    header->InfoLength = BMP_INFO_LENGTH;
    header->Width = desc->Width;
    header->Height = desc->Height;
    header->Planes = 1;
    header->Bpp = 1;
    header->Compression = 0;
    header->ImageSize = desc->Height * desc->RowSize;
    header->Xppm = header->Yppm = 0;
    header->ColorsUsed = header->ColorsNeeded = 0;
    header->Color1 = 0x00000000; // (R=0,G=0,B=0,RESERVED=0)
    header->Color2 = 0x00FFFFFF; // (R=255,G=255,B=255,RESERVED=0)
    desc->HeaderPtr = header;
    desc->DataPtr = (byte_t*)header + BMP_MIN_LENGTH;
}

int dispose_descriptor(struct BitmapDescriptor** descPtr) {
    struct BitmapDescriptor* desc = *descPtr;
    if (!desc)
        return 1;
    if (desc->HeaderPtr)
        free(desc->HeaderPtr);
    free(desc);
    *descPtr = NULL;
    return 0;
}


void clear_descriptor(struct BitmapDescriptor* desc) {
    if (desc->HeaderPtr) {
        free(desc->HeaderPtr);
    }
    memset(desc, 0, sizeof(struct BitmapDescriptor));
}

struct BitmapDescriptor* override_descriptor(struct BitmapDescriptor** descPtr) {
    struct BitmapDescriptor* desc = *descPtr;
    if(desc)
        clear_descriptor(desc);
    else
        desc = *descPtr = calloc(1, sizeof(struct BitmapDescriptor));
    return desc;
}
