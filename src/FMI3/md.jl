#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_md.jl` (model description)?
# - [Sec. 1a] the function `fmi3LoadModelDescription` to load/parse the FMI model description [exported]
# - [Sec. 1b] helper functions for the load/parse function [not exported]
# - [Sec. 2]  functions to get values from the model description in the format `fmi3Get[value](md::fmi3ModelDescription)` [exported]
# - [Sec. 3]  additional functions to get useful information from the model description in the format `fmi3Get[value](md::fmi3ModelDescription)` [exported]

######################################
# [Sec. 1a] fmi3LoadModelDescription #
######################################

using FMIBase.FMICore: fmi3ModelDescriptionModelExchange, fmi3ModelDescriptionCoSimulation, fmi3ModelDescriptionScheduledExecution, fmi3ModelDescriptionDefaultExperiment
using FMIBase.FMICore: fmi3ModelDescriptionModelStructure, fmi3ModelDescriptionDefaultExperiment
using FMIBase.FMICore: fmi3VariableFloat32, fmi3VariableFloat64
using FMIBase.FMICore: fmi3VariableInt8, fmi3VariableUInt8, fmi3VariableInt16, fmi3VariableUInt16, fmi3VariableInt32, fmi3VariableUInt32, fmi3VariableInt64, fmi3VariableUInt64
using FMIBase.FMICore: fmi3VariableBoolean, fmi3VariableString, fmi3VariableBinary, fmi3VariableClock, fmi3VariableEnumeration

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

    #ToDo: md.enumerations = []
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
    md.generationTool = parseNode(root, "generationTool", String; onfail="[Unknown generation tool]")
    md.generationDateAndTime = parseNode(root, "generationDateAndTime", String; onfail="[Unknown generation date and time]")
    variableNamingConventionStr = parseNode(root, "variableNamingConvention", String; onfail= "flat")
    @assert (variableNamingConventionStr == "flat" || variableNamingConventionStr == "structured") ["fmi3ReadModelDescription(...): Unknown entry for `variableNamingConvention=$(variableNamingConventionStr)`."]
    md.variableNamingConvention = (variableNamingConventionStr == "flat" ? fmi3VariableNamingConventionFlat : fmi3VariableNamingConventionStructured)
    md.description = parseNode(root, "description", String; onfail="[Unknown Description]")

    # defaults
    md.modelExchange = nothing
    md.coSimulation = nothing
    md.scheduledExecution = nothing
    md.defaultExperiment = nothing

    # additionals 
    md.valueReferences = []
    md.valueReferenceIndicies = Dict{UInt, UInt}()

    for node in eachelement(root)
        if node.name == "CoSimulation"
            md.coSimulation = fmi3ModelDescriptionCoSimulation()
            md.coSimulation.modelIdentifier                        = node["modelIdentifier"]
            md.coSimulation.canHandleVariableCommunicationStepSize = parseNode(node, "canHandleVariableCommunicationStepSize", Bool   ; onfail=false)
            md.coSimulation.canInterpolateInputs                   = parseNode(node, "canInterpolateInputs", Bool                     ; onfail=false)
            md.coSimulation.maxOutputDerivativeOrder               = parseNode(node, "maxOutputDerivativeOrder", Int                 ; onfail=nothing)
            md.coSimulation.canGetAndSetFMUState                   = parseNode(node, "canGetAndSetFMUState", Bool                     ; onfail=false)
            md.coSimulation.canSerializeFMUState                   = parseNode(node, "canSerializeFMUState", Bool                     ; onfail=false)
            md.coSimulation.providesDirectionalDerivatives         = parseNode(node, "providesDirectionalDerivatives", Bool           ; onfail=false)
            md.coSimulation.providesAdjointDerivatives             = parseNode(node, "providesAdjointDerivatives", Bool               ; onfail=false)
            md.coSimulation.hasEventMode                           = parseNode(node, "hasEventMode", Bool                             ; onfail=false)

        elseif node.name == "ModelExchange"
            md.modelExchange = fmi3ModelDescriptionModelExchange()
            md.modelExchange.modelIdentifier                        = node["modelIdentifier"]
            md.modelExchange.canGetAndSetFMUState                   = parseNode(node, "canGetAndSetFMUState", Bool                     ; onfail=false)
            md.modelExchange.canSerializeFMUState                   = parseNode(node, "canSerializeFMUState", Bool                     ; onfail=false)
            md.modelExchange.providesDirectionalDerivatives         = parseNode(node, "providesDirectionalDerivatives", Bool           ; onfail=false)
            md.modelExchange.providesAdjointDerivatives             = parseNode(node, "providesAdjointDerivatives", Bool               ; onfail=false)
        
        elseif node.name == "ScheduledExecution"
            md.scheduledExecution = fmi3ModelDescriptionScheduledExecution()
            md.scheduledExecution.modelIdentifier                        = node["modelIdentifier"]
            md.scheduledExecution.needsExecutionTool                     = parseNode(node, "needsExecutionTool", Bool                       ; onfail=false)
            md.scheduledExecution.canBeInstantiatedOnlyOncePerProcess    = parseNode(node, "canBeInstantiatedOnlyOncePerProcess", Bool      ; onfail=false)
            md.scheduledExecution.canGetAndSetFMUState                   = parseNode(node, "canGetAndSetFMUState", Bool                     ; onfail=false)
            md.scheduledExecution.canSerializeFMUState                   = parseNode(node, "canSerializeFMUState", Bool                     ; onfail=false)
            md.scheduledExecution.providesDirectionalDerivatives         = parseNode(node, "providesDirectionalDerivatives", Bool           ; onfail=false)
            md.scheduledExecution.providesAdjointDerivatives             = parseNode(node, "providesAdjointDerivatives", Bool               ; onfail=false)
            md.scheduledExecution.providesPerElementDependencies         = parseNode(node, "providesPerElementDependencies", Bool           ; onfail=false)
        
        elseif node.name ∈ ("TypeDefinitions", "LogCategories", "UnitDefinitions")
            @warn "FMU has $(node.name), but parsing is not implemented yet." 

        elseif node.name == "ModelVariables"
            md.modelVariables = parseModelVariables(md, node)

        elseif node.name == "ModelStructure"
            md.modelStructure = fmi3ModelDescriptionModelStructure()

            parseModelStructure(md, node)

            md.numberOfContinuousStates = length(md.stateValueReferences)
            
        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi3ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNode(node, "startTime", fmi3Float64)
            md.defaultExperiment.stopTime   = parseNode(node, "stopTime", fmi3Float64)
            md.defaultExperiment.tolerance  = parseNode(node, "tolerance", fmi3Float64; onfail = md.defaultExperiment.tolerance)
            md.defaultExperiment.stepSize   = parseNode(node, "stepSize", fmi3Float64)

        else
            @assert false "Unknwon node named `$(node.name)`, please open an issue on GitHub."
        end
    end

    # creating an index for value references (fast look-up for dependencies)
    for i in 1:length(md.valueReferences)
        md.valueReferenceIndicies[md.valueReferences[i]] = i
    end 

    # check all intermediateUpdate variables
    for variable in md.modelVariables
        if hasproperty(variable, :intermediateUpdate)
            if !isnothing(variable.intermediateUpdate) && Bool(variable.intermediateUpdate)
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
function parseModelVariables(md::fmi3ModelDescription, nodes::EzXML.Node)
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    modelVariables = Array{fmi3Variable}(undef, numberOfVariables)
    index = 1
    for node in eachelement(nodes)
        name = node["name"]
        valueReference = parseNode(node, "valueReference", fmi3ValueReference)
        
        # type node
        typenode = nothing
        typename = node.name

        if typename == "Float32"
            modelVariables[index] = fmi3VariableFloat32(name, valueReference)
        elseif typename == "Float64"
            modelVariables[index] = fmi3VariableFloat64(name, valueReference)
        elseif typename == "Int8"
            modelVariables[index] = fmi3VariableInt8(name, valueReference)
        elseif typename == "UInt8"
            modelVariables[index] = fmi3VariableUInt8(name, valueReference)
        elseif typename == "Int16"
            modelVariables[index] = fmi3VariableInt16(name, valueReference)
        elseif typename == "UInt16"
            modelVariables[index] = fmi3VariableUInt16(name, valueReference)
        elseif typename == "Int32"
            modelVariables[index] = fmi3VariableInt32(name, valueReference)
        elseif typename == "UInt32"
            modelVariables[index] = fmi3VariableUInt32(name, valueReference)
        elseif typename == "Int64"
            modelVariables[index] = fmi3VariableInt64(name, valueReference)
        elseif typename == "UInt64"
            modelVariables[index] = fmi3VariableUInt64(name, valueReference)
        elseif typename == "Boolean"
            modelVariables[index] = fmi3VariableBoolean(name, valueReference)
        elseif typename == "String"
            modelVariables[index] = fmi3VariableString(name, valueReference)
        elseif typename == "Binary"
            modelVariables[index] = fmi3VariableBinary(name, valueReference)
        elseif typename == "Clock"
            modelVariables[index] = fmi3VariableClock(name, valueReference)
        elseif typename == "Enumeration"
            modelVariables[index] = fmi3VariableEnumeration(name, valueReference)
        else 
            @warn "Unknown data type `$(typename)`."
            # ToDo: how to handle unknown types
        end
        
        # modelVariables[index] = fmi3Variable(name, valueReference)

        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        if haskey(node, "description")
            modelVariables[index].description = node["description"]
        end

        if haskey(node, "causality")
            causality = stringToCausality(md, node["causality"])

            if causality == fmi3CausalityOutput
                push!(md.outputValueReferences, valueReference)
            elseif causality == fmi3CausalityInput
                push!(md.inputValueReferences, valueReference)
            elseif causality == fmi3CausalityParameter
                push!(md.parameterValueReferences, valueReference)
            end
        end

        if haskey(node, "variability")
            variability = stringToVariability(md, parseNode(node, "variability", String))
        end
        modelVariables[index].canHandleMultipleSetPerTimeInstant = parseNode(node, "canHandleMultipleSetPerTimeInstant", Bool)
        modelVariables[index].annotations = parseNode(node, "annotations", String)
        modelVariables[index].clocks = parseArrayValueReferences(md, parseNode(node, "clocks", String))
        
        if typename ∉ ("Clock", "String")
            modelVariables[index].intermediateUpdate = parseNode(node, "intermediateUpdate", Bool)
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `intermediateUpdate`."
        end
        
        if typename ∉ ("Clock", "String")
            modelVariables[index].previous = parseNode(node, "previous", Bool)
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `previous`."
        end

        if haskey(node, "initial")
            if typename ∉ ("Clock", "String", "Enumeration")
                modelVariables[index].initial = stringToInitial(md, parseNode(node, "initial", String))
            else
                @warn "Unsupported typename `$(typename)` for modelVariable attribute `initial`."
            end
        end
        
        if typename ∉ ("Clock", "String", "Binary", "Boolean")
            modelVariables[index].quantity = parseNode(node, "quantity", String)
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `quantity`."
        end

        if typename == "Float64" || typename == "Float32"
            modelVariables[index].unit = parseNode(node, "unit", String)
            modelVariables[index].displayUnit = parseNode(node, "displayUnit", String)
        end
        
        if typename != "String"
            modelVariables[index].declaredType = parseNode(node, "declaredType", String)
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `declaredType`."
        end

        if typename ∉ ("Clock", "String", "Binary", "Boolean")
            modelVariables[index].min = parseNode(node, "min", stringToDataType(md, typename))
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `min`."
        end

        if typename ∉ ("Clock", "String", "Binary", "Boolean")
            modelVariables[index].max = parseNode(node, "max", stringToDataType(md, typename))
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `max`."
        end

        if typename == "Float64" || typename == "Float32"
            modelVariables[index].nominal = parseNode(node, "nominal", stringToDataType(md, typename))  
            modelVariables[index].unbounded = parseNode(node, "unbounded", stringToDataType(md, typename))
        end

        if typename ∉ ("Binary", "Clock")
            if !isnothing(node.firstelement) && node.firstelement.name == "Dimension"
                substrings = split(node["start"], " ")

                T = stringToDataType(md, typename)
                modelVariables[index].start = Array{T}(undef, 0)
                for string in substrings
                    push!(modelVariables[index].start, parseType(string, T))
                end
            else
                if typename == "Enum"
                    for i in 1:length(md.enumerations)
                        if modelVariables[index].declaredType == md.enumerations[i][1] # identify the enum by the name
                            modelVariables[index].start = md.enumerations[i][1 + parseNode(node, "start", Int)] # find the enum value and set it
                        end
                    end
                else
                    modelVariables[index].start = parseNode(node, "start", stringToDataType(md, typename))
                end
            end
        else
            @warn "Unsupported typename `$(typename)` for modelVariable attribute `start`."
        end

        if typename == "Float64" || typename == "Float32"
            modelVariables[index].derivative = parseNode(node, "derivative", fmi3ValueReference)
            modelVariables[index].reinit = parseNode(node, "reinit", Bool)
        end
        
        if typename == "String"
            for nod in eachelement(node)
                if nod.name == "Start"
                    modelVariables[index].start = nod["value"]
                end
            end
        elseif typename == "Binary"
            for nod in eachelement(node)
                if nod.name == "Start"
                    modelVariables[index].start = pointer(nod["value"])
                end
            end
        end
            
        md.stringValueReferences[name] = valueReference

        index += 1
    end
    return modelVariables
end

# Parses the model variables of the FMU model description.
function parseModelStructure(md::fmi3ModelDescription, nodes::EzXML.Node)
    
    md.modelStructure.continuousStateDerivatives = []
    md.modelStructure.initialUnknowns = []
    md.modelStructure.eventIndicators = []
    md.modelStructure.outputs = []

    for node in eachelement(nodes)
        if haskey(node, "valueReference")
            varDep = parseDependencies(md, node)
            if node.name == "InitialUnknown"
                push!(md.modelStructure.initialUnknowns, varDep)
            elseif node.name == "EventIndicator"
                md.numberOfEventIndicators += 1
                push!(md.modelStructure.eventIndicators)
                # [TODO] parse valueReferences to another array
            elseif node.name == "ContinuousStateDerivative"

                # find states and derivatives
                derValueRef = parseNode(node, "valueReference", fmi3ValueReference)
                derVar = modelVariablesForValueReference(md, derValueRef)[1]
                stateValueRef = modelVariablesForValueReference(md, derVar.derivative)[1].valueReference
    
                if stateValueRef ∉ md.stateValueReferences
                    push!(md.stateValueReferences, stateValueRef)
                end
                if derValueRef ∉ md.derivativeValueReferences
                    push!(md.derivativeValueReferences, derValueRef)
                end
    
                push!(md.modelStructure.continuousStateDerivatives, varDep)
            elseif node.name =="Output"
                # find outputs
                outVR = parseNode(node, "valueReference", fmi3ValueReference)
                
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

function parseDependencies(md::fmi3ModelDescription, node::EzXML.Node)
    varDep = fmi3VariableDependency(parseNode(node, "valueReference", fmi3ValueReference))

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
                varDep.dependenciesKind = collect(stringToDependencyKind(md, e) for e in dependenciesKindSplit)
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

function parseContinuousStateDerivative(md::fmi3ModelDescription, nodes::EzXML.Node)
    @assert (nodes.name == "ContinuousStateDerivative") "Wrong element name."
    md.modelStructure.derivatives = []
    for node in eachelement(nodes)
        if node.name == "InitialUnknown"
            if haskey(node, "index")
                varDep = parseUnknwon(md, node)

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