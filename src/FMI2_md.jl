#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_md.jl` (model description)?
# - [Sec. 1a] the function `fmi2LoadModelDescription` to load/parse the FMI model description [exported]
# - [Sec. 1b] helper functions for the load/parse function [not exported]
# - [Sec. 2]  functions to get values from the model description in the format `fmi2Get[value](md::fmi2ModelDescription)` [exported]
# - [Sec. 3]  additional functions to get useful information from the model description in the format `fmi2Get[value](md::fmi2ModelDescription)` [exported]

using EzXML

using FMICore: fmi2ModelDescriptionModelExchange, fmi2ModelDescriptionCoSimulation, fmi2ModelDescriptionDefaultExperiment
using FMICore: fmi2ModelDescriptionReal, fmi2ModelDescriptionBoolean, fmi2ModelDescriptionInteger, fmi2ModelDescriptionString, fmi2ModelDescriptionEnumeration
using FMICore: fmi2ModelDescriptionModelStructure
using FMICore: fmi2DependencyKind
using FMICore: FMU2

######################################
# [Sec. 1a] fmi2LoadModelDescription #
######################################

"""
Extract the FMU variables and meta data from the ModelDescription

ToDo: New docstring format!
"""
function fmi2LoadModelDescription(pathToModellDescription::String)
    md = fmi2ModelDescription()

    md.stringValueReferences = Dict{String, fmi2ValueReference}()
    md.outputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.inputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.stateValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.derivativeValueReferences = Array{fmi2ValueReference}(undef, 0)

    md.enumerations = []
    typedefinitions = nothing
    modelvariables = nothing
    modelstructure = nothing

    doc = readxml(pathToModellDescription)

    root = doc.root

    # mandatory
    md.fmiVersion = root["fmiVersion"]
    md.modelName = root["modelName"]
    md.guid = root["guid"]
    
    # optional
    md.generationTool           = parseNodeString(root, "generationTool"; onfail="[Unknown generation tool]")
    md.generationDateAndTime    = parseNodeString(root, "generationDateAndTime"; onfail="[Unknown generation date and time]")
    variableNamingConventionStr = parseNodeString(root, "variableNamingConvention"; onfail="flat")
    @assert (variableNamingConventionStr == "flat" || variableNamingConventionStr == "structured") ["fmi2ReadModelDescription(...): Unknown entry for `variableNamingConvention=$(variableNamingConventionStr)`."]
    md.variableNamingConvention = (variableNamingConventionStr == "flat" ? fmi2VariableNamingConventionFlat : fmi2VariableNamingConventionStructured)
    md.numberOfEventIndicators  = parseNodeInteger(root, "numberOfEventIndicators"; onfail=0)
    md.description              = parseNodeString(root, "description"; onfail="[Unknown Description]")

    # defaults
    md.modelExchange = nothing
    md.coSimulation = nothing
    md.defaultExperiment = nothing

    # additionals 
    md.valueReferences = []
    md.valueReferenceIndicies = Dict{UInt, UInt}()
    
    for node in eachelement(root)

        if node.name == "CoSimulation" || node.name == "ModelExchange"
            if node.name == "CoSimulation"
                md.coSimulation = fmi2ModelDescriptionCoSimulation()
                md.coSimulation.modelIdentifier                        = node["modelIdentifier"]
                md.coSimulation.canHandleVariableCommunicationStepSize = parseNodeBoolean(node, "canHandleVariableCommunicationStepSize"   ; onfail=false)
                md.coSimulation.canInterpolateInputs                   = parseNodeBoolean(node, "canInterpolateInputs"                     ; onfail=false)
                md.coSimulation.maxOutputDerivativeOrder               = parseNodeInteger(node, "maxOutputDerivativeOrder"                 ; onfail=nothing)
                md.coSimulation.canGetAndSetFMUstate                   = parseNodeBoolean(node, "canGetAndSetFMUstate"                     ; onfail=false)
                md.coSimulation.canSerializeFMUstate                   = parseNodeBoolean(node, "canSerializeFMUstate"                     ; onfail=false)
                md.coSimulation.providesDirectionalDerivative          = parseNodeBoolean(node, "providesDirectionalDerivative"            ; onfail=false)
            end

            if node.name == "ModelExchange"
                md.modelExchange = fmi2ModelDescriptionModelExchange()
                md.modelExchange.modelIdentifier                        = node["modelIdentifier"]
                md.modelExchange.canGetAndSetFMUstate                   = parseNodeBoolean(node, "canGetAndSetFMUstate"                     ; onfail=false)
                md.modelExchange.canSerializeFMUstate                   = parseNodeBoolean(node, "canSerializeFMUstate"                     ; onfail=false)
                md.modelExchange.providesDirectionalDerivative          = parseNodeBoolean(node, "providesDirectionalDerivative"            ; onfail=false)
            end
        elseif node.name == "TypeDefinitions"
            md.enumerations = createEnum(node)

        elseif node.name == "ModelVariables"
            md.modelVariables = parseModelVariables(node, md)

        elseif node.name == "ModelStructure"
            md.modelStructure = fmi2ModelDescriptionModelStructure()

            for element in eachelement(node)
                if element.name == "Derivatives" 
                    parseDerivatives(element, md)
                elseif element.name == "InitialUnknowns"
                    parseInitialUnknowns(element, md)
                elseif element.name == "Outputs"
                    parseOutputs(element, md)
                else
                    @warn "Unknown tag `$(element.name)` for node `ModelStructure`."
                end
            end

        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi2ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNodeReal(node, "startTime")
            md.defaultExperiment.stopTime   = parseNodeReal(node, "stopTime")
            md.defaultExperiment.tolerance  = parseNodeReal(node, "tolerance")
            md.defaultExperiment.stepSize   = parseNodeReal(node, "stepSize")
        end
    end

    # creating an index for value references (fast look-up for dependencies)
    for i in 1:length(md.valueReferences)
        md.valueReferenceIndicies[md.valueReferences[i]] = i
    end 

    md
end

#######################################
# [Sec. 1b] helpers for load function #
#######################################

# Returns the indices of the state derivatives.
function getDerivativeIndices(node::EzXML.Node)
    indices = []
    for element in eachelement(node)
        if element.name == "Derivatives"
            for derivative in eachelement(element)
                ind = parse(Int, derivative["index"])
                der = nothing 
                derKind = nothing 

                if haskey(derivative, "dependencies")
                    der = split(derivative["dependencies"], " ")

                    if der[1] == ""
                        der = fmi2Integer[]
                    else
                        der = collect(parse(fmi2Integer, e) for e in der)
                    end
                end 

                if haskey(derivative, "dependenciesKind")
                    derKind = split(derivative["dependenciesKind"], " ")
                end 

                push!(indices, (ind, der, derKind))
            end
        end
    end
    sort!(indices, rev=true)
end

# Parses the model variables of the FMU model description.
function parseModelVariables(nodes::EzXML.Node, md::fmi2ModelDescription)
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    scalarVariables = Array{fmi2ScalarVariable}(undef, numberOfVariables)

    index = 1
    for node in eachelement(nodes)
        name = node["name"]
        valueReference = parse(fmi2ValueReference, node["valueReference"])

        scalarVariables[index] = fmi2ScalarVariable(name, valueReference)
        
        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        if haskey(node, "description")
            scalarVariables[index].description = node["description"]
        end
        if haskey(node, "causality")
            scalarVariables[index].causality = fmi2StringToCausality(node["causality"])

            if scalarVariables[index].causality == fmi2CausalityOutput
                push!(md.outputValueReferences, valueReference)
            elseif scalarVariables[index].causality == fmi2CausalityInput
                push!(md.inputValueReferences, valueReference)
            end
        end
        if haskey(node, "variability")
            scalarVariables[index].variability = fmi2StringToVariability(node["variability"])
        end
        if haskey(node, "initial")
            scalarVariables[index].initial = fmi2StringToInitial(node["initial"])
        end

        # type node
        typenode = nothing
        typename = node.firstelement.name

        if typename == "Real"
            scalarVariables[index]._Real = fmi2ModelDescriptionReal()
            typenode = scalarVariables[index]._Real
            if haskey(node.firstelement, "quantity")
                typenode.quantity = node.firstelement["quantity"]
            end
            if haskey(node.firstelement, "unit")
                typenode.unit = node.firstelement["unit"]
            end
            if haskey(node.firstelement, "displayUnit")
                typenode.displayUnit = node.firstelement["displayUnit"]
            end
            if haskey(node.firstelement, "relativeQuantity")
                typenode.relativeQuantity = parseBoolean(node.firstelement["relativeQuantity"])
            end
            if haskey(node.firstelement, "min")
                typenode.min = parseReal(node.firstelement["min"])
            end
            if haskey(node.firstelement, "max")
                typenode.max = parseReal(node.firstelement["max"])
            end
            if haskey(node.firstelement, "nominal")
                typenode.nominal = parseReal(node.firstelement["nominal"])
            end
            if haskey(node.firstelement, "unbounded")
                typenode.unbounded = parseBoolean(node.firstelement["unbounded"])
            end
            if haskey(node.firstelement, "start")
                typenode.start = parseReal(node.firstelement["start"])
            end
            if haskey(node.firstelement, "derivative")
                typenode.derivative = parse(UInt, node.firstelement["derivative"])
            end
        elseif typename == "String"
            scalarVariables[index]._String = fmi2ModelDescriptionString()
            typenode = scalarVariables[index]._String
            if haskey(node.firstelement, "start")
                scalarVariables[index]._String.start = node.firstelement["start"]
            end
            # ToDo: remaining attributes
        elseif typename == "Boolean"
            scalarVariables[index]._Boolean = fmi2ModelDescriptionBoolean()
            typenode = scalarVariables[index]._Boolean
            if haskey(node.firstelement, "start")
                scalarVariables[index]._Boolean.start = parseFMI2Boolean(node.firstelement["start"])
            end
            # ToDo: remaining attributes
        elseif typename == "Integer"
            scalarVariables[index]._Integer = fmi2ModelDescriptionInteger()
            typenode = scalarVariables[index]._Integer
            if haskey(node.firstelement, "start")
                scalarVariables[index]._Integer.start = parseInteger(node.firstelement["start"])
            end
            # ToDo: remaining attributes
        elseif typename == "Enumeration"
            scalarVariables[index]._Enumeration = fmi2ModelDescriptionEnumeration()
            typenode = scalarVariables[index]._Enumeration
            # ToDo: Save start value
            # ToDo: remaining attributes
        else 
            @warn "Unknown data type `$(typename)`."
        end

        # generic attributes
        if typenode != nothing 
            if haskey(node.firstelement, "declaredType")
                typenode.declaredType = node.firstelement["declaredType"]
            end
        end

        md.stringValueReferences[name] = valueReference

        index += 1
    end
   
    scalarVariables
end

# Parses the `ModelStructure.Derivatives` of the FMU model description.
function parseUnknwon(node::EzXML.Node)
    if haskey(node, "index")
        varDep = fmi2VariableDependency(parseInteger(node["index"]))

        if haskey(node, "dependencies")
            dependencies = node["dependencies"]
            if length(dependencies) > 0
                dependenciesSplit = split(dependencies, " ")
                if length(dependenciesSplit) > 0
                    varDep.dependencies = collect(parse(UInt, e) for e in dependenciesSplit)
                end
            end
        end 

        if haskey(node, "dependenciesKind")
            dependenciesKind = node["dependenciesKind"]
            if length(dependenciesKind) > 0
                dependenciesKindSplit = split(dependenciesKind, " ")
                if length(dependenciesKindSplit) > 0
                    varDep.dependenciesKind = collect(fmi2StringToDependencyKind(e) for e in dependenciesKindSplit)
                end
            end
        end

        if varDep.dependencies != nothing && varDep.dependenciesKind != nothing
            if length(varDep.dependencies) != length(varDep.dependenciesKind)
                @warn "Length of field dependencies ($(length(varDep.dependencies))) doesn't match length of dependenciesKind ($(length(varDep.dependenciesKind)))."   
            end
        end

        return varDep
    else 
        return nothing 
    end
end 

# ToDo: Comment
function parseDerivatives(nodes::EzXML.Node, md::fmi2ModelDescription)
    @assert (nodes.name == "Derivatives") "Wrong element name."
    md.modelStructure.derivatives = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknwon(node)

                # find states and derivatives
                derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV._Real.derivative].valueReference

                if stateVR ∉ md.stateValueReferences
                    push!(md.stateValueReferences, stateVR)
                end
                if derVR ∉ md.derivativeValueReferences
                    push!(md.derivativeValueReferences, derVR)
                end

                push!(md.modelStructure.derivatives, varDep)
            else 
                @warn "Invalid entry for node `Unknown` in `ModelStructure`, missing entry `index`."
            end
        else 
            @warn "Unknown entry in `ModelStructure.Derivatives` named `$(node.name)`."
        end 
    end
end

# ToDo: Comment
function parseInitialUnknowns(nodes::EzXML.Node, md::fmi2ModelDescription)
    @assert (nodes.name == "InitialUnknowns") "Wrong element name."
    md.modelStructure.initialUnknowns = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknwon(node)

                push!(md.modelStructure.initialUnknowns, varDep)
            else 
                @warn "Invalid entry for node `Unknown` in `ModelStructure`, missing entry `index`."
            end
        else 
            @warn "Unknown entry in `ModelStructure.InitialUnknowns` named `$(node.name)`."
        end 
    end
end

# ToDo: Comment
function parseOutputs(nodes::EzXML.Node, md::fmi2ModelDescription)
    @assert (nodes.name == "Outputs") "Wrong element name."
    md.modelStructure.outputs = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknwon(node)

                # find outputs
                outVR = md.modelVariables[varDep.index].valueReference
                
                if outVR ∉ md.outputValueReferences
                    push!(md.outputValueReferences, outVR)
                end

                push!(md.modelStructure.outputs, varDep)
            else 
                @warn "Invalid entry for node `Unknown` in `ModelStructure`, missing entry `index`."
            end
        else 
            @warn "Unknown entry in `ModelStructure.Outputs` named `$(node.name)`."
        end 
    end
end

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
function parseInteger(s::Union{String, SubString{String}}; onfail=nothing)
    if onfail == nothing
        return parse(fmi2Integer, s)
    else
        try
            return parse(fmi2Integer, s)
        catch
            return onfail
        end
    end
end

# parses node (interpreted as integer)
function parseNodeInteger(node, key; onfail=nothing)
    if haskey(node, key)
        return parseInteger(node[key]; onfail=onfail)
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

# set the datatype and attributes of an model variable
function fmi2SetDatatypeVariables(node::EzXML.Node, md::fmi2ModelDescription, sv)
    type = fmi2DatatypeVariable()
    typenode = node.firstelement
    typename = typenode.name
    type.start = nothing
    type.min = nothing
    type.max = nothing
    type.quantity = nothing
    type.unit = nothing
    type.displayUnit = nothing
    type.relativeQuantity = nothing
    type.nominal = nothing
    type.unbounded = nothing
    type.derivative = nothing
    type.reinit = nothing
    type.datatype = nothing

    if typename == "Real"
        type.datatype = fmi2Real
        sv._Real = fmi2ModelDescriptionReal()
    elseif typename == "String"
        type.datatype = fmi2String
    elseif typename == "Boolean"
        type.datatype = fmi2Boolean
    elseif typename == "Integer"
        type.datatype = fmi2Integer
    elseif typename == "Enumeration"
        type.datatype = fmi2Enum
    else 
        @warn "Unknown data type `$(type.datatype)`."
    end

    if haskey(typenode, "declaredType")
        type.declaredType = typenode["declaredType"]
    end

    if haskey(typenode, "start")
        if typename == "Real"
            type.start = parse(fmi2Real, typenode["start"])
            sv._Real.start = type.start
        elseif typename == "Integer"
            type.start = parse(fmi2Integer, typenode["start"])
        elseif typename == "Boolean"
            type.start = parseFMI2Boolean(typenode["start"])
        elseif typename == "Enumeration"
            for i in 1:length(md.enumerations)
                if type.declaredType == md.enumerations[i][1] # identify the enum by the name
                    type.start = md.enumerations[i][1 + parse(fmi2Integer, typenode["start"])] # find the enum value and set it
                end
            end
        elseif typename == "String"
            type.start = typenode["start"]
        else
            @warn "setDatatypeVariables(...) unimplemented start value type $typename"
            type.start = typenode["start"]
        end
    end

    if haskey(typenode, "min") && (type.datatype == fmi2Real || type.datatype == fmi2Integer || type.datatype == fmi2Enum)
        if type.datatype == fmi2Real
            type.min = parse(fmi2Real, typenode["min"])
        else
            type.min = parse(fmi2Integer, typenode["min"])
        end
    end
    if haskey(typenode, "max") && (type.datatype == fmi2Real || type.datatype == fmi2Integer || type.datatype == fmi2Enum)
        if type.datatype == fmi2Real
            type.max = parse(fmi2Real, typenode["max"])
        elseif type.datatype == fmi2Integer
            type.max = parse(fmi2Integer, typenode["max"])
        end
    end
    if haskey(typenode, "quantity") && (type.datatype == fmi2Real || type.datatype == fmi2Integer || type.datatype == fmi2Enum)
        type.quantity = typenode["quantity"]
    end
    if haskey(typenode, "unit") && type.datatype == fmi2Real
        type.unit = typenode["unit"]
    end
    if haskey(typenode, "displayUnit") && type.datatype == fmi2Real
        type.displayUnit = typenode["displayUnit"]
    end
    if haskey(typenode, "relativeQuantity") && type.datatype == fmi2Real
        type.relativeQuantity = convert(fmi2Boolean, parse(Bool, typenode["relativeQuantity"]))
    end
    if haskey(typenode, "nominal") && type.datatype == fmi2Real
        type.nominal = parse(fmi2Real, typenode["nominal"])
    end
    if haskey(typenode, "unbounded") && type.datatype == fmi2Real
        type.unbounded = parse(fmi2Boolean, typenode["unbounded"])
    end
    if haskey(typenode, "derivative") && type.datatype == fmi2Real
        type.derivative = parse(fmi2Integer, typenode["derivative"])
        if typename == "Real"
            sv._Real.derivative = type.derivative
        end
    end
    if haskey(typenode, "reinit") && type.datatype == fmi2Real
        type.reinit = parseFMI2Boolean(typenode["reinit"])
    end
    type
end

#=
Read all enumerations from the modeldescription and store them in a matrix. First entries are the enum names
-------------------------------------------
Example:
"enum1name" "value1"    "value2"
"enum2name" "value1"    "value2"
=#
function createEnum(node::EzXML.Node)
    enum = 1
    idx = 1
    enumerations = []
    for simpleType in eachelement(node)
        name = simpleType["name"]
        for type in eachelement(simpleType)
            if type.name == "Enumeration"
                enum = []
                push!(enum, name)
                for item in eachelement(type)
                    push!(enum, item["name"])
                end
                push!(enumerations, enum)
            end
        end
    end
    enumerations
end

################################
# [Sec. 2] get value functions #
################################

"""
Returns startTime from DefaultExperiment if defined else defaults to nothing.

    ToDo: update docstring format.
"""
function fmi2GetDefaultStartTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.startTime
end

"""
Returns stopTime from DefaultExperiment if defined else defaults to nothing.

    ToDo: update docstring format.
"""
function fmi2GetDefaultStopTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.stopTime
end

"""
Returns tolerance from DefaultExperiment if defined else defaults to nothing.

ToDo: update docstring format.
"""
function fmi2GetDefaultTolerance(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.tolerance
end

"""
Returns stepSize from DefaultExperiment if defined else defaults to nothing.

ToDo: update docstring format.
"""
function fmi2GetDefaultStepSize(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.stepSize
end

"""
Returns the tag 'modelName' from the model description.

ToDo: update docstring format.
"""
function fmi2GetModelName(md::fmi2ModelDescription)#, escape::Bool = true)
    md.modelName
end

"""
Returns the tag 'guid' from the model description.

ToDo: update docstring format.
"""
function fmi2GetGUID(md::fmi2ModelDescription)
    md.guid
end

"""
Returns the tag 'generationtool' from the model description.

ToDo: update docstring format.
"""
function fmi2GetGenerationTool(md::fmi2ModelDescription)
    md.generationTool
end

"""
Returns the tag 'generationdateandtime' from the model description.

ToDo: update docstring format.
"""
function fmi2GetGenerationDateAndTime(md::fmi2ModelDescription)
    md.generationDateAndTime
end

"""
Returns the tag 'varaiblenamingconvention' from the model description.

ToDo: update docstring format.
"""
function fmi2GetVariableNamingConvention(md::fmi2ModelDescription)
    md.variableNamingConvention
end

"""
Returns the tag 'numberOfEventIndicators' from the model description.

ToDo: update docstring format.
"""
function fmi2GetNumberOfEventIndicators(md::fmi2ModelDescription)
    md.numberOfEventIndicators
end

"""
Returns the number of states of the FMU.

ToDo: update docstring format.
"""
function fmi2GetNumberOfStates(md::fmi2ModelDescription)
    length(md.stateValueReferences)
end

"""
Returns true, if the FMU supports co simulation

ToDo: update docstring format.
"""
function fmi2IsCoSimulation(md::fmi2ModelDescription)
    return (md.coSimulation != nothing)
end

"""
Returns true, if the FMU supports model exchange

ToDo: update docstring format.
"""
function fmi2IsModelExchange(md::fmi2ModelDescription)
    return (md.modelExchange != nothing)
end

##################################
# [Sec. 3] information functions #
##################################

"""
Returns if the FMU model description contains `dependency` information.

ToDo: update docstring format.
"""
function fmi2DependenciesSupported(md::fmi2ModelDescription)
    if md.modelstructure === nothing 
        return false
    end

    return true
end

"""
Returns if the FMU model description contains `dependency` information for `derivatives`.

ToDo: update docstring format.
"""
function fmi2DerivativeDependenciesSupported(md::fmi2ModelDescription)
    if !fmi2DependenciesSupported(md) 
        return false
    end

    der = md.modelStructure.derivatives
    if der === nothing || length(der) <= 0
        return false
    end
    
    return true
end

"""
Returns the tag 'modelIdentifier' from CS or ME section.

ToDo: update docstring format.
"""
function fmi2GetModelIdentifier(md::fmi2ModelDescription; type=nothing)
    
    if type === nothing
        if fmi2IsCoSimulation(md)
            return md.coSimulation.modelIdentifier
        elseif fmi2IsModelExchange(md)
            return md.modelExchange.modelIdentifier
        else
            @assert false "fmi2GetModelName(...): FMU does not support ME or CS!"
        end
    elseif type == fmi2TypeCoSimulation
        return md.coSimulation.modelIdentifier
    elseif type == fmi2TypeModelExchange
        return md.modelExchange.modelIdentifier
    end
end

"""
Returns true, if the FMU supports the getting/setting of states

ToDo: update docstring format.
"""
function fmi2CanGetSetState(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canGetAndSetFMUstate) || (md.modelExchange != nothing && md.modelExchange.canGetAndSetFMUstate)
end

"""
Returns true, if the FMU state can be serialized

ToDo: update docstring format.
"""
function fmi2CanSerializeFMUstate(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canSerializeFMUstate) || (md.modelExchange != nothing && md.modelExchange.canSerializeFMUstate)
end

"""
Returns true, if the FMU provides directional derivatives

ToDo: update docstring format.
"""
function fmi2ProvidesDirectionalDerivative(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.providesDirectionalDerivative) || (md.modelExchange != nothing && md.modelExchange.providesDirectionalDerivative)
end

"""
Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of value references and their corresponding names

ToDo: update docstring format.
"""
function fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.valueReferences)
    dict = Dict{fmi2ValueReference, Array{String}}()
    for vr in vrs
        dict[vr] = fmi2ValueReferenceToString(md, vr)
    end
    return dict
end

function fmi2GetValueReferencesAndNames(fmu::FMU2)
    fmi2GetValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns a array of names corresponding to value references `vrs`

If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

ToDo: update docstring format.
"""
function fmi2GetNames(md::fmi2ModelDescription; vrs=md.valueReferences, mode=:first)
    names = []
    for vr in vrs
        ns = fmi2ValueReferenceToString(md, vr)

        if mode == :first
            push!(names, ns[1])
        elseif mode == :group
            push!(names, ns)
        elseif mode == :flat 
            for n in ns
                push!(names, n)
            end
        else
            @assert false "fmi2GetNames(...) unknown mode `mode`, please choose between `:first`, `:group` and `:flat`."
        end
    end
    return names
end

function fmi2GetNames(fmu::FMU2; kwargs...)
    fmi2GetNames(fmu.modelDescription; kwargs...)
end

"""
Returns a dict with (vrs, names of inputs)

ToDo: update docstring format.
"""
function fmi2GetInputValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.inputValueReferences)
end

function fmi2GetInputValueReferencesAndNames(fmu::FMU2)
    fmi2GetInputValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns names of inputs 

ToDo: update docstring format.
"""
function fmi2GetInputNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.inputValueReferences, kwargs...)
end

function fmi2GetInputNames(fmu::FMU2; kwargs...)
    fmi2GetInputNames(fmu.modelDescription; kwargs...)
end

"""
ToDo: update docstring format.
"""
function fmi2GetOutputValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.outputValueReferences)
end

function fmi2GetOutputValueReferencesAndNames(fmu::FMU2)
    fmi2GetOutputValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns names of outputs 

ToDo: update docstring format.
"""
function fmi2GetOutputNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.outputValueReferences, kwargs...)
end

function fmi2GetOutputNames(fmu::FMU2; kwargs...)
    fmi2GetOutputNames(fmu.modelDescription; kwargs...)
end

"""
ToDo: update docstring format.
"""
function fmi2GetParameterValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.parameterValueReferences)
end

function fmi2GetParameterValueReferencesAndNames(fmu::FMU2)
    fmi2GetParameterValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns names of parameters

ToDo: update docstring format.
"""
function fmi2GetParameterNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.parameterValueReferences, kwargs...)
end

function fmi2GetParameterNames(fmu::FMU2; kwargs...)
    fmi2GetParameterNames(fmu.modelDescription; kwargs...)
end

"""
Returns dict(vrs, names of states)

ToDo: update docstring format.
"""
function fmi2GetStateValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.stateValueReferences)
end

function fmi2GetStateValueReferencesAndNames(fmu::FMU2)
    fmi2GetStateValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns names of states 

ToDo: update docstring format.
"""
function fmi2GetStateNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.stateValueReferences, kwargs...)
end

function fmi2GetStateNames(fmu::FMU2; kwargs...)
    fmi2GetStateNames(fmu.modelDescription; kwargs...)
end

"""
ToDo: update docstring format.
"""
function fmi2GetDerivateValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.derivativeValueReferences)
end

function fmi2GetDerivateValueReferencesAndNames(fmu::FMU2)
    fmi2GetDerivateValueReferencesAndNames(fmu.modelDescription)
end

"""
Returns names of derivatives

ToDo: update docstring format.
"""
function fmi2GetDerivativeNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.derivativeValueReferences, kwargs...)
end

function fmi2GetDerivativeNames(fmu::FMU2; kwargs...)
    fmi2GetDerivativeNames(fmu.modelDescription; kwargs...)
end

"""
Returns a dictionary of variables with their descriptions

ToDo: update docstring format.
"""
function fmi2GetNamesAndDescriptions(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => md.modelVariables[i].description for i = 1:length(md.modelVariables))
end

function fmi2GetNamesAndDescriptions(fmu::FMU2)
    fmi2GetNamesAndDescriptions(fmu.modelDescription)
end

"""
Returns a dictionary of variables with their units

ToDo: update docstring format.
"""
function fmi2GetNamesAndUnits(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => fmi2GetUnit(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

function fmi2GetNamesAndUnits(fmu::FMU2)
    fmi2GetNamesAndUnits(fmu.modelDescription)
end

"""
Returns a dictionary of variables with their initials

ToDo: update docstring format.
"""
function fmi2GetNamesAndInitials(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => fmi2GetInitial(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

function fmi2GetNamesAndInitials(fmu::FMU2)
    fmi2GetNamesAndInitials(fmu.modelDescription)
end

"""
Returns a dictionary of variables with their starting values

ToDo: update docstring format.
"""
function fmi2GetNamesAndInitials(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => md.modelVariables[i].initial for i = 1:length(md.modelVariables))
end

function fmi2GetNamesAndInitials(fmu::FMU2)
    fmi2GetNamesAndInitials(fmu.modelDescription)
end