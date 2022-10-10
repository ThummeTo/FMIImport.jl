# STATUS: no todos
# ABM: done

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
Returns an array of ValueReferences coresponding to the variable names.
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
Returns the model variable(s) fitting the value reference.
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
Returns the ValueReference coresponding to the variable name.
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

function fmi3StringToValueReference(fmu::FMU3, name::Union{String, AbstractArray{String}})
    fmi3StringToValueReference(fmu.modelDescription, name)
end

"""
Returns an array of variable names matching a fmi3ValueReference.
"""
function fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::fmi3ValueReference)
    [k for (k,v) in md.stringValueReferences if v == reference]
end
function fmi3ValueReferenceToString(md::fmi3ModelDescription, reference::Int64)
    fmi3ValueReferenceToString(md, fmi3ValueReference(reference))
end

function fmi3ValueReferenceToString(fmu::FMU3, reference::Union{fmi3ValueReference, Int64})
    fmi3ValueReferenceToString(fmu.modelDescription, reference)
end

"""
todo
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
Todo
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
Todo
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