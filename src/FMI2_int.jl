#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_int.jl` (internal functions)?
# - optional, more comfortable calls to the C-functions from the FMI-spec (example: `fmiGetReal!(c, v, a)` is bulky, `a = fmiGetReal(c, v)` is more user friendly)

"""
TODO: FMI specification reference.

Returns a string representing the header file used to compile the FMU.

Returns "default" by default.

For more information call ?fmi2GetTypesPlatform
"""
# this is basically already defined in FMI2_c.jl

"""
TODO: FMI specification reference.

Returns the version of the FMI Standard used in this FMU.

For more information call ?fmi2GetVersion
"""
# this is basically already defined in FMI2_c.jl

"""
TODO: FMI specification reference.

Set the DebugLogger for the FMU.
"""
function fmi2SetDebugLogging(c::FMU2Component)
    fmi2SetDebugLogging(c.fmu, c.compAddr, fmi2False, Unsigned(0), C_NULL)
end

"""
TODO: FMI specification reference.

Setup the simulation but without defining all of the parameters.

For more information call ?fmi2SetupExperiment (#ToDo endless recursion)
"""
function fmi2SetupExperiment(c::FMU2Component, startTime::Union{Real, Nothing} = nothing, stopTime::Union{Real, Nothing} = nothing; tolerance::Union{Real, Nothing} = nothing)

    if startTime == nothing
        startTime = fmi2GetDefaultStartTime(c.fmu.modelDescription)
        if startTime == nothing 
            startTime = 0.0
        end
    end

    # default stopTime is set automatically if doing nothing
    # if stopTime == nothing
    #     stopTime = fmi2GetDefaultStopTime(c.fmu.modelDescription)
    # end

    # default tolerance is set automatically if doing nothing
    # if tolerance == nothing
    #     tolerance = fmi2GetDefaultTolerance(c.fmu.modelDescription)
    # end

    c.t = startTime

    toleranceDefined = (tolerance != nothing)
    if !toleranceDefined
        tolerance = 0.0 # dummy value, will be ignored
    end 

    stopTimeDefined = (stopTime != nothing)
    if !stopTimeDefined
        stopTime = 0.0 # dummy value, will be ignored
    end

    fmi2SetupExperiment(c, fmi2Boolean(toleranceDefined), fmi2Real(tolerance), fmi2Real(startTime), fmi2Boolean(stopTimeDefined), fmi2Real(stopTime))
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Real variables.

For more information call ?fmi2GetReal!
"""
function fmi2GetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi2Real, nvr)
    fmi2GetReal!(c.fmu.cGetReal, c.compAddr, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Real variables.

For more information call ?fmi2GetReal!
"""
function fmi2GetReal!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Array{fmi2Real})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetReal!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    # values[:] = fmi2Real.(values)
    fmi2GetReal!(c.fmu.cGetReal, c.compAddr, vr, nvr, values)
    nothing
end
function fmi2GetReal!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Real)
    @assert false "fmi2GetReal! is only possible for arrays of values, please use an array instead of a scalar."
end

"""
TODO: FMI specification reference.

Set the values of an array of fmi2Real variables.

For more information call ?fmi2SetReal
"""
function fmi2SetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{Array{<:Real}, <:Real})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetReal(...): `vr` ($(length(vr))) and `values` ($(length(values))) need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetReal(c.fmu.cSetReal, c.compAddr, vr, nvr, Array{fmi2Real}(values))
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Integer variables.

For more information call ?fmi2GetInteger!
"""
function fmi2GetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi2Integer, nvr)
    fmi2GetInteger!(c.fmu.cGetInteger, c.compAddr, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Integer variables.

For more information call ?fmi2GetInteger!
"""
function fmi2GetInteger!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Array{fmi2Integer})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetInteger!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi2GetInteger!(c.fmu.cGetInteger, c.compAddr, vr, nvr, values)
    nothing
end
function fmi2GetInteger!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Integer)
    @assert false "fmi2GetInteger! is only possible for arrays of values, please use an array instead of a scalar."
end

"""
TODO: FMI specification reference.

Set the values of an array of fmi2Integer variables.

For more information call ?fmi2SetInteger
"""
function fmi2SetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{Array{<:Integer}, <:Integer})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetInteger(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetInteger(c.fmu.cSetInteger, c.compAddr, vr, nvr, Array{fmi2Integer}(values))
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Boolean variables.

For more information call ?fmi2GetBoolean!
"""
function fmi2GetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = Array{fmi2Boolean}(undef, nvr)
    fmi2GetBoolean!(c.fmu.cGetBoolean, c.compAddr, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2Boolean variables.

For more information call ?fmi2GetBoolean!
"""
function fmi2GetBoolean!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Array{fmi2Boolean})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetBoolean!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    #values = fmi2Boolean.(values)
    fmi2GetBoolean!(c.fmu.cGetBoolean, c.compAddr, vr, nvr, values)

    nothing
end
function fmi2GetBoolean!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Bool)
    @assert false "fmi2GetBoolean! is only possible for arrays of values, please use an array instead of a scalar."
end

"""
TODO: FMI specification reference.

Set the values of an array of fmi2Boolean variables.

For more information call ?fmi2SetBoolean
"""
function fmi2SetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{Array{Bool}, Bool})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetBoolean(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetBoolean(c.fmu.cSetBoolean, c.compAddr, vr, nvr, Array{fmi2Boolean}(values))
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2String variables.

For more information call ?fmi2GetString!
"""
function fmi2GetString(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    vars = Vector{fmi2String}(undef, nvr)
    values = string.(zeros(nvr))
    fmi2GetString!(c.fmu.cGetString, c.compAddr, vr, nvr, vars)
    values[:] = unsafe_string.(vars)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""
TODO: FMI specification reference.

Get the values of an array of fmi2String variables.

For more information call ?fmi2GetString!
"""
function fmi2GetString!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Array{fmi2String})

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi2GetString!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2GetString!(c.fmu.cGetString, c.compAddr, vr, nvr, values)
    
    nothing
end
function fmi2GetString!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::String)
    @assert false "fmi2GetString! is only possible for arrays of values, please use an array instead of a scalar."
end

"""
TODO: FMI specification reference.

Set the values of an array of fmi2String variables.

For more information call ?fmi2SetString
"""
function fmi2SetString(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{Array{String}, String})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetReal(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    ptrs = pointer.(values)
    fmi2SetString(c.fmu.cSetString, c.compAddr, vr, nvr, ptrs)
end

"""
TODO: FMI specification reference.

Get the pointer to the current FMU state.

For more information call ?fmi2GetFMUstate
"""
function fmi2GetFMUstate(c::FMU2Component)
    state = fmi2FMUstate()
    stateRef = Ref(state)
    fmi2GetFMUstate!(c.fmu.cGetFMUstate, c.compAddr, stateRef)
    state = stateRef[]
    state
end

"""
TODO: FMI specification reference.

Free the allocated memory for the FMU state.

For more information call ?fmi2FreeFMUstate
"""
function fmi2FreeFMUstate!(c::FMU2Component, state::fmi2FMUstate)
    stateRef = Ref(state)
    fmi2FreeFMUstate!(c.fmu.cFreeFMUstate, c.compAddr, stateRef)
    state = stateRef[]
    return nothing 
end

"""
TODO: FMI specification reference.

Returns the size of a byte vector the FMU can be stored in.

For more information call ?fmi2SerzializedFMUstateSize
"""
function fmi2SerializedFMUstateSize(c::FMU2Component, state::fmi2FMUstate)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi2SerializedFMUstateSize!(c.fmu.cSerializedFMUstateSize, c.compAddr, state, sizeRef)
    size = sizeRef[]
end

"""
TODO: FMI specification reference.

Serialize the data in the FMU state pointer.

For more information call ?fmi2SerzializeFMUstate
"""
function fmi2SerializeFMUstate(c::FMU2Component, state::fmi2FMUstate)
    size = fmi2SerializedFMUstateSize(c, state)
    serializedState = Array{fmi2Byte}(undef, size)
    status = fmi2SerializeFMUstate!(c.fmu.cSerializeFMUstate, c.compAddr, state, serializedState, size)
    @assert status == Int(fmi2StatusOK) ["Failed with status `$status`."]
    serializedState
end

"""
TODO: FMI specification reference.

Deserialize the data in the serializedState fmi2Byte field.

For more information call ?fmi2DeSerzializeFMUstate
"""
function fmi2DeSerializeFMUstate(c::FMU2Component, serializedState::Array{fmi2Byte})
    size = length(serializedState)
    state = fmi2FMUstate()
    stateRef = Ref(state)

    status = fmi2DeSerializeFMUstate!(c.fmu.cDeSerializeFMUstate, c.compAddr, serializedState, Csize_t(size), stateRef)
    @assert status == Int(fmi2StatusOK) "Failed with status `$status`."

    state = stateRef[]
end

"""
TODO: FMI specification reference.

Computes directional derivatives.

For more information call ?fmi2GetDirectionalDerivatives
"""
function fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::Array{fmi2ValueReference},
                                      vKnown_ref::Array{fmi2ValueReference},
                                      dvKnown::Union{Array{fmi2Real}, Nothing} = nothing)
                                      
    nUnknown = Csize_t(length(vUnknown_ref))     

    dvUnknown = zeros(fmi2Real, nUnknown)
    status = fmi2GetDirectionalDerivative!(c, vUnknown_ref, vKnown_ref, dvUnknown, dvKnown)
    @assert status == fmi2StatusOK ["Failed with status `$status`."]

    return dvUnknown
end

"""
TODO: FMI specification reference.

Computes directional derivatives.

For more information call ?fmi2GetDirectionalDerivatives
"""
function fmi2GetDirectionalDerivative!(c::FMU2Component,
                                      vUnknown_ref::Array{fmi2ValueReference},
                                      vKnown_ref::Array{fmi2ValueReference},
                                      dvUnknown::AbstractArray, 
                                      dvKnown::Union{Array{fmi2Real}, Nothing} = nothing)

    nKnown = Csize_t(length(vKnown_ref))
    nUnknown = Csize_t(length(vUnknown_ref))

    if dvKnown == nothing
        dvKnown = ones(fmi2Real, nKnown)
    end

    status = fmi2GetDirectionalDerivative!(c.fmu.cGetDirectionalDerivative, c.compAddr, vUnknown_ref, nUnknown, vKnown_ref, nKnown, dvKnown, dvUnknown)

    return status
end

"""
TODO: FMI specification reference.

Computes directional derivatives.

For more information call ?fmi2GetDirectionalDerivatives
"""
function fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::fmi2ValueReference,
                                      vKnown_ref::fmi2ValueReference,
                                      dvKnown::fmi2Real = 1.0)

    fmi2GetDirectionalDerivative(c, [vUnknown_ref], [vKnown_ref], [dvKnown])[1]
end

# CoSimulation specific functions
"""
TODO: FMI specification reference.

Sets the n-th time derivative of real input variables.
vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables
"""
function fmi2SetRealInputDerivatives(c::FMU2Component, vr::fmi2ValueReferenceFormat, order, values)
    vr = prepareValueReference(c, vr)
    order = prepareValue(order)
    values = prepareValue(values)
    nvr = Csize_t(length(vr))
    fmi2SetRealInputDerivatives(c.fmu.cSetRealInputDerivatives, c.compAddr, vr, nvr, Array{fmi2Integer}(order), Array{fmi2Real}(values))
end

"""
TODO: FMI specification reference.

vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables

For more information call ?fmi2GetRealOutputDerivatives
"""
function fmi2GetRealOutputDerivatives(c::FMU2Component, vr::fmi2ValueReferenceFormat, order)
    vr = prepareValueReference(c, vr)
    order = prepareValue(order)
    nvr = Csize_t(length(vr))
    values = zeros(fmi2Real, nvr)
    fmi2GetRealOutputDerivatives!(c.fmu.cGetRealOutputDerivatives, c.compAddr, vr, nvr, Array{fmi2Integer}(order), values)
    
    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""
TODO: FMI specification reference.

The computation of a time step is started.

For more information call ?fmi2DoStep
"""
function fmi2DoStep(c::FMU2Component, communicationStepSize::Union{Real, Nothing} = nothing; currentCommunicationPoint::Union{Real, Nothing} = nothing, noSetFMUStatePriorToCurrentPoint::Bool = true)

    # skip `fmi2DoStep` if this is set (allows evaluation of a CS_NeuralFMUs at t_0)
    if c.skipNextDoStep
        c.skipNextDoStep = false
        return fmi2StatusOK
    end

    if currentCommunicationPoint == nothing 
        currentCommunicationPoint = c.t 
    end
    
    if communicationStepSize == nothing
        communicationStepSize = fmi2GetDefaultStepSize(c.fmu.modelDescription)
        if communicationStepSize == nothing
            communicationStepSize = 1e-2 
        end 
    end

    c.t = currentCommunicationPoint
    status = fmi2DoStep(c.fmu.cDoStep, c.compAddr, fmi2Real(currentCommunicationPoint), fmi2Real(communicationStepSize), fmi2Boolean(noSetFMUStatePriorToCurrentPoint))
    c.t += communicationStepSize

    return status
end

"""
TODO: FMI specification reference.
"""
function fmi2SetTime(c::FMU2Component, t::Real)
    status = fmi2SetTime(c.fmu.cSetTime, c.compAddr, fmi2Real(t))
    c.t = t 
    return status
end 

# Model Exchange specific functions

"""
TODO: FMI specification reference.

Set a new (continuous) state vector and reinitialize chaching of variables that depend on states.

For more information call ?fmi2SetContinuousStates
"""
function fmi2SetContinuousStates(c::FMU2Component, x::Union{Array{Float32}, Array{Float64}})
    nx = Csize_t(length(x))
    status = fmi2SetContinuousStates(c.fmu.cSetContinuousStates, c.compAddr, Array{fmi2Real}(x), nx)
    if status == fmi2StatusOK
        c.x = x
    end 
    return status
end

"""
TODO: FMI specification reference.

Increment the super dense time in event mode.

For more information call ?fmi2NewDiscretestates
"""
function fmi2NewDiscreteStates(c::FMU2Component)
    eventInfo = fmi2EventInfo()
    fmi2NewDiscreteStates!(c, eventInfo)
    eventInfo
end

"""
TODO: FMI specification reference.

This function must be called by the environment after every completed step
If enterEventMode == fmi2True, the event mode must be entered
If terminateSimulation == fmi2True, the simulation shall be terminated

For more information call ?fmi2CompletedIntegratorStep
"""
function fmi2CompletedIntegratorStep(c::FMU2Component,
                                     noSetFMUStatePriorToCurrentPoint::fmi2Boolean)
    enterEventMode = zeros(fmi2Boolean, 1)
    terminateSimulation = zeros(fmi2Boolean, 1)

    status = fmi2CompletedIntegratorStep!(c.fmu.cCompletedIntegratorStep,
                                          c.compAddr, 
                                          noSetFMUStatePriorToCurrentPoint,
                                          pointer(enterEventMode),
                                          pointer(terminateSimulation))

    return (status, enterEventMode[1], terminateSimulation[1])
end

"""
TODO: FMI specification reference.

Compute state derivatives at the current time instant and for the current states.

For more information call ?fmi2GetDerivatives
"""
function fmi2GetDerivatives(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    derivatives = zeros(fmi2Real, nx)
    fmi2GetDerivatives!(c, derivatives)
    return derivatives
end

"""
TODO: FMI specification reference.

Compute state derivatives at the current time instant and for the current states.

For more information call ?fmi2GetDerivatives
"""
function fmi2GetDerivatives!(c::FMU2Component, derivatives::Array{fmi2Real})
    status = fmi2GetDerivatives!(c, derivatives, Csize_t(length(derivatives)))
    if status == fmi2StatusOK
        c.ẋ = derivatives
    end 
    return status
end

"""
TODO: FMI specification reference.

Returns the event indicators of the FMU.

For more information call ?fmi2GetEventIndicators
"""
function fmi2GetEventIndicators(c::FMU2Component)
    ni = Csize_t(c.fmu.modelDescription.numberOfEventIndicators)
    eventIndicators = zeros(fmi2Real, ni)
    fmi2GetEventIndicators!(c, eventIndicators)
    return eventIndicators
end

"""
TODO: FMI specification reference.

Returns the event indicators of the FMU.

For more information call ?fmi2GetEventIndicators
"""
function fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::Union{SubArray{fmi2Real}, Vector{fmi2Real}})
    ni = Csize_t(length(eventIndicators))
    fmi2GetEventIndicators!(c.fmu.cGetEventIndicators, c.compAddr, eventIndicators, ni)
end

"""
TODO: FMI specification reference.

Return the new (continuous) state vector x.

For more information call ?fmi2GetContinuousStates
"""
function fmi2GetContinuousStates(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    x = zeros(fmi2Real, nx)
    fmi2GetContinuousStates!(c.fmu.cGetContinuousStates, c.compAddr, x, nx)
    x
end

"""
TODO: FMI specification reference.

Return the new (continuous) state vector x.

For more information call ?fmi2GetNominalsOfContinuousStates
"""
function fmi2GetNominalsOfContinuousStates(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    x = zeros(fmi2Real, nx)
    fmi2GetNominalsOfContinuousStates!(c.fmu.cGetNominalsOfContinuousStates, c.compAddr, x, nx)
    x
end

""" 
ToDo 
"""
function fmi2GetStatus(c::FMU2Component, s::fmi2StatusKind)
    rtype = nothing
    if s == fmi2Terminated
        rtype = fmi2Boolean
    else 
        @assert false "fmi2GetStatus(_, $(s)): StatusKind $(s) not implemented yet, please open an issue."
    end
    value = zeros(rtype, 1)

    status = fmi2Error
    if rtype == fmi2Boolean
        status = fmi2GetStatus!(c.fmu.cGetStatus, c.compAddr, s, value)
    end 

    status, value[1]
end
