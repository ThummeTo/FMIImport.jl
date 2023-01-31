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

    fmi2GetTypesPlatform(fmu::FMU2)

Returns the string to uniquely identify the “fmi2TypesPlatform.h” header file used for compilation of the functions of the FMU.
The standard header file, as documented in this specification, has fmi2TypesPlatform set to “default” (so this function usually returns “default”).

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- Returns the string to uniquely identify the “fmi2TypesPlatform.h” header file used for compilation of the functions of the FMU.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
"""
function fmi2GetTypesPlatform(fmu::FMU2)

    typesPlatform = fmi2GetTypesPlatform(fmu.cGetTypesPlatform)

    unsafe_string(typesPlatform)
end
# special case



"""

    fmi2GetTypesPlatform(c::FMU2Component)

Returns the string to uniquely identify the “fmi2TypesPlatform.h” header file used for compilation of the functions of the FMU.
The standard header file, as documented in this specification, has fmi2TypesPlatform set to “default” (so this function usually returns “default”).

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- Returns the string to uniquely identify the “fmi2TypesPlatform.h” header file used for compilation of the functions of the FMU.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
"""

function fmi2GetTypesPlatform(c::FMU2Component)
    fmi2GetTypesPlatform(c.fmu)
end

"""

    fmi2GetVersion(fmu::FMU2)

Returns the version of the “fmi2Functions.h” header file which was used to compile the functions of the FMU.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- Returns a string from the address of a C-style (NUL-terminated) string. The string represents the version of the “fmi2Functions.h” header file which was used to compile the functions of the FMU. The function returns “fmiVersion” which is defined in this header file. The standard header file as documented in this specification has version “2.0”


# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
"""
function fmi2GetVersion(fmu::FMU2)

    fmi2Version = fmi2GetVersion(fmu.cGetVersion)

    unsafe_string(fmi2Version)
end
# special case
"""

    fmi2GetVersion(c::FMU2Component)

Returns the version of the “fmi2Functions.h” header file which was used to compile the functions of the FMU.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- Returns a string from the address of a C-style (NUL-terminated) string. The string represents the version of the “fmi2Functions.h” header file which was used to compile the functions of the FMU. The function returns “fmiVersion” which is defined in this header file. The standard header file as documented in this specification has version “2.0”


# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.4 Inquire Platform and Version Number of Header Files
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
"""

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

    fmi2SetDebugLogging(c::FMU2Component, logginOn::fmi2Boolean, nCategories::Unsigned, categories::Ptr{Nothing})

Control the use of the logging callback function, version independent.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `logginOn::fmi2Boolean`: If `loggingOn = fmi2True`, debug logging is enabled for the log categories specified in categories, otherwise it is disabled. Type `fmi2Boolean` is defined as an alias Type for the C-Type Boolean and is to be used with `fmi2True` and `fmi2False`.
- `nCategories::Unsigned`: Argument `nCategories` defines the length of the argument `categories`.
- `categories::Ptr{Nothing}`:

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.22]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.22]: 2.1.5 Creation, Destruction and Logging of FMU Instances
See also [`fmi2SetDebugLogging`](@ref).
"""
function fmi2SetDebugLogging(c::FMU2Component, logginOn::fmi2Boolean, nCategories::Unsigned, categories::Ptr{Nothing})

    status = fmi2SetDebugLogging(c.fmu.cSetDebugLogging, c.compAddr, logginOn, nCategories, categories)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetupExperiment(c::FMU2Component, toleranceDefined::fmi2Boolean, tolerance::fmi2Real, startTime::fmi2Real, stopTimeDefined::fmi2Boolean, stopTime::fmi2Real)

Informs the FMU to setup the experiment. This function must be called after `fmi2Instantiate` and before `fmi2EnterInitializationMode` is called.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `toleranceDefined::fmi2Boolean`: Arguments `toleranceDefined` depend on the FMU type:
  - fmuType = fmi2ModelExchange: If `toleranceDefined = fmi2True`, then the model is called with a numerical integration scheme where the step size is controlled by using `tolerance` for error estimation. In such a case, all numerical algorithms used inside the model (for example, to solve non-linear algebraic equations) should also operate with an error estimation of an appropriate smaller relative tolerance.
  - fmuType = fmi2CoSimulation: If `toleranceDefined = fmi2True`, then the communication interval of the slave is controlled by error estimation.  In case the slave utilizes a numerical integrator with variable step size and error estimation, it is suggested to use “tolerance” for the error estimation of the internal integrator (usually as relative tolerance). An FMU for Co-Simulation might ignore this argument.
- `startTime::fmi2Real`: Argument `startTime` can be used to check whether the model is valid within the given boundaries or to allocate memory which is necessary for storing results. It is the fixed initial value of the independent variable and if the independent variable is `time`, `startTime` is the starting time of initializaton.
- `stopTimeDefined::fmi2Boolean`:  If `stopTimeDefined = fmi2True`, then stopTime is the defined final value of the independent variable and if `stopTimeDefined = fmi2False`, then no final value
of the independent variable is defined and argument `stopTime` is meaningless.
- `stopTime::fmi2Real`: Argument `stopTime` can be used to check whether the model is valid within the given boundaries or to allocate memory which is necessary for storing results. It is the fixed final value of the independent variable and if the independent variable is “time”, stopTime is the stop time of the simulation.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.22]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.22]: 2.1.6 Initialization, Termination, and Resetting an FMU
See also [`fmi2SetupExperiment`](@ref).

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

    fmi2EnterInitializationMode(c::FMU2Component)

Informs the FMU to enter Initialization Mode. Before calling this function, all variables with attribute <ScalarVariable initial = "exact" or "approx"> can be set with the “fmi2SetXXX” functions (the ScalarVariable attributes are defined in the Model Description File, see section 2.2.7). Setting other variables is not allowed. Furthermore, `fmi2SetupExperiment` must be called at least once before calling `fmi2EnterInitializationMode`, in order that `startTime` is defined.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.22]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.22]: 2.1.6 Initialization, Termination, and Resetting an FMU
See also [`fmi2EnterInitializationMode`](@ref).

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

    fmi2ExitInitializationMode(c::FMU2Component)

Informs the FMU to exit Initialization Mode.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.22]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.22]: 2.1.6 Initialization, Termination, and Resetting an FMU
See also [`fmi2EnterInitializationMode`](@ref).
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

    fmi2Terminate(c::FMU2Component; soft::Bool=false)

Informs the FMU that the simulation run is terminated.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Keywords
- `soft::Bool=false`: If the Keyword `soft = true` the command is only performed if the FMU is in an allowed state for this command.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.22]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.22]: 2.1.6 Initialization, Termination, and Resetting an FMU
See also [`fmi2Terminate`](@ref).
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

    fmi2Reset(c::FMU2Component; soft::Bool=false)

Is called by the environment to reset the FMU after a simulation run. The FMU goes into the same state as if fmi2Instantiate would have been called.All variables have their default values. Before starting a new run, fmi2SetupExperiment and fmi2EnterInitializationMode have to be called.

# Arguments
- `c::FMU2Component`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Keywords
- `soft::Bool=false`: If the Keyword `soft = true` the command is only performed if the FMU is in an allowed state for this command.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.3 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.3[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.3[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.3[p.22]: 2.1.6 Initialization, Termination, and Resetting an FMU
See also [`fmi2Terminate`](@ref).
"""
function fmi2Reset(c::FMU2Component; soft::Bool=false)
    # according to FMISpec2.0.3[p.90], fmi2Reset can be called almost always, except before 
    # initialization and after a fatal error.
    if c.state == fmi2ComponentStateFatal
        if soft
            @warn "fmi2Reset was called in \"soft\" mode while the component was in Fatal state. Doing nothing."
            return fmi2StatusWarning
        else
            @warn "fmi2Reset was called in \"hard\" mode while the component was in Fatal state. Trying to reset anyways."
            # TODO maybe set a flag to also return fmi2StatusWarning later? 
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

    fmi2GetReal!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Real})

Functions to get and set values of variables idetified by their valueReference

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an AbstractArray of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::AbstractArray{fm2Real}`: Argument `values` is an AbstractArray with the actual values of these variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

 See also [`fmi2GetReal!`](@ref).

"""
function fmi2GetReal!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Real})

    status = fmi2GetReal!(c.fmu.cGetReal,
          c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetReal(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Real})

Functions to get and set values of variables idetified by their valueReference
# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an AbstractArray of `nvr` value handels, called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::AbstractArray{fm2Real}`: Argument `values` is an AbstractArray with the actual values of these variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values

 See also [`fmi2GetReal`](@ref).
"""
function fmi2SetReal(c::FMU2Component, 
    vr::AbstractArray{fmi2ValueReference}, 
    nvr::Csize_t, 
    value::AbstractArray{fmi2Real};
    track::Bool=true)

    status = fmi2SetReal(c.fmu.cSetReal,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)

    if track
        if status == fmi2StatusOK
            for j in (c.A, c.B, c.C, c.D)
                if any(collect(v in j.∂f_refs for v in vr))
                    FMICore.invalidate!(j)
                end
            end
        end
    end

    return status
end

"""

    fmi2GetInteger!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})

Writes the integer values of an array of variables in the given field

fmi2GetInteger! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an AbstractArray of `nvr` value handels, called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::AbstractArray{fmi2Integer}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

See also [`fmi2GetInteger!`](@ref),[`fmi2ValueReferenceFormat`](@ref), [`fmi2Struct`](@ref), [`FMU2`](@ref), [`FMU2Component`](@ref).

"""
function fmi2GetInteger!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})

    status = fmi2GetInteger!(c.fmu.cGetInteger,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetInteger(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})

Set the values of an array of integer variables

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an AbstractArray of `nvr` value handels, called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::AbstractArray{fmi2Integer}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

    See also [`fmi2GetInteger!`](@ref).
"""
function fmi2SetInteger(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Integer})

    status = fmi2SetInteger(c.fmu.cSetInteger,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetBoolean!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})

Writes the boolean values of an array of variables in the given field

fmi2GetBoolean! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments

- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an AbstractArray of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `value::AbstractArray{fmi2Boolean}`: Argument `values` is an array with the actual values of these variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
See also [`fmi2GetBoolean!`](@ref).

"""
function fmi2GetBoolean!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})

    status = fmi2GetBoolean!(c.fmu.cGetBoolean,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetBoolean(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})

Functions to get and set values of variables idetified by their valueReference

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `value::AbstractArray{fmi2Boolean}`: Argument `values` is an array with the actual values of these variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
See also [`fmi2GetBoolean`](@ref),[`fmi2ValueReferenceFormat`](@ref), [`fmi2Struct`](@ref), [`FMU2`](@ref), [`FMU2Component`](@ref).
"""
function fmi2SetBoolean(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::AbstractArray{fmi2Boolean})

    status = fmi2SetBoolean(c.fmu.cSetBoolean,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetString!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}})

Functions to get and set values of variables idetified by their valueReference

These functions are especially used to get the actual values of output variables if a model is connected with other
models.


# Arguments
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `value::Union{AbstractArray{Ptr{Cchar}, AbstractArray{Ptr{UInt8}}}`: The `value` argument is an AbstractArray of values whose memory address refers to data of type Cchar or UInt8and describes a vector with the actual values of these. variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
See also [`fmi2GetString!`](@ref).
"""
function fmi2GetString!(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}})

    status = fmi2GetString!(c.fmu.cGetString,
                c.compAddr, vr, nvr, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetString(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, value::Union{AbstractArray{Ptr{Cchar}}, AbstractArray{Ptr{UInt8}}})

Set the values of an array of string variables

For the exact rules on which type of variables fmi2SetXXX can be called see FMISpec2.0.2 section 2.2.7 , as well as FMISpec2.0.2 section 3.2.3 in case of ModelExchange and FMISpec2.0.2 section 4.2.4 in case ofCoSimulation.

# Arguments
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `value::Union{AbstractArray{Ptr{Cchar}, AbstractArray{Ptr{UInt8}}}`: The `value` argument is an AbstractArray of values whose memory address refers to data of type Cchar or UInt8and describes a vector with the actual values of these. variables.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
See also [`fmi2GetString!`](@ref).

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

    fmi2GetFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})

Makes a copy of the internal FMU state and returns a pointer to this copy.

# Arguments
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `FMUstate::Ref{fmi2FMUstate}`:If on entry `FMUstate == NULL`, a new allocation is required. If `FMUstate != NULL`, then `FMUstate` points to a previously returned `FMUstate` that has not been modified since.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
See also [`fmi2GetFMUstate!`](@ref).
"""
function fmi2GetFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})

    status = fmi2GetFMUstate!(c.fmu.cGetFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""

    fmi2SetFMUstate(c::FMU2Component, FMUstate::fmi2FMUstate)

Copies the content of the previously copied FMUstate back and uses it as actual new FMU state.

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `FMUstate::fmi2FMUstate`: Argument `FMUstate` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously


# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2GetFMUstate`](@ref), [`fmi2Struct`](@ref), [`FMU2`](@ref), [`FMU2Component`](@ref).
"""
function fmi2SetFMUstate(c::FMU2Component, FMUstate::fmi2FMUstate)

    status = fmi2SetFMUstate(c.fmu.cSetFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""

    fmi2FreeFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})

Frees all memory and other resources allocated with the fmi2GetFMUstate call for this FMUstate.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `FMUstate::Ref{fmi2FMUstate}`: Argument `FMUstate` is an object that safely references data of type `fmi3FMUstate` which is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2FreeFMUstate!`](@ref).
"""
function fmi2FreeFMUstate!(c::FMU2Component, FMUstate::Ref{fmi2FMUstate})

    status = fmi2FreeFMUstate!(c.fmu.cFreeFMUstate,
                c.compAddr, FMUstate)
    checkStatus(c, status)
    return status
end

"""

    fmi2SerializedFMUstateSize!(c::FMU2Component, FMUstate::fmi2FMUstate, size::Ref{Csize_t})

Stores the size of the byte vector in the given referenced Address, in order that FMUstate can be stored in it.
# Argument
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `FMUstate::fmi2FMUstate`: Argument `FMUstate` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.
- `size::Ref{Csize_t}`: Argument `size` is an object that safely references a value of type `Csize_t` and defines the size of the byte vector in which the FMUstate can be stored.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2SerializedFMUstateSize!`](@ref).
"""
function fmi2SerializedFMUstateSize!(c::FMU2Component, FMUstate::fmi2FMUstate, size::Ref{Csize_t})

    status = fmi2SerializedFMUstateSize!(c.fmu.cSerializedFMUstateSize,
                c.compAddr, FMUstate, size)
    checkStatus(c, status)
    return status
end

"""

    fmi2SerializeFMUstate!(c::FMU2Component, FMUstate::fmi2FMUstate, serialzedState::AbstractArray{fmi2Byte}, size::Csize_t)

Serializes the data which is referenced by pointer `FMUstate` and copies this data in to the byte vector `serializedState` of length `size`, that must be provided by the environment.

# Arguments
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `state::fmi2FMUstate`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.
- `serialzedState::AbstractArray{fmi2Byte}`: Argument `serializedState` contains the copy of the serialized data referenced by the pointer FMUstate.
- `size::Csize_t`: Argument `size` defines the length of the serialized vector.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2SerializeFMUstate`](@ref),[`fmi2FMUstate`](@ref), [`fmi2Struct`](@ref), [`FMU2`](@ref), [`FMU2Component`](@ref).
"""
function fmi2SerializeFMUstate!(c::FMU2Component, FMUstate::fmi2FMUstate, serialzedState::AbstractArray{fmi2Byte}, size::Csize_t)

    status = fmi2SerializeFMUstate!(c.fmu.cSerializeFMUstate,
                c.compAddr, FMUstate, serialzedState, size)
    checkStatus(c, status)
    return status
end

"""

    fmi2DeSerializeFMUstate!(c::FMU2Component, serializedState::AbstractArray{fmi2Byte}, size::Csize_t, FMUstate::Ref{fmi2FMUstate})

Deserializes the byte vector serializedState of length size, constructs a copy of the FMU state and stores the FMU state in the given address of the reference `FMUstate`, the pointer to this copy.

# Arguments
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `state::fmi2FMUstate`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.
- `serialzedState::AbstractArray{fmi2Byte}`: Argument `serializedState` contains the copy of the serialized data referenced by the pointer FMUstate.
- `size::Csize_t`: Argument `size` defines the length of the serialized vector.
- `FMUstate::Ref{fmi2FMUstate}`: Argument `FMUstate` is an object that safely references data of type `fmi3FMUstate` which is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2DeSerializeFMUstate!`](@ref).

"""
function fmi2DeSerializeFMUstate!(c::FMU2Component, serializedState::AbstractArray{fmi2Byte}, size::Csize_t, FMUstate::Ref{fmi2FMUstate})

    status = fmi2DeSerializeFMUstate!(c.fmu.cDeSerializeFMUstate,
                c.compAddr, serializedState, size, FMUstate)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetDirectionalDerivative!(c::FMU2Component,
                                       vUnknown_ref::AbstractArray{fmi2ValueReference},
                                       nUnknown::Csize_t,
                                       vKnown_ref::AbstractArray{fmi2ValueReference},
                                       nKnown::Csize_t,
                                       dvKnown::AbstractArray{fmi2Real},
                                       dvUnknown::AbstractArray{fmi2Real})

Wrapper Function call to compute the partial derivative with respect to the variables `vKnown_ref`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
   - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknowns>` that have type Real.
   - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
   - Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Outputs>` with type Real and variability = `discrete`.
   - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><Derivatives>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

   Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::AbstracArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `nUnknown::Csize_t`: Length of the `Unknown` Array.
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `nKnown::Csize_t`: Length of the `Known` Array.
- `dvKnown::AbstractArray{fmi2Real}`:The vector values Compute the partial derivative with respect to the given entries in vector `vKnown_ref` with the matching evaluate of `dvKnown`.
- `dvUnknown::AbstractArray{fmi2Real}`: Stores the directional derivative vector values.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.9 Getting Partial Derivatives
See also [`fmi2GetDirectionalDerivative`](@ref).
"""
function fmi2GetDirectionalDerivative!(c::FMU2Component,
                                       vUnknown_ref::AbstractArray{fmi2ValueReference},
                                       nUnknown::Csize_t,
                                       vKnown_ref::AbstractArray{fmi2ValueReference},
                                       nKnown::Csize_t,
                                       dvKnown::AbstractArray{fmi2Real},
                                       dvUnknown::AbstractArray{fmi2Real})
    @assert fmi2ProvidesDirectionalDerivative(c.fmu) ["fmi2GetDirectionalDerivative!(...): This FMU does not support build-in directional derivatives!"]

    status = fmi2GetDirectionalDerivative!(c.fmu.cGetDirectionalDerivative,
          c.compAddr, vUnknown_ref, nUnknown, vKnown_ref, nKnown, dvKnown, dvUnknown)
    checkStatus(c, status)
    return status
end

# Functions specificly for isCoSimulation
"""

    fmi2SetRealInputDerivatives(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})

Sets the n-th time derivative of real input variables.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that t define the variables whose derivatives shall be set.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `order::AbstractArray{fmi2Integer}`: Argument `order` is an AbstractArray of fmi2Integer values witch specifys the corresponding order of derivative of the real input variable.
- `values::AbstractArray{fmi2Real}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

See also [`fmi2SetRealInputDerivatives`](@ref).
"""
function fmi2SetRealInputDerivatives(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})

    status = fmi2SetRealInputDerivatives(c.fmu.cSetRealInputDerivatives,
                c.compAddr, vr, nvr, order, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetRealOutputDerivatives!(c::FMU2Component,  vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})

Sets the n-th time derivative of real input variables.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that t define the variables whose derivatives shall be set.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `order::Array{fmi2Integer}`: Argument `order` is an array of fmi2Integer values witch specifys the corresponding order of derivative of the real input variable.
- `values::Array{fmi2Real}`: Argument `values` is an array with the actual values of these variables.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

See also [`fmi2SetRealInputDerivatives!`](@ref).
"""
function fmi2GetRealOutputDerivatives!(c::FMU2Component,  vr::AbstractArray{fmi2ValueReference}, nvr::Csize_t, order::AbstractArray{fmi2Integer}, value::AbstractArray{fmi2Real})

    status = fmi2GetRealOutputDerivatives!(c.fmu.cGetRealOutputDerivatives,
                c.compAddr, vr, nvr, order, value)
    checkStatus(c, status)
    return status
end

"""

    fmi2DoStep(c::FMU2Component, currentCommunicationPoint::fmi2Real, communicationStepSize::fmi2Real, noSetFMUStatePriorToCurrentPoint::fmi2Boolean)

The computation of a time step is started.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `currentCommunicationPoint::fmi2Real`:  Argument `currentCommunicationPoint` contains a value of type `fmi2Real` which is a identifier for a variable value . `currentCommunicationPoint` defines the current communication point of the master.
- `communicationStepSize::fmi2Real`: Argument `communicationStepSize` contains a value of type `fmi2Real` which is a identifier for a variable value. `communicationStepSize` defines the communiction step size.
`noSetFMUStatePriorToCurrentPoint::Bool = true`: Argument `noSetFMUStatePriorToCurrentPoint` contains a value of type `Boolean`. If no argument is passed the default value `true` is used. `noSetFMUStatePriorToCurrentPoint` indicates whether `fmi2SetFMUState` is no longer called for times before the `currentCommunicationPoint` in this simulation run Simulation run.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.104]: 4.2.2 Computation
See also [`fmi2DoStep`](@ref).
"""
function fmi2DoStep(c::FMU2Component, currentCommunicationPoint::fmi2Real, communicationStepSize::fmi2Real, noSetFMUStatePriorToCurrentPoint::fmi2Boolean)
    @assert c.fmu.cDoStep != C_NULL ["fmi2DoStep(...): This FMU does not support fmi2DoStep, probably it's a ME-FMU with no CS-support?"]

    status = fmi2DoStep(c.fmu.cDoStep,
          c.compAddr, currentCommunicationPoint, communicationStepSize, noSetFMUStatePriorToCurrentPoint)
    checkStatus(c, status)
    return status
end

"""

    fmi2CancelStep(c::FMU2Component)

Can be called if `fmi2DoStep` returned `fmi2Pending` in order to stop the current asynchronous execution.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.104]: 4.2.2 Computation
See also [`fmi2DoStep`](@ref).
"""
function fmi2CancelStep(c::FMU2Component)

    status = fmi2CancelStep(c.fmu.cCancelStep, c.compAddr)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetStatus!(c::FMU2Component, s::fmi2StatusKind, value::Ref{fmi2Status}) 

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: Argument `s` defines which status information is to be returned. `fmi2StatusKind` is an enumeration that defines which status is inquired.
The following status information can be retrieved from a slave:
  - `fmi2DoStepStatus::fmi2Status`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers `fmi2Pending` if the computation is not finished. Otherwise the function returns the result of the asynchronously executed `fmi2DoStep` call.
  - `fmi2PendingStatus::fmi2String`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers a string which informs about the status of the currently running asynchronous `fmi2DoStep` computation
  - `fmi2LastSuccessfulTime:: fmi2Real`: Returns the end time of the last successfully completed communication step. Can be called after fmi2DoStep(..) returned fmi2Discard.
  - `fmi2Terminated::fmi2Boolean`: Returns `fmi2True`, if the slave wants to terminate the simulation. Can be called after fmi2DoStep(..) returned `fmi2Discard`. Use fmi2LastSuccessfulTime to determine the time instant at which the slave terminated.
- `value::Ref{fmi2Status}`: The `value` argument points to a status flag that was requested.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave
See also [`fmi2GetStatus!`](@ref).
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

    fmi2GetRealStatus!(c::FMU2Component, s::fmi2StatusKind, value::Ref{fmi2Real})

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: Argument `s` defines which status information is to be returned. `fmi2StatusKind` is an enumeration that defines which status is inquired.
The following status information can be retrieved from a slave:
  - `fmi2DoStepStatus::fmi2Status`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers `fmi2Pending` if the computation is not finished. Otherwise the function returns the result of the asynchronously executed `fmi2DoStep` call.
  - `fmi2PendingStatus::fmi2String`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers a string which informs about the status of the currently running asynchronous `fmi2DoStep` computation
  - `fmi2LastSuccessfulTime:: fmi2Real`: Returns the end time of the last successfully completed communication step. Can be called after fmi2DoStep(..) returned fmi2Discard.
  - `fmi2Terminated::fmi2Boolean`: Returns `fmi2True`, if the slave wants to terminate the simulation. Can be called after fmi2DoStep(..) returned `fmi2Discard`. Use fmi2LastSuccessfulTime to determine the time instant at which the slave terminated.
- `value::Ref{fmi2Real}`: Argument `value` points to the return value (fmi2Real) which was requested. `fmi2Real` is a alias type for `Real` data type.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave
See also [`fmi2GetRealStatus!`](@ref).
"""
function fmi2GetRealStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Real)

    status = fmi2GetRealStatus!(c.fmu.cGetRealStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""

    fmi2GetIntegerStatus!(c::FMU2Component, s::fmi2StatusKind, value::Ref{fmi2Integer})

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: Argument `s` defines which status information is to be returned. `fmi2StatusKind` is an enumeration that defines which status is inquired.
The following status information can be retrieved from a slave:
  - `fmi2DoStepStatus::fmi2Status`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers `fmi2Pending` if the computation is not finished. Otherwise the function returns the result of the asynchronously executed `fmi2DoStep` call.
  - `fmi2PendingStatus::fmi2String`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers a string which informs about the status of the currently running asynchronous `fmi2DoStep` computation
  - `fmi2LastSuccessfulTime:: fmi2Real`: Returns the end time of the last successfully completed communication step. Can be called after fmi2DoStep(..) returned fmi2Discard.
  - `fmi2Terminated::fmi2Boolean`: Returns `fmi2True`, if the slave wants to terminate the simulation. Can be called after fmi2DoStep(..) returned `fmi2Discard`. Use fmi2LastSuccessfulTime to determine the time instant at which the slave terminated.
- `value::Ref{fmi2Integer}`: Argument `value` points to the return value (fmi2Integer) which was requested. `fmi2Integer` is a alias type for `Integer` data type.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave
See also [`fmi2GetIntegerStatus!`](@ref).
"""
function fmi2GetIntegerStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Integer)

    status = fmi2GetIntegerStatus!(c.fmu.cGetIntegerStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""

    fmi2GetBooleanStatus!(c::FMU2Component, s::fmi2StatusKind, value::Ref{fmi2Boolean})

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: Argument `s` defines which status information is to be returned. `fmi2StatusKind` is an enumeration that defines which status is inquired.
The following status information can be retrieved from a slave:
 - `fmi2DoStepStatus::fmi2Status`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers `fmi2Pending` if the computation is not finished. Otherwise the function returns the result of the asynchronously executed `fmi2DoStep` call.
 - `fmi2PendingStatus::fmi2String`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers a string which informs about the status of the currently running asynchronous `fmi2DoStep` computation
 - `fmi2LastSuccessfulTime:: fmi2Real`: Returns the end time of the last successfully completed communication step. Can be called after fmi2DoStep(..) returned fmi2Discard.
 - `fmi2Terminated::fmi2Boolean`: Returns `fmi2True`, if the slave wants to terminate the simulation. Can be called after fmi2DoStep(..) returned `fmi2Discard`. Use fmi2LastSuccessfulTime to determine the time instant at which the slave terminated.
- `value::Ref{fmi2Boolean}`: Argument `value` points to the return value (fmi2Boolean) which was requested. `fmi2Boolean` is a alias type for `Boolean` data type.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave
See also [`fmi2GetBooleanStatus!`](@ref).
"""
function fmi2GetBooleanStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2Boolean)

    status = fmi2GetBooleanStatus!(c.fmu.cGetBooleanStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

"""

    fmi2GetStringStatus!(c::FMU2Component, s::fmi2StatusKind, value::Ref{fmi2String})

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: Argument `s` defines which status information is to be returned. `fmi2StatusKind` is an enumeration that defines which status is inquired.
The following status information can be retrieved from a slave:
- `fmi2DoStepStatus::fmi2Status`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers `fmi2Pending` if the computation is not finished. Otherwise the function returns the result of the asynchronously executed `fmi2DoStep` call.
- `fmi2PendingStatus::fmi2String`: Can be called when the `fmi2DoStep` function returned `fmi2Pending`. The function delivers a string which informs about the status of the currently running asynchronous `fmi2DoStep` computation
- `fmi2LastSuccessfulTime:: fmi2Real`: Returns the end time of the last successfully completed communication step. Can be called after fmi2DoStep(..) returned fmi2Discard.
- `fmi2Terminated::fmi2Boolean`: Returns `fmi2True`, if the slave wants to terminate the simulation. Can be called after fmi2DoStep(..) returned `fmi2Discard`. Use fmi2LastSuccessfulTime to determine the time instant at which the slave terminated.
- `value:Ref{fmi2String}:` Argument `value` points to the return value (fmi2String) which was requested. `fmi2String` is a alias type for `String` data type.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
- `fmi2OK`: all well
- `fmi2Warning`: things are not quite right, but the computation can continue
- `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi2Error`: the communication step could not be carried out at all
- `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
- `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.106]: 4.2.3 Retrieving Status Information from the Slave
See also [`fmi2GetStringStatus!`](@ref).
"""
function fmi2GetStringStatus!(c::FMU2Component, s::fmi2StatusKind, value::fmi2String)

    status = fmi2GetStringStatus!(c.fmu.cGetStringStatus,
                c.compAddr, s, Ref(value))
    checkStatus(c, status)
    return status
end

# Model Exchange specific Functions

"""

    fmi2SetTime(c::FMU2Component, time::fmi2Real; soft::Bool=false)

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `time::fmi2Real`: Argument `time` contains a value of type `fmi2Real` which is a alias type for `Real` data type. `time` sets the independent variable time t.

# Keywords
- `soft::Bool=false`: If the Keyword `soft = true` the command is only performed if the FMU is in an allowed state for this command.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching
See also [`fmi2SetTime`](@ref).
"""
function fmi2SetTime(c::FMU2Component, time::fmi2Real; soft::Bool=false, track::Bool=true, force::Bool=c.fmu.executionConfig.force, time_shift::Bool=c.fmu.executionConfig.autoTimeShift)

    # ToDo: Double-check this in the spec.
    # discrete = (c.fmu.hasStateEvents == true || c.fmu.hasTimeEvents == true)
    # if !( discrete && c.state == fmi2ComponentStateEventMode && c.eventInfo.newDiscreteStatesNeeded == fmi2False) &&
    #    !(!discrete && c.state == fmi2ComponentStateContinuousTimeMode)
    #     if soft
    #         return fmi2StatusOK
    #     else
    #         @warn "fmi2SetTime(...): Called at the wrong time, must be in event mode and `newDiscreteStatesNeeded=false` (if discrete) or in continuous time mode (if continuous)."
    #     end
    # end

    if time_shift
        time += c.t_offset
    end

    if !force
        if c.t == time 
            return fmi2StatusOK
        end
    end

    status = fmi2SetTime(c.fmu.cSetTime, c.compAddr, time)
    checkStatus(c, status)

    if track
        if status == fmi2StatusOK
            c.t = time

            FMICore.invalidate!(c.A)
            FMICore.invalidate!(c.B)
            FMICore.invalidate!(c.C)
            FMICore.invalidate!(c.D)
        end
    end

    return status
end

"""

    fmi2SetContinuousStates(c::FMU2Component,
                                 x::AbstractArray{fmi2Real},
                                 nx::Csize_t)

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `x::AbstractArray{fmi2Real}`: Argument `x` contains values of type `fmi2Real` which is a alias type for `Real` data type.`x` is the `AbstractArray` of the vector values of `Real` input variables of function h that changes its value in the actual Mode.
- `nx::Csize_t`: Argument `nx` defines the length of vector `x` and is provided for checking purposes

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.1 Providing Independent Variables and Re-initialization of Caching
See also [`fmi2SetContinuousStates`](@ref).
"""

fmi2NewDiscreteStates!
function fmi2SetContinuousStates(c::FMU2Component,
    x::AbstractArray{fmi2Real},
    nx::Csize_t;
    track::Bool=true,
    force::Bool=c.fmu.executionConfig.force)

    if !force
        if c.x == x 
            return fmi2StatusOK 
        end
    end

    status = fmi2SetContinuousStates(c.fmu.cSetContinuousStates, c.compAddr, x, nx)
    checkStatus(c, status)

    if track
        if status == fmi2StatusOK
            c.x = copy(x)

            FMICore.invalidate!(c.A)
            FMICore.invalidate!(c.C)
        end
    end

    return status
end

"""

    fmi2EnterEventMode(c::FMU2Component; soft::Bool=false)

The model enters Event Mode from the Continuous-Time Mode and discrete-time equations may become active (and relations are not “frozen”).

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Keywords
- `soft::Bool=false`: If the Keyword `soft = true` the command is only performed if the FMU is in an allowed state for this command.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
 - `fmi2OK`: all well
 - `fmi2Warning`: things are not quite right, but the computation can continue
 - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
 - `fmi2Error`: the communication step could not be carried out at all
 - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
 - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2EnterEventMode`](@ref).
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

    fmi2NewDiscreteStates!(c::FMU2Component, eventInfo::fmi2EventInfo)

The FMU is in Event Mode and the super dense time is incremented by this call.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `eventInfo::fmi2EventInfo*`: Strut with `fmi2Boolean` Variables that
More detailed:
 - `newDiscreteStatesNeeded::fmi2Boolean`: If `newDiscreteStatesNeeded = fmi2True` the FMU should stay in Event Mode, and the FMU requires to set new inputs to the FMU to compute and get the outputs and to call
fmi2NewDiscreteStates again. If all FMUs return `newDiscreteStatesNeeded = fmi2False` call fmi2EnterContinuousTimeMode.
 - `terminateSimulation::fmi2Boolean`: If `terminateSimulation = fmi2True` call `fmi2Terminate`
 - `nominalsOfContinuousStatesChanged::fmi2Boolean`: If `nominalsOfContinuousStatesChanged = fmi2True` then the nominal values of the states have changed due to the function call and can be inquired with `fmi2GetNominalsOfContinuousStates`.
 - `valuesOfContinuousStatesChanged::fmi2Boolean`: If `valuesOfContinuousStatesChanged = fmi2True`, then at least one element of the continuous state vector has changed its value due to the function call. The new values of the states can be retrieved with `fmi2GetContinuousStates`. If no element of the continuous state vector has changed its value, `valuesOfContinuousStatesChanged` must return fmi2False.
 - `nextEventTimeDefined::fmi2Boolean`: If `nextEventTimeDefined = fmi2True`, then the simulation shall integrate at most until `time = nextEventTime`, and shall call `fmi2EnterEventMode` at this time instant. If integration is stopped before nextEventTime, the definition of `nextEventTime` becomes obsolete.
 - `nextEventTime::fmi2Real`: next event if `nextEventTimeDefined=fmi2True`

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
- `fmi2OK`: all well
- `fmi2Warning`: things are not quite right, but the computation can continue
- `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi2Error`: the communication step could not be carried out at all
- `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
- `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2NewDiscreteStates`](@ref).
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

    fmi2EnterContinuousTimeMode(c::FMU2Component; soft::Bool=false)

The model enters Continuous-Time Mode and all discrete-time equations become inactive and all relations are “frozen”.
This function has to be called when changing from Event Mode (after the global event iteration in Event Mode over all involved FMUs and other models has converged) into Continuous-Time Mode.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.


# Keywords
- `soft::Bool=false`: If the Keyword `soft = true` the command is only performed if the FMU is in an allowed state for this command.


# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2EnterContinuousTimeMode`](@ref).
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

    fmi2CompletedIntegratorStep!(c::FMU2Component,
                                    noSetFMUStatePriorToCurrentPoint::fmi2Boolean,
                                    enterEventMode::Ref{fmi2Boolean},
                                    terminateSimulation::Ref{fmi2Boolean})

This function must be called by the environment after every completed step of the integrator provided the capability flag completedIntegratorStepNotNeeded = false.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `noSetFMUStatePriorToCurrentPoint::fmi2Boolean`: Argument `noSetFMUStatePriorToCurrentPoint = fmi2True` if `fmi2SetFMUState`  will no longer be called for time instants prior to current time in this simulation run.
- `enterEventMode::Ref{fmi2Boolean}`: Argument `enterEventMode` points to the return value (fmi2Boolean) which signals to the environment if the FMU shall call `fmi2EnterEventMode`. `fmi2Boolean` is an alias type for `Boolean` data type.
- `terminateSimulation::Ref{fmi2Boolean}`: Argument `terminateSimulation` points to the return value (fmi2Boolean) which signals signal if the simulation shall be terminated. `fmi2Boolean` is an alias type for `Boolean` data type.
# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2CompletedIntegratorStep`](@ref), [`fmi2SetFMUState`](@ref).
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

    fmi2GetDerivatives!(c::FMU2Component,
                       derivatives::AbstractArray{fmi2Real},
                       nx::Csize_t)

Compute state derivatives at the current time instant and for the current states.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `derivatives::AbstractArray{fmi2Real}`: Argument `derivatives` contains values of type `fmi2Real` which is a alias type for `Real` data type.`derivatives` is the `AbstractArray` which contains the `Real` values of the vector that represent the derivatives. The ordering of the elements of the derivatives vector is identical to the ordering of the state vector.
- `nx::Csize_t`: Argument `nx` defines the length of vector `derivatives` and is provided for checking purposes


# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetDerivatives!`](@ref).

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

    fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::AbstractArray{fmi2Real}, ni::Csize_t)

Compute event indicators at the current time instant and for the current states.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `eventIndicators::AbstractArray{fmi2Real}`: Argument `eventIndicators` contains values of type `fmi2Real` which is a alias type for `Real` data type.`eventIndicators` is the `AbstractArray` which contains the `Real` values of the vector that represent the event indicators.
- `ni::Csize_t`: Argument `ni` defines the length of vector `eventIndicators` and is provided for checking purposes

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators!`](@ref).
"""
function fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::AbstractArray{fmi2Real}, ni::Csize_t)

    status = fmi2GetEventIndicators!(c.fmu.cGetEventIndicators,
                    c.compAddr, eventIndicators, ni)
    checkStatus(c, status)
    return status
end

"""

    fmi2GetContinuousStates!(c::FMU2Component,
                                x::AbstractArray{fmi2Real},
                                nx::Csize_t)

Stores the new (continuous) state vector in x.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `x::AbstractArray{fmi2Real}`: Argument `x` contains values of type `fmi2Real` which is a alias type for `Real` data type.`x` is the `AbstractArray` which contains the `Real` values of the vector that represent the new state vector.
- `nx::Csize_t`: Argument `nx` defines the length of vector `x` and is provided for checking purposes

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators!`](@ref).
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

    fmi2GetNominalsOfContinuousStates!(c::FMU2Component, x_nominal::AbstractArray{fmi2Real}, nx::Csize_t)

Stores the nominal values of the continuous states in x_nominal.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `x_nominal::AbstractArray{fmi2Real}`: Argument `x_nominal` contains values of type `fmi2Real` which is a alias type for `Real` data type.`x_nominal` is the `AbstractArray` which contains the `Real` values of the vector that represent the nominal values of the continuous states.
- `nx::Csize_t`: Argument `nx` defines the length of vector `x` and is provided for checking purposes

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators!`](@ref).
"""
function fmi2GetNominalsOfContinuousStates!(c::FMU2Component, x_nominal::AbstractArray{fmi2Real}, nx::Csize_t)

    status = fmi2GetNominalsOfContinuousStates!(c.fmu.cGetNominalsOfContinuousStates,
                    c.compAddr, x_nominal, nx)
    checkStatus(c, status)
    return status
end
