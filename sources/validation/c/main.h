#include "fmi2FunctionTypes.h"
#include "fmi2Functions.h"
#include "fmi2TypesPlatform.h"

static void logger(fmi2Component m, fmi2String instanceName, fmi2Status status,
                   fmi2String category, fmi2String message, ...);

static void loggerFail();

static void terminateFree(fmi2Component instance);

static long long int tick();
