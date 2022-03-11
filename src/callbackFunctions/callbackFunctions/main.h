//
// Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#ifndef __MAIN_H__
#define __MAIN_H__

#include <windows.h>

/*  To use this exported function of dll, include this header
 *  in your project.
 */

#ifdef BUILD_DLL
    #define DLL_EXPORT __declspec(dllexport)
#else
    #define DLL_EXPORT __declspec(dllimport)
#endif


#ifdef __cplusplus
extern "C"
{
#endif

typedef void* fmi2ComponentEnvironment;

typedef char fmi2Char;
typedef fmi2Char* fmi2String;
typedef double fmi2Real;
typedef int fmi2Integer;
typedef int fmi2Boolean;

// FMI-Specification 2.0.2 p.18
typedef enum
{
    fmi2OK,
    fmi2Warning,
    fmi2Discard,
    fmi2Error,
    fmi2Fatal,
    fmi2Pending
} fmi2Status;

void DLL_EXPORT logger(fmi2ComponentEnvironment componentEnvironment,
                       fmi2String instanceName,
                       fmi2Status status,
                       fmi2String category,
                       fmi2String message, ...);
void* DLL_EXPORT allocateMemory(size_t nobj,
                                size_t size);
void DLL_EXPORT freeMemory(void* obj);
void DLL_EXPORT stepFinished(fmi2ComponentEnvironment componentEnvironment,
                             fmi2Status status);

#ifdef __cplusplus
}
#endif

#endif // __MAIN_H__
