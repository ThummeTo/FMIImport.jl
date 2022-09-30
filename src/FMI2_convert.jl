#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using ChainRulesCore: ignore_derivatives

# Receives one or an array of value references in an arbitrary format (see fmi2ValueReferenceFormat) and converts it into an Array{fmi2ValueReference} (if not already).
function prepareValueReference(md::fmi2ModelDescription, vr::fmi2ValueReferenceFormat)
    tvr = typeof(vr)
    if isa(vr, AbstractArray{fmi2ValueReference,1})
        return vr
    elseif tvr == fmi2ValueReference
        return [vr]
    elseif tvr == String
        return [fmi2StringToValueReference(md, vr)]
    elseif isa(vr, AbstractArray{String,1})
        return fmi2StringToValueReference(md, vr)
    elseif tvr == Int64
        return [fmi2ValueReference(vr)]
    elseif isa(vr, AbstractArray{Int64,1})
        return fmi2ValueReference.(vr)
    elseif tvr == Nothing
        return Array{fmi2ValueReference,1}()
    elseif tvr == Symbol
        if vr == :states
            return md.stateValueReferences
        elseif vr == :derivatives
            return md.derivativeValueReferences
        elseif vr == :inputs
            return md.inputValueReferences
        elseif vr == :outputs
            return md.outputValueReferences
        elseif vr == :all
            return md.valueReferences
        elseif vr == :none
            return Array{fmi2ValueReference,1}()
        else
            @assert false "Unknwon symbol `$vr`, can't convert to value reference."
        end
    end

    @assert false "prepareValueReference(...): Unknown value reference structure `$tvr`."
end
function prepareValueReference(fmu::FMU2, vr::fmi2ValueReferenceFormat)
    prepareValueReference(fmu.modelDescription, vr)
end
function prepareValueReference(comp::FMU2Component, vr::fmi2ValueReferenceFormat)
    prepareValueReference(comp.fmu.modelDescription, vr)
end

"""

   fmi2StringToValueReference(md::fmi2ModelDescription, names::AbstractArray{String})

Returns an array of ValueReferences coresponding to the variable names.

# Arguments
- `md::fmi2ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `names::AbstractArray{String}`: Argument `names` contains a list of Strings. For each string ("variable name"), the corresponding value reference is searched in the given modelDescription.

# Returns
- `vr:Array{fmi2ValueReference}`: Return `vr` is an array of `ValueReference` coresponding to the variable names.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
See also [`fmi2StringToValueReference`](@ref).
"""
function fmi2StringToValueReference(md::fmi2ModelDescription, names::AbstractArray{String})
    vr = Array{fmi2ValueReference}(undef,0)
    for name in names
        reference = fmi2StringToValueReference(md, name)
        if reference == nothing
            @warn "Value reference for variable '$name' not found, skipping."
        else
            push!(vr, reference)
        end
    end
    vr
end

"""

   fmi2ModelVariablesForValueReference(md::fmi2ModelDescription, vr::fmi2ValueReference)

Returns the model variable(s) fitting the value reference.

# Arguments
- `md::fmi2ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `vr::fmi2ValueReference`: Argument `vr` contains a value of type`fmi2ValueReference` which are identifiers of a variable value of the model.

# Returns
- `ar::Array{fmi2ScalarVariable}`: Return `ar` is an array of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference to the input variable vr.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
See also [`fmi2ModelVariablesForValueReference`](@ref).
"""
function fmi2ModelVariablesForValueReference(md::fmi2ModelDescription, vr::fmi2ValueReference)
    ar = []
    for modelVariable in md.modelVariables
        if modelVariable.valueReference == vr
            push!(ar, modelVariable)
        end
    end
    ar
end

"""
   fmi2StringToValueReference(md::fmi2ModelDescription, name::String)

   fmi2StringToValueReference(fmu::FMU2, name::Union{String, AbstractArray{String}})

Returns the ValueReference or an array of ValueReferences coresponding to the variable names.

# Arguments
- `md::fmi2ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `fmu::FMU2`:  Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `name::String`: Argument `names` contains a String or a list of Strings. For each string ("variable name"), the corresponding value reference is searched in the given modelDescription.
- `name::Union{String, AbstractArray{String}}`: Argument `names` contains a Strings or AbstractArray{String}. For that, the corresponding value reference is searched in the given modelDescription.
# Returns
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::Sting`:
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::AbstractArray{String}`
- `ar::Array{fmi2ScalarVariable}`: Return `ar` is an array of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference to the input variable vr.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions
See also [`fmi2StringToValueReference`](@ref)
"""
function fmi2StringToValueReference(md::fmi2ModelDescription, name::String)
    reference = nothing
    if haskey(md.stringValueReferences, name)
        reference = md.stringValueReferences[name]
    else
        @warn "No variable named '$name' found."
    end
    reference
end

"""
Returns the ValueReference or an array of ValueReferences coresponding to the variable names.
"""
function fmi2StringToValueReference(fmu::FMU2, name::Union{String, AbstractArray{String}})
    fmi2StringToValueReference(fmu.modelDescription, name)
end

"""

   fmi2ValueReferenceToString(md::fmi2ModelDescription, reference::fmi2ValueReference)

   fmi2ValueReferenceToString(md::fmi2ModelDescription, reference::Int64)

   fmi2ValueReferenceToString(fmu::FMU2, reference::Union{fmi2ValueReference, Int64})

# Arguments
- `md::fmi2ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `reference::fmi2ValueReference`: The argument `references` is a variable of the type `ValueReference`.
- `reference::Int64`: Argument `references` is a variable of the type `Int64`.
- `reference::Union{fmi2ValueReference, Int64}`: Argument `references` of the type `fmi2ValueReference` or `Int64`.

# Return
- `md.stringValueReferences::Dict{String, fmi2ValueReference}`: Returns a dictionary `md.stringValueReferences` that constructs a hash table with keys of type String and values of type fmi2ValueReference.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
"""
function fmi2ValueReferenceToString(md::fmi2ModelDescription, reference::fmi2ValueReference)
    [k for (k,v) in md.stringValueReferences if v == reference]
end
function fmi2ValueReferenceToString(md::fmi2ModelDescription, reference::Int64)
    fmi2ValueReferenceToString(md, fmi2ValueReference(reference))
end

function fmi2ValueReferenceToString(fmu::FMU2, reference::Union{fmi2ValueReference, Int64})
    fmi2ValueReferenceToString(fmu.modelDescription, reference)
end


"""

   fmi2GetSolutionState(solution::FMU2Solution, vr::fmi2ValueReferenceFormat; isIndex::Bool=false)

Returns the Solution state.

# Arguments
- `solution::FMU2Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.
- `vr::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `isIndex::Bool=false`: Argument `isIndex` exists to check if `vr` ist the spezific solution element ("index") that equals the given fmi2ValueReferenceFormat

# Return
- If `isIndex = false` the function returns an array which contains the solution states till the spezific solution element ("index") that equals the given fmi2ValueReferenceFormat.
- If `isIndex = true` the function return an array which contains the solution states till the spezific solution element ("index").
- If no solution element ("index = 0") is found `nothing` is returned.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)

"""

function fmi2GetSolutionState(solution::FMU2Solution, vr::fmi2ValueReferenceFormat; isIndex::Bool=false)

    index = 0

    if isIndex
        index = vr
    else
        ignore_derivatives() do
            vr = prepareValueReference(solution.fmu, vr)[1]

            if solution.states !== nothing
                for i in 1:length(solution.fmu.modelDescription.stateValueReferences)
                    if solution.fmu.modelDescription.stateValueReferences[i] == vr
                        index = i
                        break
                    end
                end
            end

        end # ignore_derivatives
    end

    if index > 0
        return collect(u[index] for u in solution.states.u)
    end

    return nothing
end

"""

   fmi2GetSolutionValue(solution::FMU2Solution, vr::fmi2ValueReferenceFormat; isIndex::Bool=false)

Returns the Solution values.

# Arguments
- `solution::FMU2Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.
- `vr::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `isIndex::Bool=false`: Argument `isIndex` exists to check if `vr` ist the spezific solution element ("index") that equals the given fmi2ValueReferenceFormat

# Return
- If `isIndex = false` the function returns an array which contains the solution states till the spezific solution element ("index") that equals the given fmi2ValueReferenceFormat.
- If `isIndex = true` the function return an array which contains the solution values till the spezific solution element ("index").
- If no solution element ("index = 0") is found `nothing` is returned.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
"""

function fmi2GetSolutionValue(solution::FMU2Solution, vr::fmi2ValueReferenceFormat; isIndex::Bool=false)

    index = 0

    if isIndex
        index = vr
    else
        ignore_derivatives() do
            vr = prepareValueReference(solution.fmu, vr)[1]

            if solution.states !== nothing
                for i in 1:length(solution.fmu.modelDescription.stateValueReferences)
                    if solution.fmu.modelDescription.stateValueReferences[i] == vr
                        index = i
                        break
                    end
                end
            end

            if index > 0
                return collect(u[index] for u in solution.states.u)
            end

            if solution.values !== nothing
                for i in 1:length(solution.valueReferences)
                    if solution.valueReferences[i] == vr
                        index = i
                        break
                    end
                end
            end

        end # ignore_derivatives
    end

    if index > 0
        return collect(v[index] for v in solution.values.saveval)
    end

    return nothing
end

"""

   fmi2GetSolutionTime(solution::FMU2Solution)

Returns the Solution time.

# Arguments
- `solution::FMU2Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.

# Return
- `solution.states.t::tType`: `solution.state` is a struct `ODESolution` with attribute t. `t` is the time points corresponding to the saved values of the ODE solution.
- `solution.values.t::tType`: `solution.value` is a struct `ODESolution` with attribute t.`t` the time points corresponding to the saved values of the ODE solution.
- If no solution time is  found `nothing` is returned.

#Source
- using OrdinaryDiffEq: [ODESolution](https://github.com/SciML/SciMLBase.jl/blob/b10025c579bcdecb94b659aa3723fdd023096197/src/solutions/ode_solutions.jl)  (SciML/SciMLBase.jl)
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.22]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
"""

function fmi2GetSolutionTime(solution::FMU2Solution)
    if solution.states !== nothing
        return solution.states.t
    elseif solution.values !== nothing
        return solution.values.t
    else
        return nothing
    end
end
