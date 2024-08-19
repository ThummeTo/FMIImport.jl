#
# Copyright (c) 2024 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""

    fmi3InstantiateModelExchange!(fmu::FMU3; instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
        logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new modelExchange instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU modelExchange instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateModelExchange`](#@ref).
"""
function fmi3InstantiateModelExchange!(
    fmu::FMU3;
    instanceName::String = fmu.modelName,
    type::fmi3Type = fmu.type,
    pushInstances::Bool = true,
    visible::Bool = false,
    loggingOn::Bool = fmu.executionConfig.loggingOn,
    externalCallBacks::Bool = fmu.executionConfig.externalCallbacks,
    logStatusOK::Bool = true,
    logStatusWarning::Bool = true,
    logStatusDiscard::Bool = true,
    logStatusError::Bool = true,
    logStatusFatal::Bool = true,
)

    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(
        fmi3CallbackLogger,
        Cvoid,
        (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar})
    )

    ptrInstanceEnvironment = Ptr{Cvoid}(pointer_from_objref(instEnv))

    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"

    addr = fmi3InstantiateModelExchange(
        fmu.cInstantiateModelExchange,
        pointer(instanceName),
        pointer(instantiationTokenStr),
        pointer(fmu.fmuResourceLocation),
        fmi3Boolean(visible),
        fmi3Boolean(loggingOn),
        ptrInstanceEnvironment,
        ptrLogger,
    )

    if addr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateModelExchange!(...): Instantiation failed!"
        return nothing
    end

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.addr == addr
            instance = c
            break
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateModelExchange!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else

        instance = FMU3Instance(addr, fmu)
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.z_prev = zeros(fmi3Float64, fmi3GetNumberOfEventIndicators(instance))
        instance.rootsFound = zeros(fmi3Int32, fmi3GetNumberOfEventIndicators(instance))
        instance.stateEvent = fmi3False
        instance.timeEvent = fmi3False
        instance.stepEvent = fmi3False
        instance.type = fmi3TypeModelExchange

        if pushInstances
            push!(fmu.instances, instance)
        end

        fmu.threadInstances[Threads.threadid()] = instance
    end

    return getCurrentInstance(fmu)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3InstantiateModelExchange`
export fmi3InstantiateModelExchange!

"""

    fmi3InstantiateCoSimulation!(fmu::FMU3; instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
        eventModeUsed::Bool = false, ptrIntermediateUpdate=nothing, logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new coSimulation instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `eventModeUsed::Bool = false`: Defines if the FMU instance can use the event mode. (default=`false`)
- `ptrIntermediateUpdate=nothing`: Points to a function handling intermediate Updates (defalut=`nothing`) 
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU coSimulation instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateCoSimulation`](#@ref).
"""
function fmi3InstantiateCoSimulation!(
    fmu::FMU3;
    instanceName::String = fmu.modelName,
    type::fmi3Type = fmu.type,
    pushInstances::Bool = true,
    visible::Bool = false,
    loggingOn::Bool = fmu.executionConfig.loggingOn,
    externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
    eventModeUsed::Bool = false,
    ptrIntermediateUpdate = nothing,
    logStatusOK::Bool = true,
    logStatusWarning::Bool = true,
    logStatusDiscard::Bool = true,
    logStatusError::Bool = true,
    logStatusFatal::Bool = true,
)
    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(
        fmi3CallbackLogger,
        Cvoid,
        (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar})
    )

    if ptrIntermediateUpdate === nothing
        ptrIntermediateUpdate = @cfunction(
            fmi3CallbackIntermediateUpdate,
            Cvoid,
            (
                Ptr{Cvoid},
                fmi3Float64,
                fmi3Boolean,
                fmi3Boolean,
                fmi3Boolean,
                fmi3Boolean,
                Ptr{fmi3Boolean},
                Ptr{fmi3Float64},
            )
        )
    end
    if fmu.modelDescription.coSimulation.hasEventMode !== nothing
        mode = eventModeUsed
    else
        mode = false
    end
    ptrInstanceEnvironment = Ptr{Cvoid}(pointer_from_objref(instEnv))

    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"

    addr = fmi3InstantiateCoSimulation(
        fmu.cInstantiateCoSimulation,
        pointer(instanceName),
        pointer(instantiationTokenStr),
        pointer(fmu.fmuResourceLocation),
        fmi3Boolean(visible),
        fmi3Boolean(loggingOn),
        fmi3Boolean(mode),
        fmi3Boolean(
            fmu.modelDescription.coSimulation.canReturnEarlyAfterIntermediateUpdate !==
            nothing,
        ),
        fmu.modelDescription.intermediateUpdateValueReferences,
        Csize_t(length(fmu.modelDescription.intermediateUpdateValueReferences)),
        ptrInstanceEnvironment,
        ptrLogger,
        ptrIntermediateUpdate,
    )

    if addr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateCoSimulation!(...): Instantiation failed!"
        return nothing
    end

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.addr == addr
            instance = c
            break
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateCoSimulation!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        instance = FMU3Instance(addr, fmu)
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.type = fmi3TypeCoSimulation

        if pushInstances
            push!(fmu.instances, instance)
        end

        fmu.threadInstances[Threads.threadid()] = instance
    end

    return getCurrentInstance(fmu)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3InstantiateCoSimulation`
export fmi3InstantiateCoSimulation!

# TODO not tested
"""

    fmi3InstantiateScheduledExecution!(fmu::FMU3; ptrlockPreemption::Ptr{Cvoid}, ptrunlockPreemption::Ptr{Cvoid}, instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
        logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new ScheduledExecution instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `ptrlockPreemption::Ptr{Cvoid}`: Points to a function handling locking Preemption
- `ptrunlockPreemption::Ptr{Cvoid}`: Points to a function handling unlocking Preemption
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU ScheduledExecution instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateScheduledExecution`](#@ref).
"""
function fmi3InstantiateScheduledExecution!(
    fmu::FMU3;
    ptrlockPreemption::Ptr{Cvoid},
    ptrunlockPreemption::Ptr{Cvoid},
    instanceName::String = fmu.modelName,
    type::fmi3Type = fmu.type,
    pushInstances::Bool = true,
    visible::Bool = false,
    loggingOn::Bool = fmu.executionConfig.loggingOn,
    externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
    logStatusOK::Bool = true,
    logStatusWarning::Bool = true,
    logStatusDiscard::Bool = true,
    logStatusError::Bool = true,
    logStatusFatal::Bool = true,
)

    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(
        fmi3CallbackLogger,
        Cvoid,
        (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar})
    )
    ptrClockUpdate = @cfunction(fmi3CallbackClockUpdate, Cvoid, (Ptr{Cvoid},))

    ptrInstanceEnvironment = Ptr{FMU3InstanceEnvironment}(pointer_from_objref(instEnv))

    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"

    addr = fmi3InstantiateScheduledExecution(
        fmu.cInstantiateScheduledExecution,
        pointer(instanceName),
        pointer(instantiationTokenStr),
        pointer(fmu.fmuResourceLocation),
        fmi3Boolean(visible),
        fmi3Boolean(loggingOn),
        ptrInstanceEnvironment,
        ptrLogger,
        ptrClockUpdate,
        ptrlockPreemption,
        ptrunlockPreemption,
    )

    if addr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateScheduledExecution!(...): Instantiation failed!"
        return nothing
    end

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.addr == addr
            instance = c
            break
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateScheduledExecution!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        instance = FMU3Instance(addr, fmu)
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.type = fmi3TypeScheduledExecution

        if pushInstances
            push!(fmu.instances, instance)
        end

        fmu.threadInstances[Threads.threadid()] = instance
    end

    return getCurrentInstance(fmu)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3InstantiateScheduledExecution`
export fmi3InstantiateScheduledExecution!

"""
    
    fmi3FreeInstance!(c::FMU3Instance; popInstance::Bool = true)

Disposes the given instance, unloads the loaded model, and frees all the allocated memory and other resources that have been allocated by the functions of the FMU interface.
If a null pointer is provided for “c”, the function call is ignored (does not have an effect).

Removes the component from the FMUs component list.
            
# Arguments
- `c::FMU3Instance`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Keywords
- `popInstance::Bool=true`: If the Keyword `popInstance = true` the freed instance is deleted

# Returns
- nothing

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable
"""
function fmi3FreeInstance!(c::FMU3Instance; popInstance::Bool = true)

    addr = c.addr

    if popInstance
        ind = findall(x -> x.addr == c.addr, c.fmu.instances)
        @assert length(ind) == 1 "fmi3FreeInstance!(...): Freeing $(length(ind)) instances with one call, this is not allowed."
        deleteat!(c.fmu.instances, ind)

        for key in keys(c.fmu.threadInstances)
            if !isnothing(c.fmu.threadInstances[key]) &&
               c.fmu.threadInstances[key].addr == addr
                c.fmu.threadInstances[key] = nothing
            end
        end
    end
    fmi3FreeInstance(c.fmu.cFreeInstance, c.addr)

    nothing
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3FreeInstance`
export fmi3FreeInstance!


"""

    fmi3SetDebugLogging(c::FMU3Instance)

Set the DebugLogger for the FMU.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- Returns a warning if `str.state` is not called in `fmi3InstanceStateInstantiated`.
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3SetDebugLogging`](@ref).
"""
function fmi3SetDebugLogging(c::FMU3Instance)
    fmi3SetDebugLogging(c, fmi3False, Unsigned(0), C_NULL)
end

"""

    fmi3EnterInitializationMode(c::FMU3Instance, startTime::Union{Real, Nothing} = nothing, stopTime::Union{Real, Nothing} = nothing; tolerance::Union{Real, Nothing} = nothing)

FMU enters Initialization mode.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `startTime::Union{Real, Nothing} = nothing`: `startTime` is a real number which sets the value of starting time of the experiment. The default value is set automatically if doing nothing (default = `nothing`).
- `stopTime::Union{Real, Nothing} = nothing`: `stopTime` is a real number which sets the value of ending time of the experiment. The default value is set automatically if doing nothing (default = `nothing`).
 
# Keywords
- `tolerance::Union{Real, Nothing} = nothing`: `tolerance` is a real number which sets the value of tolerance range. The default value is set automatically if doing nothing (default = `nothing`).
 
# Returns
- Returns a warning if `str.state` is not called in `fmi3InstanceStateInstantiated`.
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.3.2. State: Instantiated

See also [`fmi3EnterInitializationMode`](@ref).
"""
function fmi3EnterInitializationMode(
    c::FMU3Instance,
    startTime::Union{Real,Nothing} = nothing,
    stopTime::Union{Real,Nothing} = nothing;
    tolerance::Union{Real,Nothing} = nothing,
)
    if c.state != fmi3InstanceStateInstantiated
        @warn "fmi3EnterInitializationMode(...): Needs to be called in state `fmi3IntanceStateInstantiated`."
    end

    if startTime === nothing
        startTime = getDefaultStartTime(c.fmu.modelDescription)
        if startTime === nothing
            startTime = 0.0
        end
    end
    c.t = startTime

    toleranceDefined = (tolerance !== nothing)
    if !toleranceDefined
        tolerance = 0.0 # dummy value, will be ignored
    end

    stopTimeDefined = (stopTime !== nothing)
    if !stopTimeDefined
        stopTime = 0.0 # dummy value, will be ignored
    end

    status = fmi3EnterInitializationMode(
        c.fmu.cEnterInitializationMode,
        c.addr,
        fmi3Boolean(toleranceDefined),
        fmi3Float64(tolerance),
        fmi3Float64(startTime),
        fmi3Boolean(stopTimeDefined),
        fmi3Float64(stopTime),
    )
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateInitializationMode
    end
    return status
end

"""

    fmi3GetFloat32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Float32 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Float32}`: returns values of an array of fmi3Float32 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetFloat32`](@ref).
"""
function fmi3GetFloat32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Float32, nvr)
    fmi3GetFloat32!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetFloat32!`
export fmi3GetFloat32

"""

    fmi3GetFloat32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Float32})

Writes the real values of an array of variables in the given field

fmi3GetFloat32! is only possible for arrays of values, please use an array instead of a scalar.
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Float32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetFloat32!`](@ref).
"""
function fmi3GetFloat32!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Float32},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetFloat32!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetFloat32!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetFloat32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Float32)
    @assert false "fmi3GetFloat32! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetFloat32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Float32}, fmi3Float32})

Set the values of an array of real variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Float32}, fmi3Float32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetFloat32`](@ref).
"""
function fmi3SetFloat32(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Float32},fmi3Float32},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetFloat32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetFloat32(c, vr, nvr, values, nvr)
end

"""

    fmi3GetFloat64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Float64 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Float64}`: returns values of an array of fmi3Float64 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetFloat64`](@ref).
"""
function fmi3GetFloat64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Float64, nvr)
    fmi3GetFloat64!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetFloat64!`
export fmi3GetFloat64

"""

    fmi3GetFloat64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Float64})

Writes the real values of an array of variables in the given field

fmi3GetFloat64! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Float64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetFloat64!`](@ref).
"""
function fmi3GetFloat64!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Float64},
)

    vr = prepareValueReference(c, vr)

    @assert length(vr) == length(values) "fmi3GetFloat64!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetFloat64!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetFloat64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Float64)
    @assert false "fmi3GetFloat64! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetFloat64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Float64}, fmi3Float64})

Set the values of an array of real variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Float64}, fmi3Float64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetFloat64`](@ref).
"""
function fmi3SetFloat64(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Float64},fmi3Float64};
    kwargs...,
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetFloat64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    return fmi3SetFloat64(c, vr, nvr, values, nvr; kwargs...)
end

"""

    fmi3GetInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Int8 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Int8}`: returns values of an array of fmi3Int8 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt8`](@ref).
"""
function fmi3GetInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Int8, nvr)
    fmi3GetInt8!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetInt8!`
export fmi3GetInt8

"""

    fmi3GetInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int8})

Writes the integer values of an array of variables in the given field

fmi3GetInt8! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Int8}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt8!`](@ref).
"""
function fmi3GetInt8!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Int8},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetInt8!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetInt8!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Int8)
    @assert false "fmi3GetInt8! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int8}, fmi3Int8})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Int8}, fmi3Int8}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetInt8`](@ref).
"""
function fmi3SetInt8(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Int8},fmi3Int8},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt8(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt8(c, vr, nvr, values, nvr)
end

"""

    fmi3GetUInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3UInt8 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3UInt8}`: returns values of an array of fmi3UInt8 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt8`](@ref).
"""
function fmi3GetUInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3UInt8, nvr)
    fmi3GetUInt8!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetUInt8!`
export fmi3GetUInt8

"""

    fmi3GetUInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt8})

Writes the integer values of an array of variables in the given field

fmi3GetUInt8! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3UInt8}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt8!`](@ref).
"""
function fmi3GetUInt8!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3UInt8},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetUInt8!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetUInt8!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetUInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3UInt8)
    @assert false "fmi3GetUInt8! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetUInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt8}, fmi3UInt8})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3UInt8}, fmi3UInt8}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetUInt8`](@ref).
"""
function fmi3SetUInt8(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3UInt8},fmi3UInt8},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt8(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt8(c, vr, nvr, values, nvr)
end

"""

    fmi3GetInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Int16 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Int16}`: returns values of an array of fmi3Int16 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt16`](@ref).
"""
function fmi3GetInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Int16, nvr)
    fmi3GetInt16!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetInt16!`
export fmi3GetInt16

"""

    fmi3GetInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int16})

Writes the integer values of an array of variables in the given field

fmi3GetInt16! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Int16}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt16!`](@ref).
"""
function fmi3GetInt16!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Int16},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetInt16!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetInt16!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Int16)
    @assert false "fmi3GetInt16! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int16}, fmi3Int16})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Int16}, fmi3Int16}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetInt16`](@ref).
"""
function fmi3SetInt16(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Int16},fmi3Int16},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt16(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt16(c, vr, nvr, values, nvr)
end

"""

    fmi3GetUInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3UInt16 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3UInt16}`: returns values of an array of fmi3UInt16 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt16`](@ref).
"""
function fmi3GetUInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3UInt16, nvr)
    fmi3GetUInt16!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetUInt16!`
export fmi3GetUInt16

"""

    fmi3GetUInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt16})

Writes the integer values of an array of variables in the given field

fmi3GetUInt16! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3UInt16}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt16!`](@ref).
"""
function fmi3GetUInt16!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3UInt16},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetUInt16!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetUInt16!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetUInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3UInt16)
    @assert false "fmi3GetUInt16! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetUInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt16}, fmi3UInt16})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3UInt16}, fmi3UInt16}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetUInt16`](@ref).
"""
function fmi3SetUInt16(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3UInt16},fmi3UInt16},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt16(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt16(c, vr, nvr, values, nvr)
end

"""

    fmi3GetInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Int32 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Int32}`: returns values of an array of fmi3Int32 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt32`](@ref).
"""
function fmi3GetInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Int32, nvr)
    fmi3GetInt32!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetInt32!`
export fmi3GetInt32

"""

    fmi3GetInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int32})

Writes the integer values of an array of variables in the given field

fmi3GetInt32! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Int32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt32!`](@ref).
"""
function fmi3GetInt32!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Int32},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetInt32!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetInt32!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Int32)
    @assert false "fmi3GetInt32! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int32}, fmi3Int32})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Int32}, fmi3Int32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetInt32`](@ref).
"""
function fmi3SetInt32(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Int32},fmi3Int32},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt32(c, vr, nvr, values, nvr)
end

"""

    fmi3GetUInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3UInt32 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3UInt32}`: returns values of an array of fmi3UInt32 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt32`](@ref).
"""
function fmi3GetUInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3UInt32, nvr)
    fmi3GetUInt32!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetUInt32!`
export fmi3GetUInt32

"""

    fmi3GetUInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt32})

Writes the integer values of an array of variables in the given field

fmi3GetUInt32! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3UInt32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt32!`](@ref).
"""
function fmi3GetUInt32!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3UInt32},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetUInt32!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetUInt32!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetUInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3UInt32)
    @assert false "fmi3GetUInt32! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetUInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt32}, fmi3UInt32})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3UInt32}, fmi3UInt32}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetUInt32`](@ref).
"""
function fmi3SetUInt32(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3UInt32},fmi3UInt32},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt32(c, vr, nvr, values, nvr)
end

"""

    fmi3GetInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Int64 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Int64}`: returns values of an array of fmi3Int64 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt64`](@ref).
"""
function fmi3GetInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3Int64, nvr)
    fmi3GetInt64!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetInt64!`
export fmi3GetInt64


"""

    fmi3GetInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int64})

Writes the integer values of an array of variables in the given field

fmi3GetInt64! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Int64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetInt64!`](@ref).
"""
function fmi3GetInt64!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Int64},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetInt64!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetInt64!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Int64)
    @assert false "fmi3GetInt64! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int64}, fmi3Int64})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Int64}, fmi3Int64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetInt64`](@ref).
"""
function fmi3SetInt64(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Int64},fmi3Int64},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt64(c, vr, nvr, values, nvr)
end

"""

    fmi3GetUInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3UInt64 variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3UInt64}`: returns values of an array of fmi3UInt64 variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt64`](@ref).
"""
function fmi3GetUInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi3UInt64, nvr)
    fmi3GetUInt64!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetUInt64!`
export fmi3GetUInt64

"""

    fmi3GetUInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt64})

Writes the integer values of an array of variables in the given field

fmi3GetUInt64! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3UInt64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetUInt64!`](@ref).
"""
function fmi3GetUInt64!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3UInt64},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetUInt64!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetUInt64!(c, vr, nvr, values, nvr)
    nothing
end
function fmi3GetUInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3UInt64)
    @assert false "fmi3GetUInt64! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetUInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt64}, fmi3UInt64})

Set the values of an array of integer variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3UInt64}, fmi3UInt64}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetUInt64`](@ref).
"""
function fmi3SetUInt64(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3UInt64},fmi3UInt64},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt64(c, vr, nvr, values, nvr)
end

"""

    fmi3GetBoolean(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Boolean variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Boolean}`: returns values of an array of fmi3Boolean variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetBoolean`](@ref).
"""
function fmi3GetBoolean(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = Array{fmi3Boolean}(undef, nvr)
    fmi3GetBoolean!(c, vr, nvr, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetBoolean!`
export fmi3GetBoolean

"""

    fmi3GetBoolean!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Boolean})

Writes the boolean values of an array of variables in the given field

fmi3GetBoolean! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Boolean}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetBoolean!`](@ref).
"""
function fmi3GetBoolean!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Boolean},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetBoolean!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi3GetBoolean!(c, vr, nvr, values, nvr)

    nothing
end
function fmi3GetBoolean!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Bool)
    @assert false "fmi3GetBoolean! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetBoolean(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{Bool}, Bool})

Set the values of an array of boolean variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{Bool}, Bool}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetBoolean`](@ref).
"""
function fmi3SetBoolean(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{Bool},Bool},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetBoolean(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetBoolean(c, vr, nvr, Array{fmi3Boolean}(values), nvr)
end

"""

    fmi3GetString(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3String variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3String}`: returns values of an array of fmi3String variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetString`](@ref).
"""
function fmi3GetString(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    vars = Vector{Ptr{Cchar}}(undef, nvr)
    values = string.(zeros(nvr))
    fmi3GetString!(c, vr, nvr, vars, nvr)
    values[:] = unsafe_string.(vars)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetString!`
export fmi3GetString

"""

    fmi3GetString!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3String})

Writes the string values of an array of variables in the given field

fmi3GetString! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3String}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetString!`](@ref).
"""
function fmi3GetString!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3String},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetString!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    # values = Vector{Ptr{Cchar}}.(values)
    vars = Vector{Ptr{Cchar}}(undef, nvr)
    fmi3GetString!(c, vr, nvr, vars, nvr)
    values[:] = unsafe_string.(vars)
    nothing
end
function fmi3GetString!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::String)
    @assert false "fmi3GetString! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetString(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{String}, String})

Set the values of an array of string variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{String}, String}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetString`](@ref).
"""
function fmi3SetString(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{String},String},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetString(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    ptrs = pointer.(values)
    fmi3SetString(c, vr, nvr, ptrs, nvr)
end

"""

    fmi3GetBinary(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Binary variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Binary}`: returns values of an array of fmi3Binary variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetBinary`](@ref).
"""
function fmi3GetBinary(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = Array{fmi3Binary}(undef, nvr)
    valueSizes = Array{Csize_t}(undef, nvr)
    fmi3GetBinary!(c, vr, nvr, valueSizes, values, nvr)
    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetBinary!`
export fmi3GetBinary

"""

    fmi3GetBinary!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Binary})

Writes the binary values of an array of variables in the given field

fmi3GetBinary! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Binary}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetBinary!`](@ref).
"""
function fmi3GetBinary!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Binary},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetBinary!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    valueSizes = Array{Csize_t}(undef, nvr)
    fmi3GetBinary!(c, vr, nvr, valueSizes, values, nvr)
end
function fmi3GetBinary!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Binary)
    @assert false "fmi3GetBinary! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetBinary(c::FMU3Instance, vr::fmi3ValueReferenceFormat, valueSizes::Union{AbstractArray{Csize_t}, Csize_t}, values::Union{AbstractArray{fmi3Binary}, fmi3Binary})

Set the values of an array of binary variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `valueSizes::Union{AbstractArray{Csize_t}, Csize_t}`: Argument `valueSizes` defines the size of a binary element of each variable.
- `values::Union{AbstractArray{fmi3Binary}, fmi3Binary}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetBinary`](@ref).
"""
function fmi3SetBinary(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    valueSizes::Union{AbstractArray{Csize_t},Csize_t},
    values::Union{AbstractArray{fmi3Binary},fmi3Binary},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    valueSizes = prepareValue(valueSizes)
    @assert length(vr) == length(values) "fmi3SetBinary(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetBinary(c, vr, nvr, valueSizes, values, nvr)
end

"""
    fmi3GetClock(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

Get the values of an array of fmi3Clock variables.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi3Clock}`: returns values of an array of fmi3Clock variables with the dimension of fmi3ValueReferenceFormat length.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetClock`](@ref).
"""
function fmi3GetClock(c::FMU3Instance, vr::fmi3ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = Array{fmi3Clock}(undef, nvr)
    fmi3GetClock!(c, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetClock!`
export fmi3GetClock

"""

    fmi3GetClock!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Clock})

Writes the clock values of an array of variables in the given field

fmi3GetClock! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi3Clock}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3GetClock!`](@ref).
"""
function fmi3GetClock!(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::AbstractArray{fmi3Clock},
)

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi3GetClock!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3GetClock!(c, vr, nvr, values)
    nothing
end
function fmi3GetClock!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::fmi3Clock)
    @assert false "fmi3GetClock! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

    fmi3SetClock(c::FMU3Instance, vr::fmi3ValueReferenceFormat, valueSizes::Union{AbstractArray{Csize_t}, Csize_t}, values::Union{AbstractArray{fmi3Clock}, fmi3Clock})

Set the values of an array of clock variables
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::fmi3ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{AbstractArray{fmi3Clock}, fmi3Clock}`: Argument `values` is an AbstractArray with the actual values of these variables.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values

See also [`fmi3SetClock`](@ref).
"""
function fmi3SetClock(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    values::Union{AbstractArray{fmi3Clock},fmi3Clock},
)

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetClock(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetClock(c, vr, nvr, values)
end

"""

    fmi3GetFMUState(c::FMU3Instance)

Makes a copy of the internal FMU state and returns a pointer to this copy.

# Arguments
 - `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- Return `state` is a pointer to a copy of the internal FMU state.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.6.4. Getting and Setting the Complete FMU State

See also [`fmi3GetFMUState`](@ref).
"""
function fmi3GetFMUState(c::FMU3Instance)
    state = fmi3FMUState()
    stateRef = Ref(state)
    fmi3GetFMUState!(c, stateRef)
    state = stateRef[]
    state
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetFMUState!`
export fmi3GetFMUState

"""
    
    fmi3FreeFMUState!(c::FMU3Instance, state::fmi3FMUState)

Free the allocated memory for the FMU state.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `state::fmi3FMUState`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- Return singleton instance of type `Nothing`, if there is no value to return (as in a C void function) or when a variable or field holds no value.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.6.4. Getting and Setting the Complete FMU State
"""
function fmi3FreeFMUState(c::FMU3Instance, state::fmi3FMUState)
    stateRef = Ref(state)
    fmi3FreeFMUState(c, stateRef)
    state = stateRef[]
end

"""
    
    fmi3SerializedFMUStateSize(c::FMU3Instance, state::fmi3FMUState)

Returns the size of the byte vector in which the FMUstate can be stored.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `state::fmi3FMUState`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- Return `size` is an object that safely references a value of type `Csize_t`.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.6.4. Getting and Setting the Complete FMU State

See also [`fmi3SerializedFMUStateSize`](@ref).
"""
function fmi3SerializedFMUStateSize(c::FMU3Instance, state::fmi3FMUState)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3SerializedFMUStateSize!(c, state, sizeRef)
    size = sizeRef[]
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3SerializedFMUStateSize!`
export fmi3SerializedFMUStateSize

"""
    
    fmi3SerializeFMUState(c::FMU3Instance, state::fmi3FMUState)

Serializes the data referenced by the pointer FMUstate and copies this data into the byte vector serializedState of length size to be provided by the environment.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `state::fmi3FMUState`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- `serializedState:: Array{fmi3Byte}`: Return `serializedState` contains the copy of the serialized data referenced by the pointer FMUstate

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.6.4. Getting and Setting the Complete FMU State

See also [`fmi3SerializeFMUState`](@ref).
"""
function fmi3SerializeFMUState(c::FMU3Instance, state::fmi3FMUState)
    size = fmi3SerializedFMUStateSize(c, state)
    serializedState = Array{fmi3Byte}(undef, size)
    status = fmi3SerializeFMUState!(c, state, serializedState, size)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]
    serializedState
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3SerializeFMUState!`
export fmi3SerializeFMUState

"""
    
fmi3SerializeFMUState(c::FMU3Instance, state::fmi3FMUState)

Serializes the data referenced by the pointer FMUstate and copies this data into the byte vector serializedState of length size to be provided by the environment.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `serializedState::Array{fmi3Byte}`: Argument `serializedState` contains the fmi3Byte field to be deserialized.

# Returns
- Return `state` is a pointer to a copy of the internal FMU state.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.6.4. Getting and Setting the Complete FMU State

See also [`fmi3DeSerializeFMUState`](@ref).
"""
function fmi3DeSerializeFMUState(c::FMU3Instance, serializedState::AbstractArray{fmi3Byte})
    size = length(serializedState)
    state = fmi3FMUState()
    stateRef = Ref(state)

    status = fmi3DeSerializeFMUState!(c, serializedState, Csize_t(size), stateRef)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]

    state = stateRef[]
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3DeSerializeFMUState!`
export fmi3DeSerializeFMUState

"""

    fmi3GetDirectionalDerivative(c::FMU3Instance,
        unknowns::AbstractArray{fmi3ValueReference},
        knowns::AbstractArray{fmi3ValueReference},
        seed::AbstractArray{fmi3Float64})

Wrapper Function call to compute the partial derivative with respect to the variables `unknowns`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3) and Co-Simulation (section 4). In every Mode, the general form of the FMU equations are:
unknowns = 𝐡(knowns, rest)

- `unknowns`: vector of unknown Real variables computed in the actual Mode:
    - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
    - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><ContinuousStateDerivative>)`.
    - Event Mode (ModelExchange/CoSimulation): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
    - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `knowns`: Real input variables of function h that changes its value in the actual Mode.
- `rest`: Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δunknowns = (δh / δknowns) Δknowns

# Arguments
- `c::FMU3Instance` Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `unknowns::AbstracArray{fmi3ValueReference}`: Argument `unknowns` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `unknowns` can be equated with `unknowns`(variable described above).
- `knowns::AbstractArray{fmi3ValueReference}`: Argument `knowns` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`knowns` can be equated with `knowns`(variable described above).
- `seed::AbstractArray{fmi3Float64}`:The vector values Compute the partial derivative with respect to the given entries in vector `knowns` with the matching evaluate of `sensitivity`.

# Returns
- `sensitivity::Array{fmi3Float64}`: Return `sensitivity` contains the directional derivative vector values.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.11. Getting Partial Derivatives

See also [`fmi3GetDirectionalDerivative`](@ref).
"""
function fmi3GetDirectionalDerivative(
    c::FMU3Instance,
    unknowns::AbstractArray{fmi3ValueReference},
    knowns::AbstractArray{fmi3ValueReference},
    seed::AbstractArray{fmi3Float64},
)

    nUnknown = Csize_t(length(unknowns))
    sensitivity = zeros(fmi3Float64, nUnknown)

    status = fmi3GetDirectionalDerivative!(c, unknowns, knowns, seed, sensitivity)
    @assert isStatusOK(c, status) "Failed with status `$(status)`."

    return sensitivity
end
fmi3GetDirectionalDerivative(
    c::FMU3Instance,
    unknown::fmi3ValueReference,
    known::fmi3ValueReference,
    seed::fmi3Float64,
) = fmi3GetDirectionalDerivative(c, [unknown], [known], [seed])[1]
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetDirectionalDerivative!`
export fmi3GetDirectionalDerivative

"""

    fmi3GetDirectionalDerivative!(c::FMU3Instance,
        unknowns::AbstractArray{fmi3ValueReference},
        knowns::AbstractArray{fmi3ValueReference},
        sensitivity::AbstractArray{fmi3Float64},
        seed::AbstractArray{fmi3Float64})

Wrapper Function call to compute the partial derivative with respect to the variables `unknowns`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3) and Co-Simulation (section 4). In every Mode, the general form of the FMU equations are:
unknowns = 𝐡(knowns, rest)

- `unknowns`: vector of unknown Real variables computed in the actual Mode:
    - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
    - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><ContinuousStateDerivative>)`.
    - Event Mode (ModelExchange/CoSimulation): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
    - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `knowns`: Real input variables of function h that changes its value in the actual Mode.
- `rest`: Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δunknowns = (δh / δknowns) Δknowns

# Arguments
- `c::FMU3Instance` Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `unknowns::AbstracArray{fmi3ValueReference}`: Argument `unknowns` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `unknowns` can be equated with `unknowns`(variable described above).
- `knowns::AbstractArray{fmi3ValueReference}`: Argument `knowns` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`knowns` can be equated with `knowns`(variable described above).
- `sensitivity::AbstractArray{fmi3Float64}`: Stores the directional derivative vector values.
- `seed::AbstractArray{fmi3Float64}`:The vector values Compute the partial derivative with respect to the given entries in vector `knowns` with the matching evaluate of `sensitivity`.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.11. Getting Partial Derivatives

See also [`fmi3GetDirectionalDerivative!`](@ref).
"""
function fmi3GetDirectionalDerivative!(
    c::FMU3Instance,
    unknowns::AbstractArray{fmi3ValueReference},
    knowns::AbstractArray{fmi3ValueReference},
    seed::AbstractArray{fmi3Float64},
    sensitivity::AbstractArray{fmi3Float64},
)

    nUnknowns = Csize_t(length(unknowns))
    nKnowns = Csize_t(length(knowns))

    nSeed = Csize_t(length(seed))
    nSensitivity = Csize_t(length(sensitivity))

    status = fmi3GetDirectionalDerivative!(
        c,
        unknowns,
        nUnknowns,
        knowns,
        nKnowns,
        seed,
        nSeed,
        sensitivity,
        nSensitivity,
    )

    return status
end

"""

    fmi3GetAdjointDerivative(c::FMU3Instance,
        unknowns::AbstractArray{fmi3ValueReference},
        knowns::AbstractArray{fmi3ValueReference},
        seed::AbstractArray{fmi3Float64})
Wrapper Function call to compute the partial derivative with respect to the variables `unknowns`.

Computes the adjoint derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3) and Co-Simulation (section 4). In every Mode, the general form of the FMU equations are:
unknowns = 𝐡(knowns, rest)

- `unknowns`: vector of unknown Real variables computed in the actual Mode:
    - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
    - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><ContinuousStateDerivative>)`.
    - Event Mode (ModelExchange/CoSimulation): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
    - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `knowns`: Real input variables of function h that changes its value in the actual Mode.
- `rest`: Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δunknowns = (δh / δknowns) Δknowns

# Arguments
- `c::FMU3Instance` Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `unknowns::AbstracArray{fmi3ValueReference}`: Argument `unknowns` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `unknowns` can be equated with `unknowns`(variable described above).
- `knowns::AbstractArray{fmi3ValueReference}`: Argument `knowns` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`knowns` can be equated with `knowns`(variable described above).
- `seed::AbstractArray{fmi3Float64}`:The vector values Compute the partial derivative with respect to the given entries in vector `knowns` with the matching evaluate of `sensitivity`.

# Returns
- `sensitivity::Array{fmi3Float64}`: Return `sensitivity` contains the directional derivative vector values.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.11. Getting Partial Derivatives

See also [`fmi3GetAdjointDerivative`](@ref).
"""
function fmi3GetAdjointDerivative(
    c::FMU3Instance,
    unknowns::AbstractArray{fmi3ValueReference},
    knowns::AbstractArray{fmi3ValueReference},
    seed::AbstractArray{fmi3Float64},
)

    nUnknown = Csize_t(length(unknowns))
    sensitivity = zeros(fmi3Float64, nUnknown)

    status = fmi3GetAdjointDerivative!(c, unknowns, knowns, seed, sensitivity)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]

    return sensitivity
end
fmi3GetAdjointDerivative(
    c::FMU3Instance,
    unknowns::fmi3ValueReference,
    knowns::fmi3ValueReference,
    seed::fmi3Float64,
) = fmi3GetAdjointDerivative(c, [unknowns], [knowns], [seed])[1]
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetAdjointDerivative!`
export fmi3GetAdjointDerivative

"""

    fmi3GetAdjointDerivative!(c::FMU3Instance,
        unknowns::AbstractArray{fmi3ValueReference},
        knowns::AbstractArray{fmi3ValueReference},
        sensitivity::AbstractArray{fmi3Float64},
        seed::AbstractArray{fmi3Float64})

Wrapper Function call to compute the partial derivative with respect to the variables `unknowns`.

Computes the adjoint derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3) and Co-Simulation (section 4). In every Mode, the general form of the FMU equations are:
unknowns = 𝐡(knowns, rest)

- `unknowns`: vector of unknown Real variables computed in the actual Mode:
    - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
    - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><ContinuousStateDerivative>)`.
    - Event Mode (ModelExchange/CoSimulation): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
    - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `knowns`: Real input variables of function h that changes its value in the actual Mode.
- `rest`: Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δunknowns = (δh / δknowns) Δknowns

# Arguments
- `c::FMU3Instance` Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `unknowns::AbstracArray{fmi3ValueReference}`: Argument `unknowns` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `unknowns` can be equated with `unknowns`(variable described above).
- `knowns::AbstractArray{fmi3ValueReference}`: Argument `knowns` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`knowns` can be equated with `knowns`(variable described above).
- `sensitivity::AbstractArray{fmi3Float64}`: Stores the directional derivative vector values.
- `seed::AbstractArray{fmi3Float64}`:The vector values Compute the partial derivative with respect to the given entries in vector `knowns` with the matching evaluate of `sensitivity`.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.11. Getting Partial Derivatives

See also [`fmi3GetAdjointDerivative!`](@ref).
"""
function fmi3GetAdjointDerivative!(
    c::FMU3Instance,
    unknowns::AbstractArray{fmi3ValueReference},
    knowns::AbstractArray{fmi3ValueReference},
    sensitivity::AbstractArray,
    seed::AbstractArray{fmi3Float64},
)

    nKnowns = Csize_t(length(knowns))
    nUnknowns = Csize_t(length(unknowns))

    nSeed = Csize_t(length(seed))
    nSensitivity = Csize_t(length(sensitivity))

    status = fmi3GetAdjointDerivative!(
        c,
        unknowns,
        nUnknowns,
        knowns,
        nKnowns,
        seed,
        nSeed,
        sensitivity,
        nSensitivity,
    )

    return status
end

"""

fmi3GetOutputDerivatives!(c::FMU3Instance, vr::AbstractArray{fmi3ValueReference}, nValueReferences::Csize_t, order::AbstractArray{fmi3Int32}, values::AbstractArray{fmi3Float64}, nValues::Csize_t)

Retrieves the n-th derivative of output values.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::Array{fmi3ValueReference}`: Argument `vr` is an array of `nValueReferences` value handels called "ValueReference" that t define the variables whose derivatives shall be set.
- `order::Array{fmi3Int32}`: Argument `order` is an array of fmi3Int32 values witch specifys the corresponding order of derivative of the real input variable.

# Returns
- `value::AbstactArray{fmi3Float64}`: Return `value` is an array which represents a vector with the values of the derivatives.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.12. Getting Derivatives of Continuous Outputs

See also [`fmi3GetOutputDerivatives`](@ref).
"""
function fmi3GetOutputDerivatives(
    c::FMU3Instance,
    vr::fmi3ValueReferenceFormat,
    order::AbstractArray{Integer},
)
    vr = prepareValueReference(c, vr)
    order = prepareValue(order)
    nvr = Csize_t(length(vr))
    values = zeros(fmi3Float64, nvr)
    fmi3GetOutputDerivatives!(c, vr, nvr, order, values, nvr)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetOutputDerivatives!`
export fmi3GetOutputDerivatives

"""

    fmi3GetNumberOfContinuousStates(c::FMU3Instance)

This function returns the number of continuous states. This function can only be called in Model Exchange. 
    
`fmi3GetNumberOfContinuousStates` must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
    
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `size::Integer`: Return `size` is the number of continuous states of this instance 

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.2. State: Instantiated

See also [`fmi3GetNumberOfContinuousStates`](@ref).
"""
function fmi3GetNumberOfContinuousStates(c::FMU3Instance)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfContinuousStates!(c, sizeRef) # [ToDo, Refactor] this needs to be inplace/non-allocating!
    size = sizeRef[]
    return Int32(size)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetNumberOfContinuousStates!`
export fmi3GetNumberOfContinuousStates

"""

    fmi3GetNumberOfEventIndicators(c::FMU3Instance)

This function returns the number of event indicators. This function can only be called in Model Exchange. 

`fmi3GetNumberOfEventIndicators` must be called after a structural parameter is changed. As long as no structural parameters changed, the number of states is given in the modelDescription.xml, alleviating the need to call this function.
        
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `size::Integer`: Return `size` is the number of event indicators of this instance 

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.2. State: Instantiated

See also [`fmi3GetNumberOfEventIndicators`](@ref).
"""
function fmi3GetNumberOfEventIndicators(c::FMU3Instance)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfEventIndicators!(c, sizeRef) # [ToDo, Refactor] this needs to be inplace/non-allocating!
    size = sizeRef[]
    return Int32(size)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetNumberOfEventIndicators!`
export fmi3GetNumberOfEventIndicators

"""

    fmi3GetNumberOfVariableDependencies(c::FMU3Instance, vr::fmi3ValueReference, nvr::Ref{Csize_t})

The number of dependencies of a given variable, which may change if structural parameters are changed, can be retrieved by calling fmi3GetNumberOfVariableDependencies.

This information can only be retrieved if the 'providesPerElementDependencies' tag in the ModelDescription is set.

# Arguments
- `c::FMU3Instance`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::Union{fmi3ValueReference, String}`: Argument `vr` is the value handel called "ValueReference" that define the variable that shall be inquired.

# Returns
- `size::Integer`: Return `size` is the number of variable dependencies for the given variable 

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.10. Dependencies of Variables

See also [`fmi3GetNumberOfVariableDependencies`](@ref).
"""
function fmi3GetNumberOfVariableDependencies(
    c::FMU3Instance,
    vr::Union{fmi3ValueReference,String},
)
    if typeof(vr) == String
        vr = fmi3String2ValueReference(c.fmu.modelDescription, vr)
    end
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfVariableDependencies!(c, vr, sizeRef) # [ToDo, Refactor] this needs to be inplace/non-allocating!
    size = sizeRef[]
    Int32(size)
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetNumberOfVariableDependencies!`
export fmi3GetNumberOfVariableDependencies

"""

    fmi3GetVariableDependencies(c::FMU3Instance, vr::Union{fmi3ValueReference, String})

The actual dependencies (of type dependenciesKind) can be retrieved by calling the function fmi3GetVariableDependencies:

# Arguments
- `c::FMU3Instance`: Argument `c` is a Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vr::Union{fmi3ValueReference, String}`: Argument `vr` is the value handel called "ValueReference" that define the variable that shall be inquired.
    
# Returns
- `elementIndicesOfDependent::AbstractArray{Csize_t}`: must point to a buffer of size_t values of size `nDependencies` allocated by the calling environment. 
    It is filled in by this function with the element index of the dependent variable that dependency information is provided for. The element indices start with 1. Using the element index 0 means all elements of the variable. (Note: If an array has more than one dimension the indices are serialized in the same order as defined for values in Section 2.2.6.1.)
- `independents::AbstractArray{fmi3ValueReference}`:  must point to a buffer of `fmi3ValueReference` values of size `nDependencies` allocated by the calling environment. 
    It is filled in by this function with the value reference of the independent variable that this dependency entry is dependent upon.
- `elementIndicesIndependents::AbstractArray{Csize_t}`: must point to a buffer of size_t `values` of size `nDependencies` allocated by the calling environment. 
    It is filled in by this function with the element index of the independent variable that this dependency entry is dependent upon. The element indices start with 1. Using the element index 0 means all elements of the variable. (Note: If an array has more than one dimension the indices are serialized in the same order as defined for values in Section 2.2.6.1.)
- `dependencyKinds::AbstractArray{fmi3DependencyKind}`: must point to a buffer of dependenciesKind values of size `nDependencies` allocated by the calling environment. 
    It is filled in by this function with the enumeration value describing the dependency of this dependency entry.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.10. Dependencies of Variables

See also [`fmi3GetVariableDependencies!`](@ref).
"""
function fmi3GetVariableDependencies(c::FMU3Instance, vr::Union{fmi3ValueReference,String})
    if typeof(vr) == String
        vr = fmi3String2ValueReference(c.fmu.modelDescription, vr)
    end
    nDependencies = fmi3GetNumberOfVariableDependencies(c, vr)
    elementIndiceOfDependents = Array{Csize_t}(undef, nDependencies)
    independents = Array{fmi3ValueReference}(undef, nDependencies)
    elementIndiceOfIndependents = Array{Csize_t}(undef, nDependencies)
    dependencyKinds = Array{fmi3DependencyKind}(undef, nDependencies)

    fmi3GetVariableDependencies!(
        c,
        vr,
        elementIndiceOfDependents,
        independents,
        elementIndiceOfIndependents,
        dependencyKinds,
        nDependencies,
    )

    return elementIndiceOfDependents,
    independents,
    elementIndiceOfIndependents,
    dependencyKinds
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetVariableDependencies!`
export fmi3GetVariableDependencies

"""

    fmi3GetContinuousStates(c::FMU3Instance)

Return the new (continuous) state vector x

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `x::Array{fmi3Float64}`: Returns an array of `fmi3Float64` values representing the new continuous state vector `x`.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.3. State: Initialization Mode

See also [`fmi3GetContinuousStates`](@ref).
"""
function fmi3GetContinuousStates(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    x = zeros(fmi3Float64, nx)
    fmi3GetContinuousStates!(c, x, nx)
    return x
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetContinuousStates!`
export fmi3GetContinuousStates

"""

    fmi3GetNominalsOfContinuousStates(c::FMU3Instance)

Return the nominal values of the continuous states.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `x::Array{fmi3Float64}`: Returns an array of `fmi3Float64` values representing the new nominals of continuous state vector `x`.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.3. State: Initialization Mode

See also [`fmi3GetNominalsOfContinuousStates`](@ref).
"""
function fmi3GetNominalsOfContinuousStates(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    x = zeros(fmi3Float64, nx)
    fmi3GetNominalsOfContinuousStates!(c, x, nx)
    return x
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetNominalsOfContinuousStates!`
export fmi3GetNominalsOfContinuousStates

"""

    fmi3SetTime(c::FMU3Instance, time::Real)

Set a new time instant and re-initialize caching of variables that depend on time, provided the newly provided time value is different to the previously set time value (variables that depend solely on constants or parameters need not to be newly computed in the sequel, but the previously computed values can be reused).

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `t::Real`: Argument `t` contains a value of type `Real` which is a alias type for `Real` data type. `time` sets the independent variable time t.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3SetTime`](@ref)."""
function fmi3SetTime(c::FMU3Instance, t::Real)
    status = fmi3SetTime(c, fmi3Float64(t))
    c.t = t
    return status
end

"""

    fmi3SetContinuousStates(c::FMU3Instance, x::Union{AbstractArray{Float32}, AbstractArray{Float64}})

Set a new (continuous) state vector and re-initialize caching of variables that depend on the states. Argument nx is the length of vector x and is provided for checking purposes

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `x::Union{AbstractArray{Float32},AbstractArray{Float64}}`:Argument `x` is the `AbstractArray` of the vector values of `Float64` or `Float32`.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3SetContinuousStates`](@ref).
"""
function fmi3SetContinuousStates(
    c::FMU3Instance,
    x::Union{AbstractArray{Float32},AbstractArray{Float64}},
)
    nx = Csize_t(length(x))
    status = fmi3SetContinuousStates(c, Array{fmi3Float64}(x), nx)
    if status == fmi3StatusOK
        c.x = x
    end
    return status
end

"""

    fmi3GetContinuousStateDerivatives(c::FMU3Instance)

Compute state derivatives at the current time instant and for the current states.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `derivatives::Array{fmi3Float64}`: Returns an array of `fmi3Float64` values representing the `derivatives` for the current states. The ordering of the elements of the derivatives vector is identical to the ordering of the state
vector.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3GetContinuousStateDerivatives`](@ref).
"""
function fmi3GetContinuousStateDerivatives(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    derivatives = zeros(fmi3Float64, nx)
    fmi3GetContinuousStateDerivatives!(c, derivatives)
    return derivatives
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetContinuousStateDerivatives!`
export fmi3GetContinuousStateDerivatives

"""

    fmi3GetContinuousStateDerivatives!(c::FMU3Instance, derivatives::Array{fmi3Float64})

Compute state derivatives at the current time instant and for the current states.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `derivatives::AbstractArray{fmi3Float64}`: Argument `derivatives` contains values of type `fmi3Float64` which is a alias type for `Real` data type.`derivatives` is the `AbstractArray` which contains the `Real` values of the vector that represent the derivatives. The ordering of the elements of the derivatives vector is identical to the ordering of the state vector.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3GetContinuousStateDerivatives!`](@ref).
"""
function fmi3GetContinuousStateDerivatives!(
    c::FMU3Instance,
    derivatives::AbstractArray{fmi3Float64},
)
    status =
        fmi3GetContinuousStateDerivatives!(c, derivatives, Csize_t(length(derivatives)))
    if status == fmi3StatusOK
        c.ẋ = derivatives
    end
    return status
end

"""
    fmi3UpdateDiscreteStates(c::FMU3Instance)

This function is called to signal a converged solution at the current super-dense time instant. fmi3UpdateDiscreteStates must be called at least once per super-dense time instant.
Results are returned, use `fmi3UpdateDiscreteStates!` for the inplace variant.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `discreteStatesNeedUpdate`
- `terminateSimulation`
- `nominalsOfContinuousStatesChanged`
- `valuesOfContinuousStatesChanged`
- `nextEventTimeDefined`
- `nextEventTime`

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.5. State: Event Mode

"""
function fmi3UpdateDiscreteStates(c::FMU3Instance)

    discreteStatesNeedUpdate = fmi3True
    terminateSimulation = fmi3True
    nominalsOfContinuousStatesChanged = fmi3True
    valuesOfContinuousStatesChanged = fmi3True
    nextEventTimeDefined = fmi3True
    nextEventTime = fmi3Float64(1.0)
    refdS = Ref(discreteStatesNeedUpdate)
    reftS = Ref(terminateSimulation)
    refnOCS = Ref(nominalsOfContinuousStatesChanged)
    refvOCS = Ref(valuesOfContinuousStatesChanged)
    refnETD = Ref(nextEventTimeDefined)
    refnET = Ref(nextEventTime)

    fmi3UpdateDiscreteStates(c, refdS, reftS, refnOCS, refvOCS, refnETD, refnET)

    discreteStatesNeedUpdate = refdS[]
    terminateSimulation = reftS[]
    nominalsOfContinuousStatesChanged = refnOCS[]
    valuesOfContinuousStatesChanged = refvOCS[]
    nextEventTimeDefined = refnETD[]
    nextEventTime = refnET[]

    discreteStatesNeedUpdate,
    terminateSimulation,
    nominalsOfContinuousStatesChanged,
    valuesOfContinuousStatesChanged,
    nextEventTimeDefined,
    nextEventTime
end

"""
    fmi3UpdateDiscreteStates!(c::FMU3Instance)

This function is called to signal a converged solution at the current super-dense time instant. fmi3UpdateDiscreteStates must be called at least once per super-dense time instant.
Results are returned, use `fmi3UpdateDiscreteStates` for the out-of-place variant.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `fmi3Status`

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.3.5. State: Event Mode
"""
function fmi3UpdateDiscreteStates!(c::FMU3Instance)

    status = fmi3UpdateDiscreteStates(
        c,
        c._ptr_discreteStatesNeedUpdate,
        c._ptr_terminateSimulation,
        c._ptr_nominalsOfContinuousStatesChanged,
        c._ptr_valuesOfContinuousStatesChanged,
        c._ptr_nextEventTimeDefined,
        c._ptr_nextEventTime,
    )

    return status
end

"""

    fmi3GetEventIndicators(c::FMU3Instance)

Returns the event indicators of the FMU

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.

# Returns
- `eventIndicators::Array{fmi3Float64}`:The event indicators are returned as a vector represented by an array of "fmi3Float64" values.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3GetEventIndicators`](@ref).
"""
function fmi3GetEventIndicators(c::FMU3Instance)
    ni = Csize_t(c.fmu.modelDescription.numberOfEventIndicators)
    eventIndicators = zeros(fmi3Float64, ni)
    fmi3GetEventIndicators!(c, eventIndicators, ni)
    return eventIndicators
end
# [NOTE] needs to be exported, because FMICore only exports `fmi3GetEventIndicators!`
export fmi3GetEventIndicators

"""

    fmi3CompletedIntegratorStep!(c::FMU3Instance, noSetFMUStatePriorToCurrentPoint::fmi3Boolean)

This function must be called by the environment after every completed step

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `noSetFMUStatePriorToCurrentPoint::fmi3Boolean`: Argument `noSetFMUStatePriorToCurrentPoint = fmi3True` if `fmi3SetFMUState`  will no longer be called for time instants prior to current time in this simulation run.

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably
- `enterEventMode::Array{fmi3Boolean, 1}`: Returns `enterEventMode[1]` to signal to the environment if the FMU shall call `fmi2EnterEventMode`
- `terminateSimulation::Array{fmi3Boolean, 1}`: Returns `terminateSimulation[1]` to signal if the simulation shall be terminated.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3CompletedIntegratorStep`](@ref).
"""
function fmi3CompletedIntegratorStep(
    c::FMU3Instance,
    noSetFMUStatePriorToCurrentPoint::fmi3Boolean,
)

    status = fmi3CompletedIntegratorStep!(
        c,
        noSetFMUStatePriorToCurrentPoint,
        c._ptr_enterEventMode,
        c._ptr_terminateSimulation,
    )

    return (status, c.enterEventMode, c.terminateSimulation)
end

"""

    fmi3EnterEventMode(c::FMU3Instance, stepEvent::Bool, stateEvent::Bool, rootsFound::AbstractArray{fmi3Int32}, nEventIndicators::Csize_t, timeEvent::Bool)

The model enters Event Mode from the Continuous-Time Mode in ModelExchange oder Step Mode in CoSimulation and discrete-time equations may become active (and relations are not “frozen”).

# TODO argmuents
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `stepEvent::Bool`:  
- `stateEvent::Bool`: 
- `rootsFound::AbstractArray{fmi3Int32}`: 
- `nEventIndicators::Csize_t`: 
- `timeEvent::Bool`: 

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 3.2.1. State: Continuous-Time Mode

See also [`fmi3EnterEventMode`](@ref).
"""
function fmi3EnterEventMode(
    c::FMU3Instance,
    stepEvent::Bool,
    stateEvent::Bool,
    rootsFound::AbstractArray{fmi3Int32},
    nEventIndicators::Csize_t,
    timeEvent::Bool,
)
    fmi3EnterEventMode(
        c,
        fmi3Boolean(stepEvent),
        fmi3Boolean(stateEvent),
        rootsFound,
        nEventIndicators,
        fmi3Boolean(timeEvent),
    )
end

"""
    fmi3DoStep!(c::FMU3Instance, currentCommunicationPoint::Union{Real, Nothing} = nothing, communicationStepSize::Union{Real, Nothing} = nothing, noSetFMUStatePriorToCurrentPoint::Bool = true,
        eventEncountered::fmi3Boolean = fmi3False, terminateSimulation::fmi3Boolean = fmi3False, earlyReturn::fmi3Boolean = fmi3False, lastSuccessfulTime::fmi3Float64 = 0.0)

The computation of a time step is started.

# TODO argmuents
# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `currentCommunicationPoint::Union{Real, Nothing} = nothing`
- `communicationStepSize::Union{Real, Nothing} = nothing`
- `noSetFMUStatePriorToCurrentPoint::Bool = true`
- `eventEncountered::fmi3Boolean = fmi3False`
- `terminateSimulation::fmi3Boolean = fmi3False`
- `earlyReturn::fmi3Boolean = fmi3False`
- `lastSuccessfulTime::fmi3Float64 = 0.0`

# Returns
- `status::fmi3Status`: Return `status` is an enumeration of type `fmi3Status` and indicates the success of the function call.
More detailed:
- `fmi3OK`: all well
- `fmi3Warning`: things are not quite right, but the computation can continue
- `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
- `fmi3Error`: the communication step could not be carried out at all
- `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 4.2.1. State: Step Mode

See also [`fmi3DoStep!`](@ref).
"""
function fmi3DoStep!(
    c::FMU3Instance,
    currentCommunicationPoint::Union{Real,Nothing} = nothing,
    communicationStepSize::Union{Real,Nothing} = nothing,
    noSetFMUStatePriorToCurrentPoint::Bool = true,
    eventEncountered::fmi3Boolean = fmi3False,
    terminateSimulation::fmi3Boolean = fmi3False,
    earlyReturn::fmi3Boolean = fmi3False,
    lastSuccessfulTime::fmi3Float64 = 0.0,
)

    if currentCommunicationPoint === nothing
        currentCommunicationPoint = c.t
    end

    if communicationStepSize === nothing
        communicationStepSize = fmi3GetDefaultStepSize(c.fmu.modelDescription)
        if communicationStepSize === nothing
            communicationStepSize = 1e-2
        end
    end

    refeventEncountered = Ref(eventEncountered)
    refterminateSimulation = Ref(terminateSimulation)
    refearlyReturn = Ref(earlyReturn)
    reflastSuccessfulTime = Ref(lastSuccessfulTime)

    c.t = currentCommunicationPoint
    status = fmi3DoStep!(
        c,
        fmi3Float64(currentCommunicationPoint),
        fmi3Float64(communicationStepSize),
        fmi3Boolean(noSetFMUStatePriorToCurrentPoint),
        refeventEncountered,
        refterminateSimulation,
        refearlyReturn,
        reflastSuccessfulTime,
    )
    c.t += communicationStepSize

    eventEncountered = refeventEncountered[]
    terminateSimulation = refterminateSimulation[]
    earlyReturn = refearlyReturn[]
    lastSuccessfulTime = reflastSuccessfulTime[]

    return status
end
