#include "main.h"
#include "sources/all.c"
#include "variables.h"

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>

#include <sys/time.h>
#include <sys/timeb.h>
#include <time.h>

#undef h

#include <sys/time.h>

extern const char *GUIDString;
static const fmi2CallbackFunctions cb_functions = {logger, calloc, free, NULL,
                                                   NULL};

int main() {
  fmi2Component instance = 0;
  instance = fmi2Instantiate("testing", fmi2CoSimulation, GUIDString, "file://",
                             &cb_functions, fmi2False, fmi2False);

  // fmi2SetDebugLogging(instance, fmi2True, 0, 0);

  fmi2SetupExperiment(instance, toleranceDefined, tolerance, 0, fmi2False, 0);

  if (fmi2EnterInitializationMode(instance) != FMIOK) {
    terminateFree(instance);
  }
  if (fmi2ExitInitializationMode(instance) != FMIOK) {
    terminateFree(instance);
  }

#ifdef _PROFILING
  long long int tick_ms = tick();
  printf("Start at tick %lld \n", tick_ms);
#endif

  fmi2Real time = 0;
  fmi2Real outputs[1] = {0};

  while (time < stopTime) {
    fmi2DoStep(instance, time, h, fmi2False);
    fmi2GetReal(instance, out, 1, outputs);
    time += h;

    printf("time:%g\n", time);
    printf("%g \n", outputs[0]);
  }

#ifdef _PROFILING
  long long int tock_ms = tick();
  printf("Stop at tock %lld \n", tock_ms);
  printf("Duration %lld ms\n", (tock_ms - tick_ms));
#endif

  terminateFree(instance);
}

static long long int tick() {
  struct timeb timer;
  long long int timestamp;
  if (!ftime(&timer)) {
    timestamp =
        ((long long int)timer.time) * 1000ll + (long long int)timer.millitm;
  }
  return timestamp;
}

static void terminateFree(fmi2Component instance) {
  fmi2Terminate(instance);
  fmi2FreeInstance(instance);
  exit(1);
}

static void loggerFail() { printf("Logging fail, message too long?"); }

static void logger(FMIComponent m, FMIString instanceName, FMIStatus status,
                   FMIString category, FMIString message, ...) {
  char msg[1024];
  char buf[1024];
  int len;
  int capacity;

  va_list ap;
  va_start(ap, message);
  capacity = sizeof(buf) - 1;

  len = snprintf(msg, capacity, "%s: %s", instanceName, message);
  if (len < 0) {
    loggerFail();
    return;
  }
  len = vsnprintf(buf, capacity, msg, ap);
  if (len < 0) {
    loggerFail();
    return;
  }

  buf[len] = '\n';
  buf[len + 1] = 0;
  va_end(ap);
  printf(buf);
}
