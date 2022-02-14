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
function fmi2CallbackLogger(componentEnvironment::fmi2ComponentEnvironment,
            instanceName::Ptr{Cchar},
            status::Cuint,
            category::Ptr{Cchar},
            message::Ptr{Cchar})
    _message = unsafe_string(message)
    _category = unsafe_string(category)
    _status = fmi2StatusToString(status)
    _instanceName = unsafe_string(instanceName)

    if status == Integer(fmi2StatusOK)
        @info "[$_status][$_category][$_instanceName]: $_message"
    elseif status == Integer(fmi2StatusWarning)
        @warn "[$_status][$_category][$_instanceName]: $_message"
    else
        @error "[$_status][$_category][$_instanceName]: $_message"
    end

    nothing
end

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
function fmi2FreeInstance!(c::FMU2Component)

    ind = findall(x->x==c, c.fmu.components)
    deleteat!(c.fmu.components, ind)
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

"""
Source: FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances

The function controls debug logging that is output via the logger function callback. If loggingOn = fmi2True, debug logging is enabled, otherwise it is switched off.
"""
function fmi2SetDebugLogging(c::FMU2Component, logginOn::fmi2Boolean, nCategories::Unsigned, categories::Ptr{Nothing})
    status = fmi2SetDebugLogging(c.fmu.cSetDebugLogging, c.compAddr, logginOn, nCategories, categories)
    status
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

    status = fmi2SetupExperiment(c.fmu.cSetupExperiment,
                c.compAddr, toleranceDefined, tolerance, startTime, stopTimeDefined, stopTime)

    if status > Integer(fmi2StatusWarning)
        throw(fmi2Error(status))
    end

    status
end

"""
Source: FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU to enter Initialization Mode. Before calling this function, all variables with attribute <ScalarVariable initial = "exact" or "approx"> can be set with the “fmi2SetXXX” functions (the ScalarVariable attributes are defined in the Model Description File, see section 2.2.7). Setting other variables is not allowed. Furthermore, fmi2SetupExperiment must be called at least once before calling fmi2EnterInitializationMode, in order that startTime is defined.
"""
function fmi2EnterInitializationMode(c::FMU2Component)
    fmi2EnterInitializationMode(c.fmu.cEnterInitializationMode,
          c.compAddr)
end

"""
Source: FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU to exit Initialization Mode.
"""
function fmi2ExitInitializationMode(c::FMU2Component)
    c.state = fmi2ComponentStateModelInitialized
    fmi2ExitInitializationMode(c.fmu.cExitInitializationMode,
          c.compAddr)
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.6 Initialization, Termination, and Resetting an FMU

Informs the FMU that the simulation run is terminated.
"""
function fmi2Terminate(c::FMU2Component)
    if c.state != fmi2ComponentStateModelInitialized
        @warn "fmi2Terminate(_): Should be only called in FMU state `modelInitialized`."
    end
    c.state = fmi2ComponentStateModelSetableFMUstate
    fmi2Terminate(c.fmu.cTerminate, c.compAddr)
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.6 Initialization, Termination, and Resetting an FMU

Is called by the environment to reset the FMU after a simulation run. The FMU goes into the same state as if fmi2Instantiate would have been called.
"""
function fmi2Reset(c::FMU2Component)
    if c.state != fmi2ComponentStateModelSetableFMUstate
        @warn "fmi2Reset(_): Should be only called in FMU state `modelSetableFMUstate`."
    end
    c.state = fmi2ComponentStateModelUnderEvaluation
    fmi2Reset(c.fmu.cReset, c.compAddr)
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetReal!(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Real})
    fmi2GetReal!(c.fmu.cGetReal,
          c.compAddr, vr, nvr, value)
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetReal(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Real})
    status = fmi2SetReal(c.fmu.cSetReal,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetInteger!(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Integer})
    status = fmi2GetInteger!(c.fmu.cGetInteger,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetInteger(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Integer})
    status = fmi2SetInteger(c.fmu.cSetInteger,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetBoolean!(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Boolean})
    status = fmi2GetBoolean!(c.fmu.cGetBoolean,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetBoolean(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Array{fmi2Boolean})
    status = fmi2SetBoolean(c.fmu.cSetBoolean,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2GetString!(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Vector{Ptr{Cchar}})
    status = fmi2GetString!(c.fmu.cGetString,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

Functions to get and set values of variables idetified by their valueReference
"""
function fmi2SetString(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, value::Union{Array{Ptr{Cchar}}, Array{Ptr{UInt8}}})
    status = fmi2SetString(c.fmu.cSetString,
                c.compAddr, vr, nvr, value)
    status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2GetFMUstate makes a copy of the internal FMU state and returns a pointer to this copy
"""
function fmi2GetFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})
    status = fmi2GetFMUstate!(c.fmu.cGetFMUstate,
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SetFMUstate copies the content of the previously copied FMUstate back and uses it as actual new FMU state.
"""
function fmi2SetFMUstate(c::FMU2Component, FMUstate::fmi2FMUstate)
    status = fmi2SetFMUstate(c.fmu.cSetFMUstate,
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2FreeFMUstate frees all memory and other resources allocated with the fmi2GetFMUstate call for this FMUstate.
"""
function fmi2FreeFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})
    status = fmi2FreeFMUstate!(c.fmu.cFreeFMUstate,
                c.compAddr, FMUstate)
    status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SerializedFMUstateSize returns the size of the byte vector, in order that FMUstate can be stored in it.
"""
function fmi2SerializedFMUstateSize!(c::FMU2Component, FMUstate::fmi2FMUstate, size::Ref{Csize_t})
    status = fmi2SerializedFMUstateSize!(c.fmu.cSerializedFMUstateSize,
                c.compAddr, FMUstate, size)
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2SerializeFMUstate serializes the data which is referenced by pointer FMUstate and copies this data in to the byte vector serializedState of length size
"""
function fmi2SerializeFMUstate!(c::FMU2Component, FMUstate::fmi2FMUstate, serialzedState::Array{fmi2Byte}, size::Csize_t)
    status = fmi2SerializeFMUstate!(c.fmu.cSerializeFMUstate,
                c.compAddr, FMUstate, serialzedState, size)
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.8 Getting and Setting the Complete FMU State

fmi2DeSerializeFMUstate deserializes the byte vector serializedState of length size, constructs a copy of the FMU state and returns FMUstate, the pointer to this copy.
"""
function fmi2DeSerializeFMUstate!(c::FMU2Component, serializedState::Array{fmi2Byte}, size::Csize_t, FMUstate::Ref{fmi2FMUstate})
    status = fmi2DeSerializeFMUstate!(c.fmu.cDeSerializeFMUstate,
                c.compAddr, serializedState, size, FMUstate)
    return status
end

"""
Source: FMISpec2.0.2[p.26]: 2.1.9 Getting Partial Derivatives

This function computes the directional derivatives of an FMU.
"""
function fmi2GetDirectionalDerivative!(c::FMU2Component,
                                       vUnknown_ref::Array{fmi2ValueReference},
                                       nUnknown::Csize_t,
                                       vKnown_ref::Array{fmi2ValueReference},
                                       nKnown::Csize_t,
                                       dvKnown::Array{fmi2Real},
                                       dvUnknown::AbstractArray)
    @assert fmi2ProvidesDirectionalDerivative(c.fmu) ["fmi2GetDirectionalDerivative!(...): This FMU does not support build-in directional derivatives!"]
    status = fmi2GetDirectionalDerivative!(c.fmu.cGetDirectionalDerivative,
          c.compAddr, vUnknown_ref, nUnknown, vKnown_ref, nKnown, dvKnown, dvUnknown)
    return status
end

# Functions specificly for isCoSimulation
"""
Source: FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

Sets the n-th time derivative of real input variables.
vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables
"""
function fmi2SetRealInputDerivatives(c::FMU2Component, vr::Array{fmi2ValueReference}, nvr::Csize_t, order::Array{fmi2Integer}, value::Array{fmi2Real})
    status = fmi2SetRealInputDerivatives(c.fmu.cSetRealInputDerivatives,
                c.compAddr, vr, nvr, order, value)
end

"""
Source: FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

Retrieves the n-th derivative of output values.
vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables
"""
function fmi2GetRealOutputDerivatives(c::FMU2Component,  vr::Array{fmi2ValueReference}, nvr::Csize_t, order::Array{fmi2Integer}, value::Array{fmi2Real})
    fmi2GetRealOutputDerivatives(c.fmu.cGetRealOutputDerivatives,
                c.compAddr, vr, nvr, order, value)
end

"""
Source: FMISpec2.0.2[p.104]: 4.2.2 Computation

The computation of a time step is started.
"""
function fmi2DoStep(c::FMU2Component, currentCommunicationPoint::fmi2Real, communicationStepSize::fmi2Real, noSetFMUStatePriorToCurrentPoint::fmi2Boolean)
    @assert c.fmu.cDoStep != C_NULL ["fmi2DoStep(...): This FMU does not support fmi2DoStep, probably it's a ME-FMU with no CS-support?"]
    fmi2DoStep(c.fmu.cDoStep,
          c.compAddr, currentCommunicationPoint, communicationStepSize, noSetFMUStatePriorToCurrentPoint)
end

"""
Source: FMISpec2.0.2[p.105]: 4.2.2 Computation

Can be called if fmi2DoStep returned fmi2Pending in order to stop the current asynchronous execution.
"""
function fmi2CancelStep(c::FMU2Component)
    fmi2CancelStep(c.fmu.cCancelStep, c.compAddr)
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
    end 
    status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetRealStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Real)
    status = fmi2GetRealStatus!(c.fmu.cGetRealStatus,
                c.compAddr, s, Ref(value))
    status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetIntegerStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Integer)
    status = fmi2GetIntegerStatus!(c.fmu.cGetIntegerStatus,
                c.compAddr, s, Ref(value))
    status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetBooleanStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Boolean)
    status = fmi2GetBooleanStatus!(c.fmu.cGetBooleanStatus,
                c.compAddr, s, Ref(value))
    status
end

"""
Source: FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument fmi2StatusKind.
"""
function fmi2GetStringStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2String)
    status = fmi2GetStringStatus!(c.fmu.cGetStringStatus,
                c.compAddr, s, Ref(value))
    status
end

# Model Exchange specific Functions

"""
Source: FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).
"""
function fmi2SetTime(c::FMU2Component, time::fmi2Real)
    c.t = time
    fmi2SetTime(c.fmu.cSetTime,
          c.compAddr, time)
end

"""
Source: FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes
"""
function fmi2SetContinuousStates(c::FMU2Component,
                                 x::Array{fmi2Real},
                                 nx::Csize_t)
    fmi2SetContinuousStates(c.fmu.cSetContinuousStates, c.compAddr, x, nx)
end

"""
Source: FMISpec2.0.2[p.84]: 3.2.2 Evaluation of Model Equations

The model enters Event Mode from the Continuous-Time Mode and discrete-time equations may become active (and relations are not “frozen”).
"""
function fmi2EnterEventMode(c::FMU2Component)
    fmi2EnterEventMode(c.fmu.cEnterEventMode,
          c.compAddr)
end

"""
Source: FMISpec2.0.2[p.84]: 3.2.2 Evaluation of Model Equations

The FMU is in Event Mode and the super dense time is incremented by this call.
"""
function fmi2NewDiscreteStates(c::FMU2Component, eventInfo::fmi2EventInfo)
    fmi2NewDiscreteStates(c.fmu.cNewDiscreteStates,
                    c.compAddr, Ref(eventInfo))
end

"""
Source: FMISpec2.0.2[p.85]: 3.2.2 Evaluation of Model Equations

The model enters Continuous-Time Mode and all discrete-time equations become inactive and all relations are “frozen”.
This function has to be called when changing from Event Mode (after the global event iteration in Event Mode over all involved FMUs and other models has converged) into Continuous-Time Mode.
"""
function fmi2EnterContinuousTimeMode(c::FMU2Component)
    fmi2EnterContinuousTimeMode(c.fmu.cEnterContinuousTimeMode,
          c.compAddr)
end

"""
Source: FMISpec2.0.2[p.85]: 3.2.2 Evaluation of Model Equations

This function must be called by the environment after every completed step of the integrator provided the capability flag completedIntegratorStepNotNeeded = false.
If enterEventMode == fmi2True, the event mode must be entered
If terminateSimulation == fmi2True, the simulation shall be terminated
"""
function fmi2CompletedIntegratorStep!(c::FMU2Component,
                                      noSetFMUStatePriorToCurrentPoint::fmi2Boolean,
                                      enterEventMode::fmi2Boolean,
                                      terminateSimulation::fmi2Boolean)

    fmi2CompletedIntegratorStep!(c.fmu.cCompletedIntegratorStep,
          c.compAddr, noSetFMUStatePriorToCurrentPoint, Ref(enterEventMode), Ref(terminateSimulation))
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Compute state derivatives at the current time instant and for the current states.
"""
function fmi2GetDerivatives(c::FMU2Component,
                            derivatives::Array{fmi2Real},
                            nx::Csize_t)
                            
    fmi2GetDerivatives(c.fmu.cGetDerivatives,
          c.compAddr, derivatives, nx)
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Compute event indicators at the current time instant and for the current states.
"""
function fmi2GetEventIndicators(c::FMU2Component, eventIndicators::Array{fmi2Real}, ni::Csize_t)
    fmi2GetEventIndicators(c.fmu.cGetEventIndicators,
                    c.compAddr, eventIndicators, ni)
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Return the new (continuous) state vector x.
"""
function fmi2GetContinuousStates(c::FMU2Component,
                                 x::Array{fmi2Real},
                                 nx::Csize_t)
                                 
    fmi2GetContinuousStates(c.fmu.cGetContinuousStates,
          c.compAddr, x, nx)
end

"""
Source: FMISpec2.0.2[p.86]: 3.2.2 Evaluation of Model Equations

Return the nominal values of the continuous states.
"""
function fmi2GetNominalsOfContinuousStates(c::FMU2Component, x_nominal::Array{fmi2Real}, nx::Csize_t)
    fmi2GetNominalsOfContinuousStates(c.fmu.cGetNominalsOfContinuousStates,
                    c.compAddr, x_nominal, nx)
end
