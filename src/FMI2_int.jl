#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_int.jl` (internal functions)?
# - optional, more comfortable calls to the C-functions from the FMI-spec (example: `fmiGetReal!(c, v, a)` is bulky, `a = fmiGetReal(c, v)` is more user friendly)

# Best practices:
# - no direct access on C-pointers (`compAddr`), use existing FMICore-functions

"""
TODO: FMI specification reference.

Set the DebugLogger for the FMU.
"""
function fmi2SetDebugLogging(c::FMU2Component)
    fmi2SetDebugLogging(c, fmi2False, Unsigned(0), C_NULL)
end

"""

   fmi2SetupExperiment(c::FMU2Component, startTime::Union{Real, Nothing} = nothing, stopTime::Union{Real, Nothing} = nothing; tolerance::Union{Real, Nothing} = nothing)

Setup the simulation but without defining all of the parameters.

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `startTime::Union{Real, Nothing} = nothing`: `startTime` is a real number which sets the value of starting time of the experiment. The default value is set automatically if doing nothing (default = `nothing`).
- `stopTime::Union{Real, Nothing} = nothing`: `stopTime` is a real number which sets the value of ending time of the experiment. The default value is set automatically if doing nothing (default = `nothing`).

# Keywords
- `tolerance::Union{Real, Nothing} = nothing`: `tolerance` is a real number which sets the value of tolerance range. The default value is set automatically if doing nothing (default = `nothing`).

# Returns
- Returns a warning if `str.state` is not called in `fmi2ComponentStateInstantiated`.
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
- FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

See also [`fmi2SetupExperiment`](@ref).
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


   fmi2GetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat)

Get the values of an array of fmi2Real variables.

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fm2Real}`: returns values of an array of fmi2Real variables with the dimension of fmi2ValueReferenceFormat length.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

 See also [`fmi2GetReal`](@ref).
"""
function fmi2GetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi2Real, nvr)
    fmi2GetReal!(c, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""

   fmi2GetReal!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Real})


Get the values of an array of fmi2Real variables.

rites the real values of an array of variables in the given field

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
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
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
 See also [`fmi2GetReal!`](@ref).
"""
function fmi2GetReal!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Real})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetReal!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    # values[:] = fmi2Real.(values)
    fmi2GetReal!(c, vr, nvr, values)
    nothing
end
function fmi2GetReal!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Real)
    @assert false "fmi2GetReal! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

   fmi2SetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{<:Real}, <:Real})


Set the values of an array of real variables

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
- `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{Array{<:Real}, <:Real}`: Argument `values` is an array with the actual values of these variables.

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
See also [`fmi2SetReal`](@ref).
"""
function fmi2SetReal(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{<:Real}, <:Real})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetReal(...): `vr` ($(length(vr))) and `values` ($(length(values))) need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetReal(c, vr, nvr, Array{fmi2Real}(values))
end

"""

   fmi2GetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat)

Returns the integer values of an array of variables

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi2Integer}`: Return `values` is an array with the actual values of these variables.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

See also [`fmi2GetInteger!`](@ref)
"""
function fmi2GetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = zeros(fmi2Integer, nvr)
    fmi2GetInteger!(c, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""

   fmi2GetInteger!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Integer})

Writes the integer values of an array of variables in the given field

fmi2GetInteger! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::Array{fmi2Integer}`: Argument `values` is an array with the actual values of these variables.

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
function fmi2GetInteger!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Integer})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetInteger!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    fmi2GetInteger!(c, vr, nvr, values)
    nothing
end
function fmi2GetInteger!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Integer)
    @assert false "fmi2GetInteger! is only possible for arrays of values, please use an array instead of a scalar."
"""



   fmi2SetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{<:Integer}, <:Integer})

Set the values of an array of integer variables

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `values::Union{Array{<:Integer}, <:Integer}`: Argument `values` is an array or a single value with type Integer or any subtyp
# Returns
- `status::fmi2Status`: Return `status` indicates the success of the function call.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

See also [`fmi2SetInteger`](@ref).
"""
function fmi2SetInteger(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{<:Integer}, <:Integer})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetInteger(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetInteger(c, vr, nvr, Array{fmi2Integer}(values))
end

"""

   fmi2GetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat)

Get the values of an array of fmi2Boolean variables.

# Arguments
- `c::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `c::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi2Boolean}`: Return `values` is an array with the actual values of these variables.

See also [`fmi2GetBoolean!`](@ref).
"""
function fmi2GetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    values = Array{fmi2Boolean}(undef, nvr)
    fmi2GetBoolean!(c, vr, nvr, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""

   fmi2GetBoolean!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Boolean})

Writes the boolean values of an array of variables in the given field

fmi2GetBoolean! is only possible for arrays of values, please use an array instead of a scalar.

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `vr::AbstractArray{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variable that shall be inquired.
- `nvr::Csize_t`: Argument `nvr` defines the size of `vr`.
- `values::AbstractArray{fmi2Boolean}`: Argument `value` is an array with the actual values of these variables

# Returns
- Return singleton instance of type `Nothing`, if there is no value to return (as in a C void function) or when a variable or field holds no value.


# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
See also [`fmi2GetBoolean!`](@ref).
"""
function fmi2GetBoolean!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2Boolean})

    vr = prepareValueReference(c, vr)
    # values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2GetBoolean!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(values))
    #values = fmi2Boolean.(values)
    fmi2GetBoolean!(c, vr, nvr, values)

    nothing
end
function fmi2GetBoolean!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Bool)
    @assert false "fmi2GetBoolean! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

   fmi2SetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{Bool}, Bool})

Set the values of an array of boolean variables

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{Array{Bool}, Bool}`: Argument `values` is an array or a single value with type Boolean or any subtyp
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
function fmi2SetBoolean(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{Bool}, Bool})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetBoolean(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2SetBoolean(c, vr, nvr, Array{fmi2Boolean}(values))
end

"""

   fmi2GetString(c::FMU2Component, vr::fmi2ValueReferenceFormat)

Get the values of an array of fmi2String variables.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `values::Array{fmi2String}`:  Return `values` is an array with the actual values of these variables.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
See also [`fmi2GetString!`](@ref).
"""
function fmi2GetString(c::FMU2Component, vr::fmi2ValueReferenceFormat)

    vr = prepareValueReference(c, vr)

    nvr = Csize_t(length(vr))
    vars = Vector{fmi2String}(undef, nvr)
    values = string.(zeros(nvr))
    fmi2GetString!(c, vr, nvr, vars)
    values[:] = unsafe_string.(vars)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""

   fmi2GetString!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2String})

Writes the string values of an array of variables in the given field

These functions are especially used to get the actual values of output variables if a model is connected with other
models.

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::AbstractArray{fmi2String}`: Argument `values` is an AbstractArray with the actual values of these variables

# Returns
- Return singleton instance of type `Nothing`, if there is no value to return (as in a C void function) or when a variable or field holds no value.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.24]: 2.1.7 Getting and Setting Variable Values
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
See also [`fmi2GetString!`](@ref).
"""
function fmi2GetString!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::AbstractArray{fmi2String})

    vr = prepareValueReference(c, vr)
    @assert length(vr) == length(values) "fmi2GetString!(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    fmi2GetString!(c, vr, nvr, values)

    nothing
end
function fmi2GetString!(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::String)
    @assert false "fmi2GetString! is only possible for arrays of values, please use an array instead of a scalar."
end

"""

   fmi2SetString(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{String}, String})

Set the values of an array of string variables

For the exact rules on which type of variables fmi2SetXXX
can be called see FMISpec2.0.2 section 2.2.7 , as well as FMISpec2.0.2 section 3.2.3 in case of ModelExchange and FMISpec2.0.2 section 4.2.4 in case of
CoSimulation.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::fmi2ValueReferenceFormat`: Argument `vr` defines the value references of the variables.
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `values::Union{Array{String}, String}`: Argument `values` is an array or a single value with type String.

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
- FMISpec2.0.2[p.46]: 2.2.7 Definition of Model Variables
- FMISpec2.0.2[p.46]: 3.2.3 State Machine of Calling Sequence
- FMISpec2.0.2[p.108]: 4.2.4 State Machine of Calling Sequence from Master to Slave
See also [`fmi2SetString`](@ref).
"""
function fmi2SetString(c::FMU2Component, vr::fmi2ValueReferenceFormat, values::Union{AbstractArray{String}, String})

    vr = prepareValueReference(c, vr)
    values = prepareValue(values)
    @assert length(vr) == length(values) "fmi2SetReal(...): `vr` and `values` need to be the same length."

    nvr = Csize_t(length(vr))
    ptrs = pointer.(values)
    fmi2SetString(c, vr, nvr, ptrs)
end

"""

   fmi2GetFMUstate(c::FMU2Component)

Makes a copy of the internal FMU state and returns a pointer to this copy.

# Arguments
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- Return `state` is a pointer to a copy of the internal FMU state.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2GetFMUstate`](@ref).
"""
function fmi2GetFMUstate(c::FMU2Component)
    state = fmi2FMUstate()
    stateRef = Ref(state)
    fmi2GetFMUstate!(c, stateRef)
    state = stateRef[]
    state
end

"""

   fmi2FreeFMUstate!(c::FMU2Component, state::fmi2FMUstate)

Free the memory for the allocated FMU state

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `state::fmi2FMUstate`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- Return singleton instance of type `Nothing`, if there is no value to return (as in a C void function) or when a variable or field holds no value.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2FreeFMUstate`](@ref).
"""
function fmi2FreeFMUstate!(c::FMU2Component, state::fmi2FMUstate)
    stateRef = Ref(state)
    fmi2FreeFMUstate!(c, stateRef)
    state = stateRef[]
    return nothing
end

"""

   fmi2SerializedFMUstateSize(c::FMU2Component, state::fmi2FMUstate)

Returns the size of the byte vector in which the FMUstate can be stored.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `state::fmi2FMUstate`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- Return `size` is an object that safely references a value of type `Csize_t`.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2SerializedFMUstateSize`](@ref).
"""
function fmi2SerializedFMUstateSize(c::FMU2Component, state::fmi2FMUstate)
    size = 0
    sizeRef = Ref(Csize_t(size))
    fmi2SerializedFMUstateSize!(c, state, sizeRef)
    size = sizeRef[]
end

"""

   fmi2SerializeFMUstate(c::FMU2Component, state::fmi2FMUstate)

Serializes the data referenced by the pointer FMUstate and copies this data into the byte vector serializedState of length size to be provided by the environment.

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `state::fmi2FMUstate`: Argument `state` is a pointer to a data structure in the FMU that saves the internal FMU state of the actual or a previous time instant.

# Returns
- `serializedState:: Array{fmi2Byte}`: Return `serializedState` contains the copy of the serialized data referenced by the pointer FMUstate

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2SerializeFMUstate`](@ref).
"""
function fmi2SerializeFMUstate(c::FMU2Component, state::fmi2FMUstate)
    size = fmi2SerializedFMUstateSize(c, state)
    serializedState = Array{fmi2Byte}(undef, size)
    status = fmi2SerializeFMUstate!(c, state, serializedState, size)
    @assert status == Int(fmi2StatusOK) ["Failed with status `$status`."]
    serializedState
end

"""

   fmi2DeSerializeFMUstate(c::FMU2Component, serializedState::AbstractArray{fmi2Byte})

Deserialize the data in the serializedState fmi2Byte field

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `serializedState::Array{fmi2Byte}`: Argument `serializedState` contains the fmi2Byte field to be deserialized.

# Returns
- Return `state` is a pointer to a copy of the internal FMU state.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.8 Getting and Setting the Complete FMU State

See also [`fmi2DeSerializeFMUstate`](@ref).
"""
function fmi2DeSerializeFMUstate(c::FMU2Component, serializedState::AbstractArray{fmi2Byte})
    size = length(serializedState)
    state = fmi2FMUstate()
    stateRef = Ref(state)

    status = fmi2DeSerializeFMUstate!(c, serializedState, Csize_t(size), stateRef)
    @assert status == Int(fmi2StatusOK) "Failed with status `$status`."

    state = stateRef[]
end

"""

   fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::AbstractArray{fmi2ValueReference},
                                      vKnown_ref::AbstractArray{fmi2ValueReference},
                                      dvKnown::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Wrapper Function call to compute the partial derivative with respect to the variables `vKnown_ref`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns.The
precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
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
- `vUnknown_ref::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `dvKnown::Union{AbstractArray{fmi2Real}, Nothing} = nothing`: If no seed vector is passed the value `nothing` is used. The vector values Compute the partial derivative with respect to the given entries in vector `vKnown_ref` with the matching evaluate of `dvKnown`.  # gehört das zu den v_rest values

# Returns
- `dvUnknown::Array{fmi2Real}`: Return `dvUnknown` contains the directional derivative vector values.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.9 Getting Partial Derivatives
See also [`fmi2GetDirectionalDerivative`](@ref).
"""
function fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::AbstractArray{fmi2ValueReference},
                                      vKnown_ref::AbstractArray{fmi2ValueReference},
                                      dvKnown::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    nUnknown = Csize_t(length(vUnknown_ref))

    dvUnknown = zeros(fmi2Real, nUnknown)
    status = fmi2GetDirectionalDerivative!(c, vUnknown_ref, vKnown_ref, dvUnknown, dvKnown)
    @assert status == fmi2StatusOK ["Failed with status `$status`."]

    return dvUnknown
end

"""

    fmiGetDirectionalDerivative!(c::FMU2Component,
                                      vUnknown_ref::AbstractArray{fmi2ValueReference},
                                      vKnown_ref::AbstractArray{fmi2ValueReference},
                                      dvUnknown::AbstractArray,
                                      dvKnown::Union{Array{fmi2Real}, Nothing} = nothing)

Wrapper Function call to compute the partial derivative with respect to the variables `vKnown_ref`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns.The
precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
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
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `dvUnknown::AbstractArray{fmi2Real}`: Stores the directional derivative vector values.
- `dvKnown::Union{AbstractArray{fmi2Real}, Nothing} = nothing`: If no seed vector is passed the value `nothing` is used. The vector values Compute the partial derivative with respect to the given entries in vector `vKnown_ref` with the matching evaluate of `dvKnown`.


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
                                      vKnown_ref::AbstractArray{fmi2ValueReference},
                                      dvUnknown::AbstractArray, # ToDo: Data-type
                                      dvKnown::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    nKnown = Csize_t(length(vKnown_ref))
    nUnknown = Csize_t(length(vUnknown_ref))

    if dvKnown == nothing
        dvKnown = ones(fmi2Real, nKnown)
    end

    status = fmi2GetDirectionalDerivative!(c, vUnknown_ref, nUnknown, vKnown_ref, nKnown, dvKnown, dvUnknown)

    return status
end

"""

   fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::fmi2ValueReference,
                                      vKnown_ref::fmi2ValueReference,
                                      dvKnown::fmi2Real = 1.0)

Direct function call to compute the partial derivative with respect to `vKnown_ref`.

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns.The
precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
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
 - `vUnknown_ref::fmi2ValueReference`: Argument `vUnknown_ref` contains a value of type`fmi2ValueReference` which is an identifier of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
 - `vKnown_ref::fmi2ValueReference`: Argument `vKnown_ref` contains a value of type`fmi2ValueReference` which is an identifier of a variable value of the model. `vKnown_ref` can be equated with `v_known`(variable described above).
 - `dvKnown::fmi2Real = 1.0`: If no seed value is passed the value `dvKnown = 1.0` is used. Compute the partial derivative with respect to `vKnown_ref` with the value `dvKnown = 1.0`.  # gehört das zu den v_rest values
# Returns
- `dvUnknown::Array{fmi2Real}`: Return `dvUnknown` contains the directional derivative vector values.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.25]: 2.1.9 Getting Partial Derivatives
See also [`fmi2GetDirectionalDerivative`](@ref).
"""
function fmi2GetDirectionalDerivative(c::FMU2Component,
                                      vUnknown_ref::fmi2ValueReference,
                                      vKnown_ref::fmi2ValueReference,
                                      dvKnown::fmi2Real = 1.0)

    fmi2GetDirectionalDerivative(c, [vUnknown_ref], [vKnown_ref], [dvKnown])[1]
end

# CoSimulation specific functions
"""

    fmi2SetRealInputDerivatives(c::FMU2Component, vr::AbstractArray{fmi2ValueReference}, order::AbstractArray{fmi2Integer}, values::AbstractArray{fmi2Real})

Sets the n-th time derivative of real input variables.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that define the variables whose derivatives shall be set.
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
function fmi2SetRealInputDerivatives(c::FMU2Component, vr::fmi2ValueReferenceFormat, order::AbstractArray{fmi2Integer}, values::AbstractArray{fmi2Real})

    @assert c.type == fmi2TypeCoSimulation "`fmi2SetRealInputDerivatives` only available for CS-FMUs."

    vr = prepareValueReference(c, vr)
    order = prepareValue(order)
    values = prepareValue(values)
    nvr = Csize_t(length(vr))
    fmi2SetRealInputDerivatives(c, vr, nvr, order, values)
end

"""

   fmi2GetRealOutputDerivatives(c::FMU2Component, vr::fmi2ValueReferenceFormat, order::AbstractArray{fmi2Integer})

Sets the n-th time derivative of real input variables.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vr::Array{fmi2ValueReference}`: Argument `vr` is an array of `nvr` value handels called "ValueReference" that t define the variables whose derivatives shall be set.
- `order::Array{fmi2Integer}`: Argument `order` is an array of fmi2Integer values witch specifys the corresponding order of derivative of the real input variable.

# Returns
- `value::AbstactArray{fmi2Integer}`: Return `value` is an array which represents a vector with the values of the derivatives.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.104]: 4.2.1 Transfer of Input / Output Values and Parameters

See also [`fmi2SetRealInputDerivatives!`](@ref).
"""
function fmi2GetRealOutputDerivatives(c::FMU2Component, vr::fmi2ValueReferenceFormat, order::AbstractArray{fmi2Integer})

    @assert c.type == fmi2TypeCoSimulation "`fmi2GetRealOutputDerivatives` only available for CS-FMUs."

    vr = prepareValueReference(c, vr)
    order = prepareValue(order)
    nvr = Csize_t(length(vr))
    values = zeros(fmi2Real, nvr)
    fmi2GetRealOutputDerivatives!(c, vr, nvr, order, values)

    if length(values) == 1
        return values[1]
    else
        return values
    end
end

"""

    fmi2DoStep(c::FMU2Component, communicationStepSize::Union{Real, Nothing} = nothing; currentCommunicationPoint::Union{Real, Nothing} = nothing, noSetFMUStatePriorToCurrentPoint::Bool = true)


Does one step in the CoSimulation FMU

# Arguments
- `C::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `communicationStepSize::Union{Real, Nothing} = nothing`: Argument `communicationStepSize` contains a value of type `Real` or `Nothing` , if no argument is passed the default value `nothing` is used. `communicationStepSize` defines the communiction step size.

# Keywords
- `currentCommunicationPoint::Union{Real, Nothing} = nothing`: Argument `currentCommunicationPoint` contains a value of type `Real` or type `Nothing`. If no argument is passed the default value `nothing` is used. `currentCommunicationPoint` defines the current communication point of the master.
- `noSetFMUStatePriorToCurrentPoint::Bool = true`: Argument `noSetFMUStatePriorToCurrentPoint` contains a value of type `Boolean`. If no argument is passed the default value `true` is used. `noSetFMUStatePriorToCurrentPoint` indicates whether `fmi2SetFMUState` is no longer called for times before the `currentCommunicationPoint` in this simulation run Simulation run.

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
See also [`fmi2DoStep`](@ref), [`fmi2Struct`](@ref), [`FMU2`](@ref), [`FMU2Component`](@ref).
"""
function fmi2DoStep(c::FMU2Component, communicationStepSize::Union{Real, Nothing} = nothing; currentCommunicationPoint::Union{Real, Nothing} = nothing, noSetFMUStatePriorToCurrentPoint::Bool = true)

    @assert c.type == fmi2TypeCoSimulation "`fmi2DoStep` only available for CS-FMUs."

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
    status = fmi2DoStep(c, fmi2Real(currentCommunicationPoint), fmi2Real(communicationStepSize), fmi2Boolean(noSetFMUStatePriorToCurrentPoint))
    c.t += communicationStepSize

    return status
end

"""

    fmiSetTime(c::FMU2Component, t::Real)

Set a new time instant and re-initialize caching of variables that depend on time.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `t::Real`: Argument `t` contains a value of type `Real`. `t` sets the independent variable time t.

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
See also [`fmi2SetTime`](@ref)
"""
function fmi2SetTime(c::FMU2Component, t::Real)

    @assert c.type == fmi2TypeModelExchange "`fmi2SetTime` only available for ME-FMUs."

    status = fmi2SetTime(c, fmi2Real(t))
    c.t = t
    return status
end

# Model Exchange specific functions

"""


    fmiSetContinuousStates(c::FMU2Component,
                                 x::Union{AbstractArray{Float32},AbstractArray{Float64}})

Set a new (continuous) state vector and reinitialize chaching of variables that depend on states.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `x::Union{AbstractArray{Float32},AbstractArray{Float64}}`:Argument `x` is the `AbstractArray` of the vector values of `Float64` or `Float32`.

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
function fmi2SetContinuousStates(c::FMU2Component, x::Union{AbstractArray{Float32}, AbstractArray{Float64}})
    nx = Csize_t(length(x))
    status = fmi2SetContinuousStates(c, Array{fmi2Real}(x), nx)
    if status == fmi2StatusOK
        c.x = x
    end
    return status
end

"""

    fmi2NewDiscreteStates(c::FMU2Component)

Returns the next discrete states

# Arguments
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `eventInfo::fmi2EventInfo*`: Strut with `fmi2Boolean` Variables
More detailed:
  - `newDiscreteStatesNeeded::fmi2Boolean`: If `newDiscreteStatesNeeded = fmi2True` the FMU should stay in Event Mode, and the FMU requires to set new inputs to the FMU to compute and get the outputs and to call
fmi2NewDiscreteStates again. If all FMUs return `newDiscreteStatesNeeded = fmi2False` call fmi2EnterContinuousTimeMode.
  - `terminateSimulation::fmi2Boolean`: If `terminateSimulation = fmi2True` call `fmi2Terminate`
  - `nominalsOfContinuousStatesChanged::fmi2Boolean`: If `nominalsOfContinuousStatesChanged = fmi2True` then the nominal values of the states have changed due to the function call and can be inquired with `fmi2GetNominalsOfContinuousStates`.
  - `valuesOfContinuousStatesChanged::fmi2Boolean`: If `valuesOfContinuousStatesChanged = fmi2True`, then at least one element of the continuous state vector has changed its value due to the function call. The new values of the states can be retrieved with `fmi2GetContinuousStates`. If no element of the continuous state vector has changed its value, `valuesOfContinuousStatesChanged` must return fmi2False.
  - `nextEventTimeDefined::fmi2Boolean`: If `nextEventTimeDefined = fmi2True`, then the simulation shall integrate at most until `time = nextEventTime`, and shall call `fmi2EnterEventMode` at this time instant. If integration is stopped before nextEventTime, the definition of `nextEventTime` becomes obsolete.
  - `nextEventTime::fmi2Real`: next event if `nextEventTimeDefined=fmi2True`
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2NewDiscreteStates`](@ref).
"""
function fmi2NewDiscreteStates(c::FMU2Component)
    eventInfo = fmi2EventInfo()
    fmi2NewDiscreteStates!(c, eventInfo)
    eventInfo
end

"""

    fmiCompletedIntegratorStep(c::FMU2Component, noSetFMUStatePriorToCurrentPoint::fmi2Boolean)

This function must be called by the environment after every completed step

# Arguments
- `C::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `noSetFMUStatePriorToCurrentPoint::fmi2Boolean`: Argument `noSetFMUStatePriorToCurrentPoint = fmi2True` if `fmi2SetFMUState`  will no longer be called for time instants prior to current time in this simulation run.

# Returns
- `status::fmi2Status`: Return `status` is an enumeration of type `fmi2Status` and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously
- `enterEventMode::Array{fmi2Boolean, 1}`: Returns `enterEventMode[1]` to signal to the environment if the FMU shall call `fmi2EnterEventMode`
- `terminateSimulation::Array{fmi2Boolean, 1}`: Returns `terminateSimulation[1]` to signal if the simulation shall be terminated.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2CompletedIntegratorStep`](@ref), [`fmi2SetFMUState`](@ref).
"""
function fmi2CompletedIntegratorStep(c::FMU2Component,
                                     noSetFMUStatePriorToCurrentPoint::fmi2Boolean)
    enterEventMode = zeros(fmi2Boolean, 1)
    terminateSimulation = zeros(fmi2Boolean, 1)

    status = fmi2CompletedIntegratorStep!(c,
                                          noSetFMUStatePriorToCurrentPoint,
                                          pointer(enterEventMode),
                                          pointer(terminateSimulation))

    return (status, enterEventMode[1], terminateSimulation[1])
end

"""

   fmi2GetDerivatives(c::FMU2Component)

Compute state derivatives at the current time instant and for the current states.

# Arguments
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `derivatives::Array{fmi2Real}`: Returns an array of `fmi2Real` values representing the `derivatives` for the current states. The ordering of the elements of the derivatives vector is identical to the ordering of the state
vector.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetDerivatives`](@ref).
"""
function fmi2GetDerivatives(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    derivatives = zeros(fmi2Real, nx)
    fmi2GetDerivatives!(c, derivatives)
    return derivatives
end

"""

   fmi2GetDerivatives!(c::FMU2Component, derivatives::AbstractArray{fmi2Real})

Compute state derivatives at the current time instant and for the current states.

# Arguments
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
 - `derivatives::Array{fmi2Real}`: Stores `fmi2Real` values representing the `derivatives` for the current states. The ordering of the elements of the derivatives vector is identical to the ordering of the state vector.

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
See also [`fmi2GetDerivatives`](@ref).
"""
function fmi2GetDerivatives!(c::FMU2Component, derivatives::AbstractArray{fmi2Real})
    status = fmi2GetDerivatives!(c, derivatives, Csize_t(length(derivatives)))
    if status == fmi2StatusOK
        c.ẋ = derivatives
    end
    return status
end

"""

   fmi2GetEventIndicators(c::FMU2Component)

Returns the event indicators of the FMU
# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.

# Returns
- `eventIndicators::Array{fmi2Real}`:The event indicators are returned as a vector represented by an array of "fmi2Real" values.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators`](@ref).
"""
function fmi2GetEventIndicators(c::FMU2Component)
    ni = Csize_t(c.fmu.modelDescription.numberOfEventIndicators)
    eventIndicators = zeros(fmi2Real, ni)
    fmi2GetEventIndicators!(c, eventIndicators, ni)
    return eventIndicators
end

"""

   fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::AbstractArray{fmi2Real})

Returns the event indicators of the FMU
# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `eventIndicators::AbstractArray{fmi2Real}`:The event indicators are in an AbstractArray represented by an array of "fmi2Real" values.
# Returns

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators`](@ref).
"""
function fmi2GetEventIndicators!(c::FMU2Component, eventIndicators::AbstractArray{fmi2Real})
    ni = Csize_t(length(eventIndicators))
    fmi2GetEventIndicators!(c, eventIndicators, ni)
end

"""

   fmi2GetContinuousStates(c::FMU2Component)

Return the new (continuous) state vector x
# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
# Returns
- `x::Array{fmi2Real}`: Returns an array of `fmi2Real` values representing the new continuous state vector `x`.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetEventIndicators`](@ref).
"""
function fmi2GetContinuousStates(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    x = zeros(fmi2Real, nx)
    fmi2GetContinuousStates!(c, x, nx)
    x
end

"""

   fmi2GetNominalsOfContinuousStates(c::FMU2Component)

Return the new (continuous) state vector x

# Arguments
 - `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
# Returns
- `x::Array{fmi2Real}`: Returns an array of `fmi2Real` values representing the new continuous state vector `x`.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
- FMISpec2.0.2[p.16]: 2.1.3 Status Returned by Functions
- FMISpec2.0.2[p.83]: 3.2.2 Evaluation of Model Equations
See also [`fmi2GetNominalsOfContinuousStates`](@ref).
"""
function fmi2GetNominalsOfContinuousStates(c::FMU2Component)
    nx = Csize_t(length(c.fmu.modelDescription.stateValueReferences))
    x = zeros(fmi2Real, nx)
    fmi2GetNominalsOfContinuousStates!(c, x, nx)
    x
end

"""

   fmi2GetStatus(c::FMU2Component, s::fmi2StatusKind)

Informs the master about the actual status of the simulation run. Which status information is to be returned is specified by the argument `fmi2StatusKind`.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `s::fmi2StatusKind`: The enumeration `fmi2StatusKind` defines which status is inquired.
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
-`value::Union{nothing; fmi2Boolean}`: If the slave dont want to terminate the simulation `nothing` ist returned. Howerver, if the slave wants to end the simulation the first value of the value array will be returned.
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
        status = fmi2GetStatus!(c, s, value)
    end

    status, value[1]
end
