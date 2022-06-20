#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_c.jl`?
# - default implementations for the `fmi2CallbackFunctions`
# - julia-implementaions of the functions inside the FMI-specification
# Any c-function `f(c::fmi2Component, args...)` in the spec is implemented as `f(c::FMU2Component, args...)`.
# Any c-function `f(args...)` without a leading `fmi2Component`-arguemnt is already implented as `f(c_ptr, args...)` in FMICore, where `c_ptr` is a pointer to the c-function (inside the DLL).

# already defined in FMICore.jl:
# - fmi2Instantiate

import FMICore: fmi2Instantiate, fmi2FreeInstance!, fmi2GetTypesPlatform, fmi2GetVersion
import FMICore: fmi2SetDebugLogging, fmi2SetupExperiment, fmi2EnterInitializationMode, fmi2ExitInitializationMode, fmi2Terminate, fmi2Reset
import FMICore: fmi2GetReal!, fmi2SetReal, fmi2GetInteger!, fmi2SetInteger, fmi2GetBoolean!, fmi2SetBoolean, fmi2GetString!, fmi2SetString
import FMICore: fmi2GetFMUstate!, fmi2SetFMUstate, fmi2FreeFMUstate!, fmi2SerializedFMUstateSize!, fmi2SerializeFMUstate!, fmi2DeSerializeFMUstate!
import FMICore: fmi2GetDirectionalDerivative!, fmi2SetRealInputDerivatives, fmi2GetRealOutputDerivatives!
import FMICore: fmi2DoStep, fmi2CancelStep, fmi2GetStatus!, fmi2GetRealStatus!, fmi2GetIntegerStatus!, fmi2GetBooleanStatus!, fmi2GetStringStatus!
import FMICore: fmi2SetTime, fmi2SetContinuousStates, fmi2EnterEventMode, fmi2NewDiscreteStates!, fmi2EnterContinuousTimeMode, fmi2CompletedIntegratorStep!
import FMICore: fmi2GetDerivatives!, fmi2GetEventIndicators!, fmi2GetContinuousStates!, fmi2GetNominalsOfContinuousStates!

"""
Source: FMISpec2.0.2[p.21]: 2.1.5 Creation, Destruction and Logging of FMU Instances

Function that is called in the FMU, usually if an fmi2XXX function, does not behave as desired. If “logger” is called with “status = fmi2OK”, then the message is a pure information message. “instanceName” is the instance name of the model that calls this function. “category” is the category of the message. The meaning of “category” is defined by the modeling environment that generated the FMU. Depending on this modeling environment, none, some or all allowed values of “category” for this FMU are defined in the modelDescription.xml file via element “<fmiModelDescription><LogCategories>”, see section 2.2.4. Only messages are provided by function logger that have a category according to a call to fmi2SetDebugLogging (see below). Argument “message” is provided in the same way and with the same format control as in function “printf” from the C standard library. [Typically, this function prints the message and stores it optionally in a log file.]
"""
function fmi2CallbackLogger(_componentEnvironment::Ptr{FMU2ComponentEnvironment},
            _instanceName::Ptr{Cchar},
            _status::Cuint,
            _category::Ptr{Cchar},
            _message::Ptr{Cchar})
    
    message = unsafe_string(_message)
    category = unsafe_string(_category)
    status = fmi2StatusToString(_status)
    instanceName = unsafe_string(_instanceName)
    componentEnvironment = unsafe_load(_componentEnvironment)

    if status == fmi2StatusOK && componentEnvironment.logStatusOK
        @info "[$status][$category][$instanceName]: $message"
    elseif (status == fmi2StatusWarning && componentEnvironment.logStatusWarning) ||
           (status == fmi2StatusPending && componentEnvironment.logStatusPending)
        @warn "[$status][$category][$instanceName]: $message"
    elseif (status == fmi2StatusDiscard && componentEnvironment.logStatusDiscard) ||
           (status == fmi2StatusError   && componentEnvironment.logStatusError) ||
           (status == fmi2StatusFatal   && componentEnvironment.logStatusFatal)
        @error "[$status][$category][$instanceName]: $message"
    end

    return nothing
end

# (cfmi2CallbackLogger, fmi2CallbackLogger) = Cfunction{                      fmi2ComponentEnvironment,               Ptr{Cchar},         Cuint,           Ptr{Cchar},          Tuple{Ptr{Cchar}, Vararg}   }() do componentEnvironment::fmi2ComponentEnvironment, instanceName::Ptr{Cchar}, status::Cuint, category::Ptr{Cchar}, message::Tuple{Ptr{Cchar}, Vararg}
#     printf(message)
#     nothing
# end 



"""
Source: FMISpec2.0.2[p.21-22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

Function that is called in the FMU if memory needs to be allocated. If attribute “canNotUseMemoryManagementFunctions = true” in <fmiModelDescription><ModelExchange / CoSimulation>, then function allocateMemory is not used in the FMU and a void pointer can be provided. If this attribute has a value of “false” (which is the default), the FMU must not use malloc, calloc or other memory allocation functions. One reason is that these functions might not be available for embedded systems on the target machine. Another reason is that the environment may have optimized or specialized memory allocation functions. allocateMemory returns a pointer to space for a vector of nobj objects, each of size “size” or NULL, if the request cannot be satisfied. The space is initialized to zero bytes [(a simple implementation is to use calloc from the C standard library)].
"""
function fmi2CallbackAllocateMemory(nobj::Csize_t, size::Csize_t)
    ptr = Libc.calloc(nobj, size)
    @debug "cbAllocateMemory($(nobj), $(size)): Allocated $(nobj) x $(size) bytes at $(ptr)."
	ptr
end

"""
Source: FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

Function that must be called in the FMU if memory is freed that has been allocated with allocateMemory. If a null pointer is provided as input argument obj, the function shall perform no action [(a simple implementation is to use free from the C standard library; in ANSI C89 and C99, the null pointer handling is identical as defined here)]. If attribute “canNotUseMemoryManagementFunctions = true” in <fmiModelDescription><ModelExchange / CoSimulation>, then function freeMemory is not used in the FMU and a null pointer can be provided.
"""
function fmi2CallbackFreeMemory(obj::Ptr{Cvoid})
    @debug "cbFreeMemory($(obj)): Freeing object at $(obj)."
	Libc.free(obj)
    nothing
end

"""
Source: FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

Optional call back function to signal if the computation of a communication step of a co-simulation slave is finished. A null pointer can be provided. In this case the master must use fmiGetStatus(..) to query the status of fmi2DoStep. If a pointer to a function is provided, it must be called by the FMU after a completed communication step.
"""
function fmi2CallbackStepFinished(componentEnvironment::Ptr{Cvoid}, status::Cuint)
    @debug "cbStepFinished(_, $(status)): Step finished."
    nothing
end

# Common function for ModelExchange & CoSimulation

"""
Source: FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

Disposes the given instance, unloads the loaded model, and frees all the allocated memory and other resources that have been allocated by the functions of the FMU interface.
If a null pointer is provided for “c”, the function call is ignored (does not have an effect).

Removes the component from the FMUs component list.
"""
function fmi2FreeInstance!(c::FMU2Component; popComponent::Bool = true)

    if popComponent
        ind = findall(x -> x.compAddr==c.compAddr, c.fmu.components)
        @assert length(ind) == 1 "fmi2FreeInstance!(...): Freeing $(length(ind)) instances with one call, this is not allowed."
        deleteat!(c.fmu.components, ind)
    end

    fmi2FreeInstance!(c.fmu.cFreeInstance, c.compAddr)

    nothing
end

"""
Source: FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files

Returns the string to uniquely identify the “fmi2TypesPlatform.h” header file used for compilation of the functions of the FMU.
The standard header file, as documented in this specification, has fmi2TypesPlatform set to “default” (so this function usually returns “default”).
"""
function fmi2GetTypesPlatform(fmu::FMU2)

    typesPlatform = fmi2GetTypesPlatform(fmu.cGetTypesPlatform)

    unsafe_string(typesPlatform)
end
# special case
function fmi2GetTypesPlatform(c::FMU2Component)
    fmi2GetTypesPlatform(c.fmu)
end

"""
Source: FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files

Returns the version of the “fmi2Functions.h” header file which was used to compile the functions of the FMU. The function returns “fmiVersion” which is defined in this header file. The standard header file as documented in this specification has version “2.0”
"""
function fmi2GetVersion(fmu::FMU2)

    fmi2Version = fmi2GetVersion(fmu.cGetVersion)

    unsafe_string(fmi2Version)
end
# special case
function fmi2GetVersion(c::FMU2Component)
    fmi2GetVersion(c.fmu)
end

# helper 
function checkStatus(c::FMU2Component, status::fmi2Status)
    @assert (status != fmi2StatusWarning) || !c.fmu.executionConfig.assertOnWarning "Assert on `fmi2StatusWarning`. See stack for errors."
    
    if status == fmi2StatusError
        c.state = fmi2ComponentStateError
        @assert !c.fmu.executionConfig.assertOnError "Assert on `fmi2StatusError`. See stack for errors."
    
    elseif status == fmi2StatusFatal 
        c.state = fmi2ComponentStateFatal
        @assert false "Assert on `fmi2StatusFatal`. See stack for errors."
    end
end

"""
Source: FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

The function controls debug logging that is output via the logger function callback. If loggingOn = fmi2True, debug logging is enabled, otherwise it is switched off.
"""
function fmi2SetDebugLogging(c::FMU2Component, logginOn::fmi2Boolean, nCategories::Unsigned, categories::Ptr{Nothing})
    
    status = fmi2SetDebugLogging(c.fmu.cSetDebugLogging, c.compAddr, logginOn, nCategories, categories)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU to setup the experiment. This function must be called after fmi2Instantiate and before fmi2EnterInitializationMode is called.The function controls debug logging that is output via the logger function callback. If loggingOn = fmi2True, debug logging is enabled, otherwise it is switched off.
"""
function fmi2SetupExperiment(c::FMU2Component,
    toleranceDefined::fmi2Boolean,
    tolerance::fmi2Real,
    startTime::fmi2Real,
    stopTimeDefined::fmi2Boolean,
    stopTime::fmi2Real)

    if c.state != fmi2ComponentStateInstantiated
        @warn "fmi2SetupExperiment(...): Needs to be called in state `fmi2ComponentStateInstantiated`."
    end

    if startTime != 0.0
        if c.fmu.executionConfig.autoTimeShift
            #@info "fmi2SetupExperiment(...): You picked a start time which is not zero. Many FMUs don't support that feature, so all time intervals are shifted in the background to achieve the desired result. If this feature is unwanted, please use `myFMU.executionConfig.autoTimeShift=false`."
            c.t_offset = -startTime
            stopTime -= startTime
            startTime = 0.0 # equivalent to: startTime -= startTime
        end
    end

    status = fmi2SetupExperiment(c.fmu.cSetupExperiment,
                c.compAddr, toleranceDefined, tolerance, startTime, stopTimeDefined, stopTime)
    checkStatus(c, status)

    # remain in status on success, nothing to do here

    return status
end

"""
Source: FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU to enter Initialization Mode. Before calling this function, all variables with attribute <ScalarVariable initial = "exact" or "approx"> can be set with the “fmi2SetXXX” functions (the ScalarVariable attributes are defined in the Model Description File, see section 2.2.7). Setting other variables is not allowed. Furthermore, fmi2SetupExperiment must be called at least once before calling fmi2EnterInitializationMode, in order that startTime is defined.
"""
function fmi2EnterInitializationMode(c::FMU2Component)
 
    if c.state != fmi2ComponentStateInstantiated
        @warn "fmi2EnterInitializationMode(...): Needs to be called in state `fmi2ComponentStateInstantiated`."
    end
    status = fmi2EnterInitializationMode(c.fmu.cEnterInitializationMode, c.compAddr)
    checkStatus(c, status)
    if status == fmi2StatusOK
        c.state = fmi2ComponentStateInitializationMode
    end
    return status
end

"""
Source: FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU to exit Initialization Mode.
"""
function fmi2ExitInitializationMode(c::FMU2Component)

    if c.state != fmi2ComponentStateInitializationMode
        @warn "fmi2ExitInitializationMode(...): Needs to be called in state `fmi2ComponentStateInitializationMode`."
    end
  
    status = fmi2ExitInitializationMode(c.fmu.cExitInitializationMode, c.compAddr)
    checkStatus(c, status)
    if status == fmi2StatusOK
        c.state = fmi2ComponentStateEventMode
    end 
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU that the simulation run is terminated.
"""
function fmi2Terminate(c::FMU2Component; soft::Bool=false)
    if c.state != fmi2ComponentStateContinuousTimeMode && c.state != fmi2ComponentStateEventMode
        if soft 
            return fmi2StatusOK
        else
            @warn "fmi2Terminate(_): Needs to be called in state `fmi2ComponentStateContinuousTimeMode` or `fmi2ComponentStateEventMode`."
        end
    end
 
    status = fmi2Terminate(c.fmu.cTerminate, c.compAddr)
    checkStatus(c, status)
    if status == fmi2StatusOK 
        c.state = fmi2ComponentStateTerminated
    end 
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.6 Initialization, Termination, and Resetting an FMU

Is called by the environment to reset the FMU after a simulation run. The FMU goes into the same state as if fmi2Instantiate would have been called.
"""
function fmi2Reset(c::FMU2Component; soft::Bool=false)
    if c.state != fmi2ComponentStateTerminated && c.state != fmi2ComponentStateError
        if soft 
            return fmi2StatusOK
        else
            @warn "fmi2Reset(_): Needs to be called in state `fmi2ComponentStateTerminated` or `fmi2ComponentStateError`."
        end
    end
   
    if c.fmu.cReset == C_NULL
        fmi2FreeInstance!(c.fmu.cFreeInstance, c.compAddr)
        compAddr = fmi2Instantiate(c.fmu.cInstantiate, pointer(c.fmu.instanceName), c.fmu.type, pointer(c.fmu.modelDescription.guid), pointer(c.fmu.fmuResourceLocation), Ptr{fmi2CallbackFunctions}(pointer_from_objref(c.callbackFunctions)), fmi2Boolean(false), fmi2Boolean(false))

        if compAddr == Ptr{Cvoid}(C_NULL)
            @error "fmi2Reset(...): Reinstantiation failed!"
            return fmi2StatusError
        end

        c.compAddr = compAddr
        return fmi2StatusOK
    else
        status = fmi2Reset(c.fmu.cReset, c.compAddr)
        checkStatus(c, status)
        if status == fmi2StatusOK
            c.state = fmi2ComponentStateInstantiated
        end 
        return status
    end
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetReal!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Real})
   
    status = fmi2GetReal!(c.fmu.cGetReal,
          c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetReal(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Real})
    
    status = fmi2SetReal(c.fmu.cSetReal,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetInteger!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})
   
    status = fmi2GetInteger!(c.fmu.cGetInteger,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetInteger(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})
   
    status = fmi2SetInteger(c.fmu.cSetInteger,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetBoolean!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})
    
    status = fmi2GetBoolean!(c.fmu.cGetBoolean,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetBoolean(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})
   
    status = fmi2SetBoolean(c.fmu.cSetBoolean,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetString!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}})
   
    status = fmi2GetString!(c.fmu.cGetString,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetString(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}})
    
    status = fmi2SetString(c.fmu.cSetString,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2GetFMUstate makes a copy of the internal FMU state and returns a pointer to this copy
"""
function fmi2GetFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})
   
    status = fmi2GetFMUstate!(c.fmu.cGetFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SetFMUstate copies the content of the previously copied FMUstate back and uses it as actual new FMU state.
"""
function fmi2SetFMUstate(c::FMU2Component, FMUstate::fmi2FMUstate)
  
    status = fmi2SetFMUstate(c.fmu.cSetFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2FreeFMUstate frees all memory and other resources allocated with the fmi2GetFMUstate call for this FMUstate.
"""
function fmi2FreeFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})
   
    status = fmi2FreeFMUstate!(c.fmu.cFreeFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SerializedFMUstateSize returns the size of the byte vector, in order that FMUstate can be stored in it.
"""
function fmi2SerializedFMUstateSize!(c::FMU2Component, FMUstate::fmi2FMUstate, size::Ref{Csize_t})
   
    status = fmi2SerializedFMUstateSize!(c.fmu.cSerializedFMUstateSize,
                c.compAddr, FMUstate, size)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SerializeFMUstate serializes the data which is referenced by pointer FMUstate and copies this data in to the byte vector serializedState of length size
"""
function fmi2SerializeFMUstate!(c::FMU2Component, FMUstate::fmi2FMUstate, serialzedState::AbstractArray{fmi2Byte}, size::Csize_t)
  
    status = fmi2SerializeFMUstate!(c.fmu.cSerializeFMUstate,
                c.compAddr, FMUstate, serialzedState, size)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2DeSerializeFMUstate deserializes the byte vector serializedState of length size, constructs a copy of the FMU state and returns FMUstate, the pointer to this copy.
"""
function fmi2DeSerializeFMUstate!(c::FMU2Component, serializedState::AbstractArray{fmi2Byte}, size::Csize_t, FMUstate::Ref{fmi2FMUstate})
  
    status = fmi2DeSerializeFMUstate!(c.fmu.cDeSerializeFMUstate,
                c.compAddr, serializedState, size, FMUstate)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.9 Getting Partial Derivatives

This function computes the directional derivatives of an FMU.
"""
function fmi2GetDirectionalDerivative!(c::FMU2Component,
                                       vUnknown_ref::AbstractArray{fmi2ValueReference},
                                       nUnknown::Csize_t,
                                       vKnown_ref::AbstractArray{fmi2ValueReference},
                                       nKnown::Csize_t,
                                       dvKnown::AbstractArray{fmi2Real},
                                       dvUnknown::AbstractArray) # ToDo: Datatype for AbstractArray
    @assert fmi2ProvidesDirectionalDerivative(c.fmu) ["fmi2GetDirectionalDerivative!(...): This FMU does not support build-in directional derivatives!"]
   
    status = fmi2GetDirectionalDerivative!(c.fmu.cGetDirectionalDerivative,
          c.compAddr, vUnknown_ref, nUnknown, vKnown_ref, nKnown, dvKnown, dvUnknown)
    checkStatus(c, status)
    return status
end

# Functions specificly for isCoSimulation
"""
Source: FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

Sets the n-th time derivative of real input variables.
vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables
"""
function fmi2SetRealInputDerivatives(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})
    
    status = fmi2SetRealInputDerivatives(c.fmu.cSetRealInputDerivatives,
                c.compAddr, vr, nvr, order, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

Retrieves the n-th derivative of output values.
vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables
"""
function fmi2GetRealOutputDerivatives!(c::FMU2Component,  vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})
   
    status = fmi2GetRealOutputDerivatives!(c.fmu.cGetRealOutputDerivatives,
                c.compAddr, vr, nvr, order, value)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.104]: 4.2.2 Computation

The computation of a time step is started.
"""
function fmi2DoStep(c::FMU2Component, currentCommunicationPoint::fmi2Real, communicationStepSize::fmi2Real, noSetFMUStatePriorToCurrentPoint::fmi2Boolean)
    @assert c.fmu.cDoStep != C_NULL ["fmi2DoStep(...): This FMU does not support fmi2DoStep, probably it's a ME-FMU with no CS-support?"]
  
    status = fmi2DoStep(c.fmu.cDoStep,
          c.compAddr, currentCommunicationPoint, communicationStepSize, noSetFMUStatePriorToCurrentPoint)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.105]: 4.2.2 Computation

Can be called if fmi2DoStep returned fmi2Pending in order to stop the current asynchronous execution.
"""
function fmi2CancelStep(c::FMU2Component)
 
    status = fmi2CancelStep(c.fmu.cCancelStep, c.compAddr)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetStatus!(c::FMU2Component, s::fmi2StatusKind, value)
    rtype = nothing
    if s == fmi2Terminated
        rtype = fmi2Boolean
    else 
        @assert false "fmi2GetStatus!(_, $(s), $(value)): StatusKind $(s) not implemented yet, please open an issue."
    end
    @assert typeof(value) == rtype "fmi2GetStatus!(_, $(s), $(value)): Type of value ($(typeof(value))) doesn't fit type of return type $(rtype). Change type of value to $(rtype) or change status kind."
    
    status = fmi2Error
    if rtype == fmi2Boolean
        status = fmi2GetStatus!(c.fmu.cGetRealStatus,
                    c.compAddr, s, Ref(value))
        checkStatus(c, status)
    end 
    return status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetRealStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Real)
   
    status = fmi2GetRealStatus!(c.fmu.cGetRealStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetIntegerStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Integer)
  
    status = fmi2GetIntegerStatus!(c.fmu.cGetIntegerStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetBooleanStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Boolean)
  
    status = fmi2GetBooleanStatus!(c.fmu.cGetBooleanStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetStringStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2String)
  
    status = fmi2GetStringStatus!(c.fmu.cGetStringStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

# Model Exchange specific Functions

"""
Source: FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).
"""
function fmi2SetTime(c::FMU2Component, time::fmi2Real)
  
    status = fmi2SetTime(c.fmu.cSetTime,
          c.compAddr, time + c.t_offset)
    checkStatus(c, status)
    if status == fmi2StatusOK
        c.t = time 
    end 
    return status
end

"""
Source: FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes
"""
function fmi2SetContinuousStates(c::FMU2Component,
                                 x::AbstractArray{fmi2Real},
                                 nx::Csize_t)
 
    status = fmi2SetContinuousStates(c.fmu.cSetContinuousStates, c.compAddr, x, nx)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.84]: 3.2.2 Evaluation of Model Equations

The model enters Event Mode from the Continuous-Time Mode and discrete-time equations may become active (and relations are not “frozen”).
"""
function fmi2EnterEventMode(c::FMU2Component; soft::Bool=false)

    if c.state != fmi2ComponentStateContinuousTimeMode
        if soft 
            return fmi2StatusOK
        else
            @warn "fmi2EnterEventMode(...): Called at the wrong time."
        end
    end

    status = fmi2EnterEventMode(c.fmu.cEnterEventMode,
          c.compAddr)
    checkStatus(c, status)
    if status == fmi2StatusOK
        c.state = fmi2ComponentStateEventMode
    end
    return status
end

"""
Source: FMISpec2.0.2[p.84]: 3.2.2 Evaluation of Model Equations

The FMU is in Event Mode and the super dense time is incremented by this call.
"""
function fmi2NewDiscreteStates!(c::FMU2Component, eventInfo::fmi2EventInfo)

    if c.state != fmi2ComponentStateEventMode
        @warn "fmi2NewDiscreteStates(...): Needs to be called in state `fmi2ComponentStateEventMode` [$(fmi2ComponentStateEventMode)], is in [$(c.state)]."
    end
 
    status = fmi2NewDiscreteStates!(c.fmu.cNewDiscreteStates,
                    c.compAddr, Ptr{fmi2EventInfo}(pointer_from_objref(eventInfo)) )

    if eventInfo.nextEventTimeDefined == fmi2True
        eventInfo.nextEventTime -= c.t_offset
    end 

    checkStatus(c, status)
    # remain in the same mode and status (or ToDo: Meta-states)
    return status
end

"""
Source: FMISpec2.0.2[p.85]: 3.2.2 Evaluation of Model Equations

The model enters Continuous-Time Mode and all discrete-time equations become inactive and all relations are “frozen”.
This function has to be called when changing from Event Mode (after the global event iteration in Event Mode over all involved FMUs and other models has converged) into Continuous-Time Mode.
"""
function fmi2EnterContinuousTimeMode(c::FMU2Component; soft::Bool=false)

    if c.state != fmi2ComponentStateEventMode
        if soft 
            return fmi2StatusOK
        else
            @warn "fmi2EnterContinuousTimeMode(...): Needs to be called in state `fmi2ComponentStateEventMode`."
        end
    end

    status = fmi2EnterContinuousTimeMode(c.fmu.cEnterContinuousTimeMode,
          c.compAddr)
    checkStatus(c, status)
    if status == fmi2StatusOK
        c.state = fmi2ComponentStateContinuousTimeMode
    end
    return status
end

"""
Source: FMISpec2.0.2[p.85]: 3.2.2 Evaluation of Model Equations

This function must be called by the environment after every completed step of the integrator provided the capability flag completedIntegratorStepNotNeeded = false.
If enterEventMode == fmi2True, the event mode must be entered
If terminateSimulation == fmi2True, the simulation shall be terminated
"""
function fmi2CompletedIntegratorStep!(c::FMU2Component,
                                      noSetFMUStatePriorToCurrentPoint::fmi2Boolean,
                                      enterEventMode::Ptr{fmi2Boolean},
                                      terminateSimulation::Ptr{fmi2Boolean})
 
    status = fmi2CompletedIntegratorStep!(c.fmu.cCompletedIntegratorStep,
          c.compAddr, noSetFMUStatePriorToCurrentPoint, enterEventMode, terminateSimulation)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Compute state derivatives at the current time instant and for the current states.
"""
function fmi2GetDerivatives!(c::FMU2Component,
                            derivatives::AbstractArray{fmi2Real},
                            nx::Csize_t)
                    
    status = fmi2GetDerivatives!(c.fmu.cGetDerivatives,
          c.compAddr, derivatives, nx)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Compute event indicators at the current time instant and for the current states.
"""
function fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::AbstractArray{fmi2Real}, ni::Csize_t)

    status = fmi2GetEventIndicators!(c.fmu.cGetEventIndicators,
                    c.compAddr, eventIndicators, ni)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Return the new (continuous) state vector x.
"""
function fmi2GetContinuousStates!(c::FMU2Component,
                                 x::AbstractArray{fmi2Real},
                                 nx::Csize_t)
                       
    status = fmi2GetContinuousStates!(c.fmu.cGetContinuousStates,
          c.compAddr, x, nx)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Return the nominal values of the continuous states.
"""
function fmi2GetNominalsOfContinuousStates!(c::FMU2Component, x_nominal::AbstractArray{fmi2Real}, nx::Csize_t)
 
    status = fmi2GetNominalsOfContinuousStates!(c.fmu.cGetNominalsOfContinuousStates,
                    c.compAddr, x_nominal, nx)
    checkStatus(c, status)
    return status
end
