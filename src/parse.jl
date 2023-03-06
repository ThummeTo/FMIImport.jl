
#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# Parses a Bool value represented by a string.
function parseBoolean(s::Union{String, SubString{String}}; onfail=nothing)
    if s == "true"
        return true
    elseif s == "false"
        return false
    else
        @assert onfail != nothing ["parseBoolean(...) unknown boolean value '$s'."]
        return onfail
    end
end

# parses node (interpreted as boolean)
function parseNodeBoolean(node, key; onfail=nothing)
    if haskey(node, key)
        return parseBoolean(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# Parses an Integer value represented by a string.
function parseType(s::Union{String, SubString{String}}, type; onfail=nothing)
    if onfail == nothing
        return parse(type, s)
    else
        try
            return parse(type, s)
        catch
            return onfail
        end
    end
end

function parseInteger(s::Union{String, SubString{String}}; kwargs...)
    return parseType(s, Int; kwargs...)
end

function parseUInt(s::Union{String, SubString{String}}; kwargs...)
    return parseType(s, UInt; kwargs...)
end

# parses node (interpreted as integer)
function parseNodeInteger(node, key; onfail=nothing)
    if haskey(node, key)
        return parseInteger(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# parses node (interpreted as integer)
function parseNodeUInt(node, key; onfail=nothing)
    if haskey(node, key)
        return parseUInt(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# Parses a real value represented by a string.
function parseReal(s::Union{String, SubString{String}}; onfail=nothing)
    if onfail == nothing
        return parse(fmi2Real, s)
    else
        try
            return parse(fmi2Real, s)
        catch
            return onfail
        end
    end
end

# parses node (interpreted as real)
function parseNodeReal(node, key; onfail=nothing)
    if haskey(node, key)
        return parseReal(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# parses node (interpreted as string)
function parseNodeString(node, key; onfail=nothing)
    if haskey(node, key)
        return node[key]
    else
        return onfail
    end
end

# Parses a fmi2Boolean value represented by a string.
function parseFMI2Boolean(s::Union{String, SubString{String}})
    if parseBoolean(s)
        return fmi2True
    else
        return fmi2False
    end
end