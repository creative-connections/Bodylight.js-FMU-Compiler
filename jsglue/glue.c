#include "fmi2Functions.h"
#include "fmi2FunctionTypes.h"
#include "fmi2TypesPlatform.h"
#include "stdio.h"
#include "string.h"
#include "stdarg.h"

fmi2CallbackFunctions * createFmi2CallbackFunctions(fmi2CallbackLogger logger) {
    fmi2CallbackFunctions cbf_local = {
        logger,
        calloc,
        free,
        NULL,
        NULL,
    };

    fmi2CallbackFunctions *cbf = malloc(sizeof (*cbf));
    memcpy(cbf, &cbf_local, sizeof(*cbf));
    return cbf;
}

//1.1.2024 TK - have empty main function in order to export runtime addOnPreMain by emscripten
int main() {
    return 0;
}