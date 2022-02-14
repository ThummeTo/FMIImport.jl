#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# Receives one or an array of value references in an arbitrary format (see fmi2ValueReferenceFormat) and converts it into an Array{fmi2ValueReference} (if not already).
function prepareValueReference(md::fmi2ModelDescription, vr::fmi2ValueReferenceFormat)
    tvr = typeof(vr)
    if tvr == Array{fmi2ValueReference,1}
        return vr
    elseif tvr == fmi2ValueReference
        return [vr]
    elseif tvr == String
        return [fmi2StringToValueReference(md, vr)]
    elseif tvr == Array{String,1}
        return fmi2StringToValueReference(md, vr)
    elseif tvr == Int64
        return [fmi2ValueReference(vr)]
    elseif tvr == Array{Int64,1}
        return fmi2ValueReference.(vr)
    elseif tvr == Nothing
        return Array{fmi2ValueReference,1}()
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
Returns an array of ValueReferences coresponding to the variable names.
"""
function fmi2StringToValueReference(md::fmi2ModelDescription, names::Array{String})
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
Returns the model variable(s) fitting the value reference.
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
Returns the ValueReference coresponding to the variable name.
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

function fmi2StringToValueReference(fmu::FMU2, name::Union{String, Array{String}})
    fmi2StringToValueReference(fmu.modelDescription, name)
end

"""
Returns an array of variable names matching a fmi2ValueReference.
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