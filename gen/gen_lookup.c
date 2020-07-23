// Przemysław Rozwałka, ARKO 2020
// Program generujący pomocniczą tablicę obrotu

#include "stdio.h"
#include <stdint.h>

#define ENTRIES 256
#define SIZE 8 * ENTRIES

uint8_t Lookup[SIZE];

void generate_lookup() {
    uint16_t entry;
    uint8_t bits;
    uint8_t *ptr = Lookup;

    for (entry = 0; entry < ENTRIES; entry++) {
        bits = (uint8_t) entry;
        //bits = (uint8_t)((bits << 4u) | (bits >> 4u)); // switch endianness
        for (int i = 0; i < 8; i++) {
            *ptr++ = (uint8_t) (bits & 0x01);
            bits >>= 1;
        }

    }
}

void write_lookup() {
    FILE *f = fopen("lookup.bin", "w");
    fwrite(Lookup, 1, SIZE, f);
    fclose(f);
}

void print_lookup() {
    uint16_t entry;
    uint32_t *p = (uint32_t*)Lookup;

    for (entry = 0; entry < SIZE; entry+=32, p+=8) {
        printf(".word 0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x\n",
               p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);
    }
}

int main() {
    generate_lookup();
    write_lookup();
    printf("generated lookup of size %d\n", SIZE);
    print_lookup();
    return 0;
}
