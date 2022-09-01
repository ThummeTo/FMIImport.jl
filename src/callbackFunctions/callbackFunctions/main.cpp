//
// Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "main.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#define RED(message)    "\x1B[31m" message "\x1B[0m"
#define GREEN(message)  "\x1B[32m" message "\x1B[0m"
#define YELLOW(message) "\x1B[33m" message "\x1B[0m"
#define BLUE(message)   "\x1B[34m" message "\x1B[0m"

const char* fmi2StatusString(fmi2Status status)
{
    switch(status)
    {
        case fmi2OK:
            return GREEN("OK");
        case fmi2Warning:
            return YELLOW("Warning");
        case fmi2Discard:
            return YELLOW("Discard");
        case fmi2Error:
            return  RED("Error");
        case fmi2Fatal:
            return RED("Fatal");
        case fmi2Pending:
            return YELLOW("Pending");
        default:
            return RED("Unknwon");
    }
}

// FMI-Specification 2.0.2 p.20 ff
void logger(fmi2ComponentEnvironment componentEnvironment,
            fmi2String instanceName,
            fmi2Status status,
            fmi2String category,
            fmi2String message, ...)
{
    va_list args;
    size_t size;
    char* msgBuffer;

    va_start(args, message);

    size = vsnprintf(NULL, 0, message, args);
    msgBuffer = (char*) calloc(size+1, sizeof(char));

    vsprintf(msgBuffer, message, args);
    printf("[%s][%s][%s]: %s\n", fmi2StatusString(status), category, instanceName, msgBuffer);

    free(msgBuffer);
    va_end(args);
}

// FMI-Specification 2.0.2 p.20 ff
void* allocateMemory(size_t nobj, size_t size)
{
	void* ptr = calloc(nobj, size);
	//printf("[OK]: allocateMemory()\n");
	return ptr;
}

// FMI-Specification 2.0.2 p.20 ff
void freeMemory(void* obj)
{
	free(obj);
	//printf("[OK]: freeMemory()\n");
}

// FMI-Specification 2.0.2 p.20 ff
void stepFinished(fmi2ComponentEnvironment componentEnvironment, fmi2Status status)
{
    //printf("[OK]: stepFinished()\n");
}
