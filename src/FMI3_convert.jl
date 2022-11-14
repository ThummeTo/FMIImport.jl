#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using ChainRulesCore: ignore_derivatives

# Receives one or an array of value references in an arbitrary format (see fmi3ValueReferenceFormat) and converts it into an Array{fmi3ValueReference} (if not already).
function prepareValueReference(md::fmi3ModelDescription, vr::fmi3ValueReferenceFormat)
    tvr = typeof(vr)
    if isa(vr, AbstractArray{fmi3ValueReference,1})
        return vr
    elseif tvr == fmi3ValueReference
        return [vr]
    elseif tvr == String
        return [fmi3StringToValueReference(md, vr)]
    elseif isa(vr, AbstractArray{String,1})
        return fmi3StringToValueReference(md, vr)
    elseif tvr == Int64
        return [fmi3ValueReference(vr)]
    elseif isa(vr, AbstractArray{Int64,1})
        return fmi3ValueReference.(vr)
    elseif tvr == Nothing
        return Array{fmi3ValueReference,1}()
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
            return Array{fmi3ValueReference,1}()
        else
            @assert false "Unknwon symbol `$vr`, can't convert to value reference."
        end
    end

    @assert false "prepareValueReference(...): Unknown value reference structure `$tvr`."
end
function prepareValueReference(fmu::FMU3, vr::fmi3ValueReferenceFormat)
    prepareValueReference(fmu.modelDescription, vr)
end
function prepareValueReference(comp::FMU3Instance, vr::fmi3ValueReferenceFormat)
    prepareValueReference(comp.fmu.modelDescription, vr)
end

"""

    fmi3StringToValueReference(md::fmi3ModelDescription, names::AbstractArray{String})

Returns an array of ValueReferences coresponding to the variable names.

# Arguments
- `md::fmi3ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `names::AbstractArray{String}`: Argument `names` contains a list of Strings. For each string ("variable name"), the corresponding value reference is searched in the given modelDescription.

# Returns
- `vr:Array{fmi3ValueReference}`: Return `vr` is an array of `ValueReference` coresponding to the variable names.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 

See also [`fmi3StringToValueReference`](@ref).
"""
function fmi3StringToValueReference(md::fmi3ModelDescription, names::AbstractArray{String})
    vr = Array{fmi3ValueReference}(undef,0)
    for name in names
        reference = fmi3StringToValueReference(md, name)
        if reference === nothing
            @warn "Value reference for variable '$name' not found, skipping."
        else
            push!(vr, reference)
        end
    end
    vr
end

""" 

    fmi3ModelVariablesForValueReference(md::fmi3ModelDescription, vr::fmi3ValueReference)

Returns an array of ValueReferences coresponding to the variable names.

# Arguments
- `md::fmi3ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `vr::fmi3ValueReference`: Argument `vr` contains a value of type`fmi3ValueReference` which are identifiers of a variable value of the model.

# Returns
- `ar::Array{fmi3ModelVariable}`: Return `ar` is an array of `fmi3ModelVariable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 

See also [`fmi3ModelVariablesForValueReference`](@ref).
"""
function fmi3ModelVariablesForValueReference(md::fmi3ModelDescription, vr::fmi3ValueReference)
    ar = []
    for modelVariable in md.modelVariables
        if modelVariable.valueReference == vr 
            push!(ar, modelVariable)
        end 
    end 
    ar
end

"""

    fmi3StringToValueReference(md::fmi3ModelDescription, name::String)

Returns the ValueReference or an array of ValueReferences coresponding to the variable names.

# Arguments
- `md::fmi3ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `name::String`: Argument `names` contains a String or a list of Strings. For each string ("variable name"), the corresponding value reference is searched in the given modelDescription.
- `name::Union{String, AbstractArray{String}}`: Argument `names` contains a Strings or AbstractArray{String}. For that, the corresponding value reference is searched in the given modelDescription.

# Returns
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::Sting`:
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::AbstractArray{String}`
- `ar::Array{fmi3ModelVariable}`: Return `ar` is an array of `fmi3ModelVariable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 

See also [`fmi3StringToValueReference`](@ref)
"""
function fmi3StringToValueReference(md::fmi3ModelDescription, name::String)
    reference = nothing
    if haskey(md.stringValueReferences, name)
        reference = md.stringValueReferences[name]
    else
        @warn "No variable named '$name' found."
    end
    reference
end

"""

    fmi3StringToValueReference(md::fmi3ModelDescription, name::String)

Returns the ValueReference or an array of ValueReferences coresponding to the variable names.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.
- `name::String`: Argument `names` contains a String or a list of Strings. For each string ("variable name"), the corresponding value reference is searched in the given modelDescription.
- `name::Union{String, AbstractArray{String}}`: Argument `names` contains a Strings or AbstractArray{String}. For that, the corresponding value reference is searched in the given modelDescription.

# Returns
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::Sting`:
- `reference::md.stringValueReferences`: Return `references` is an array of `ValueReference` coresponding to the variable name.
For input parameter `name::AbstractArray{String}`
- `ar::Array{fmi3ModelVariable}`: Return `ar` is an array of `fmi3ModelVariable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 

See also [`fmi3StringToValueReference`](@ref)
"""
function fmi3StringToValueReference(fmu::FMU3, name::Union{String, AbstractArray{String}})
    fmi3StringToValueReference(fmu.modelDescription, name)
end

"""

    fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::fmi3ValueReference)

# Arguments
- `md::fmi3ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `reference::fmi3ValueReference`: The argument `references` is a variable of the type `ValueReference`.

# Return
- `md.stringValueReferences::Dict{String, fmi3ValueReference}`: Returns a dictionary `md.stringValueReferences` that constructs a hash table with keys of type String and values of type fmi3ValueReference.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::fmi3ValueReference)
    [k for (k,v) in md.stringValueReferences if v == reference]
end

"""

    fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::Int64)

# Arguments
- `md::fmi3ModelDescription`: Argument `md` stores all static information related to an FMU. Especially, the FMU variables and their attributes such as name, unit, default initial value, etc..
- `reference::Int64`: Argument `references` is a variable of the type `Int64`.

# Return
- `md.stringValueReferences::Dict{String, fmi3ValueReference}`: Returns a dictionary `md.stringValueReferences` that constructs a hash table with keys of type String and values of type fmi3ValueReference.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::Int64)
    fmi3ValueReferenceToString(md, fmi3ValueReference(reference))
end

"""

    fmi3ValueReferenceToString(fmu::FMU3, reference::Union{fmi3ValueReference, Int64})

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.
- `reference::Union{fmi3ValueReference, Int64}`: Argument `references` of the type `fmi3ValueReference` or `Int64`.

# Return
- `md.stringValueReferences::Dict{String, fmi3ValueReference}`: Returns a dictionary `md.stringValueReferences` that constructs a hash table with keys of type String and values of type fmi3ValueReference.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3ValueReferenceToString(fmu::FMU3, reference::Union{fmi3ValueReference, Int64})
    fmi3ValueReferenceToString(fmu.modelDescription, reference)
end

"""

    fmi3GetSolutionState(solution::FMU3Solution, vr::fmi3ValueReferenceFormat; isIndex::Bool=false)

Returns the Solution state.

# Arguments
- `solution::FMU3Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `isIndex::Bool=false`: Argument `isIndex` exists to check if `vr` ist the spezific solution element ("index") that equals the given fmi3ValueReferenceFormat

# Return
- If `isIndex = false` the function returns an array which contains the solution states till the spezific solution element ("index") that equals the given fmi3ValueReferenceFormat.
- If `isIndex = true` the function return an array which contains the solution states till the spezific solution element ("index").
- If no solution element ("index = 0") is found `nothing` is returned.


# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3GetSolutionState(solution::FMU3Solution, vr::fmi3ValueReferenceFormat; isIndex::Bool=false)
 
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

    fmi3GetSolutionValue(solution::FMU3Solution, vr::fmi3ValueReferenceFormat; isIndex::Bool=false)

Returns the Solution values.

# Arguments
- `solution::FMU3Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.
- `vr::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `isIndex::Bool=false`: Argument `isIndex` exists to check if `vr` ist the spezific solution element ("index") that equals the given fmi3ValueReferenceFormat

# Return
- If `isIndex = false` the function returns an array which contains the solution states till the spezific solution element ("index") that equals the given fmi3ValueReferenceFormat.
- If `isIndex = true` the function return an array which contains the solution values till the spezific solution element ("index").
- If no solution element ("index = 0") is found `nothing` is returned.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3GetSolutionValue(solution::FMU3Solution, vr::fmi3ValueReferenceFormat; isIndex::Bool=false)

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

    fmi3GetSolutionTime(solution::FMU3Solution)

Returns the Solution time.

# Arguments
- `solution::FMU3Solution`: Struct contains information about the solution `value`, `success`, `state` and  `events` of a specific FMU.

# Return
- `solution.states.t::tType`: `solution.state` is a struct `ODESolution` with attribute t. `t` is the time points corresponding to the saved values of the ODE solution.
- `solution.values.t::tType`: `solution.value` is a struct `ODESolution` with attribute t.`t` the time points corresponding to the saved values of the ODE solution.
- If no solution time is  found `nothing` is returned.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.3 Platform Dependent Definitions 
"""
function fmi3GetSolutionTime(solution::FMU3Solution)
    if solution.states !== nothing 
        return solution.states.t
    elseif solution.values !== nothing 
        return solution.values.t
    else
        return nothing
    end
end