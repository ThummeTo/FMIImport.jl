#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function prepareValueReference(md::fmi3ModelDescription, vr::fmi3ValueReferenceFormat)
    tvr = typeof(vr)
    if tvr == Array{fmi3ValueReference,1}
        return vr
    elseif tvr == fmi3ValueReference
        return [vr]
    elseif tvr == String
        return [fmi3String2ValueReference(md, vr)]
    elseif tvr == Array{String,1}
        return fmi3String2ValueReference(md, vr)
    elseif tvr == Int64
        return [fmi3ValueReference(vr)]
    elseif tvr == Array{Int64,1}
        return fmi3ValueReference.(vr)
    elseif tvr == Nothing
        return Array{fmi3ValueReference,1}()
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
function fmi3String2ValueReference(md::fmi3ModelDescription, names::Array{String})
    vr = Array{fmi3ValueReference}(undef,0)
    for name in names
        reference = fmi3String2ValueReference(md, name)
        if reference === nothing
            @warn "Value reference for variable '$name' not found, skipping."
        else
            push!(vr, reference)
        end
    end
    vr
end

"""
Returns the ValueReference coresponding to the variable name.
"""
function fmi3String2ValueReference(md::fmi3ModelDescription, name::String)
    reference = nothing
    if haskey(md.stringValueReferences, name)
        reference = md.stringValueReferences[name]
    else
        @warn "No variable named '$name' found."
    end
    reference
end

function fmi3String2ValueReference(fmu::FMU3, name::Union{String, Array{String}})
    fmi3String2ValueReference(fmu.modelDescription, name)
end

"""
Returns an array of variable names matching a fmi3ValueReference.
"""
function fmi3ValueReference2String(md::fmi3ModelDescription, reference::fmi3ValueReference)
    [k for (k,v) in md.stringValueReferences if v == reference]
end
function fmi3ValueReference2String(md::fmi3ModelDescription, reference::Int64)
    fmi3ValueReference2String(md, fmi3ValueReference(reference))
end

function fmi3ValueReference2String(fmu::FMU3, reference::Union{fmi3ValueReference, Int64})
    fmi3ValueReference2String(fmu.modelDescription, reference)
end