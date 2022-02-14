#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_c.jl`?
# - default implementations for the `fmi3CallbackFunctions`
# - enum definition for `fmi2ComponentState` to protocol the current FMU-state
# - julia-implementaions of the functions inside the FMI-specification
# Any c-function `f(c::fmi2Component, args...)` in the spec is implemented as `f(c::fmi2Component, args...)`.
# Any c-function `f(args...)` without a leading `fmi2Component`-arguemnt is implented as `f(c_ptr, args...)` where `c_ptr` is a pointer to the c-function (inside the DLL).

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Function that is called in the FMU, usually if an fmi3XXX function, does not behave as desired. If “logger” is called with “status = fmi3OK”, then the message is a pure information message. 
instanceEnvironment - is the instance name of the model that calls this function. 
category - is the category of the message. The meaning of “category” is defined by the modeling environment that generated the FMU. Depending on this modeling environment, none, some or all allowed values of “category” for this FMU are defined in the modelDescription.xml file via element “<fmiModelDescription><LogCategories>”, see section 2.4.5. Only messages are provided by function logger that have a category according to a call to fmi3SetDebugLogging (see below). 
message - is provided in the same way and with the same format control as in function “printf” from the C standard library. [Typically, this function prints the message and stores it optionally in a log file.]
"""
# TODO error in the specification??
function fmi3CallbackLogger(instanceEnvironment::Ptr{Cvoid},
            category::Ptr{Cchar},
            status::Cuint,
            message::Ptr{Cchar})
    
    if message != C_NULL
        _message = unsafe_string(message)
    else
        _message = ""
    end

    if category != C_NULL
        _category = unsafe_string(category)
    else
        _category = "No category"
    end
    _status = fmi3StatusString(status)
    if status == Integer(fmi3StatusOK)
        @info "[$_status][$_category]: $_message"
    elseif status == Integer(fmi3StatusWarning)
        @warn "[$_status][$_category]: $_message"
    else
        @error "[$_status][$_category]: $_message"
    end

    nothing
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

# this is a custom type to catch the internal state of the component 
@enum fmi3ComponentState begin
    # ToDo
    fmi3ComponentStateToDo
end

"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable

This function instantiates a Model Exchange FMU (see Section 3). It is allowed to call this function only if modelDescription.xml includes a <ModelExchange> element.
"""
function fmi3InstantiateModelExchange(cfunc::Ptr{Nothing},
        instanceName::fmi3String,
        fmuinstantiationToken::fmi3String,
        fmuResourceLocation::fmi3String,
        visible::fmi3Boolean,
        loggingOn::fmi3Boolean,
        instanceEnvironment::fmi3InstanceEnvironment,
        logMessage::Ptr{Cvoid})

    compAddr = ccall(cfunc,
        Ptr{Cvoid},
        (Cstring, Cstring, Cstring,
        Cuint, Cuint, Ptr{Cvoid}, Ptr{Cvoid}),
        instanceName, fmuinstantiationToken, fmuResourceLocation,
        visible, loggingOn, instanceEnvironment, logMessage)

    compAddr
end

"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable

This function instantiates a Co-Simulation FMU (see Section 4). It is allowed to call this function only if modelDescription.xml includes a <CoSimulation> element.
"""
function fmi3InstantiateCoSimulation(cfunc::Ptr{Nothing},
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    eventModeUsed::fmi3Boolean,
    earlyReturnAllowed::fmi3Boolean,
    requiredIntermediateVariables::Array{fmi3ValueReference},
    nRequiredIntermediateVariables::Csize_t,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
    intermediateUpdate::Ptr{Cvoid})

    compAddr = ccall(cfunc,
        Ptr{Cvoid},
        (Cstring, Cstring, Cstring,
        Cint, Cint, Cint, Cint, Ptr{fmi3ValueReference}, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        instanceName, instantiationToken, resourcePath,
        visible, loggingOn, eventModeUsed, earlyReturnAllowed, requiredIntermediateVariables,
        nRequiredIntermediateVariables, instanceEnvironment, logMessage, intermediateUpdate)

    compAddr
end

# TODO not tested
"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable

This function instantiates a Scheduled Execution FMU (see Section 4). It is allowed to call this function only if modelDescription.xml includes a <ScheduledExecution> element.
"""
function fmi3InstantiateScheduledExecution(cfunc::Ptr{Nothing},
    instanceName::fmi3String,
    instantiationToken::fmi3String,
    resourcePath::fmi3String,
    visible::fmi3Boolean,
    loggingOn::fmi3Boolean,
    instanceEnvironment::fmi3InstanceEnvironment,
    logMessage::Ptr{Cvoid},
    clockUpdate::Ptr{Cvoid},
    lockPreemption::Ptr{Cvoid},
    unlockPreemption::Ptr{Cvoid})
    @assert false "Not tested!"
    compAddr = ccall(cfunc,
        Ptr{Cvoid},
        (Cstring, Cstring, Cstring,
        Cint, Cint, Cint, Cint, Ptr{fmi3ValueReference}, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        instanceName, instantiationToken, resourcePath,
        visible, loggingOn, eventModeUsed, earlyReturnAllowed, requiredIntermediateVariables,
        nRequiredIntermediateVariables, instanceEnvironment, logMessage, clockUpdate, lockPreemption, unlockPreemption)

    compAddr
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Disposes the given instance, unloads the loaded model, and frees all the allocated memory and other resources that have been allocated by the functions of the FMU interface. If a NULL pointer is provided for argument instance, the function call is ignored (does not have an effect).
"""
function fmi3FreeInstance!(c::fmi3Component)

    ind = findall(x->x==c, c.fmu.components)
    deleteat!(c.fmu.components, ind)
    ccall(c.fmu.cFreeInstance, Cvoid, (Ptr{Cvoid},), c.compAddr)

    nothing
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.4. Inquire Version Number of Header Files

This function returns fmi3Version of the fmi3Functions.h header file which was used to compile the functions of the FMU. This function call is allowed always and in all interface types.

The standard header file as documented in this specification has version "3.0-beta.2", so this function returns "3.0-beta.2".
"""
function fmi3GetVersion(cfunc::Ptr{Nothing})

    fmi3Version = ccall(cfunc,
                        Cstring,
                        ())

    unsafe_string(fmi3Version)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

The function controls debug logging that is output via the logger function callback. If loggingOn = fmi3True, debug logging is enabled, otherwise it is switched off.
"""
function fmi3SetDebugLogging(c::fmi3Component, logginOn::fmi3Boolean, nCategories::Unsigned, categories::Ptr{Nothing})
    status = ccall(c.fmu.cSetDebugLogging,
                   Cuint,
                   (Ptr{Nothing}, Cint, Csize_t, Ptr{Nothing}),
                   c.compAddr, logginOn, nCategories, categories)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

Informs the FMU to enter Initialization Mode. Before calling this function, all variables with attribute <Datatype initial = "exact" or "approx"> can be set with the “fmi3SetXXX” functions (the ScalarVariable attributes are defined in the Model Description File, see section 2.4.7). Setting other variables is not allowed.
Also sets the simulation start and stop time.
"""
function fmi3EnterInitializationMode(c::fmi3Component,toleranceDefined::fmi3Boolean,
    tolerance::fmi3Float64,
    startTime::fmi3Float64,
    stopTimeDefined::fmi3Boolean,
    stopTime::fmi3Float64)
    ccall(c.fmu.cEnterInitializationMode,
          Cuint,
          (Ptr{Nothing}, fmi3Boolean, fmi3Float64, fmi3Float64, fmi3Boolean, fmi3Float64),
          c.compAddr, toleranceDefined, tolerance, startTime, stopTimeDefined, stopTime)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Informs the FMU to exit Initialization Mode.
"""
function fmi3ExitInitializationMode(c::fmi3Component)
    ccall(c.fmu.cExitInitializationMode,
          Cuint,
          (Ptr{Nothing},),
          c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.4. Super State: Initialized

Informs the FMU that the simulation run is terminated.
"""
function fmi3Terminate(c::fmi3Component)
    ccall(c.fmu.cTerminate, Cuint, (Ptr{Nothing},), c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Is called by the environment to reset the FMU after a simulation run. The FMU goes into the same state as if fmi3InstantiateXXX would have been called.
"""
function fmi3Reset(c::fmi3Component)
    ccall(c.fmu.cReset, Cuint, (Ptr{Nothing},), c.compAddr)
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetFloat32!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Float32}, nvalue::Csize_t)
    ccall(c.fmu.cGetFloat32,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float32}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end


"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetFloat32(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Float32}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetFloat32,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float32}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetFloat64!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Float64}, nvalue::Csize_t)
    ccall(c.fmu.cGetFloat64,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end


"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetFloat64(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Float64}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetFloat64,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt8!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int8}, nvalue::Csize_t)
    ccall(c.fmu.cGetInt8,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int8}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt8(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int8}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetInt8,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int8}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt8!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt8}, nvalue::Csize_t)
    ccall(c.fmu.cGetUInt8,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt8}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt8(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt8}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetUInt8,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt8}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt16!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int16}, nvalue::Csize_t)
    ccall(c.fmu.cGetInt16,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int16}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt16(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int16}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetInt16,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int16}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt16!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt16}, nvalue::Csize_t)
    ccall(c.fmu.cGetUInt16,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt16}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt16(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt16}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetUInt16,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt16}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt32!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int32}, nvalue::Csize_t)
    ccall(c.fmu.cGetInt32,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int32}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt32(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int32}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetInt32,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int32}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt32!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt32}, nvalue::Csize_t)
    ccall(c.fmu.cGetUInt32,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt32}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt32(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt32}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetUInt32,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt32}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetInt64!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int64}, nvalue::Csize_t)
    ccall(c.fmu.cGetInt64,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int64}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetInt64(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Int64}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetInt64,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int64}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

# TODO test, no variable in FMUs
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetUInt64!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt64}, nvalue::Csize_t)
    ccall(c.fmu.cGetUInt64,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt64}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetUInt64(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3UInt64}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetUInt64,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt64}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetBoolean!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Boolean}, nvalue::Csize_t)
    status = ccall(c.fmu.cGetBoolean,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Boolean}, Csize_t),
          c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetBoolean(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Boolean}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetBoolean,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Boolean}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetString!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Vector{Ptr{Cchar}}, nvalue::Csize_t)
    status = ccall(c.fmu.cGetString,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t,  Ptr{Cchar}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""     
function fmi3SetString(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Union{Array{Ptr{Cchar}}, Array{Ptr{UInt8}}}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetString,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{Cchar}, Csize_t),
                c.compAddr, vr, nvr, value, nvalue)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValues - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetBinary!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, valueSizes::Array{Csize_t}, value::Array{fmi3Binary}, nvalue::Csize_t)
    ccall(c.fmu.cGetBinary,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{Csize_t}, Ptr{fmi3Binary}, Csize_t),
                c.compAddr, vr, nvr, valueSizes, value, nvalue)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetBinary(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, valueSizes::Array{Csize_t}, value::Array{fmi3Binary}, nvalue::Csize_t)
    status = ccall(c.fmu.cSetBinary,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{Csize_t}, Ptr{fmi3Binary}, Csize_t),
                c.compAddr, vr, nvr, valueSizes, value, nvalue)
    status
end

# TODO, Clocks not implemented so far thus not tested
"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3GetClock!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Clock})
    status = ccall(c.fmu.cGetClock,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t,  Ptr{fmi3Clock}),
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference.

nValue - is different from nvr if the value reference represents an array and therefore are more values tied to a single value reference.
"""
function fmi3SetClock(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, value::Array{fmi3Clock})
    status = ccall(c.fmu.cSetClock,
                Cuint,
                (Ptr{Nothing},Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Clock}),
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3GetFMUstate makes a copy of the internal FMU state and returns a pointer to this copy
"""
function fmi3GetFMUState!(c::fmi3Component, FMUstate::Ref{fmi3FMUState})
    status = ccall(c.fmu.cGetFMUState,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3FMUState}),
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SetFMUstate copies the content of the previously copied FMUstate back and uses it as actual new FMU state.
"""
function fmi3SetFMUState(c::fmi3Component, FMUstate::fmi3FMUState)
    status = ccall(c.fmu.cSetFMUState,
                Cuint,
                (Ptr{Nothing}, fmi3FMUState),
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3FreeFMUstate frees all memory and other resources allocated with the fmi3GetFMUstate call for this FMUstate.
"""
function fmi3FreeFMUState!(c::fmi3Component, FMUstate::Ref{fmi3FMUState})
    status = ccall(c.fmu.cFreeFMUState,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3FMUState}),
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SerializedFMUstateSize returns the size of the byte vector which is needed to store FMUstate in it.
"""
function fmi3SerializedFMUStateSize!(c::fmi3Component, FMUstate::fmi3FMUState, size::Ref{Csize_t})
    status = ccall(c.fmu.cSerializedFMUStateSize,
                Cuint,
                (Ptr{Nothing}, Ptr{Cvoid}, Ptr{Csize_t}),
                c.compAddr, FMUstate, size)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3SerializeFMUstate serializes the data which is referenced by pointer FMUstate and copies this data in to the byte vector serializedState of length size
"""
function fmi3SerializeFMUState!(c::fmi3Component, FMUstate::fmi3FMUState, serialzedState::Array{fmi3Byte}, size::Csize_t)
    status = ccall(c.fmu.cSerializeFMUState,
                Cuint,
                (Ptr{Nothing}, Ptr{Cvoid}, Ptr{Cchar}, Csize_t),
                c.compAddr, FMUstate, serialzedState, size)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

fmi3DeSerializeFMUstate deserializes the byte vector serializedState of length size, constructs a copy of the FMU state and returns FMUstate, the pointer to this copy.
"""
function fmi3DeSerializeFMUState!(c::fmi3Component, serialzedState::Array{fmi3Byte}, size::Csize_t, FMUstate::Ref{fmi3FMUState})
    status = ccall(c.fmu.cDeSerializeFMUState,
                Cuint,
                (Ptr{Nothing}, Ptr{Cchar}, Csize_t, Ptr{fmi3FMUState}),
                c.compAddr, serialzedState, size, FMUstate)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3SetIntervalDecimal sets the interval until the next clock tick
"""
# TODO Clocks and dependencies functions
function fmi3SetIntervalDecimal(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, intervals::Array{fmi3Float64})
    @assert false "Not tested"
    status = ccall(c.fmu.cSetIntervalDecimal,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}),
                c.compAddr, vr, nvr, intervals)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3SetIntervalFraction sets the interval until the next clock tick
Only allowed if the attribute 'supportsFraction' is set.
"""
function fmi3SetIntervalFraction(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, intervalCounters::Array{fmi3UInt64}, resolutions::Array{fmi3UInt64})
    @assert false "Not tested"
    status = ccall(c.fmu.cSetIntervalFraction,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt64}, Ptr{fmi3UInt64}),
                c.compAddr, vr, nvr, intervalCounters, resolutions)
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
function fmi3GetIntervalDecimal!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, intervals::Array{fmi3Float64}, qualifiers::fmi3IntervalQualifier)
    @assert false "Not tested"
    status = ccall(c.fmu.cGetIntervalDecimal,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}, Ptr{fmi3IntervalQualifier}),
                c.compAddr, vr, nvr, intervals, qualifiers)
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
function fmi3GetIntervalFraction!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, intervalCounters::Array{fmi3UInt64}, resolutions::Array{fmi3UInt64}, qualifiers::fmi3IntervalQualifier)
    @assert false "Not tested"
    status = ccall(c.fmu.cGetIntervalFraction,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt64}, Ptr{fmi3UInt64}, Ptr{fmi3IntervalQualifier}),
                c.compAddr, vr, nvr, intervalCounters, resolutions, qualifiers)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetShiftDecimal retrieves the delay to the first Clock tick from the FMU.
"""
function fmi3GetShiftDecimal!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, shifts::Array{fmi3Float64})
    @assert false "Not tested"
    status = ccall(c.fmu.cGetShiftDecimal,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}),
                c.compAddr, vr, nvr, shifts)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.9. Clocks

fmi3GetShiftFraction retrieves the delay to the first Clock tick from the FMU.
"""
function fmi3GetShiftFraction!(c::fmi3Component, vr::Array{fmi3ValueReference}, nvr::Csize_t, shiftCounters::Array{fmi3UInt64}, resolutions::Array{fmi3UInt64})
    @assert false "Not tested"
    status = ccall(c.fmu.cGetShiftFraction,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3UInt64}, Ptr{fmi3UInt64}),
                c.compAddr, vr, nvr, shiftCounters, resolutions)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 5.2.2. State: Clock Activation Mode

During Clock Activation Mode (see 5.2.2.) after fmi3ActivateModelPartition has been called for a calculated, tunable or changing Clock the FMU provides the information on when the Clock will tick again, i.e. when the corresponding model partition has to be scheduled the next time.

Each fmi3ActivateModelPartition call is associated with the computation of an exposed model partition of the FMU and therefore to an input Clock.
"""
function fmi3ActivateModelPartition(c::fmi3Component, vr::fmi3ValueReference, activationTime::Array{fmi3Float64})
    @assert false "Not tested"
    status = ccall(c.fmu.cActivateModelPartition,
                Cuint,
                (Ptr{Nothing}, fmi3ValueReference, Ptr{fmi3Float64}),
                c.compAddr, vr, activationTime)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.10. Dependencies of Variables

The number of dependencies of a given variable, which may change if structural parameters are changed, can be retrieved by calling fmi3GetNumberOfVariableDependencies.

This information can only be retrieved if the 'providesPerElementDependencies' tag in the ModelDescription is set.
"""
# TODO not tested
function fmi3GetNumberOfVariableDependencies!(c::fmi3Component, vr::fmi3ValueReference, nvr::Ref{Csize_t})
    @assert false "Not tested"
    status = ccall(c.fmu.cGetNumberOfVariableDependencies,
                Cuint,
                (Ptr{Nothing}, fmi3ValueReference, Ptr{Csize_t}),
                c.compAddr, vr, nvr)
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
function fmi3GetVariableDependencies!(c::fmi3Component, vr::fmi3ValueReference, elementIndiceOfDependents::Array{Csize_t}, independents::Array{fmi3ValueReference},  elementIndiceOfInpendents::Array{Csize_t}, dependencyKind::Array{fmi3DependencyKind}, ndependencies::Csize_t)
    @assert false "Not tested"
    status = ccall(c.fmu.cGetVariableDependencies,
                Cuint,
                (Ptr{Nothing}, fmi3ValueReference, Ptr{Csize_t}, Ptr{fmi3ValueReference}, Ptr{Csize_t}, Ptr{fmi3DependencyKind}, Csize_t),
                c.compAddr, vr, elementIndiceOfDependents, independents, elementIndiceOfInpendents, dependencyKind, ndependencies)
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
function fmi3GetDirectionalDerivative!(c::fmi3Component,
                                       unknowns::Array{fmi3ValueReference},
                                       nUnknowns::Csize_t,
                                       knowns::Array{fmi3ValueReference},
                                       nKnowns::Csize_t,
                                       seed::Array{fmi3Float64},
                                       nSeed::Csize_t,
                                       sensitivity::Array{fmi3Float64},
                                       nSensitivity::Csize_t)
    @assert fmi3ProvidesDirectionalDerivatives(c.fmu) ["fmi3GetDirectionalDerivative!(...): This FMU does not support build-in directional derivatives!"]
    ccall(c.fmu.cGetDirectionalDerivative,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}, Csize_t, Ptr{fmi3Float64}, Csize_t),
          c.compAddr, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)
    
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
function fmi3GetAdjointDerivative!(c::fmi3Component,
                                       unknowns::Array{fmi3ValueReference},
                                       nUnknowns::Csize_t,
                                       knowns::Array{fmi3ValueReference},
                                       nKnowns::Csize_t,
                                       seed::Array{fmi3Float64},
                                       nSeed::Csize_t,
                                       sensitivity::Array{fmi3Float64},
                                       nSensitivity::Csize_t)
    @assert fmi3ProvidesAdjointDerivatives(c.fmu) ["fmi3GetAdjointDerivative!(...): This FMU does not support build-in adjoint derivatives!"]
    ccall(c.fmu.cGetAdjointDerivative,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Float64}, Csize_t, Ptr{fmi3Float64}, Csize_t),
          c.compAddr, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)
    
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
function fmi3GetOutputDerivatives!(c::fmi3Component,  vr::Array{fmi3ValueReference}, nValueReferences::Csize_t, order::Array{fmi3Int32}, values::Array{fmi3Float64}, nValues::Csize_t)
    status = ccall(c.fmu.cGetOutputDerivatives,
                Cuint,
                (Ptr{Nothing}, Ptr{fmi3ValueReference}, Csize_t, Ptr{fmi3Int32}, Ptr{fmi3Float64}, Csize_t),
                c.compAddr, vr, nValueReferences, order, values, nValues)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

If the importer needs to change structural parameters, it must move the FMU into Configuration Mode using fmi3EnterConfigurationMode.
"""
function fmi3EnterConfigurationMode(c::fmi3Component)
    ccall(c.fmu.cEnterConfigurationMode,
            Cuint,
            (Ptr{Nothing},),
            c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.6. State: Configuration Mode

Exits the Configuration Mode and returns to state Instantiated.
"""
function fmi3ExitConfigurationMode(c::fmi3Component)
    ccall(c.fmu.cExitConfigurationMode,
          Cuint,
          (Ptr{Nothing},),
          c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of continuous states.
This function can only be called in Model Exchange. 

fmi3GetNumberOfContinuousStates must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
"""
function fmi3GetNumberOfContinuousStates!(c::fmi3Component, nContinuousStates::Ref{Csize_t})
    ccall(c.fmu.cGetNumberOfContinuousStates,
            Cuint,
            (Ptr{Nothing}, Ptr{Csize_t}),
            c.compAddr, nContinuousStates)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of event indicators.
This function can only be called in Model Exchange. 

fmi3GetNumberOfEventIndicators must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
"""
function fmi3GetNumberOfEventIndicators!(c::fmi3Component, nEventIndicators::Ref{Csize_t})
    ccall(c.fmu.cGetNumberOfEventIndicators,
            Cuint,
            (Ptr{Nothing}, Ptr{Csize_t}),
            c.compAddr, nEventIndicators)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the states at the current time instant.

This function must be called if fmi3UpdateDiscreteStates returned with valuesOfContinuousStatesChanged == fmi3True. Not allowed in Co-Simulation and Scheduled Execution.
"""
function fmi3GetContinuousStates!(c::fmi3Component, nominals::Array{fmi3Float64}, nContinuousStates::Csize_t)
    ccall(c.fmu.cGetContinuousStates,
            Cuint,
            (Ptr{Nothing}, Ptr{fmi3Float64}, Csize_t),
            c.compAddr, nominals, nContinuousStates)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the nominal values of the continuous states.

If fmi3UpdateDiscreteStates returned with nominalsOfContinuousStatesChanged == fmi3True, then at least one nominal value of the states has changed and can be inquired with fmi3GetNominalsOfContinuousStates.
Not allowed in Co-Simulation and Scheduled Execution.
"""
function fmi3GetNominalsOfContinuousStates!(c::fmi3Component, x_nominal::Array{fmi3Float64}, nx::Csize_t)
    status = ccall(c.fmu.cGetNominalsOfContinuousStates,
                    Cuint,
                    (Ptr{Nothing}, Ptr{fmi3Float64}, Csize_t),
                    c.compAddr, x_nominal, nx)
end

# TODO not testable not supported by FMU
"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

This function is called to trigger the evaluation of fdisc to compute the current values of discrete states from previous values. 
The FMU signals the support of fmi3EvaluateDiscreteStates via the capability flag providesEvaluateDiscreteStates.
"""
function fmi3EvaluateDiscreteStates(c::fmi3Component)
    ccall(c.fmu.cEvaluateDiscreteStates,
            Cuint,
            (Ptr{Nothing},),
            c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

This function is called to signal a converged solution at the current super-dense time instant. fmi3UpdateDiscreteStates must be called at least once per super-dense time instant.
"""
function fmi3UpdateDiscreteStates(c::fmi3Component, discreteStatesNeedUpdate::Ref{fmi3Boolean}, terminateSimulation::Ref{fmi3Boolean}, 
                                    nominalsOfContinuousStatesChanged::Ref{fmi3Boolean}, valuesOfContinuousStatesChanged::Ref{fmi3Boolean},
                                    nextEventTimeDefined::Ref{fmi3Boolean}, nextEventTime::Ref{fmi3Float64})
    ccall(c.fmu.cUpdateDiscreteStates,
            Cuint,
            (Ptr{Nothing}, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Float64}),
            c.compAddr, discreteStatesNeedUpdate, terminateSimulation, nominalsOfContinuousStatesChanged, valuesOfContinuousStatesChanged, nextEventTimeDefined, nextEventTime)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

The model enters Continuous-Time Mode and all discrete-time equations become inactive and all relations are “frozen”.
This function has to be called when changing from Event Mode (after the global event iteration in Event Mode over all involved FMUs and other models has converged) into Continuous-Time Mode.
"""
function fmi3EnterContinuousTimeMode(c::fmi3Component)
    ccall(c.fmu.cEnterContinuousTimeMode,
          Cuint,
          (Ptr{Nothing},),
          c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

This function must be called to change from Event Mode into Step Mode in Co-Simulation (see 4.2.).
"""
function fmi3EnterStepMode(c::fmi3Component)
    ccall(c.fmu.cEnterStepMode,
          Cuint,
          (Ptr{Nothing},),
          c.compAddr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).
"""
function fmi3SetTime(c::fmi3Component, time::fmi3Float64)
    c.t = time
    ccall(c.fmu.cSetTime,
          Cuint,
          (Ptr{Nothing}, fmi3Float64),
          c.compAddr, time)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes
"""
function fmi3SetContinuousStates(c::fmi3Component,
                                 x::Array{fmi3Float64},
                                 nx::Csize_t)
    ccall(c.fmu.cSetContinuousStates,
         Cuint,
         (Ptr{Nothing}, Ptr{fmi3Float64}, Csize_t),
         c.compAddr, x, nx)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute first-oder state derivatives at the current time instant and for the current states.
"""
function fmi3GetContinuousStateDerivatives(c::fmi3Component,
                            derivatives::Array{fmi3Float64},
                            nx::Csize_t)
    ccall(c.fmu.cGetContinuousStateDerivatives,
          Cuint,
          (Ptr{Nothing}, Ptr{fmi3Float64}, Csize_t),
          c.compAddr, derivatives, nx)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute event indicators at the current time instant and for the current states. EventIndicators signal Events by their sign change.
"""
function fmi3GetEventIndicators!(c::fmi3Component, eventIndicators::Array{fmi3Float64}, ni::Csize_t)
    status = ccall(c.fmu.cGetEventIndicators,
                    Cuint,
                    (Ptr{Nothing}, Ptr{fmi3Float64}, Csize_t),
                    c.compAddr, eventIndicators, ni)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

This function must be called by the environment after every completed step of the integrator provided the capability flag needsCompletedIntegratorStep = true.
If enterEventMode == fmi3True, the event mode must be entered
If terminateSimulation == fmi3True, the simulation shall be terminated
"""
function fmi3CompletedIntegratorStep!(c::fmi3Component,
                                      noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
                                      enterEventMode::Ref{fmi3Boolean},
                                      terminateSimulation::Ref{fmi3Boolean})
    ccall(c.fmu.cCompletedIntegratorStep,
          Cuint,
          (Ptr{Nothing}, fmi3Boolean, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}),
          c.compAddr, noSetFMUStatePriorToCurrentPoint, enterEventMode, terminateSimulation)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

The model enters Event Mode from the Continuous-Time Mode in ModelExchange oder Step Mode in CoSimulation and discrete-time equations may become active (and relations are not “frozen”).
"""
function fmi3EnterEventMode(c::fmi3Component, stepEvent::fmi3Boolean, stateEvent::fmi3Boolean, rootsFound::Array{fmi3Int32}, nEventIndicators::Csize_t, timeEvent::fmi3Boolean)
    ccall(c.fmu.cEnterEventMode,
          Cuint,
          (Ptr{Nothing},fmi3Boolean, fmi3Boolean, Ptr{fmi3Int32}, Csize_t, fmi3Boolean),
          c.compAddr, stepEvent, stateEvent, rootsFound, nEventIndicators, timeEvent)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 4.2.1. State: Step Mode

The computation of a time step is started.
"""
function fmi3DoStep!(c::fmi3Component, currentCommunicationPoint::fmi3Float64, communicationStepSize::fmi3Float64, noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
                    eventEncountered::Ref{fmi3Boolean}, terminateSimulation::Ref{fmi3Boolean}, earlyReturn::Ref{fmi3Boolean}, lastSuccessfulTime::Ref{fmi3Float64})
    @assert c.fmu.cDoStep != C_NULL ["fmi3DoStep(...): This FMU does not support fmi3DoStep, probably it's a ME-FMU with no CS-support?"]

    ccall(c.fmu.cDoStep, Cuint,
          (Ptr{Nothing}, fmi3Float64, fmi3Float64, fmi3Boolean, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Boolean}, Ptr{fmi3Float64}),
          c.compAddr, currentCommunicationPoint, communicationStepSize, noSetFMUStatePriorToCurrentPoint, eventEncountered, terminateSimulation, earlyReturn, lastSuccessfulTime)
end