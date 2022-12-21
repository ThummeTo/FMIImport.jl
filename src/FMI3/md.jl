#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_md.jl` (model description)?
# - [Sec. 1a] the function `fmi3LoadModelDescription` to load/parse the FMI model description [exported]
# - [Sec. 1b] helper functions for the load/parse function [not exported]
# - [Sec. 2]  functions to get values from the model description in the format `fmi3Get[value](md::fmi3ModelDescription)` [exported]
# - [Sec. 3]  additional functions to get useful information from the model description in the format `fmi3Get[value](md::fmi3ModelDescription)` [exported]

using EzXML


using FMICore: fmi3ModelDescriptionModelExchange, fmi3ModelDescriptionCoSimulation, fmi3ModelDescriptionDefaultExperiment
using FMICore: mvFloat32, mvFloat64, mvInt8, mvUInt8, mvInt16, mvUInt16, mvInt32, mvUInt32, mvInt64, mvUInt64, mvBoolean, mvString, mvBinary, mvClock, mvEnumeration
using FMICore: fmi3ModelDescriptionModelStructure
using FMICore: fmi3DependencyKind
######################################
# [Sec. 1a] fmi3LoadModelDescription #
######################################

"""
Extract the FMU variables and meta data from the ModelDescription
"""
function fmi3LoadModelDescription(pathToModellDescription::String)
    md = fmi3ModelDescription()

    md.stringValueReferences = Dict{String, fmi3ValueReference}()
    md.outputValueReferences = Array{fmi3ValueReference}(undef, 0)
    md.inputValueReferences = Array{fmi3ValueReference}(undef, 0)
    md.stateValueReferences = Array{fmi3ValueReference}(undef, 0)
    md.derivativeValueReferences = Array{fmi3ValueReference}(undef, 0)
    md.intermediateUpdateValueReferences = Array{fmi3ValueReference}(undef, 0)
    md.numberOfEventIndicators = 0

    md.enumerations = []
    typedefinitions = nothing
    modelvariables = nothing
    modelstructure = nothing

    doc = readxml(pathToModellDescription)

    root = doc.root

    # mandatory
    md.fmiVersion = root["fmiVersion"]
    md.modelName = root["modelName"]
    md.instantiationToken = root["instantiationToken"]

    # optional
    md.generationTool = parseNodeString(root, "generationTool"; onfail="[Unknown generation tool]")
    md.generationDateAndTime = parseNodeString(root, "generationDateAndTime"; onfail="[Unknown generation date and time]")
    variableNamingConventionStr = parseNodeString(root, "variableNamingConvention"; onfail= "flat")
    @assert (variableNamingConventionStr == "flat" || variableNamingConventionStr == "structured") ["fmi3ReadModelDescription(...): Unknown entry for `variableNamingConvention=$(variableNamingConventionStr)`."]
    md.variableNamingConvention = (variableNamingConventionStr == "flat" ? fmi3VariableNamingConventionFlat : fmi3VariableNamingConventionStructured)
    md.description = parseNodeString(root, "description"; onfail="[Unknown Description]")

    # defaults
    md.modelExchange = nothing
    md.coSimulation = nothing
    md.scheduledExecution = nothing

    # additionals 
    md.valueReferences = []
    md.valueReferenceIndicies = Dict{UInt, UInt}()

    md.defaultStartTime = 0.0
    md.defaultStopTime = 1.0
    md.defaultTolerance = 0.0001

    for node in eachelement(root)
        if node.name == "CoSimulation" || node.name == "ModelExchange" || node.name == "ScheduledExecution"
            if node.name == "CoSimulation"
                md.coSimulation = fmi3ModelDescriptionCoSimulation()
                md.coSimulation.modelIdentifier                        = node["modelIdentifier"]
                md.coSimulation.canHandleVariableCommunicationStepSize = parseNodeBoolean(node, "canHandleVariableCommunicationStepSize"   ; onfail=false)
                md.coSimulation.canInterpolateInputs                   = parseNodeBoolean(node, "canInterpolateInputs"                     ; onfail=false)
                md.coSimulation.maxOutputDerivativeOrder               = parseNodeInteger(node, "maxOutputDerivativeOrder"                 ; onfail=nothing)
                md.coSimulation.canGetAndSetFMUstate                   = parseNodeBoolean(node, "canGetAndSetFMUState"                     ; onfail=false)
                md.coSimulation.canSerializeFMUstate                   = parseNodeBoolean(node, "canSerializeFMUState"                     ; onfail=false)
                md.coSimulation.providesDirectionalDerivatives         = parseNodeBoolean(node, "providesDirectionalDerivatives"           ; onfail=false)
                md.coSimulation.providesAdjointDerivatives             = parseNodeBoolean(node, "providesAdjointDerivatives"               ; onfail=false)
                md.coSimulation.hasEventMode                           = parseNodeBoolean(node, "hasEventMode"                             ; onfail=false)
            end

            if node.name == "ModelExchange"
                md.modelExchange = fmi3ModelDescriptionModelExchange()
                md.modelExchange.modelIdentifier                        = node["modelIdentifier"]
                md.modelExchange.canGetAndSetFMUstate                   = parseNodeBoolean(node, "canGetAndSetFMUState"                     ; onfail=false)
                md.modelExchange.canSerializeFMUstate                   = parseNodeBoolean(node, "canSerializeFMUState"                     ; onfail=false)
                md.modelExchange.providesDirectionalDerivatives         = parseNodeBoolean(node, "providesDirectionalDerivatives"           ; onfail=false)
                md.modelExchange.providesAdjointDerivatives             = parseNodeBoolean(node, "providesAdjointDerivatives"               ; onfail=false)
            end
        
            if node.name == "ScheduledExecution"
                md.scheduledExecution = FMICore.fmi3ModelDescriptionScheduledExecution()
                md.scheduledExecution.modelIdentifier                        = node["modelIdentifier"]
                md.scheduledExecution.needsExecutionTool                     = parseNodeBoolean(node, "needsExecutionTool"                       ; onfail=false)
                md.scheduledExecution.canBeInstantiatedOnlyOncePerProcess    = parseNodeBoolean(node, "canBeInstantiatedOnlyOncePerProcess"      ; onfail=false)
                md.scheduledExecution.canGetAndSetFMUstate                   = parseNodeBoolean(node, "canGetAndSetFMUState"                     ; onfail=false)
                md.scheduledExecution.canSerializeFMUstate                   = parseNodeBoolean(node, "canSerializeFMUState"                     ; onfail=false)
                md.scheduledExecution.providesDirectionalDerivatives         = parseNodeBoolean(node, "providesDirectionalDerivatives"           ; onfail=false)
                md.scheduledExecution.providesAdjointDerivatives             = parseNodeBoolean(node, "providesAdjointDerivatives"               ; onfail=false)
                md.scheduledExecution.providesPerElementDependencies         = parseNodeBoolean(node, "providesPerElementDependencies"           ; onfail=false)
            end
        elseif node.name == "TypeDefinitions"
            md.enumerations = createEnum(node)

        elseif node.name == "ModelVariables"
            md.modelVariables = parseModelVariables(node, md)

        elseif node.name == "ModelStructure"
            md.modelStructure = fmi3ModelDescriptionModelStructure()

            parseModelStructure(node, md)
            
        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi3ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNodeReal(node, "startTime")
            md.defaultExperiment.stopTime   = parseNodeReal(node, "stopTime")
            md.defaultExperiment.tolerance  = parseNodeReal(node, "tolerance"; onfail = md.defaultTolerance)
            md.defaultExperiment.stepSize   = parseNodeReal(node, "stepSize")
        end
    end

    # creating an index for value references (fast look-up for dependencies)
    for i in 1:length(md.valueReferences)
        md.valueReferenceIndicies[md.valueReferences[i]] = i
    end 

    # check all intermediateUpdate variables
    for variable in md.modelVariables
        if hasproperty(variable, :intermediateUpdate)
            if Bool(variable.intermediateUpdate)
                push!(md.intermediateUpdateValueReferences, variable.valueReference)
            end
        end
    end

    md
end

#######################################
# [Sec. 1b] helpers for load function #
#######################################

# Parses the model variables of the FMU model description.
function parseModelVariables(nodes::EzXML.Node, md::fmi3ModelDescription)
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    modelVariables = Array{fmi3Variable}(undef, numberOfVariables)
    index = 1
    for node in eachelement(nodes)
        name = node["name"]
        valueReference = parse(fmi3ValueReference, (node["valueReference"]))
        
        # type node
        typenode = nothing
        typename = node.name

        if typename == "Float32"
            modelVariables[index] = mvFloat32(name, valueReference)
        elseif typename == "Float64"
            modelVariables[index] = mvFloat64(name, valueReference)
        elseif typename == "Int8"
            modelVariables[index] = mvInt8(name, valueReference)
        elseif typename == "UInt8"
            modelVariables[index] = mvUInt8(name, valueReference)
        elseif typename == "Int16"
            modelVariables[index] = mvInt16(name, valueReference)
        elseif typename == "UInt16"
            modelVariables[index] = mvUInt16(name, valueReference)
        elseif typename == "Int32"
            modelVariables[index] = mvInt32(name, valueReference)
        elseif typename == "UInt32"
            modelVariables[index] = mvUInt32(name, valueReference)
        elseif typename == "Int64"
            modelVariables[index] = mvInt64(name, valueReference)
        elseif typename == "UInt64"
            modelVariables[index] = mvUInt64(name, valueReference)
        elseif typename == "Boolean"
            modelVariables[index] = mvBoolean(name, valueReference)
        elseif typename == "String"
            modelVariables[index] = mvString(name, valueReference)
        elseif typename == "Binary"
            modelVariables[index] = mvBinary(name, valueReference)
        elseif typename == "Clock"
            modelVariables[index] = mvClock(name, valueReference)
        elseif typename == "Enumeration"
            modelVariables[index] = mvEnumeration(name, valueReference)
        else 
            @warn "Unknown data type `$(typename)`."
            # tODO how to handle unknown types
        end
        
        # modelVariables[index] = fmi3ModelVariable(name, valueReference)

        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        if haskey(node, "description")
            modelVariables[index].description = node["description"]
        end

        if haskey(node, "causality")
            modelVariables[index].causality = fmi3StringToCausality(node["causality"])

            if modelVariables[index].causality == fmi3CausalityOutput
                push!(md.outputValueReferences, valueReference)
            elseif modelVariables[index].causality == fmi3CausalityInput
                push!(md.inputValueReferences, valueReference)
            end
        end

        if haskey(node, "variability")
            modelVariables[index].variability = fmi3StringToVariability(node["variability"])
        end

        if haskey(node, "canHandleMultipleSetPerTimeInstant")
            modelVariables[index].canHandleMultipleSetPerTimeInstant = fmi3parseBoolean(node["canHandleMultipleSetPerTimeInstant"])
        end

        if haskey(node, "annotations")
            modelVariables[index].annotations = node["annotations"]
        end

        if haskey(node, "clocks")
            modelVariables[index].clocks = fmi3parseArrayValueReferences(node["clocks"])
        end

        if haskey(node, "intermediateUpdate") && typename != "Clock" && typename != "String"
            modelVariables[index].intermediateUpdate = fmi3parseBoolean(node["intermediateUpdate"])
        end
        
        if haskey(node, "previous") && typename != "Clock" && typename != "String"
            modelVariables[index].previous = fmi3parseBoolean(node["previous"])
        end

        if haskey(node, "initial") && typename != "Clock" && typename != "String" && typename != "Enumeration"
            modelVariables[index].initial = fmi3StringToInitial(node["initial"])
        end
        
        if haskey(node, "quantity") && typename != "Clock" && typename != "String" && typename != "Binary" && typename != "Boolean"
            modelVariables[index].quantity = node["quantity"]
        end
        
        if haskey(node, "unit") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].unit = node["unit"]
        end
        
        if haskey(node, "displayUnit") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].displayUnit = node["displayUnit"]
        end
        
        if haskey(node, "declaredType") && typename != "String"
            modelVariables[index].declaredType = node["declaredType"]
        end

        if haskey(node, "min") && typename != "Clock" && typename != "String" && typename != "Binary" && typename != "Boolean"
            if typename == "Float32"
                modelVariables[index].min = parse(fmi3Float32, node["min"])
            elseif typename == "Float64"
                modelVariables[index].min = parse(fmi3Float32, node["min"])
            elseif typename == "Int8"
                modelVariables[index].min = parse(fmi3Int8, node["min"])
            elseif typename == "UInt8"
                modelVariables[index].min = parse(fmi3UInt8, node["min"])
            elseif typename == "Int16"
                modelVariables[index].min = parse(fmi3Int16, node["min"])
            elseif typename == "UInt16"
                modelVariables[index].min = parse(fmi3UInt16, node["min"])
            elseif typename == "Int32"
                modelVariables[index].min = parse(fmi3Int32, node["min"])
            elseif typename == "UInt32"
                modelVariables[index].min = parse(fmi3UInt32, node["min"])
            elseif typename == "Int64"
                modelVariables[index].min = parse(fmi3Int64, node["min"])
            elseif typename == "UInt64"
                modelVariables[index].min = parse(fmi3UInt64, node["min"])  
            end
        end

        if haskey(node, "max") && typename != "Clock" && typename != "String" && typename != "Binary" && typename != "Boolean"
            if typename == "Float32"
                modelVariables[index].max = parse(fmi3Float32, node["max"])
            elseif typename == "Float64"
                modelVariables[index].max = parse(fmi3Float32, node["max"])
            elseif typename == "Int8"
                modelVariables[index].max = parse(fmi3Int8, node["max"])
            elseif typename == "UInt8"
                modelVariables[index].max = parse(fmi3UInt8, node["max"])
            elseif typename == "Int16"
                modelVariables[index].max = parse(fmi3Int16, node["max"])
            elseif typename == "UInt16"
                modelVariables[index].max = parse(fmi3UInt16, node["max"])
            elseif typename == "Int32"
                modelVariables[index].max = parse(fmi3Int32, node["max"])
            elseif typename == "UInt32"
                modelVariables[index].max = parse(fmi3UInt32, node["max"])
            elseif typename == "Int64"
                modelVariables[index].max = parse(fmi3Int64, node["max"])
            elseif typename == "UInt64"
                modelVariables[index].max = parse(fmi3UInt64, node["max"]) 
            end
        end

        if haskey(node, "nominal") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].nominal = parse(Real, node["nominal"])
        end
        
        if haskey(node, "unbounded") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].unbounded = fmi3parseBoolean(node["nominal"])
        end

        if haskey(node, "start") && typename != "Binary" && typename != "Clock"
            if node.firstelement !== nothing && node.firstelement.name == "Dimension"
                substrings = split(node["start"], " ")
                if typename == "Float32"
                    modelVariables[index].start = Array{fmi3Float32}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3Float32, string))
                    end
                elseif typename == "Float64"
                    modelVariables[index].start = Array{fmi3Float64}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3Float64, string))
                    end
                elseif typename == "Int32"
                    modelVariables[index].start = Array{fmi3Int32}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3Int32, string))
                    end
                elseif typename == "UInt32"
                    modelVariables[index].start = Array{fmi3UInt32}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3UInt32, string))
                    end
                elseif typename == "Int64"
                    modelVariables[index].start = Array{fmi3Int64}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3Int64, string))
                    end
                elseif typename == "UInt64"
                    modelVariables[index].start = Array{fmi3UInt64}(undef, 0)
                    for string in substrings
                        push!(modelVariables[index].start, parse(fmi3UInt64, string))
                    end
                else
                    @warn "More array variable types not implemented yet!"
                end
            else
                if typename == "Float32"
                    modelVariables[index].start = parse(fmi3Float32, node["start"])
                elseif typename == "Float64"
                    modelVariables[index].start = parse(fmi3Float32, node["start"])
                elseif typename == "Int8"
                    modelVariables[index].start = parse(fmi3Int8, node["start"])
                elseif typename == "UInt8"
                    modelVariables[index].start = parse(fmi3UInt8, node["start"])
                elseif typename == "Int16"
                    modelVariables[index].start = parse(fmi3Int16, node["start"])
                elseif typename == "UInt16"
                    modelVariables[index].start = parse(fmi3UInt16, node["start"])
                elseif typename == "Int32"
                    modelVariables[index].start = parse(fmi3Int32, node["start"])
                elseif typename == "UInt32"
                    modelVariables[index].start = parse(fmi3UInt32, node["start"])
                elseif typename == "Int64"
                    modelVariables[index].start = parse(fmi3Int64, node["start"])
                elseif typename == "UInt64"
                    modelVariables[index].start = parse(fmi3UInt64, node["start"]) 
                elseif typename == "Boolean"
                    modelVariables[index].start = parseFMI3Boolean(node["start"])
                elseif typename == "Binary"
                    modelVariables[index].start = pointer(node["start"])
                elseif typename == "String"
                    modelVariables[index].start = parse(fmi3String, node["start"])
                elseif typename == "Enum"
                    for i in 1:length(md.enumerations)
                        if modelVariables[index].declaredType == md.enumerations[i][1] # identify the enum by the name
                            modelVariables[index].start = md.enumerations[i][1 + parse(Int, node["start"])] # find the enum value and set it
                        end
                    end
                end
            end
        end

        if haskey(node, "derivative") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].derivative = parse(fmi3ValueReference, node["derivative"])
        end
        
        if haskey(node, "reinit") && (typename == "Float32" || typename == "Float64")
            modelVariables[index].reinit = parseFMI3Boolean(node["reinit"])
        end
        
        md.stringValueReferences[name] = valueReference

        index += 1
    end
    md.numberOfContinuousStates = length(md.stateValueReferences)
    modelVariables
end

# Parses the model variables of the FMU model description.
function parseModelStructure(nodes::EzXML.Node, md::fmi3ModelDescription)
    @assert (nodes.name == "ModelStructure") "Wrong section name."
    md.modelStructure.continuousStateDerivatives = []
    md.modelStructure.initialUnknowns = []
    md.modelStructure.eventIndicators = []
    md.modelStructure.outputs = []
    for node in eachelement(nodes)
        if haskey(node, "valueReference")
            varDep = parseDependencies(node)
            if node.name == "InitialUnknown"
                push!(md.modelStructure.initialUnknowns, varDep)
            elseif node.name == "EventIndicator"
                md.numberOfEventIndicators += 1
                push!(md.modelStructure.eventIndicators)
                # TODO parse valueReferences to another array
            elseif node.name == "ContinuousStateDerivative"

                # find states and derivatives^
                derSV = fmi3ModelVariablesForValueReference(md, fmi3ValueReference(fmi3parseInteger(node["valueReference"])))[1]
                # derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV.derivative].valueReference
    
                if stateVR ∉ md.stateValueReferences
                    push!(md.stateValueReferences, stateVR)
                end
                if derVR ∉ md.derivativeValueReferences
                    push!(md.derivativeValueReferences, derVR)
                end
    
                push!(md.modelStructure.continuousStateDerivatives, varDep)
            elseif node.name =="Output"
                # find outputs
                outVR = fmi3ValueReference(fmi3parseInteger(node["valueReference"]))
                
                if outVR ∉ md.outputValueReferences
                    push!(md.outputValueReferences, outVR)
                end

                push!(md.modelStructure.outputs, varDep)
            else
                @warn "Unknown entry in `ModelStructure` named `$(node.name)`."
            end
        else 
            @warn "Invalid entry for node `$(node.name)` in `ModelStructure`, missing entry `valueReference`."
        end
    end
end

function parseDependencies(node::EzXML.Node)
    varDep = fmi3VariableDependency(fmi3ValueReference(fmi3parseInteger(node["valueReference"])))

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
                varDep.dependenciesKind = collect(fmi3StringToDependencyKind(e) for e in dependenciesKindSplit)
            end
        end
    end

    if varDep.dependencies !== nothing && varDep.dependenciesKind !== nothing
        if length(varDep.dependencies) != length(varDep.dependenciesKind)
            @warn "Length of field dependencies ($(length(varDep.dependencies))) doesn't match length of dependenciesKind ($(length(varDep.dependenciesKind)))."   
        end
    end

    return varDep
end 

function parseContinuousStateDerivative(nodes::EzXML.Node, md::fmi3ModelDescription)
    @assert (nodes.name == "ContinuousStateDerivative") "Wrong element name."
    md.modelStructure.derivatives = []
    for node in eachelement(nodes)
        if node.name == "InitialUnknown"
            if haskey(node, "index")
                varDep = parseUnknwon(node)

                # find states and derivatives
                derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV.derivative].valueReference

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
        elseif node.name == "EventIndicator"
            md.numberOfEventIndicators += 1
            # TODO parse valueReferences to another array
        else
            @warn "Unknown entry in `ModelStructure.Derivatives` named `$(node.name)`."
        end 
    end
end

# Parses a real value represented by a string.
function fmi3parseFloat(s::Union{String, SubString{String}}; onfail=nothing)
    if onfail === nothing
        return parse(fmi3Float64, s)
    else
        try
            return parse(fmi3Float64, s)
        catch
            return onfail
        end
    end
end

function fmi3parseNodeFloat(node, key; onfail=nothing)
    if haskey(node, key)
        return fmi3parseFloat(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# Parses a Bool value represented by a string.
function fmi3parseBoolean(s::Union{String, SubString{String}}; onfail=nothing)
    if s == "true"
        return true
    elseif s == "false"
        return false
    else
        @assert onfail !== nothing ["parseBoolean(...) unknown boolean value '$s'."]
        return onfail
    end
end

function fmi3parseNodeBoolean(node, key; onfail=nothing)
    if haskey(node, key)
        return fmi3parseBoolean(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# Parses an Integer value represented by a string.
function fmi3parseInteger(s::Union{String, SubString{String}}; onfail=nothing)
    if onfail === nothing
        return parse(Int, s)
    else
        try
            return parse(Int, s)
        catch
            return onfail
        end
    end
end

function fmi3parseNodeInteger(node, key; onfail=nothing)
    if haskey(node, key)
        return fmi3parseInteger(node[key]; onfail=onfail)
    else
        return onfail
    end
end

function fmi3parseNodeString(node, key; onfail=nothing)
    if haskey(node, key)
        return node[key]
    else
        return onfail
    end
end

# Parses a fmi3Boolean value represented by a string.
function parseFMI3Boolean(s::Union{String, SubString{String}})
    if fmi3parseBoolean(s)
        return fmi3True
    else
        return fmi3False
    end
end

# Parses a Bool value represented by a string.
function fmi3parseArrayValueReferences(s::Union{String, SubString{String}})
    references = Array{fmi3ValueReference}(undef, 0)
    substrings = split(s, " ")

    for string in substrings
        push!(references, parse(fmi3ValueReferenceFormat, string))
    end
    
    return references
end

#=
Read all enumerations from the modeldescription and store them in a matrix. First entries are the enum names
-------------------------------------------
Example:
"enum1name" "value1"    "value2"
"enum2name" "value1"    "value2"
=#
# TODO unused
function fmi3createEnum(node::EzXML.Node)
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
function fmi3GetDefaultStartTime(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.startTime
end

"""
Returns stopTime from DefaultExperiment if defined else defaults to nothing.
"""
function fmi3GetDefaultStopTime(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.stopTime
end

"""
Returns tolerance from DefaultExperiment if defined else defaults to nothing.
"""
function fmi3GetDefaultTolerance(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.tolerance
end

"""
Returns stepSize from DefaultExperiment if defined else defaults to nothing.
"""
function fmi3GetDefaultStepSize(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.stepSize
end

"""
Returns the tag 'modelName' from the model description.
"""
function fmi3GetModelName(md::fmi3ModelDescription)#, escape::Bool = true)
    md.modelName
end

"""
Returns the tag 'instantionToken' from the model description.
"""
function fmi3GetInstantiationToken(md::fmi3ModelDescription)
    md.instantiationToken
end

"""
Returns the tag 'generationtool' from the model description.
"""
function fmi3GetGenerationTool(md::fmi3ModelDescription)
    md.generationTool
end

"""
Returns the tag 'generationdateandtime' from the model description.
"""
function fmi3GetGenerationDateAndTime(md::fmi3ModelDescription)
    md.generationDateAndTime
end

"""
Returns the tag 'varaiblenamingconvention' from the model description.
"""
function fmi3GetVariableNamingConvention(md::fmi3ModelDescription)
    md.variableNamingConvention
end

"""
Returns the number of EventIndicators from the model description.
"""
function fmi3GetNumberOfEventIndicators(md::fmi3ModelDescription)
    md.numberOfEventIndicators
end

"""
Returns true, if the FMU supports co simulation
"""
function fmi3IsCoSimulation(md::fmi3ModelDescription)
    return( md.coSimulation !== nothing)
end

"""
Returns true, if the FMU supports model exchange
"""
function fmi3IsModelExchange(md::fmi3ModelDescription)
    return( md.modelExchange !== nothing)
end
"""
Returns true, if the FMU supports scheduled execution
"""
function fmi3IsScheduledExecution(md::fmi3ModelDescription)
    return( md.scheduledExecution !== nothing)
end

##################################
# [Sec. 3] information functions #
##################################

"""
Returns the tag 'modelIdentifier' from CS or ME section.
"""
function fmi3GetModelIdentifier(md::fmi3ModelDescription)
    if fmi3IsCoSimulation(md)
        return md.coSimulation.modelIdentifier
    elseif fmi3IsModelExchange(md)
        return md.modelExchange.modelIdentifier
    else
        @assert false "fmi3GetModelName(...): FMU does not support ME or CS!"
    end
end

"""
Returns true, if the FMU supports the getting/setting of states
"""
function fmi3CanGetSetState(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.canGetAndSetFMUstate) || (md.modelExchange !== nothing && md.modelExchange.canGetAndSetFMUstate)

end

"""
Returns true, if the FMU state can be serialized
"""
function fmi3CanSerializeFMUState(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.canSerializeFMUstate) || (md.modelExchange !== nothing && md.modelExchange.canSerializeFMUstate)

end

"""
Returns true, if the FMU provides directional derivatives
"""
function fmi3ProvidesDirectionalDerivatives(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.providesDirectionalDerivatives) || (md.modelExchange !== nothing && md.modelExchange.providesDirectionalDerivatives)
end

"""
Returns true, if the FMU provides adjoint derivatives
"""
function fmi3ProvidesAdjointDerivatives(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.providesAdjointDerivatives) || (md.modelExchange !== nothing && md.modelExchange.providesAdjointDerivatives)

end
