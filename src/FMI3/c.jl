#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_c.jl`?
# - default implementations for the `fmi3CallbackFunctions`
# - enum definition for `fmi3InstanceState` to protocol the current FMU-state
# - julia-implementaions of the functions inside the FMI-specification
# Any c-function `f(c::fmi3Instance, args...)` in the spec is implemented as `f(c::FMU3Instance, args...)`.
# Any c-function `f(args...)` without a leading `fmi3Instance`-arguemnt is implented as `f(c_ptr, args...)` where `c_ptr` is a pointer to the c-function (inside the DLL).

import FMICore: fmi3InstantiateCoSimulation, fmi3InstantiateModelExchange, fmi3InstantiateScheduledExecution, fmi3FreeInstance!, fmi3GetVersion
import FMICore: fmi3SetDebugLogging, fmi3EnterInitializationMode, fmi3ExitInitializationMode, fmi3Terminate, fmi3Reset
import FMICore: fmi3GetFloat32!, fmi3SetFloat32, fmi3GetFloat64!, fmi3SetFloat64
import FMICore: fmi3GetInt8!, fmi3SetInt8, fmi3GetInt16!, fmi3SetInt16,fmi3GetInt32!, fmi3SetInt32, fmi3GetInt64!, fmi3SetInt64
import FMICore: fmi3GetUInt8!, fmi3SetUInt8, fmi3GetUInt16!, fmi3SetUInt16,fmi3GetUInt32!, fmi3SetUInt32, fmi3GetUInt64!, fmi3SetUInt64
import FMICore: fmi3GetBoolean!, fmi3SetBoolean, fmi3GetString!, fmi3SetString, fmi3GetBinary!, fmi3SetBinary, fmi3GetClock!, fmi3SetClock
import FMICore: fmi3GetFMUState!, fmi3SetFMUState, fmi3FreeFMUState!, fmi3SerializedFMUStateSize!, fmi3SerializeFMUState!, fmi3DeSerializeFMUState!
import FMICore: fmi3SetIntervalDecimal, fmi3SetIntervalFraction, fmi3GetIntervalDecimal!, fmi3GetIntervalFraction!, fmi3GetShiftDecimal!, fmi3GetShiftFraction!, fmi3ActivateModelPartition
import FMICore: fmi3GetNumberOfVariableDependencies!, fmi3GetVariableDependencies!
import FMICore: fmi3GetDirectionalDerivative!, fmi3GetAdjointDerivative!, fmi3GetOutputDerivatives!
import FMICore: fmi3EnterConfigurationMode, fmi3ExitConfigurationMode
import FMICore: fmi3GetNumberOfContinuousStates!, fmi3GetNumberOfEventIndicators!
import FMICore: fmi3DoStep!, fmi3EnterStepMode
import FMICore: fmi3SetTime, fmi3SetContinuousStates, fmi3EnterEventMode, fmi3UpdateDiscreteStates, fmi3EnterContinuousTimeMode, fmi3CompletedIntegratorStep!
import FMICore: fmi3GetContinuousStateDerivatives, fmi3GetEventIndicators!, fmi3GetContinuousStates!, fmi3GetNominalsOfContinuousStates!, fmi3EvaluateDiscreteStates

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Function that is called in the FMU, usually if an fmi3XXX function, does not behave as desired. If “logger” is called with “status = fmi3OK”, then the message is a pure information message. 
instanceEnvironment - is the instance name of the model that calls this function. 
category - is the category of the message. The meaning of “category” is defined by the modeling environment that generated the FMU. Depending on this modeling environment, none, some or all allowed values of “category” for this FMU are defined in the modelDescription.xml file via element “<fmiModelDescription><LogCategories>”, see section 2.4.5. Only messages are provided by function logger that have a category according to a call to fmi3SetDebugLogging (see below). 
message - is provided in the same way and with the same format control as in function “printf” from the C standard library. [Typically, this function prints the message and stores it optionally in a log file.]
"""
# TODO error in the specification??
function fmi3CallbackLogger(_instanceEnvironment::Ptr{Cvoid},
    _status::Cuint,
    _category::Ptr{Cchar},
    _message::Ptr{Cchar})

message = unsafe_string(_message)
category = unsafe_string(_category)
status = fmi3StatusToString(_status)
instanceEnvironment = unsafe_load(_instanceEnvironment)

if status == fmi3StatusOK && instanceEnvironment.logStatusOK
@info "[$status][$category][$instanceName]: $message"
elseif (status == fmi3StatusWarning && instanceEnvironment.logStatusWarning)
@warn "[$status][$category][$instanceName]: $message"
elseif (status == fmi3StatusDiscard && instanceEnvironment.logStatusDiscard) ||
   (status == fmi3StatusError   && instanceEnvironment.logStatusError) ||
   (status == fmi3StatusFatal   && instanceEnvironment.logStatusFatal)
@error "[$status][$category][$instanceName]: $message"
end

return nothing
end

"""
Source: FMISpec3.0, Version D5ef1c1: 4.2.2. State: Intermediate Update Mode

When a Co-Simulation FMU provides values for its output variables at intermediate points between two consecutive communication points, and is able to receive new values for input variables at these intermediate points, the Intermediate Update Callback function is called. This is typically required when the FMU uses a numerical solver to integrate the FMU's internal state between communication points in fmi3DoStep. 
The callback function switches the FMU from Step Mode (see 4.2.1.) in the Intermediate Update Mode (see 4.2.2.) and returns to Step Mode afterwards. The parameters of this function are:

instanceEnvironment - is the instance name of the model that calls this function. 

intermediateUpdateTime - is the internal value of the independent variable [typically simulation time] of the FMU at which the callback has been called for intermediate and final steps. If an event happens or an output Clock ticks, intermediateUpdateTime is the time of event or output Clock tick. In Co-Simulation, intermediateUpdateTime is restricted by the arguments to fmi3DoStep as follows:
currentCommunicationPoint ≤ intermediateUpdateTime ≤ (currentCommunicationPoint + communicationStepSize).
The FMU must not call the callback function fmi3CallbackIntermediateUpdate with an intermediateUpdateTime that is smaller than the intermediateUpdateTime given in a previous call of fmi3CallbackIntermediateUpdate with intermediateStepFinished == fmi3True.

If intermediateVariableSetRequested == fmi3True, the co-simulation algorithm may provide intermediate values for continuous input variables with intermediateUpdate = true by calling fmi3Set{VariableType}. The set of variables for which the co-simulation algorithm will provide intermediate values is declared through the requiredIntermediateVariables argument to fmi3InstantiateXXX. If a co-simulation algorithm does not provide a new value for any of the variables contained in the set it registered, the last value set remains.

If intermediateVariableGetAllowed == fmi3True, the co-simulation algorithm may collect intermediate output variables by calling fmi3Get{VariableType} for variables with intermediateUpdate = true. The set of variables for which the co-simulation algorithm can get values is supplied through the requiredIntermediateVariables argument to fmi3InstantiateXXX.

If intermediateStepFinished == fmi3False, the intermediate outputs of the FMU that the co-simulation algorithm inquires with fmi3Get{VariableType} resulting from tentative internal solver states and may still change for the same intermediateUpdateTime [e.g., if the solver deems the tentative state to cause a too high approximation error, it may go back in time and try to re-estimate the state using smaller internal time steps].
If intermediateStepFinished == fmi3True, intermediate outputs inquired by the co-simulation algorithm with fmi3Get{VariableType} correspond to accepted internal solver step.

When canReturnEarly == fmi3True the FMU signals to the co-simulation algorithm its ability to return early from the current fmi3DoStep.

earlyReturnRequested - If and only if canReturnEarly == fmi3True, the co-simulation algorithm may request the FMU to return early from fmi3DoStep by setting earlyReturnRequested == fmi3True.

earlyReturnTime is used to signal the FMU at which time to return early from the current fmi3DoStep, if the return value of earlyReturnRequested == fmi3True. If the earlyReturnTime is greater than the last signaled intermediateUpdateTime, the FMU may integrate up to the time instant earlyReturnTime.

If the ModelDescription has the "providesIntermediateUpdate" flag, the Intermediate update callback function is called. That flag is ignored in ModelExchange and ScheduledExecution.
"""
function fmi3CallbackIntermediateUpdate(instanceEnvironment::Ptr{Cvoid},
    intermediateUpdateTime::fmi3Float64,
    intermediateVariableSetRequested::fmi3Boolean,
    intermediateVariableGetAllowed::fmi3Boolean,
    intermediateStepFinished::fmi3Boolean,
    canReturnEarly::fmi3Boolean,
    earlyReturnRequested::Ptr{fmi3Boolean},
    earlyReturnTime::Ptr{fmi3Float64})
    @debug "To be implemented!"
end

"""
Source: FMISpec3.0, Version D5ef1c1: 5.2.2. State: Clock Activation Mode

A model partition of a Scheduled Execution FMU calls fmi3CallbackClockUpdate to signal that a triggered output Clock ticked or a new interval for a countdown Clock is available.
fmi3CallbackClockUpdate switches the FMU itself then into the Clock Update Mode (see 5.2.3.). The callback may be called from several model partitions.

instanceEnvironment - is the instance name of the model that calls this function. 
"""
function fmi3CallbackClockUpdate(instanceEnvironment::Ptr{Cvoid})
    @debug "to be implemented!"
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Disposes the given instance, unloads the loaded model, and frees all the allocated memory and other resources that have been allocated by the functions of the FMU interface. If a NULL pointer is provided for argument instance, the function call is ignored (does not have an effect).
"""
function fmi3FreeInstance!(c::FMU3Instance)

    ind = findall(x->x==c, c.fmu.instances)
    deleteat!(c.fmu.instances, ind)
    ccall(c.fmu.cFreeInstance, Cvoid, (Ptr{Cvoid},), c.compAddr)

    nothing
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.4. Inquire Version Number of Header Files

This function returns fmi3Version of the fmi3Functions.h header file which was used to compile the functions of the FMU. This function call is allowed always and in all interface types.

The standard header file as documented in this specification has version "3.0-beta.2", so this function returns "3.0-beta.2".
"""
function fmi3GetVersion(fmu::FMU3)

    fmi3Version = fmi3GetVersion(fmu.cGetVersion)

    unsafe_string(fmi3Version)
end
# special case
function fmi3GetVersion(c::FMU3Instance)
    fmi3GetVersion(c.fmu)
end

# helper 
function checkStatus(c::FMU3Instance, status::fmi3Status)
    @assert (status != fmi3StatusWarning) || !c.fmu.executionConfig.assertOnWarning "Assert on `fmi3StatusWarning`. See stack for errors."
    
    if status == fmi3StatusError
        c.state = fmi3InstanceStateError
        @assert !c.fmu.executionConfig.assertOnError "Assert on `fmi3StatusError`. See stack for errors."
    
    elseif status == fmi3StatusFatal 
        c.state = fmi3InstanceStateFatal
        @assert false "Assert on `fmi3StatusFatal`. See stack for errors."
    end
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

The function controls debug logging that is output via the logger function callback. If loggingOn = fmi3True, debug logging is enabled, otherwise it is switched off.
"""
function fmi3SetDebugLogging(c::FMU3Instance, logginOn::fmi3Boolean, nCategories::UInt, categories::Ptr{Nothing})
    status = fmi3SetDebugLogging(c.fmu.cSetDebugLogging, c.compAddr, logginOn, nCategories, categories)
    checkStatus(c, status)
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

Informs the FMU to enter Initialization Mode. Before calling this function, all variables with attribute <Datatype initial = "exact" or "approx"> can be set with the “fmi3SetXXX” functions (the ScalarVariable attributes are defined in the Model Description File, see section 2.4.7). Setting other variables is not allowed.
Also sets the simulation start and stop time.
"""
function fmi3EnterInitializationMode(c::FMU3Instance, toleranceDefined::fmi3Boolean,
    tolerance::fmi3Float64,
    startTime::fmi3Float64,
    stopTimeDefined::fmi3Boolean,
    stopTime::fmi3Float64)
    if c.state != fmi3InstanceStateInstantiated
        @warn "fmi3EnterInitializationMode(...): Needs to be called in state `fmi3IntanceStateInstantiated`."
    end
    status = fmi3EnterInitializationMode(c.fmu.cEnterInitializationMode, c.compAddr, toleranceDefined, tolerance, startTime, stopTimeDefined, stopTime)
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateInitializationMode
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Informs the FMU to exit Initialization Mode.
"""
function fmi3ExitInitializationMode(c::FMU3Instance)
    if c.state != fmi3InstanceStateInitializationMode
        @warn "fmi3ExitInitializationMode(...): Needs to be called in state `fmi3InstanceStateInitializationMode`."
    end
  
    status = fmi3ExitInitializationMode(c.fmu.cExitInitializationMode, c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK
        if fmi3IsCoSimulation(c.fmu) && c.fmu.modelDescription.coSimulation.hasEventMode
            c.state = fmi3InstanceStateStepMode
        elseif fmi3IsScheduledExecution(c.fmu)
            c.state = fmi3InstanceStateClockActivationMode
        else
            c.state = fmi3InstanceStateEventMode
        end
    end 
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.4. Super State: Initialized

Informs the FMU that the simulation run is terminated.
"""
function fmi3Terminate(c::FMU3Instance; soft::Bool=false)
    if c.state != fmi3InstanceStateContinuousTimeMode && c.state != fmi3InstanceStateEventMode && c.state != fmi3InstanceStateClockActivationMode && c.state != fmi3InstanceStateStepMode
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3Terminate(_): Needs to be called in state `fmi3InstanceStateContinuousTimeMode`, `fmi3InstanceStateEventMode`, `fmi3InstanceStateClockActivationMode` or `fmi3InstanceStateStepMode`."
        end
    end
 
    status = fmi3Terminate(c.fmu.cTerminate, c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK 
        c.state = fmi3InstanceStateTerminated
    end 
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Is called by the environment to reset the FMU after a simulation run. The FMU goes into the same state as if fmi3InstantiateXXX would have been called.
"""
function fmi3Reset(c::FMU3Instance)
    if c.state != fmi3InstanceStateTerminated && c.state != fmi3InstanceStateError
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3Reset(_): Needs to be called in state `fmi3InstanceStateTerminated` or `fmi3InstanceStateError`."
        end
    end
   
    if c.fmu.cReset == C_NULL
        fmi3FreeInstance!(c.fmu.cFreeInstance, c.compAddr)
        if fmi3IsCoSimulation(c.fmu)
            compAddr = fmi3InstantiateCoSimulation!(c.fmu)
        elseif fmi3IsModelExchange(c.fmu)
            compAddr = fmi3InstantiateModelExchange!(c.fmu)
        elseif fmi3IsScheduledExecution(c.fmu)
            compAddr = fmi3InstantiateScheduledExecution!(c.fmu)
        end

        if compAddr == Ptr{Cvoid}(C_NULL)
            @error "fmi3Reset(...): Reinstantiation failed!"
            return fmi3StatusError
        end

        c.compAddr = compAddr
        return fmi3StatusOK
    else
        status = fmi3Reset(c.fmu.cReset, c.compAddr)
        checkStatus(c, status)
        if status == fmi3StatusOK
            c.state = fmi3InstanceStateInstantiated
        end 
        return status
    end
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetFloat32!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Float32}, nvalue::Csize_t)
    status = fmi3GetFloat32!(c.fmu.cGetFloat32,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end


"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetFloat32(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Float32}, nvalue::Csize_t)
    status = fmi3SetFloat32(c.fmu.cSetFloat32,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetFloat64!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Float64}, nvalue::Csize_t)
    status = fmi3GetFloat64!(c.fmu.cGetFloat64,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end


"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetFloat64(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Float64}, nvalue::Csize_t)
    status = fmi3SetFloat64(c.fmu.cSetFloat64,
               c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt8!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int8}, nvalue::Csize_t)
    status = fmi3GetInt8!(c.fmu.cGetInt8,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt8(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int8}, nvalue::Csize_t)
    status = fmi3SetInt8(c.fmu.cSetInt8,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt8!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt8}, nvalue::Csize_t)
    status = fmi3GetUInt8!(c.fmu.cGetUInt8,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt8(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt8}, nvalue::Csize_t)
    status = fmi3SetUInt8(c.fmu.cSetUInt8,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt16!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int16}, nvalue::Csize_t)
    status = fmi3GetInt16!(c.fmu.cGetInt16,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status  
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt16(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int16}, nvalue::Csize_t)
    status = fmi3SetInt16(c.fmu.cSetInt16,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt16!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt16}, nvalue::Csize_t)
    status = fmi3GetUInt16!(c.fmu.cGetUInt16,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt16(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt16}, nvalue::Csize_t)
    status = fmi3SetUInt16(c.fmu.cSetUInt16,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt32!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int32}, nvalue::Csize_t)
    status = fmi3GetInt32!(c.fmu.cGetInt32,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt32(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int32}, nvalue::Csize_t)
    status = fmi3SetInt32(c.fmu.cSetInt32,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt32!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt32}, nvalue::Csize_t)
    status = fmi3GetUInt32!(c.fmu.cGetUInt32,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt32(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt32}, nvalue::Csize_t)
    status = fmi3SetUInt32(c.fmu.cSetUInt32,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt64!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int64}, nvalue::Csize_t)
    status = fmi3GetInt64!(c.fmu.cGetInt64,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt64(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Int64}, nvalue::Csize_t)
    status = fmi3SetInt64(c.fmu.cSetInt64,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt64!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt64}, nvalue::Csize_t)
    status = fmi3GetUInt64!(c.fmu.cGetUInt64,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt64(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3UInt64}, nvalue::Csize_t)
    status = fmi3SetUInt64(c.fmu.cSetUInt64,
            c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetBoolean!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Boolean}, nvalue::Csize_t)
    status = fmi3GetBoolean!(c.fmu.cGetBoolean,
          c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetBoolean(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Boolean}, nvalue::Csize_t)
    status = fmi3SetBoolean(c.fmu.cSetBoolean,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO change to fmi3String when possible to test
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetString!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::Vector{Ptr{Cchar}}, nvalue::Csize_t)
    status = fmi3GetString!(c.fmu.cGetString,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""     
function fmi3SetString(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}}, nvalue::Csize_t)
    status = fmi3SetString(c.fmu.cSetString,
                c.compAddr, vr, nvr, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValues - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetBinary!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, valueSizes::AbstractArray{Csize_t}, value::AbstractArray{fmi3Binary}, nvalue::Csize_t)
    status = fmi3GetBinary!(c.fmu.cGetBinary,
                c.compAddr, vr, nvr, valueSizes, value, nvalue)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetBinary(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, valueSizes::AbstractArray{Csize_t}, value::AbstractArray{fmi3Binary}, nvalue::Csize_t)
    status = fmi3SetBinary(c.fmu.cSetBinary,
                c.compAddr, vr, nvr, valueSizes, value, nvalue)
    checkStatus(c, status)
    status
end

# TODO, Clocks not implemented so far thus not tested
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetClock!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Clock})
    status = fmi3GetClock!(c.fmu.cGetClock,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetClock(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, value::AbstractArray{fmi3Clock})
    status = fmi3SetClock(c.fmu.cSetClock,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3GetFMUstate makes a copy of the internal FMU state and returns a pointer to this copy
"""
function fmi3GetFMUState!(c::FMU3Instance, FMUstate::Ref{fmi3FMUState})
    status = fmi3GetFMUState!(c.fmu.cGetFMUState,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SetFMUstate copies the content of the previously copied FMUstate back and uses it as actual new FMU state.
"""
function fmi3SetFMUState(c::FMU3Instance, FMUstate::fmi3FMUState)
    status = fmi3SetFMUState(c.fmu.cSetFMUState,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3FreeFMUstate frees all memory and other resources allocated with the fmi3GetFMUstate call for this FMUstate.
"""
function fmi3FreeFMUState!(c::FMU3Instance, FMUstate::Ref{fmi3FMUState})
    status = fmi3FreeFMUState!(c.fmu.cFreeFMUState,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SerializedFMUstateSize returns the size of the byte vector which is needed to store FMUstate in it.
"""
function fmi3SerializedFMUStateSize!(c::FMU3Instance, FMUstate::fmi3FMUState, size::Ref{Csize_t})
    status = fmi3SerializedFMUStateSize!(c.fmu.cSerializedFMUStateSize,
                c.compAddr, FMUstate, size)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SerializeFMUstate serializes the data which is referenced by pointer FMUstate and copies this data in to the byte vector serializedState of length size
"""
function fmi3SerializeFMUState!(c::FMU3Instance, FMUstate::fmi3FMUState, serialzedState::AbstractArray{fmi3Byte}, size::Csize_t)
    status = fmi3SerializeFMUState!(c.fmu.cSerializeFMUState,
                c.compAddr, FMUstate, serialzedState, size)
    checkStatus(c, status)
    status   
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3DeSerializeFMUstate deserializes the byte vector serializedState of length size, constructs a copy of the FMU state and returns FMUstate, the pointer to this copy.
"""
function fmi3DeSerializeFMUState!(c::FMU3Instance, serialzedState::AbstractArray{fmi3Byte}, size::Csize_t, FMUstate::Ref{fmi3FMUState})
    status = fmi3DeSerializeFMUState!(c.fmu.cDeSerializeFMUState,
                c.compAddr, serialzedState, size, FMUstate)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3SetIntervalDecimal sets the interval until the next clock tick
"""
# TODO Clocks and dependencies functions
function fmi3SetIntervalDecimal(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, intervals::AbstractArray{fmi3Float64})
    status = fmi3SetIntervalDecimal(c.fmu.cSetIntervalDecimal,
                c.compAddr, vr, nvr, intervals)     
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3SetIntervalFraction sets the interval until the next clock tick
Only allowed if the attribute 'supportsFraction' is set.
"""
function fmi3SetIntervalFraction(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, intervalCounters::AbstractArray{fmi3UInt64}, resolutions::AbstractArray{fmi3UInt64})
    status = fmi3SetIntervalFraction(c.fmu.cSetIntervalFraction,
                c.compAddr, vr, nvr, intervalCounters, resolutions)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetIntervalDecimal retrieves the interval until the next clock tick.

For input Clocks it is allowed to call this function to query the next activation interval.
For changing aperiodic Clock, this function must be called in every Event Mode where this clock was activated.
For countdown aperiodic Clock, this function must be called in every Event Mode.
Clock intervals are computed in fmi3UpdateDiscreteStates (at the latest), therefore, this function should be called after fmi3UpdateDiscreteStates.
For information about fmi3IntervalQualifiers, call ?fmi3IntervalQualifier
"""
function fmi3GetIntervalDecimal!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, intervals::AbstractArray{fmi3Float64}, qualifiers::fmi3IntervalQualifier)
    status = fmi3GetIntervalDecimal!(c.fmu.cGetIntervalDecimal,
                c.compAddr, vr, nvr, intervals, qualifiers)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetIntervalFraction retrieves the interval until the next clock tick.

For input Clocks it is allowed to call this function to query the next activation interval.
For changing aperiodic Clock, this function must be called in every Event Mode where this clock was activated.
For countdown aperiodic Clock, this function must be called in every Event Mode.
Clock intervals are computed in fmi3UpdateDiscreteStates (at the latest), therefore, this function should be called after fmi3UpdateDiscreteStates.
For information about fmi3IntervalQualifiers, call ?fmi3IntervalQualifier
"""
function fmi3GetIntervalFraction!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, intervalCounters::AbstractArray{fmi3UInt64}, resolutions::AbstractArray{fmi3UInt64}, qualifiers::fmi3IntervalQualifier)
    status = fmi3GetIntervalFraction!(c.fmu.cGetIntervalFraction,
                c.compAddr, vr, nvr, intervalCounters, resolutions, qualifiers)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetShiftDecimal retrieves the delay to the first Clock tick from the FMU.
"""
function fmi3GetShiftDecimal!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, shifts::AbstractArray{fmi3Float64})
    status = fmi3GetShiftDecimal!(c.fmu.cGetShiftDecimal,
                c.compAddr, vr, nvr, shifts)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetShiftFraction retrieves the delay to the first Clock tick from the FMU.
"""
function fmi3GetShiftFraction!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nvr::Csize_t, shiftCounters::AbstractArray{fmi3UInt64}, resolutions::AbstractArray{fmi3UInt64})
    status = fmi3GetShiftFraction!(c.fmu.cGetShiftFraction,
                c.compAddr, vr, nvr, shiftCounters, resolutions)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 5.2.2. State: Clock Activation Mode

During Clock Activation Mode (see 5.2.2.) after fmi3ActivateModelPartition has been called for a calculated, tunable or changing Clock the FMU provides the information on when the Clock will tick again, i.e. when the corresponding model partition has to be scheduled the next time.

Each fmi3ActivateModelPartition call is associated with the computation of an exposed model partition of the FMU and therefore to an input Clock.
"""
function fmi3ActivateModelPartition(c::FMU3Instance, vr::fmi3ValueReference, activationTime::AbstractArray{fmi3Float64})
    status = fmi3ActivateModelPartition(c.fmu.cActivateModelPartition,
                c.compAddr, vr, activationTime)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.10. Dependencies of Variables

The number of dependencies of a given variable, which may change if structural parameters are changed, can be retrieved by calling fmi3GetNumberOfVariableDependencies.

This information can only be retrieved if the 'providesPerElementDependencies' tag in the ModelDescription is set.
"""
# TODO not tested
function fmi3GetNumberOfVariableDependencies!(c::FMU3Instance, vr::fmi3ValueReference, nvr::Ref{Csize_t})
    status = fmi3GetNumberOfVariableDependencies!(c.fmu.cGetNumberOfVariableDependencies,
                c.compAddr, vr, nvr)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.10. Dependencies of Variables

The actual dependencies (of type dependenciesKind) can be retrieved by calling the function fmi3GetVariableDependencies:

dependent - specifies the valueReference of the variable for which the dependencies should be returned.

nDependencies - specifies the number of dependencies that the calling environment allocated space for in the result buffers, and should correspond to value obtained by calling fmi3GetNumberOfVariableDependencies.

elementIndicesOfDependent - must point to a buffer of size_t values of size nDependencies allocated by the calling environment. 
It is filled in by this function with the element index of the dependent variable that dependency information is provided for. The element indices start with 1. Using the element index 0 means all elements of the variable. (Note: If an array has more than one dimension the indices are serialized in the same order as defined for values in Section 2.2.6.1.)

independents -  must point to a buffer of fmi3ValueReference values of size nDependencies allocated by the calling environment. 
It is filled in by this function with the value reference of the independent variable that this dependency entry is dependent upon.

elementIndicesIndependents - must point to a buffer of size_t values of size nDependencies allocated by the calling environment. 
It is filled in by this function with the element index of the independent variable that this dependency entry is dependent upon. The element indices start with 1. Using the element index 0 means all elements of the variable. (Note: If an array has more than one dimension the indices are serialized in the same order as defined for values in Section 2.2.6.1.)

dependencyKinds - must point to a buffer of dependenciesKind values of size nDependencies allocated by the calling environment. 
It is filled in by this function with the enumeration value describing the dependency of this dependency entry.
For more information about dependenciesKinds, call ?fmi3DependencyKind

If this function is called before the fmi3ExitInitializationMode call, it returns the initial dependencies. If this function is called after the fmi3ExitInitializationMode call, it returns the runtime dependencies. 
The retrieved dependency information of one variable becomes invalid as soon as a structural parameter linked to the variable or to any of its depending variables are set. As a consequence, if you change structural parameters affecting B or A, the dependency of B becomes invalid. The dependency information must change only if structural parameters are changed.

This information can only be retrieved if the 'providesPerElementDependencies' tag in the ModelDescription is set.
"""
function fmi3GetVariableDependencies!(c::FMU3Instance, vr::fmi3ValueReference, elementIndiceOfDependents::AbstractArray{Csize_t}, independents::AbstractArray{fmi3ValueReference},  
    elementIndiceOfInpendents::AbstractArray{Csize_t}, dependencyKind::AbstractArray{fmi3DependencyKind}, ndependencies::Csize_t)
    status = fmi3GetVariableDependencies!(c.fmu.cGetVariableDependencies,
               c.compAddr, vr, elementIndiceOfDependents, independents, elementIndiceOfInpendents, dependencyKind, ndependencies)
    checkStatus(c, status)
    status
end

# TODO not tested
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

This function computes the directional derivatives v_{sensitivity} = J ⋅ v_{seed} of an FMU.

unknowns - contains value references to the unknowns.

nUnknowns - contains the length of argument unknowns.

knowns - contains value references of the knowns.

nKnowns - contains the length of argument knowns.

seed - contains the components of the seed vector.

nSeed - contains the length of seed.

sensitivity - contains the components of the sensitivity vector.

nSensitivity - contains the length of sensitivity.

This function can only be called if the 'ProvidesDirectionalDerivatives' tag in the ModelDescription is set.
"""
function fmi3GetDirectionalDerivative!(c::FMU3Instance,
                                       unknowns::AbstractArray{fmi3ValueReference},
                                       nUnknowns::Csize_t,
                                       knowns::AbstractArray{fmi3ValueReference},
                                       nKnowns::Csize_t,
                                       seed::AbstractArray{fmi3Float64},
                                       nSeed::Csize_t,
                                       sensitivity::AbstractArray{fmi3Float64},
                                       nSensitivity::Csize_t)
    status = fmi3GetDirectionalDerivative!(c.fmu.cGetDirectionalDerivative,
          c.compAddr, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)
    checkStatus(c, status)
    status
    
end

# TODO not tested
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

This function computes the adjoint derivatives v^T_{sensitivity}= v^T_{seed} ⋅ J of an FMU.

unknowns - contains value references to the unknowns.

nUnknowns - contains the length of argument unknowns.

knowns - contains value references of the knowns.

nKnowns - contains the length of argument knowns.

seed - contains the components of the seed vector.

nSeed - contains the length of seed.

sensitivity - contains the components of the sensitivity vector.

nSensitivity - contains the length of sensitivity.

This function can only be called if the 'ProvidesAdjointDerivatives' tag in the ModelDescription is set.
"""
function fmi3GetAdjointDerivative!(c::FMU3Instance,
                                       unknowns::AbstractArray{fmi3ValueReference},
                                       nUnknowns::Csize_t,
                                       knowns::AbstractArray{fmi3ValueReference},
                                       nKnowns::Csize_t,
                                       seed::AbstractArray{fmi3Float64},
                                       nSeed::Csize_t,
                                       sensitivity::AbstractArray{fmi3Float64},
                                       nSensitivity::Csize_t)
    status = fmi3GetAdjointDerivative!(c.fmu.cGetAdjointDerivative,
          c.compAddr, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)
    checkStatus(c, status)
    status
    
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.12. Getting Derivatives of Continuous Outputs

Retrieves the n-th derivative of output values.

valueReferences - is a vector of value references that define the variables whose derivatives shall be retrieved. If multiple derivatives of a variable shall be retrieved, list the value reference multiple times.

nValueReferences - is the dimension of the arguments valueReferences and orders.

orders - contains the orders of the respective derivative (1 means the first derivative, 2 means the second derivative, …, 0 is not allowed). 
If multiple derivatives of a variable shall be retrieved, provide a list of them in the orders array, corresponding to a multiply occurring value reference in the valueReferences array.
The highest order of derivatives retrievable can be determined by the 'maxOutputDerivativeOrder' tag in the ModelDescription.

values - is a vector with the values of the derivatives. The order of the values elements is derived from a twofold serialization: the outer level corresponds to the combination of a value reference (e.g., valueReferences[k]) and order (e.g., orders[k]), and the inner level to the serialization of variables as defined in Section 2.2.6.1. The inner level does not exist for scalar variables.

nValues - is the size of the argument values. nValues only equals nValueReferences if all corresponding output variables are scalar variables.
"""
function fmi3GetOutputDerivatives!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nValueReferences::Csize_t, order::AbstractArray{fmi3Int32}, values::AbstractArray{fmi3Float64}, nValues::Csize_t)
    status = fmi3GetOutputDerivatives!(c.fmu.cGetOutputDerivatives,
               c.compAddr, vr, nValueReferences, order, values, nValues)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

If the importer needs to change structural parameters, it must move the FMU into Configuration Mode using fmi3EnterConfigurationMode.
"""
function fmi3EnterConfigurationMode(c::FMU3Instance) 
    if c.state != fmi3InstanceStateInstantiated && (c.state != fmi3InstanceStateStepMode && fmi3IsCoSimulation(c.fmu)) && (c.state != fmi3InstanceEventMode && fmi3IsModelExchange(c.fmu)) 
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3EnterConfigurationMode(...): Called at the wrong time."
        end
    end

    status = fmi3EnterConfigurationMode(c.fmu.cEnterConfigurationMode,
    c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK
        if c.state == fmi3InstanceStateInstantiate 
            c.state = fmi3InstanceStateConfigurationMode
        else
            c.state = fmi3InstanceStateReconfigurationMode
        end
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.6. State: Configuration Mode

Exits the Configuration Mode and returns to state Instantiated.
"""
function fmi3ExitConfigurationMode(c::FMU3Instance)
    if c.state != fmi3InstanceStateConfigurationMode && c.state != fmi3InstanceStateReconfigurationMode
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3ExitConfigurationMode(...): Called at the wrong time."
        end
    end

    status = fmi3ExitConfigurationMode(c.fmu.cExitConfigurationMode,
         c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK
        if c.state == fmi3InstanceStateConfigurationMode
            c.state = fmi3InstanceStateInstantiate 
        elseif fmi3IsCoSimulation(c.fmu)
            c.state = fmi3InstanceStateStepMode
        elseif fmi3IsModelExchange(c.fmu)
            c.state = fmi3InstanceStateEventMode
        elseif fmi3IsScheduledExecution(c.fmu)
            c.state = fmi3InstanceStateClockActivationMode
        end
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of continuous states.
This function can only be called in Model Exchange. 

fmi3GetNumberOfContinuousStates must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
"""
function fmi3GetNumberOfContinuousStates!(c::FMU3Instance, nContinuousStates::Ref{Csize_t})
    status = fmi3GetNumberOfContinuousStates!(c.fmu.cGetNumberOfContinuousStates,
           c.compAddr, nContinuousStates)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of event indicators.
This function can only be called in Model Exchange. 

fmi3GetNumberOfEventIndicators must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
"""
function fmi3GetNumberOfEventIndicators!(c::FMU3Instance, nEventIndicators::Ref{Csize_t})
    status = fmi3GetNumberOfEventIndicators!(c.fmu.cGetNumberOfEventIndicators,
            c.compAddr, nEventIndicators)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the states at the current time instant.

This function must be called if fmi3UpdateDiscreteStates returned with valuesOfContinuousStatesChanged == fmi3True. Not allowed in Co-Simulation and Scheduled Execution.
"""
function fmi3GetContinuousStates!(c::FMU3Instance, nominals::AbstractArray{fmi3Float64}, nContinuousStates::Csize_t)
    status = fmi3GetContinuousStates!(c.fmu.cGetContinuousStates,
            c.compAddr, nominals, nContinuousStates)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the nominal values of the continuous states.

If fmi3UpdateDiscreteStates returned with nominalsOfContinuousStatesChanged == fmi3True, then at least one nominal value of the states has changed and can be inquired with fmi3GetNominalsOfContinuousStates.
Not allowed in Co-Simulation and Scheduled Execution.
"""
function fmi3GetNominalsOfContinuousStates!(c::FMU3Instance, x_nominal::AbstractArray{fmi3Float64}, nx::Csize_t)
    status = fmi3GetNominalsOfContinuousStates!(c.fmu.cGetNominalsOfContinuousStates,
                    c.compAddr, x_nominal, nx)
    checkStatus(c, status)
    status
end

# TODO not testable not supported by FMU
"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

This function is called to trigger the evaluation of fdisc to compute the current values of discrete states from previous values. 
The FMU signals the support of fmi3EvaluateDiscreteStates via the capability flag providesEvaluateDiscreteStates.
"""
function fmi3EvaluateDiscreteStates(c::FMU3Instance)
    status = fmi3EvaluateDiscreteStates(c.fmu.cEvaluateDiscreteStates,
            c.compAddr)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

This function is called to signal a converged solution at the current super-dense time instant. fmi3UpdateDiscreteStates must be called at least once per super-dense time instant.
"""
function fmi3UpdateDiscreteStates(c::FMU3Instance, discreteStatesNeedUpdate::Ref{fmi3Boolean}, terminateSimulation::Ref{fmi3Boolean}, 
                                    nominalsOfContinuousStatesChanged::Ref{fmi3Boolean}, valuesOfContinuousStatesChanged::Ref{fmi3Boolean},
                                    nextEventTimeDefined::Ref{fmi3Boolean}, nextEventTime::Ref{fmi3Float64})
    status = fmi3UpdateDiscreteStates(c.fmu.cUpdateDiscreteStates,
            c.compAddr, discreteStatesNeedUpdate, terminateSimulation, nominalsOfContinuousStatesChanged, valuesOfContinuousStatesChanged, nextEventTimeDefined, nextEventTime)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

The model enters Continuous-Time Mode and all discrete-time equations become inactive and all relations are “frozen”.
This function has to be called when changing from Event Mode (after the global event iteration in Event Mode over all involved FMUs and other models has converged) into Continuous-Time Mode.
"""
function fmi3EnterContinuousTimeMode(c::FMU3Instance; soft::Bool=false)
    if c.state != fmi3InstanceStateEventMode
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3EnterContinuousTimeMode(...): Needs to be called in state `fmi3InstanceStateEventMode`."
        end
    end

    status = fmi3EnterContinuousTimeMode(c.fmu.cEnterContinuousTimeMode,
          c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateContinuousTimeMode
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

This function must be called to change from Event Mode into Step Mode in Co-Simulation (see 4.2.).
"""
function fmi3EnterStepMode(c::FMU3Instance)
    if c.state != fmi3InstanceStateEventMode
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3EnterContinuousTimeMode(...): Needs to be called in state `fmi3InstanceStateEventMode`."
        end
    end

    status = fmi3EnterStepMode(c.fmu.cEnterStepMode,
    c.compAddr)
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateStepMode
    end
    return status
    
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).
"""
function fmi3SetTime(c::FMU3Instance, time::fmi3Float64)
    c.t = time
    status = fmi3SetTime(c.fmu.cSetTime,
          c.compAddr, time)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes
"""
function fmi3SetContinuousStates(c::FMU3Instance,
                                 x::AbstractArray{fmi3Float64},
                                 nx::Csize_t)
    status = fmi3SetContinuousStates(c.fmu.cSetContinuousStates,
         c.compAddr, x, nx)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute first-oder state derivatives at the current time instant and for the current states.
"""
function fmi3GetContinuousStateDerivatives(c::FMU3Instance,
                            derivatives::AbstractArray{fmi3Float64},
                            nx::Csize_t)
    status = fmi3GetContinuousStateDerivatives(c.fmu.cGetContinuousStateDerivatives,
          c.compAddr, derivatives, nx)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute event indicators at the current time instant and for the current states. EventIndicators signal Events by their sign change.
"""
function fmi3GetEventIndicators!(c::FMU3Instance, eventIndicators::AbstractArray{fmi3Float64}, ni::Csize_t)
    status = fmi3GetEventIndicators!(c.fmu.cGetEventIndicators,
                   c.compAddr, eventIndicators, ni)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

This function must be called by the environment after every completed step of the integrator provided the capability flag needsCompletedIntegratorStep = true.
If enterEventMode == fmi3True, the event mode must be entered
If terminateSimulation == fmi3True, the simulation shall be terminated
"""
function fmi3CompletedIntegratorStep!(c::FMU3Instance,
                                      noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
                                      enterEventMode::Ref{fmi3Boolean},
                                      terminateSimulation::Ref{fmi3Boolean})
    status = fmi3CompletedIntegratorStep!(c.fmu.cCompletedIntegratorStep,
         c.compAddr, noSetFMUStatePriorToCurrentPoint, enterEventMode, terminateSimulation)
    checkStatus(c, status)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

The model enters Event Mode from the Continuous-Time Mode in ModelExchange oder Step Mode in CoSimulation and discrete-time equations may become active (and relations are not “frozen”).
"""
function fmi3EnterEventMode(c::FMU3Instance, stepEvent::fmi3Boolean, stateEvent::fmi3Boolean, rootsFound::AbstractArray{fmi3Int32}, nEventIndicators::Csize_t, timeEvent::fmi3Boolean; soft::Bool=false)
    if c.state != fmi3InstanceStateContinuousTimeMode && c.state != fmi3InstanceStateStepMode
        if soft 
            return fmi3StatusOK
        else
            @warn "fmi3EnterEventMode(...): Called at the wrong time."
        end
    end

    status =  fmi3EnterEventMode(c.fmu.cEnterEventMode,
    c.compAddr, stepEvent, stateEvent, rootsFound, nEventIndicators, timeEvent)
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateEventMode
    end
    return status
   
end

"""
Source: FMISpec3.0, Version D5ef1c1: 4.2.1. State: Step Mode

The computation of a time step is started.
"""
function fmi3DoStep!(c::FMU3Instance, currentCommunicationPoint::fmi3Float64, communicationStepSize::fmi3Float64, noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
                    eventEncountered::Ref{fmi3Boolean}, terminateSimulation::Ref{fmi3Boolean}, earlyReturn::Ref{fmi3Boolean}, lastSuccessfulTime::Ref{fmi3Float64})
    status = fmi3DoStep!(c.fmu.cDoStep,
          c.compAddr, currentCommunicationPoint, communicationStepSize, noSetFMUStatePriorToCurrentPoint, eventEncountered, terminateSimulation, earlyReturn, lastSuccessfulTime)
    checkStatus(c, status)
    status
end