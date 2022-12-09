#include "main.h"

#ifdef __cplusplus
extern "C" {
#endif

int main(int argc, char* argv[]) {
  logger(NULL,
         "Test instance",
         fmi2OK,
         "Test category",
         "Hello from the external C logging function");

  logger(NULL,
         "Test instance",
         fmi2Warning,
         "Test category",
         "A warning message");

  logger(NULL,
         "Test instance",
         fmi2Discard,
         "Test category",
         "A discard message");

  logger(NULL,
         "Test instance",
         fmi2Error,
         "Test category",
         "An error message");

  logger(NULL,
         "Test instance",
         fmi2Fatal,
         "Test category",
         "A fatal error message");

  logger(NULL,
         "Test instance",
         fmi2Pending,
         "Test category",
         "A pending message. Not to be confused with appending a message.");

  double* testArray = allocateMemory(2, sizeof *testArray);
  freeMemory(testArray);

  stepFinished(NULL, fmi2OK);

  return 0;
}

#ifdef __cplusplus
} // extern "C"
#endif
