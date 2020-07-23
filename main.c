/*
 * Program wykonujacy obrot monochromatycznej bitmapy
 * Przemyslaw Rozwalka, ARKO 2020
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "structures.h"
#include "errors.h"
#include "utilities.h"
#include "bitmap_io.h"
#include <unistd.h>
#include <getopt.h>
#include <time.h>

extern int32_t _rotate(struct BitmapDescriptor* src, struct BitmapDescriptor* dst);
extern int32_t _mrotate(struct BitmapDescriptor* src, struct BitmapDescriptor* dst);



int handle_error(int error) {
    if(error < 0)
        printf("Error: %s\n", get_error_message(error));
    return error;
}

const char* input_path = NULL;
const char* output_path = NULL;

int print_verbose = 0;
int num_rotations = 1;
int rotate_left = 0;
int use_mrotate = 0;

int32_t rotate(struct BitmapDescriptor* src, struct BitmapDescriptor* dst) {
    if(!src || !dst || src->Width != dst->Height || src->Height != dst->Width) {
        return -ERR_ROTATION_INVALID;
    }
    return (use_mrotate ? _mrotate : _rotate)(src, dst);
}

int parse_arguments(int argc, char* argv[]) {
    int c;
    int val;
    while((c = getopt(argc, argv, "vlmn:")) != -1) {
        switch (c) {
            case 'l':
                rotate_left = 1;
                break;
            case 'n':
                val = atoi(optarg);
                if (val <= 0) {
                    printf("Invalid parameter 'n' -- must be a positive number.\n");
                    return 1;
                }
                num_rotations = val % 4;
                break;
            case 'm':
                use_mrotate = 1;
                break;
            case 'v':
                print_verbose = 1;
                break;
            case '?':
                if(optopt == 'n') {
                    printf("Parameter 'n' requires an argument.\n");
                }
            default:
                return 1;
        }
    }
    if(optind + 1 >= argc) {
        printf("You must specify the input/output files.\n");
        return 1;
    }
    input_path = argv[optind];
    output_path = argv[optind+1];
    if (rotate_left) {
       num_rotations = (4 - num_rotations)%4;
    }

    return 0;
}

int main(int argc, char *argv[]) {
    if(parse_arguments(argc, argv) != 0) {
        printf("Usage: %s [-v] [-l] [-m] [-n num_rotations] input output\n", argv[0]);
        printf("Options:\n\t-v verbose output\n\t-l rotate left\n\t-m use multiplication instead of lookup\n");
        return 1;
    }

    struct BitmapDescriptor* input = NULL;
    struct BitmapDescriptor* buffer = NULL;
    struct BitmapDescriptor* output = NULL;

    if(print_verbose) {
        printf("Reading bitmap from '%s'\n", input_path);
    }
    if(handle_error(read_bitmap(input_path, &input)) != 0) {
        return 1;
    }
    if(print_verbose) {
        printf("Opened a bitmap of dimensions %dx%d (%d bytes)\n",
                input->Width, input->Height, input->FileSize);
    }
    if(num_rotations > 0) {
        if (handle_error(new_1bpp_bitmap(input->Height, input->Width, &buffer)) != 0) {
            dispose_descriptor(&input);
            return 1;
        }
        if (print_verbose) {
            printf("Allocated temporary bitmap of dimensions %dx%d (%d bytes)\n",
                   buffer->Width, buffer->Height, buffer->FileSize);
            printf("Rotating image %d times using %s\n", num_rotations, use_mrotate ? "multiplication" : "lookup");
        }
    }

    output = input;
    clock_t startTime = clock();
    while (num_rotations--) {
        output = buffer;
        if (handle_error(rotate(input, buffer)) != 0) {
            dispose_descriptor(&input);
            dispose_descriptor(&buffer);
            return 1;
        }
        if(num_rotations) {
            // one more rotation to perform; swap buffers
            struct BitmapDescriptor* tmp = buffer;
            buffer = input;
            input = tmp;
        }
    }
    clock_t endTime = clock();
    if (print_verbose)
        printf("Rotations took %.2lfms\n", (double)(endTime-startTime) / CLOCKS_PER_SEC * 1000.0);

    int code = handle_error(write_bitmap(output_path, output)) != 0;
    if(print_verbose && code == 0) {
        printf("Written %d bytes to '%s'\n", output->FileSize, output_path);
    }
    dispose_descriptor(&input);
    dispose_descriptor(&buffer);

    return code ? 1 : 0;
}
