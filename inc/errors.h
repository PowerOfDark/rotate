//
// Created by powerofdark on 09.05.2020.
//

#ifndef ROTATE_ERRORS_H
#define ROTATE_ERRORS_H


#define ERR_SRC_NOTFOUND        1
#define ERR_SRC_INVALID         2
#define ERR_SRC_BPP             3
#define ERR_DST_INVALID         4
#define ERR_ROTATION_INVALID    5
#define ERR_MEMORY_ALLOC        6

static const char* ERRORS[] = {
        [ERR_SRC_NOTFOUND]      = "The source image was not found",
        [ERR_SRC_INVALID]       = "The source image is not a valid bitmap",
        [ERR_SRC_BPP]           = "The source image is not a monochromatic 1bpp bitmap",
        [ERR_DST_INVALID]       = "An error occured while saving the destination image",
        [ERR_ROTATION_INVALID]  = "Rotation is not possible - the image dimensions do not match",
        [ERR_MEMORY_ALLOC]      = "Memory allocation failed"
};

static const char* get_error_message(int error) {
    if (error < 0) error = -error;
    if (error > sizeof(ERRORS))
        return "Unknown error";
    return ERRORS[error];
}

#endif //ROTATE_ERRORS_H
