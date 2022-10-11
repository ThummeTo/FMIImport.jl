# STATUS: todos include moving sampleDerivative function
# ABM: done

#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_int.jl` (internal functions)?
# - optional, more comfortable calls to the C-functions from the FMI-spec (example: `fmiGetReal!(c, v, a)` is bulky, `a = fmiGetReal(c, v)` is more user friendly)

# Best practices:
# - no direct access on C-pointers (`compAddr`), use existing FMICore-functions

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.1. Super State: FMU State Setable

Set the DebugLogger for the FMU.
"""
function fmi3SetDebugLogging(c::FMU3Instance)
    fmi3SetDebugLogging(c, fmi3False, Unsigned(0), C_NULL)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

FMU enters Initialization mode.

For more information call ?fmi3EnterInitializationMode
"""
function fmi3EnterInitializationMode(c::FMU3Instance, startTime::Union{Real, Nothing} = nothing, stopTime::Union{Real, Nothing} = nothing; tolerance::Union{Real, Nothing} = nothing)
    if c.state != fmi3InstanceStateInstantiated
        @warn "fmi3EnterInitializationMode(...): Needs to be called in state `fmi3IntanceStateInstantiated`."
    end

    if startTime === nothing
        startTime = fmi3GetDefaultStartTime(c.fmu.modelDescription)
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

    status = fmi3EnterInitializationMode(c.fmu.cEnterInitializationMode, c.compAddr, fmi3Boolean(toleranceDefined), fmi3Float64(tolerance), fmi3Float64(startTime), fmi3Boolean(stopTimeDefined), fmi3Float64(stopTime))
    checkStatus(c, status)
    if status == fmi3StatusOK
        c.state = fmi3InstanceStateInitializationMode
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Float32 variables.

For more information call ?fmi3GetFloat32
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Float32 variables.

For more information call ?fmi3GetFloat32!
"""
function fmi3GetFloat32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Float32})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Float32 variables.

For more information call ?fmi3SetFloat32
"""
function fmi3SetFloat32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Float32}, fmi3Float32})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetFloat32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetFloat32(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Float64 variables.

For more information call ?fmi3GetFloat64
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Float64 variables.

For more information call ?fmi3GetFloat64!
"""
function fmi3GetFloat64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Float64})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Float64 variables.

For more information call ?fmi3SetFloat64
"""
function fmi3SetFloat64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Float64}, fmi3Float64})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetFloat64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetFloat64(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int8 variables.

For more information call ?fmi3GetInt8
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int8 variables.

For more information call ?fmi3GetInt8!
"""
function fmi3GetInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int8})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Int8 variables.

For more information call ?fmi3SetInt8
"""
function fmi3SetInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int8}, fmi3Int8})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt8(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt8(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt8 variables.

For more information call ?fmi3GetUInt8
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt8 variables.

For more information call ?fmi3GetUInt8!
"""
function fmi3GetUInt8!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt8})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3UInt8 variables.

For more information call ?fmi3SetUInt8
"""
function fmi3SetUInt8(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt8}, fmi3UInt8})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt8(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt8(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int16 variables.

For more information call ?fmi3GetInt16
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int16 variables.

For more information call ?fmi3GetInt16!
"""
function fmi3GetInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int16})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Int16 variables.

For more information call ?fmi3SetInt16
"""
function fmi3SetInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int16}, fmi3Int16})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt16(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt16(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt16 variables.

For more information call ?fmi3GetUInt16
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt16 variables.

For more information call ?fmi3GetUInt16!
"""
function fmi3GetUInt16!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt16})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3UInt16 variables.

For more information call ?fmi3SetUInt16
"""
function fmi3SetUInt16(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt16}, fmi3UInt16})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt16(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt16(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int32 variables.

For more information call ?fmi3GetInt32
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int32 variables.

For more information call ?fmi3GetInt32!
"""
function fmi3GetInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int32})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Int32 variables.

For more information call ?fmi3SetInt32
"""
function fmi3SetInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int32}, fmi3Int32})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt32(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt32 variables.

For more information call ?fmi3GetUInt32
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt32 variables.

For more information call ?fmi3GetUInt32!
"""
function fmi3GetUInt32!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt32})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3UInt32 variables.

For more information call ?fmi3SetUInt32
"""
function fmi3SetUInt32(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt32}, fmi3UInt32})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt32(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt32(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int64 variables.

For more information call ?fmi3GetInt64
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Int64 variables.

For more information call ?fmi3GetInt64!
"""
function fmi3GetInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Int64})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Int64 variables.

For more information call ?fmi3SetInt64
"""
function fmi3SetInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Int64}, fmi3Int64})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetInt64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetInt64(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt64 variables.

For more information call ?fmi3GetUInt64
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3UInt64 variables.

For more information call ?fmi3GetUInt64!
"""
function fmi3GetUInt64!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3UInt64})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3UInt64 variables.

For more information call ?fmi3SetUInt64
"""
function fmi3SetUInt64(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3UInt64}, fmi3UInt64})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetUInt64(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetUInt64(c, vr, nvr, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Boolean variables.

For more information call ?fmi3GetBoolean
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Boolean variables.

For more information call ?fmi3GetBoolean!
"""
function fmi3GetBoolean!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Boolean})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Boolean variables.

For more information call ?fmi3SetBoolean
"""
function fmi3SetBoolean(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{Bool}, Bool})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetBoolean(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetBoolean(c, vr, nvr, Array{fmi3Boolean}(values), nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3String variables.

For more information call ?fmi3GetString
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3String variables.

For more information call ?fmi3GetString!
"""
function fmi3GetString!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3String})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3String variables.

For more information call ?fmi3SetString
"""
function fmi3SetString(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{String}, String})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetString(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    ptrs = pointer.(values)
    fmi3SetString(c, vr, nvr, ptrs, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Binary variables.

For more information call ?fmi3GetBinary
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Binary variables.

For more information call ?fmi3GetBinary!
"""
function fmi3GetBinary!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Binary})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Binary variables.

For more information call ?fmi3SetBinary
"""
function fmi3SetBinary(c::FMU3Instance, vr::fmi3ValueReferenceFormat, valueSizes::Union{AbstractArray{Csize_t}, Csize_t}, values::Union{AbstractArray{fmi3Binary}, fmi3Binary})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    valueSizes = prepareValue(valueSizes)
    @assert length(vr) == length(values) "fmi3SetBinary(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetBinary(c, vr, nvr, valueSizes, values, nvr)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Clock variables.

For more information call ?fmi3GetClock
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Get the values of an array of fmi3Clock variables.

For more information call ?fmi3GetClock!
"""
function fmi3GetClock!(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::AbstractArray{fmi3Clock})

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
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.2. Getting and Setting Variable Values

Set the values of an array of fmi3Clock variables.

For more information call ?fmi3SetClock
"""
function fmi3SetClock(c::FMU3Instance, vr::fmi3ValueReferenceFormat, values::Union{AbstractArray{fmi3Clock}, fmi3Clock})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi3SetClock(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi3SetClock(c, vr, nvr, values)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

Get the pointer to the current FMU state.

For more information call ?fmi3GetFMUstate
"""
function fmi3GetFMUState(c::FMU3Instance)
    state = fmi3FMUState()
    stateRef = Ref(state)
    fmi3GetFMUState!(c, stateRef)
    state = stateRef[]
    state
end

"""
function fmi3FreeFMUState(c::FMU3Instance, FMUstate::Ref{fmi3FMUState})

Free the allocated memory for the FMU state.

For more information call ?fmi3FreeFMUstate
"""
function fmi3FreeFMUState!(c::FMU3Instance, state::fmi3FMUState)
    stateRef = Ref(state)
    fmi3FreeFMUState!(c, stateRef)
    state = stateRef[]
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

Returns the size of a byte vector the FMU can be stored in.

For more information call ?fmi3SerzializedFMUstateSize
"""
function fmi3SerializedFMUStateSize(c::FMU3Instance, state::fmi3FMUState)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3SerializedFMUStateSize!(c, state, sizeRef)
    size = sizeRef[]
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

Serialize the data in the FMU state pointer.

For more information call ?fmi3SerzializeFMUstate
"""
function fmi3SerializeFMUState(c::FMU3Instance, state::fmi3FMUState)
    size = fmi3SerializedFMUStateSize(c, state)
    serializedState = Array{fmi3Byte}(undef, size)
    status = fmi3SerializeFMUState!(c, state, serializedState, size)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]
    serializedState
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.6.4. Getting and Setting the Complete FMU State

Deserialize the data in the serializedState fmi3Byte field.

For more information call ?fmi3DeSerzializeFMUstate
"""
function fmi3DeSerializeFMUState(c::FMU3Instance, serializedState::AbstractArray{fmi3Byte})
    size = length(serializedState)
    state = fmi3FMUState()
    stateRef = Ref(state)

    status = fmi3DeSerializeFMUState!(c, serializedState, Csize_t(size), stateRef)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]
    
    state = stateRef[]
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes directional derivatives.

For more information call ?fmi3GetDirectionalDerivative
"""
function fmi3GetDirectionalDerivative(c::FMU3Instance,
                                      unknowns::AbstractArray{fmi3ValueReference},
                                      knowns::AbstractArray{fmi3ValueReference},
                                      seed::AbstractArray{fmi3Float64} = Array{fmi3Float64}([]))
    
    nUnknown = Csize_t(length(unknowns))
    
    sensitivity = zeros(fmi3Float64, nUnknown)

    status = fmi3GetDirectionalDerivative!(c, unknowns, knowns, sensitivity, seed)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]
    
    return sensitivity
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes directional derivatives.

For more information call ?fmi3GetDirectionalDerivative
"""
function fmi3GetDirectionalDerivative!(c::FMU3Instance,
                                      unknowns::AbstractArray{fmi3ValueReference},
                                      knowns::AbstractArray{fmi3ValueReference},
                                      sensitivity::AbstractArray,
                                      seed::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

    nKnowns = Csize_t(length(knowns))
    nUnknowns = Csize_t(length(unknowns))

    if seed === nothing
        seed = ones(fmi3Float64, nKnowns)
    end

    nSeed = Csize_t(length(seed))
    nSensitivity = Csize_t(length(sensitivity))

    status = fmi3GetDirectionalDerivative!(c, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)

    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes directional derivatives.

For more information call ?fmi3GetDirectionalDerivative
"""
function fmi3GetDirectionalDerivative(c::FMU3Instance,
                                      unknown::fmi3ValueReference,
                                      known::fmi3ValueReference,
                                      seed::fmi3Float64 = 1.0)

    fmi3GetDirectionalDerivative(c, [unknown], [known], [seed])[1]
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes adjoint derivatives.

For more information call ?fmi3GetAdjointDerivative
"""
function fmi3GetAdjointDerivative(c::FMU3Instance,
                                      unknowns::AbstractArray{fmi3ValueReference},
                                      knowns::AbstractArray{fmi3ValueReference},
                                      seed::AbstractArray{fmi3Float64} = Array{fmi3Float64}([]))
    nUnknown = Csize_t(length(unknowns))

    sensitivity = zeros(fmi3Float64, nUnknown)

    status = fmi3GetAdjointDerivative!(c, unknowns, knowns, sensitivity, seed)
    @assert status == Int(fmi3StatusOK) ["Failed with status `$status`."]
    
    return sensitivity
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes adjoint derivatives.

For more information call ?fmi3GetAdjointDerivative
"""
function fmi3GetAdjointDerivative!(c::FMU3Instance,
                                      unknowns::AbstractArray{fmi3ValueReference},
                                      knowns::AbstractArray{fmi3ValueReference},
                                      sensitivity::AbstractArray,
                                      seed::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

    nKnowns = Csize_t(length(knowns))
    nUnknowns = Csize_t(length(unknowns))

    if seed === nothing
        seed = ones(fmi3Float64, nKnowns)
    end

    nSeed = Csize_t(length(seed))
    nSensitivity = Csize_t(length(sensitivity))

    status = fmi3GetAdjointDerivative!(c, unknowns, nUnknowns, knowns, nKnowns, seed, nSeed, sensitivity, nSensitivity)

    status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.11. Getting Partial Derivatives

Computes adjoint derivatives.

For more information call ?fmi3GetAdjointDerivative
"""
function fmi3GetAdjointDerivative(c::FMU3Instance,
                                      unknowns::fmi3ValueReference,
                                      knowns::fmi3ValueReference,
                                      seed::fmi3Float64 = 1.0)

    fmi3GetAdjointDerivative(c, [unknowns], [knowns], [seed])[1]
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.12. Getting Derivatives of Continuous Outputs

Retrieves the n-th derivative of output values.

vr defines the value references of the variables
the array order specifies the corresponding order of derivation of the variables

For more information call ?fmi3GetOutputDerivatives
"""
function fmi3GetOutputDerivatives(c::FMU3Instance, vr::fmi3ValueReferenceFormat, order::AbstractArray{Integer})
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

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of continuous states.
This function can only be called in Model Exchange. 
For more information call ?fmi3GetNumberOfContinuousStates
"""
function fmi3GetNumberOfContinuousStates(c::FMU3Instance)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfContinuousStates!(c, sizeRef)
    size = sizeRef[]
    Int32(size)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.2. State: Instantiated

This function returns the number of event indicators.
This function can only be called in Model Exchange.
For more information call ?fmi3GetNumberOfEventIndicators
"""
function fmi3GetNumberOfEventIndicators(c::FMU3Instance)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfEventIndicators!(c, sizeRef)
    size = sizeRef[]
    Int32(size)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.10. Dependencies of Variables

The number of dependencies of a given variable, which may change if structural parameters are changed, can be retrieved by calling the following function:
For more information call ?fmi3GetNumberOfVariableDependencies
"""
function fmi3GetNumberOfVariableDependencies(c::FMU3Instance, vr::Union{fmi3ValueReference, String})
    if typeof(vr) == String
        vr = fmi3String2ValueReference(c.fmu.modelDescription, vr)
    end
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi3GetNumberOfVariableDependencies!(c, vr, sizeRef)
    size = sizeRef[]
    Int32(size)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.2.10. Dependencies of Variables

The actual dependencies (of type dependenciesKind) can be retrieved by calling the function fmi3GetVariableDependencies:
For more information call ?fmi3GetVariableDependencies
"""
function fmi3GetVariableDependencies(c::FMU3Instance, vr::Union{fmi3ValueReference, String})
    if typeof(vr) == String
        vr = fmi3String2ValueReference(c.fmu.modelDescription, vr)
    end
    nDependencies = fmi3GetNumberOfVariableDependencies(c, vr)
    elementIndiceOfDependents = Array{Csize_t}(undef, nDependencies)
    independents = Array{fmi3ValueReference}(undef, nDependencies)
    elementIndiceOfIndependents = Array{Csize_t}(undef, nDependencies)
    dependencyKinds = Array{fmi3DependencyKind}(undef, nDependencies)

    fmi3GetVariableDependencies!(c, vr, elementIndiceOfDependents, independents, elementIndiceOfIndependents, dependencyKinds, nDependencies)

    return elementIndiceOfDependents, independents, elementIndiceOfIndependents, dependencyKinds
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the new (continuous) state vector x.

For more information call ?fmi3GetContinuousStates
"""
function fmi3GetContinuousStates(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    x = zeros(fmi3Float64, nx)
    fmi3GetContinuousStates!(c, x, nx)
    x
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.3. State: Initialization Mode

Return the new (continuous) state vector x.

For more information call ?fmi3GetNominalsOfContinuousStates
"""
function fmi3GetNominalsOfContinuousStates(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    x = zeros(fmi3Float64, nx)
    fmi3GetNominalsOfContinuousStates!(c, x, nx)
    x
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set independent variable time and reinitialize chaching of variables that depend on time.

For more information call ?fmi3SetTime
"""
function fmi3SetTime(c::FMU3Instance, time::Real)
    status = fmi3SetTime(c, fmi3Float64(time))
    c.t = t
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Set a new (continuous) state vector and reinitialize chaching of variables that depend on states.

For more information call ?fmi3SetContinuousStates
"""
function fmi3SetContinuousStates(c::FMU3Instance, x::Union{AbstractArray{Float32}, AbstractArray{Float64}})
    nx = Csize_t(length(x))
    status = fmi3SetContinuousStates(c, Array{fmi3Float64}(x), nx)
    if status == fmi3StatusOK
        c.x = x
    end 
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute state derivatives at the current time instant and for the current states.

For more information call ?fmi3GetContinuousDerivatives
"""
function  fmi3GetContinuousStateDerivatives(c::FMU3Instance)
    nx = Csize_t(c.fmu.modelDescription.numberOfContinuousStates)
    derivatives = zeros(fmi3Float64, nx)
    fmi3GetContinuousStateDerivatives!(c, derivatives)
    return derivatives
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Compute state derivatives at the current time instant and for the current states.

For more information call ?fmi3GetContinuousDerivatives
"""
function  fmi3GetContinuousStateDerivatives!(c::FMU3Instance, derivatives::AbstractArray{fmi3Float64})
    status = fmi3GetContinuousStateDerivatives!(c, derivatives, Csize_t(length(derivatives)))
    if status == fmi3StatusOK
        c.ẋ = derivatives
    end
    return status
end

"""
Source: FMISpec3.0, Version D5ef1c1: 2.3.5. State: Event Mode

This function is called to signal a converged solution at the current super-dense time instant. fmi3UpdateDiscreteStates must be called at least once per super-dense time instant.

For more information call ?fmi3UpdateDiscreteStates
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
    nominalsOfContinuousStatesChanged =refnOCS[]
    valuesOfContinuousStatesChanged = refvOCS[]
    nextEventTimeDefined = refnETD[]
    nextEventTime = refnET[]

    discreteStatesNeedUpdate, terminateSimulation, nominalsOfContinuousStatesChanged, valuesOfContinuousStatesChanged, nextEventTimeDefined, nextEventTime
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

Returns the event indicators of the FMU.

For more information call ?fmi3GetEventIndicators
"""
function fmi3GetEventIndicators(c::FMU3Instance)
    ni = Csize_t(c.fmu.modelDescription.numberOfEventIndicators)
    eventIndicators = zeros(fmi3Float64, ni)
    fmi3GetEventIndicators!(c, eventIndicators, ni)
    return eventIndicators
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

This function must be called by the environment after every completed step
If enterEventMode == fmi3True, the event mode must be entered
If terminateSimulation == fmi3True, the simulation shall be terminated

For more information call ?fmi3CompletedIntegratorStep
"""
function fmi3CompletedIntegratorStep(c::FMU3Instance,
    noSetFMUStatePriorToCurrentPoint::fmi3Boolean)
    enterEventMode = fmi3Boolean(true)
    terminateSimulation = fmi3Boolean(true)
    refEventMode = Ref(enterEventMode)
    refterminateSimulation = Ref(terminateSimulation)
    status = fmi3CompletedIntegratorStep!(c,
                                        noSetFMUStatePriorToCurrentPoint,
                                        refEventMode,
                                        refterminateSimulation)
    enterEventMode = refEventMode[]
    terminateSimulation = refterminateSimulation[]
    
    return (status, enterEventMode, terminateSimulation)
end

"""
Source: FMISpec3.0, Version D5ef1c1: 3.2.1. State: Continuous-Time Mode

The model enters Event Mode.

For more information call ?fmi3EnterEventMode
"""
function fmi3EnterEventMode(c::FMU3Instance, stepEvent::Bool, stateEvent::Bool, rootsFound::AbstractArray{fmi3Int32}, nEventIndicators::Csize_t, timeEvent::Bool)
    fmi3EnterEventMode(c, fmi3Boolean(stepEvent), fmi3Boolean(stateEvent), rootsFound, nEventIndicators, fmi3Boolean(timeEvent))
end

function fmi3DoStep!(c::FMU3Instance, currentCommunicationPoint::Union{Real, Nothing} = nothing, communicationStepSize::Union{Real, Nothing} = nothing, noSetFMUStatePriorToCurrentPoint::Bool = true,
    eventEncountered::fmi3Boolean = fmi3False, terminateSimulation::fmi3Boolean = fmi3False, earlyReturn::fmi3Boolean = fmi3False, lastSuccessfulTime::fmi3Float64 = 0.0)

    # skip `fmi3DoStep` if this is set (allows evaluation of a CS_NeuralFMUs at t_0)
    if c.skipNextDoStep
        c.skipNextDoStep = false
        return fmi3StatusOK
    end

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
    status = fmi3DoStep!(c, fmi3Float64(currentCommunicationPoint), fmi3Float64(communicationStepSize), fmi3Boolean(noSetFMUStatePriorToCurrentPoint), refeventEncountered, refterminateSimulation, refearlyReturn, reflastSuccessfulTime)
    c.t += communicationStepSize

    eventEncountered = refeventEncountered[]
    terminateSimulation = refterminateSimulation[]
    earlyReturn = refearlyReturn[]
    lastSuccessfulTime = reflastSuccessfulTime[]

    return status
end
