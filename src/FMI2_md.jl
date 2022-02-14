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

######################################
# [Sec. 1a] fmi2LoadModelDescription #
######################################

"""
Extract the FMU variables and meta data from the ModelDescription
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
    
    for node in eachelement(root)

        if node.name == "CoSimulation" || node.name == "ModelExchange"
            if node.name == "CoSimulation"
                md.coSimulation = fmi2ModelDescriptionCoSimulation()
                md.coSimulation.modelIdentifier                        = node["modelIdentifier"]
                md.coSimulation.canHandleVariableCommunicationStepSize = parseNodeBoolean(node, "canHandleVariableCommunicationStepSize"   ; onfail=false)
                md.coSimulation.canInterpolateInputs                   = parseNodeBoolean(node, "canInterpolateInputs"                     ; onfail=false)
                md.coSimulation.maxOutputDerivativeOrder               = parseNodeInteger(node, "maxOutputDerivativeOrder"                 ; onfail=-1)
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
            modelvariables = node

        elseif node.name == "ModelStructure"
            modelstructure = node

        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi2ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNodeReal(node, "startTime")
            md.defaultExperiment.stopTime   = parseNodeReal(node, "stopTime")
            md.defaultExperiment.tolerance  = parseNodeReal(node, "tolerance")
            md.defaultExperiment.stepSize   = parseNodeReal(node, "stepSize")
        end
    end

    md.valueReferences = []
    md.valueReferenceIndicies = Dict{Integer,Integer}()

    derivativeindices = getDerivativeIndices(modelstructure)
    md.modelVariables = parseModelVariables(modelvariables, md, derivativeindices)

    # parse model dependencies (if available)
    for element in eachelement(modelstructure)
        if element.name == "Derivatives" || element.name == "InitialUnknowns"
            parseDependencies(element, md)
        elseif element.name == "Outputs"
            # ToDo
        else
            @warn "Unknown tag `$(element.name)` for node `ModelStructure`."
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
function parseModelVariables(nodes::EzXML.Node, md::fmi2ModelDescription, derivativeIndices)
    lastValueReference = fmi2ValueReference(0)
    derivativeIndex = nothing
    if derivativeIndices != []
        derivativeIndex = pop!(derivativeIndices)
    end
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    scalarVariables = Array{fmi2ScalarVariable}(undef, numberOfVariables)
    index = 1

    for node in eachelement(nodes)
        name = node["name"]
        ValueReference = parse(fmi2ValueReference, (node["valueReference"]))
        description = nothing
        causality = nothing
        variability = nothing 
        initial = nothing

        if !(ValueReference in md.valueReferences)
            push!(md.valueReferences, ValueReference)
        end

        if haskey(node, "description")
            description = node["description"]
        end
        if haskey(node, "causality")
            causality = fmi2StringToCausality(node["causality"])
        end
        if haskey(node, "variability")
            variabilityString = fmi2StringToVariability(node["variability"])
        end
        if haskey(node, "initial")
            initialString = fmi2StringToInitial(node["initial"])
        end

        datatype = fmi2SetDatatypeVariables(node, md)

        dependencies = []
        dependenciesKind = []

        if derivativeIndex != nothing
            if index == derivativeIndex[1]
                push!(md.stateValueReferences, lastValueReference)
                push!(md.derivativeValueReferences, ValueReference)
    
                if derivativeIndices != []
                    derivativeIndex = pop!(derivativeIndices)
                end
            end
        end
        
        scalarVariables[index] = fmi2ScalarVariable(name, ValueReference)
        scalarVariables[index].datatype = datatype
        scalarVariables[index].description = description
        scalarVariables[index].causality = causality
        scalarVariables[index].variability = variability
        scalarVariables[index].initial = initial
        #scalarVariables[index].dependencies = dependencies
        #scalarVariables[index].dependenciesKind = dependenciesKind

        if causality == fmi2CausalityOutput
            push!(md.outputValueReferences, ValueReference)
        elseif causality == fmi2CausalityInput
            push!(md.inputValueReferences, ValueReference)
        end
        md.stringValueReferences[name] = ValueReference

        lastValueReference = ValueReference
        index += 1
    end
   
    scalarVariables
end

# Parses the model variables of the FMU model description.
function parseDependencies(nodes::EzXML.Node, md::fmi2ModelDescription)
    for node in eachelement(nodes)
        
        if node.name == "Unknown"

            index = 0
            dependencies = nothing
            dependenciesKind = nothing

            if haskey(node, "index")
                index = parseInteger(node["index"])
                dependencies = "" 
                dependenciesKind = ""

                if haskey(node, "dependencies")
                    dependencies = node["dependencies"]
                end 

                if haskey(node, "dependenciesKind")
                    dependenciesKind = node["dependenciesKind"]
                end

                if length(dependencies) > 0 && length(dependenciesKind) > 0
                    dependenciesSplit = split(dependencies, " ")
                    dependenciesKindSplit = split(dependenciesKind, " ")

                    if length(dependenciesSplit) != length(dependenciesKindSplit)
                        @warn "Length of field dependencies ($(length(dependenciesSplit))) doesn't match length of dependenciesKind ($(length(dependenciesKindSplit)))."
                    else
                        #md.modelVariables[index].dependencies = vcat(md.modelVariables[index].dependencies, collect(parseInteger(s) for s in dependenciesSplit)) 
                        #md.modelVariables[index].dependenciesKind = vcat(md.modelVariables[index].dependenciesKind,  dependenciesKindSplit)
                    end
                else 
                    #md.modelVariables[index].dependencies = []
                    #md.modelVariables[index].dependenciesKind = []
                end
            else 
                @warn "Invalid entry for node `Unknown` in `ModelStructure`, missing entry `index`."
            end
        else 
            @warn "Unknown entry in `ModelStructure` named `$(node.name)`."
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

function parseNodeReal(node, key; onfail=nothing)
    if haskey(node, key)
        return parseReal(node[key]; onfail=onfail)
    else
        return onfail
    end
end

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
function fmi2SetDatatypeVariables(node::EzXML.Node, md::fmi2ModelDescription)
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
"""
function fmi2GetDefaultStartTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.startTime
end

"""
Returns stopTime from DefaultExperiment if defined else defaults to nothing.
"""
function fmi2GetDefaultStopTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.stopTime
end

"""
Returns tolerance from DefaultExperiment if defined else defaults to nothing.
"""
function fmi2GetDefaultTolerance(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.tolerance
end

"""
Returns stepSize from DefaultExperiment if defined else defaults to nothing.
"""
function fmi2GetDefaultStepSize(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing 
        return nothing
    end
    return md.defaultExperiment.stepSize
end

"""
Returns the tag 'modelName' from the model description.
"""
function fmi2GetModelName(md::fmi2ModelDescription)#, escape::Bool = true)
    md.modelName
end

"""
Returns the tag 'guid' from the model description.
"""
function fmi2GetGUID(md::fmi2ModelDescription)
    md.guid
end

"""
Returns the tag 'generationtool' from the model description.
"""
function fmi2GetGenerationTool(md::fmi2ModelDescription)
    md.generationTool
end

"""
Returns the tag 'generationdateandtime' from the model description.
"""
function fmi2GetGenerationDateAndTime(md::fmi2ModelDescription)
    md.generationDateAndTime
end

"""
Returns the tag 'varaiblenamingconvention' from the model description.
"""
function fmi2GetVariableNamingConvention(md::fmi2ModelDescription)
    md.variableNamingConvention
end

"""
Returns the tag 'numberOfEventIndicators' from the model description.
"""
function fmi2GetNumberOfEventIndicators(md::fmi2ModelDescription)
    md.numberOfEventIndicators
end

"""
Returns the number of states of the FMU.
"""
function fmi2GetNumberOfStates(md::fmi2ModelDescription)
    length(md.stateValueReferences)
end

"""
Returns true, if the FMU supports co simulation
"""
function fmi2IsCoSimulation(md::fmi2ModelDescription)
    return (md.coSimulation != nothing)
end

"""
Returns true, if the FMU supports model exchange
"""
function fmi2IsModelExchange(md::fmi2ModelDescription)
    return (md.modelExchange != nothing)
end

##################################
# [Sec. 3] information functions #
##################################

"""
Returns if the FMU model description contains `dependency` information.
"""
function fmi2DependenciesSupported(md::fmi2ModelDescription)
    for mv in md.modelVariables
        if mv.dependencies != nothing && length(mv.dependencies) > 0
            return true
        end
    end 

    return false
end

"""
Returns the tag 'modelIdentifier' from CS or ME section.
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
"""
function fmi2CanGetSetState(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canGetAndSetFMUstate) || (md.modelExchange != nothing && md.modelExchange.canGetAndSetFMUstate)
end

"""
Returns true, if the FMU state can be serialized
"""
function fmi2CanSerializeFMUstate(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canSerializeFMUstate) || (md.modelExchange != nothing && md.modelExchange.canSerializeFMUstate)
end

"""
Returns true, if the FMU provides directional derivatives
"""
function fmi2ProvidesDirectionalDerivative(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.providesDirectionalDerivative) || (md.modelExchange != nothing && md.modelExchange.providesDirectionalDerivative)
end