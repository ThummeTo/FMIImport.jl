#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function parseNode(node, key, type::DataType=String; onfail=nothing)
    if haskey(node, key)
        return parseType(node[key], type; onfail=onfail)
    else
        return onfail
    end
end

function parseType(s::Union{String, SubString{String}}, type; onfail=nothing)
    if onfail == nothing
        return _parse(type, s)
    else
        try
            return _parse(type, s)
        catch
            return onfail
        end
    end
end

function _parse(type, s)
    if s == "true"
        return true
    elseif s == "false"
        return false
    elseif type == String || type == Ptr{UInt8} # fmi3String
        return s
    else
        return parse(type, s)
    end
end

parseNodeBoolean(node, key; onfail=nothing) = parseNode(node, key, Bool; onfail=onfail)

# function parseNodeBoolean(node, key; onfail=nothing)
#     if haskey(node, key)
#         return parseBoolean(node[key]; onfail=onfail)
#     else
#         return onfail
#     end
# end
# function parseBoolean(s::Union{String, SubString{String}}; onfail=nothing)
#     if onfail == nothing
#         return _parseBoolean(s)
#     else
#         try
#             return _parseBoolean(s)
#         catch
#             return onfail
#         end
#     end
# end
# function _parseBoolean(s)
#     if s == "1"
#         return fmi2True # = fmi3True
#     elseif s == "0"
#         return fmi2False # = fmi3False
#     else
#         @assert false "parse(...) unknown boolean value '$s'."
#     end
# end

# [Todo]
function parseArrayValueReferences(md::fmi2ModelDescription, s::Union{String, SubString{String}})
    references = Array{fmi2ValueReference}(undef, 0)
    substrings = split(s, " ")

    for string in substrings
        push!(references, parse(fmi2ValueReferenceFormat, string))
    end
    
    return references
end
function parseArrayValueReferences(md::fmi3ModelDescription, s::Union{String, SubString{String}})
    references = Array{fmi3ValueReference}(undef, 0)
    substrings = split(s, " ")

    for string in substrings
        push!(references, parse(fmi3ValueReferenceFormat, string))
    end
    
    return references
end
function parseArrayValueReferences(md::fmiModelDescription, s::Nothing)
    return nothing
end