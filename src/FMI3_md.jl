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
using FMICore: fmi3ModelDescriptionFloat, fmi3ModelDescriptionBoolean, fmi3ModelDescriptionInteger, fmi3ModelDescriptionString, fmi3ModelDescriptionEnumeration
using FMICore: fmi3ModelDescriptionModelStructure
using FMICore: fmi3DependencyKind
using FMICore: FMU3

######################################
# [Sec. 1a] fmi3LoadModelDescription #
######################################

"""

    fmi3LoadModelDescription(pathToModellDescription::String)

Extract the FMU variables and meta data from the ModelDescription

# Arguments
- `pathToModellDescription::String`: Contains the path to a file name that is selected to be read and converted to an XML document. In order to better extract the variables and meta data in the further process.

# Returns
- `md::fmi3ModelDescription`: Retuns a struct which provides the static information of ModelVariables.

# Source
- [EzXML.jl](https://juliaio.github.io/EzXML.jl/stable/)
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
    md.generationTool                       = parseNodeString(root, "generationTool"; onfail="[Unknown generation tool]")
    md.generationDateAndTime                = parseNodeString(root, "generationDateAndTime"; onfail="[Unknown generation date and time]")
    variableNamingConventionStr             = parseNodeString(root, "variableNamingConvention"; onfail= "flat")
    @assert (variableNamingConventionStr == "flat" || variableNamingConventionStr == "structured") ["fmi3ReadModelDescription(...): Unknown entry for `variableNamingConvention=$(variableNamingConventionStr)`."]
    md.variableNamingConvention             = (variableNamingConventionStr == "flat" ? fmi3VariableNamingConventionFlat : fmi3VariableNamingConventionStructured)
    md.description                          = parseNodeString(root, "description"; onfail="[Unknown Description]")

    # defaults
    md.modelExchange = nothing
    md.coSimulation = nothing
    md.scheduledExecution = nothing
    md.defaultExperiment = nothing

    # additionals 
    md.valueReferences = []
    md.valueReferenceIndicies = Dict{UInt, UInt}()

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
            # for element in eachelement(node)
            #     if element.name == "ContinuousStateDerivative" 
            #         parseContinuousStateDerivatives(element, md)
            #     elseif element.name == "InitialUnknowns"
            #         parseInitialUnknowns(element, md)
            #     elseif element.name == "Outputs"
            #         parseOutputs(element, md)
            #     elseif element.name == "EventIndicator"
            #         parseEventIndicator(element, md)
            #     else
            #         @warn "Unknown tag `$(element.name)` for node `ModelStructure`."
            #     end
            # end
        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi3ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNodeReal(node, "startTime")
            md.defaultExperiment.stopTime   = parseNodeReal(node, "stopTime")
            md.defaultExperiment.tolerance  = parseNodeReal(node, "tolerance"; onfail= 1e-4)
            md.defaultExperiment.stepSize   = parseNodeReal(node, "stepSize")
        end
    end

    # creating an index for value references (fast look-up for dependencies)
    for i in 1:length(md.valueReferences)
        md.valueReferenceIndicies[md.valueReferences[i]] = i
    end 

    # check all intermediateUpdate variables
    for variable in md.modelVariables
        if Bool(variable.datatype.intermediateUpdate)
            push!(md.intermediateUpdateValueReferences, variable.valueReference)
        end
    end

    md
end

#######################################
# [Sec. 1b] helpers for load function #
#######################################

# Returns the indices of the state derivatives.
function fmi3getDerivativeIndices(node::EzXML.Node)
    indices = []
    for element in eachelement(node)
        if element.name == "InitialUnknown"
            ind = parse(Int, element["valueReference"])
            der = nothing 
            derKind = nothing 

            if haskey(element, "dependencies")
                der = split(element["dependencies"], " ")

                if der[1] == ""
                    der = fmi3Int32[]
                else
                    der = collect(parse(fmi3Int32, e) for e in der)
                end
            end 

            if haskey(element, "dependenciesKind")
                derKind = split(element["dependenciesKind"], " ")
            end 

            push!(indices, (ind, der, derKind))
        end
    end
    sort!(indices, rev=true)
end

# Parses the model variables of the FMU model description.
function parseModelVariables(nodes::EzXML.Node, md::fmi3ModelDescription)
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    modelVariables = Array{fmi3ModelVariable}(undef, numberOfVariables)
    
    index = 1
    for node in eachelement(nodes)
        name = node["name"]
        valueReference = parse(fmi3ValueReference, (node["valueReference"]))
        
        causality = nothing
        if haskey(node, "causality")
            causality = fmi3StringToCausality(node["causality"])

            if causality == fmi3CausalityOutput
                push!(md.outputValueReferences, valueReference)
            elseif causality == fmi3CausalityInput
                push!(md.inputValueReferences, valueReference)
            elseif causality == fmi3CausalityParameter   
                push!(md.parameterValueReferences, valueReference)
            end
        end

        variability = nothing
        if haskey(node, "variability")
            variability = fmi3StringToVariability(node["variability"])
        end

        initial = nothing
        if haskey(node, "initial")
            initial = fmi3StringToInitial(node["initial"])
        end

        modelVariables[index] = fmi3ModelVariable(name, valueReference, causality, variability, initial)
        modelVariables[index].datatype = fmi3SetDatatypeVariables(node, md) # TODO delete if datatype variable is refactored
    
        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        if haskey(node, "description")
            modelVariables[index].description = node["description"]
        end

        # type node
        typenode = nothing
        typename = node.name

        if typename == "Float32" || typename == "Float64"
            modelVariables[index]._Float = fmi3ModelDescriptionFloat()
            typenode = modelVariables[index]._Float
            if haskey(node, "quantity")
                typenode.quantity = node["quantity"]
            end
            if haskey(node, "unit")
                typenode.unit = node["unit"]
            end
            if haskey(node, "displayUnit")
                typenode.displayUnit = node["displayUnit"]
            end
            if haskey(node, "relativeQuantity")
                typenode.relativeQuantity = fmi3parseBoolean(node["relativeQuantity"])
            end
            if haskey(node, "min")
                typenode.min = fmi3parseFloat(node["min"])
            end
            if haskey(node, "max")
                typenode.max = fmi3parseFloat(node["max"])
            end
            if haskey(node, "nominal")
                typenode.nominal = fmi3parseFloat(node["nominal"])
            end
            if haskey(node, "unbounded")
                typenode.unbounded = fmi3parseBoolean(node["unbounded"])
            end
            if haskey(node, "start")
                typenode.start = fmi3parseFloat(node["start"])
            end
            if haskey(node, "derivative")
                typenode.derivative = parse(UInt, node["derivative"])
            end
        elseif typename == "String"
            modelVariables[index]._String = fmi3ModelDescriptionString()
            typenode = modelVariables[index]._String
            if haskey(node, "start")
                modelVariables[index]._String.start = node["start"]
            end
            # ToDo: remaining attributes
        elseif typename == "Boolean"
            modelVariables[index]._Boolean = fmi3ModelDescriptionBoolean()
            typenode = modelVariables[index]._Boolean
            if haskey(node, "start")
                modelVariables[index]._Boolean.start = fmi3parseBoolean(node["start"])
            end
            # ToDo: remaining attributes
        elseif typename == "Int32"
            modelVariables[index]._Integer = fmi3ModelDescriptionInteger()
            typenode = modelVariables[index]._Integer
            if haskey(node, "start")
                modelVariables[index]._Integer.start = fmi3parseInteger(node["start"])
            end
            # ToDo: remaining attributes
        elseif typename == "Enumeration"
            modelVariables[index]._Enumeration = fmi3ModelDescriptionEnumeration()
            typenode = modelVariables[index]._Enumeration
            # ToDo: Save start value
            # ToDo: remaining attributes
        else 
            @warn "Unknown data type `$(typename)`."
        end

        # generic attributes TODO not working bc not all variable types are implemented
        # if typenode !== nothing
        #     if haskey(node.firstelement, "declaredType")
        #         typenode.declaredType = node.firstelement["declaredType"]
        #     end
        # end
        
        md.stringValueReferences[name] = valueReference

        index += 1
    end

    modelVariables
end

# Parses the model structure of the FMU model description.
# replaces parseInitialUnknown, parseDerivatives, parse Output from fmi2 ABM
function parseModelStructure(nodes::EzXML.Node, md::fmi3ModelDescription)
    @assert (nodes.name == "ModelStructure") "Wrong section name."
    md.modelStructure.continuousStateDerivatives = []
    md.modelStructure.initialUnknowns = []
    md.modelStructure.eventIndicators = []
    md.modelStructure.outputs = []
    for node in eachelement(nodes)
        if haskey(node, "valueReference")
            varDep = parseDependencies(node)
            if node.name == "ContinuousStateDerivative"

                # find states and derivatives
                derSV = fmi3ModelVariablesForValueReference(md, fmi3ValueReference(fmi3parseInteger(node["valueReference"])))[1]
                # derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV._Float.derivative].valueReference

                if stateVR ∉ md.stateValueReferences
                    push!(md.stateValueReferences, stateVR)
                end
                if derVR ∉ md.derivativeValueReferences
                    push!(md.derivativeValueReferences, derVR)
                end

                push!(md.modelStructure.continuousStateDerivatives, varDep)
            elseif node.name == "InitialUnknown"
                push!(md.modelStructure.initialUnknowns, varDep)
            elseif node.name == "Output"
                # find outputs
                outVR = fmi3ValueReference(fmi3parseInteger(node["valueReference"]))
                
                if outVR ∉ md.outputValueReferences
                    push!(md.outputValueReferences, outVR)
                end

                push!(md.modelStructure.outputs, varDep)
            
            elseif node.name == "EventIndicator"
                md.numberOfEventIndicators += 1
                push!(md.modelStructure.eventIndicators)
                # TODO parse valueReferences to another array
            
            else
                @warn "Unknown entry in `ModelStructure` named `$(node.name)`."
            end
        else 
            @warn "Invalid entry for node `$(node.name)` in `ModelStructure`, missing entry `valueReference`."
        end
    end
    md.numberOfContinuousStates = length(md.stateValueReferences)
end

# parseUnknown in FMI2_md.jl
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
# TODO unused/replaced by parseModelStructure
function parseContinuousStateDerivative(nodes::EzXML.Node, md::fmi3ModelDescription)
    @assert (nodes.name == "ContinuousStateDerivative") "Wrong element name."
    md.modelStructure.derivatives = []
    for node in eachelement(nodes)
        if node.name == "ContinuousStateDerivative"
            if haskey(node, "valueReference")
                varDep = parseDependencies(node)

                # find states and derivatives
                derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV._Float.derivative].valueReference

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

# TODO unused/replaced by parseModelStructure
function parseInitialUnknowns(node::EzXML.Node, md::fmi3ModelDescription)
    @assert (node.name == "InitialUnknowns") "Wrong element name."
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknown(node)

                push!(md.modelStructure.initialUnknowns, varDep)
            else 
                @warn "Invalid entry for node `Unknown` in `ModelStructure`, missing entry `index`."
            end
        else 
            @warn "Unknown entry in `ModelStructure.InitialUnknowns` named `$(node.name)`."
        end 
    end
end

# TODO unused/replaced by parseModelStructure
function parseOutputs(nodes::EzXML.Node, md::fmi3ModelDescription)
    @assert (nodes.name == "Outputs") "Wrong element name."
    md.modelStructure.outputs = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknown(node)

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

# parses node (interpreted as boolean)
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

# parses node (interpreted as integer)
function fmi3parseNodeInteger(node, key; onfail=nothing)
    if haskey(node, key)
        return fmi3parseInteger(node[key]; onfail=onfail)
    else
        return onfail
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

# parses node (interpreted as real)
function fmi3parseNodeFloat(node, key; onfail=nothing)
    if haskey(node, key)
        return fmi3parseFloat(node[key]; onfail=onfail)
    else
        return onfail
    end
end

# parses node (interpreted as string)
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

# set the datatype and attributes of an model variable
# ABM: deprecated in fmi2 still used here until refactor
function fmi3SetDatatypeVariables(node::EzXML.Node, md::fmi3ModelDescription)
    type = fmi3DatatypeVariable()
    typename = node.name
    type.canHandleMultipleSet = nothing
    type.intermediateUpdate = fmi3False
    type.previous = nothing
    type.clocks = nothing
    type.declaredType = nothing
    type.start = nothing
    type.min = nothing
    type.max = nothing
    type.initial = nothing
    type.quantity = nothing
    type.unit = nothing
    type.displayUnit = nothing
    type.relativeQuantity = nothing
    type.nominal = nothing
    type.unbounded = nothing
    type.derivative = nothing
    type.reinit = nothing
    type.mimeType = nothing
    type.maxSize = nothing
    type.datatype = nothing

    # TODO fmi3Boolean, fmi3UInt8 are the same datatype so they get recognized the same
    if typename == "Float32"
        type.datatype = fmi3Float32
    elseif typename == "Float64"
        type.datatype = fmi3Float64
    elseif typename == "Int8"
        type.datatype = fmi3Int8
    elseif typename == "UInt8"
        type.datatype = fmi3UInt8
    elseif typename == "Int16"
        type.datatype = fmi3Int16
    elseif typename == "UInt16"
        type.datatype = fmi3UInt16
    elseif typename == "Int32"
        type.datatype = fmi3Int32
    elseif typename == "UInt32"
        type.datatype = fmi3UInt32
    elseif typename == "Int64"
        type.datatype = fmi3Int64
    elseif typename == "UInt64"
        type.datatype = fmi3UInt64
    elseif typename == "Boolean"
        type.datatype = fmi3Boolean
    elseif typename == "Binary" 
        type.datatype = fmi3Binary
    elseif typename == "Char"
        type.datatype = fmi3Char
    elseif typename == "String"
        type.datatype = fmi3String
    elseif typename == "Byte"
        type.datatype = fmi3Byte
    elseif typename == "Enum"
        type.datatype = fmi3Enum
    else
        @warn "Datatype for the variable $(node["name"]) is unknown!"
    end

    if haskey(node, "declaredType")
        type.declaredType = node["declaredType"]
    end

    # if haskey(node, "initial")
    #     for i in 0:(length(instances(fmi3initial))-1)
    #         if "fmi3" * node["initial"] == string(fmi3initial(i))
    #             type.initial = fmi3initial(i)
    #         end
    #     end
    # end

    if haskey(node, "start")
        if node.firstelement !== nothing && node.firstelement.name == "Dimension"
            substrings = split(node["start"], " ")
            if typename == "Float32"
                type.start = Array{fmi3Float32}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3Float32, string))
                end
            elseif typename == "Float64"
                type.start = Array{fmi3Float64}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3Float64, string))
                end
            elseif typename == "Int32"
                type.start = Array{fmi3Int32}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3Int32, string))
                end
            elseif typename == "UInt32"
                type.start = Array{fmi3UInt32}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3UInt32, string))
                end
            elseif typename == "Int64"
                type.start = Array{fmi3Int64}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3Int64, string))
                end
            elseif typename == "UInt64"
                type.start = Array{fmi3UInt64}(undef, 0)
                for string in substrings
                    push!(type.start, parse(fmi3UInt64, string))
                end
            else
                @warn "More array variable types not implemented yet!"
            end
        else
            if typename == "Float32"
                type.start = parse(fmi3Float32, node["start"])
            elseif typename == "Float64"
                type.start = parse(fmi3Float32, node["start"])
            elseif typename == "Int8"
                type.start = parse(fmi3Int8, node["start"])
            elseif typename == "UInt8"
                type.start = parse(fmi3UInt8, node["start"])
            elseif typename == "Int16"
                type.start = parse(fmi3Int16, node["start"])
            elseif typename == "UInt16"
                type.start = parse(fmi3UInt16, node["start"])
            elseif typename == "Int32"
                type.start = parse(fmi3Int32, node["start"])
            elseif typename == "UInt32"
                type.start = parse(fmi3UInt32, node["start"])
            elseif typename == "Int64"
                type.start = parse(fmi3Int64, node["start"])
            elseif typename == "UInt64"
                type.start = parse(fmi3UInt64, node["start"]) 
            elseif typename == "Boolean"
                type.start = parseFMI3Boolean(node["start"])
            elseif typename == "Binary"
                type.start = pointer(node["start"])
            elseif typename == "Char"
                type.start = parse(fmi3Char, node["start"])
            elseif typename == "String"
                type.start = parse(fmi3String, node["start"])
            elseif typename == "Byte"
                type.start = parse(fmi3Byte, node["start"])
            elseif typename == "Enum"
                for i in 1:length(md.enumerations)
                    if type.declaredType == md.enumerations[i][1] # identify the enum by the name
                        type.start = md.enumerations[i][1 + parse(Int, node["start"])] # find the enum value and set it
                    end
                end
            else
                @warn "setDatatypeVariables(...) unimplemented start value type $typename"
                type.start = node["start"]
            end
        end
    end
    if haskey(node, "intermediateUpdate")
        type.intermediateUpdate = fmi3True
    end

    if haskey(node, "min") && (type.datatype != fmi3Binary || type.datatype != fmiBoolean)
        if type.datatype == fmi3Float32 || type.datatype == fmi3Float64
            type.min = parse(fmi3Float64, node["min"])
        elseif type.datatype == fmi3Enum
            type.min = parse(fmi3Int64, node["min"])
        elseif type.datatype == fmi3Int8 || type.datatype == fmi3Int16 || type.datatype == fmi3Int32 || type.datatype == fmi3Int64
            type.min = parse(fmi3Int32, node["min"])
        else
            type.min = parse(fmi3UInt32, node["min"])
        end
    end
    if haskey(node, "max") && (type.datatype != fmi3Binary || type.datatype != fmiBoolean)
        if type.datatype == fmi3Float32 || type.datatype == fmi3Float64
            type.max = parse(fmi3Float64, node["max"])
        elseif type.datatype == fmi3Enum
            type.max = parse(fmi3Int64, node["max"])
        elseif type.datatype == fmi3Int8 || type.datatype == fmi3Int16 || type.datatype == fmi3Int32 || type.datatype == fmi3Int64
            type.max = parse(fmi3Int32, node["max"])
        else
            type.max = parse(fmi3UInt32, node["max"])
        end
    end
    if haskey(node, "quantity") && (type.datatype != Boolean || type.datatype != fmi3Binary)
        type.quantity = node["quantity"]
    end
    if haskey(node, "unit") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.unit = node["unit"]
    end
    if haskey(node, "displayUnit") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.displayUnit = node["displayUnit"]
    end
    if haskey(node, "relativeQuantity") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.relativeQuantity = parseFMI3Boolean(node["relativeQuantity"])
    else
        type.relativeQuantity = fmi3False
    end
    if haskey(node, "nominal") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.nominal = parse(fmi3Float64, node["nominal"])
    end
    if haskey(node, "unbounded") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.unbounded = parseFMI3Boolean(node["unbounded"])
    else
        type.unbounded = fmi3False
    end
    if haskey(node, "derivative") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.derivative = parse(fmi3UInt32, node["derivative"])
    end
    if haskey(node, "reinit") && (type.datatype == fmi3Float32 || type.datatype == fmi3Float64)
        type.reinit = parseFMI3Boolean(node["reinit"])
    end
    if haskey(node, "mimeType") && type.datatype == fmi3Binary
        type.mimeType = node["mimeType"]
    else
        type.mimeType = "application/octet"
    end
    if haskey(node, "maxSize") && type.datatype == fmi3Binary
        type.maxSize = parse(fmi3UInt32, node["maxSize"])
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

    fmi3GetDefaultStartTime(md::fmi3ModelDescription)

Returns startTime from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.startTime::Union{Real,Nothing}`: Returns a real value `startTime` from the DefaultExperiment if defined else defaults to `nothing`.
"""
function fmi3GetDefaultStartTime(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.startTime
end

"""

    fmi3GetDefaultStopTime(md::fmi3ModelDescription)

Returns stopTime from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.stopTime::Union{Real,Nothing}`: Returns a real value `stopTime` from the DefaultExperiment if defined else defaults to `nothing`.
"""
function fmi3GetDefaultStopTime(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.stopTime
end

"""

    fmi3GetDefaultTolerance(md::fmi3ModelDescription)

Returns tolerance from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.tolerance::Union{Real,Nothing}`: Returns a real value `tolerance` from the DefaultExperiment if defined else defaults to `nothing`.
"""
function fmi3GetDefaultTolerance(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.tolerance
end

"""

    fmi3GetDefaultStepSize(md::fmi3ModelDescription)

Returns stepSize from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.stepSize::Union{Real,Nothing}`: Returns a real value `setpSize` from the DefaultExperiment if defined else defaults to `nothing`.
"""
function fmi3GetDefaultStepSize(md::fmi3ModelDescription)
    if md.defaultExperiment === nothing 
        return nothing
    end
    return md.defaultExperiment.stepSize
end

"""

    fmi3GetModelName(md::fmi3ModelDescription)

Returns the tag 'modelName' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.modelName::String`: Returns the tag 'modelName' from the model description.
"""
function fmi3GetModelName(md::fmi3ModelDescription)#, escape::Bool = true)
    md.modelName
end

"""

    fmi3GetInstantiationToken(md::fmi3ModelDescription)

Returns the tag 'instantiationToken' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.instantiationToken::String`: Returns the tag 'instantiationToken' from the model description.
"""
function fmi3GetInstantiationToken(md::fmi3ModelDescription)
    md.instantiationToken
end

"""

    fmi3GetGenerationTool(md::fmi3ModelDescription)

Returns the tag 'generationtool' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.generationTool::Union{String, Nothing}`: Returns the tag 'generationtool' from the model description.
"""
function fmi3GetGenerationTool(md::fmi3ModelDescription)
    md.generationTool
end

"""

    fmi3GetGenerationDateAndTime(md::fmi3ModelDescription)

Returns the tag 'generationdateandtime' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.generationDateAndTime::DateTime`: Returns the tag 'generationdateandtime' from the model description.
"""
function fmi3GetGenerationDateAndTime(md::fmi3ModelDescription)
    md.generationDateAndTime
end

"""

    fmi3GetVariableNamingConvention(md::fmi3ModelDescription)

Returns the tag 'varaiblenamingconvention' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.variableNamingConvention::Union{fmi3VariableNamingConvention, Nothing}`: Returns the tag 'variableNamingConvention' from the model description.
"""
function fmi3GetVariableNamingConvention(md::fmi3ModelDescription)
    md.variableNamingConvention
end

"""

    fmi3GetNumberOfEventIndicators(md::fmi3ModelDescription)

Returns the tag 'numberOfEventIndicators' from the model description.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.numberOfEventIndicators::Union{UInt, Nothing}`: Returns the tag 'numberOfEventIndicators' from the model description.
"""
function fmi3GetNumberOfEventIndicators(md::fmi3ModelDescription)
    md.numberOfEventIndicators
end

"""

    fmi3GetNumberOfStates(md::fmi3ModelDescription)

Returns the number of states of the FMU.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- Returns the length of the `md.valueReferences::Array{fmi3ValueReference}` corresponding to the number of states of the FMU.
"""
function fmi3GetNumberOfStates(md::fmi3ModelDescription)
    length(md.stateValueReferences)
end

"""

    fmi3IsCoSimulation(md::fmi3ModelDescription)

Returns true, if the FMU supports co simulation

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports co simulation
"""
function fmi3IsCoSimulation(md::fmi3ModelDescription)
    return( md.coSimulation !== nothing)
end

"""

    fmi3IsModelExchange(md::fmi3ModelDescription)

Returns true, if the FMU supports model exchange

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports model exchange
"""
function fmi3IsModelExchange(md::fmi3ModelDescription)
    return( md.modelExchange !== nothing)
end
"""

    fmi3IsScheduledExecution(md::fmi3ModelDescription)

Returns true, if the FMU supports scheduled execution

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports scheduled execution
"""
function fmi3IsScheduledExecution(md::fmi3ModelDescription)
    return( md.scheduledExecution !== nothing)
end

##################################
# [Sec. 3] information functions #
##################################

"""

    fmi3DependenciesSupported(md::fmi3ModelDescription)

Returns true if the FMU model description contains `dependency` information.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information.
"""
function fmi3DependenciesSupported(md::fmi3ModelDescription)
    if md.modelStructure === nothing
        return false
    end

    return true
end

"""

    fmi3DerivativeDependenciesSupported(md::fmi3ModelDescription)

Returns if the FMU model description contains `dependency` information for `derivatives`.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information for `derivatives`.
"""
function fmi3DerivativeDependenciesSupported(md::fmi3ModelDescription)
    if !fmi3DependenciesSupported(md)
        return false
    end

    der = md.modelStructure.derivatives
    if der === nothing || length(der) <= 0
        return false
    end

    return true
end

"""

    fmi3GetModelIdentifier(md::fmi3ModelDescription; type=nothing)

Returns the tag 'modelIdentifier' from CS, ME or SE section.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `type=nothing`: Defines whether a Co-Simulation, Model Exchange or ScheduledExecution is present. (default = nothing)

# Returns
- `md.modelExchange.modelIdentifier::String`: Returns the tag `modelIdentifier` from ModelExchange section.
- `md.coSimulation.modelIdentifier::String`: Returns the tag `modelIdentifier` from CoSimulation section.
- `md.scheduledExecution.modelIdentifier::String`: Returns the tag `modelIdentifier` from ScheduledExecution section.
"""
function fmi3GetModelIdentifier(md::fmi3ModelDescription; type=nothing)

    if type === nothing
        if fmi3IsCoSimulation(md)
            return md.coSimulation.modelIdentifier
        elseif fmi3IsModelExchange(md)
            return md.modelExchange.modelIdentifier
        elseif fmi3IsScheduledExecution(md)
            return md.scheduledExecution.modelIdentifier
        else
            @assert false "fmi3GetModelName(...): FMU does not support ME or CS!"
        end
    elseif type == fmi3TypeCoSimulation
        return md.coSimulation.modelIdentifier
    elseif type == fmi3TypeModelExchange
        return md.modelExchange.modelIdentifier
    elseif type == fmi3TypeScheduledExecution
        return md.scheduledExecution.modelIdentifier
    end
end

"""

    fmi3CanGetSetState(md::fmi3ModelDescription)

Returns true, if the FMU supports the getting/setting of states

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports the getting/setting of states.
"""
function fmi3CanGetSetState(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.canGetAndSetFMUstate) || (md.modelExchange !== nothing && md.modelExchange.canGetAndSetFMUstate)

end

"""

    fmi3CanSerializeFMUstate(md::fmi3ModelDescription)

Returns true, if the FMU state can be serialized

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU state can be serialized
"""
function fmi3CanSerializeFMUState(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.canSerializeFMUstate) || (md.modelExchange !== nothing && md.modelExchange.canSerializeFMUstate)

end

"""

    fmi3ProvidesDirectionalDerivatives(md::fmi3ModelDescription)

Returns true, if the FMU provides directional derivatives

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU provides directional derivatives
"""
function fmi3ProvidesDirectionalDerivatives(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.providesDirectionalDerivatives) || (md.modelExchange !== nothing && md.modelExchange.providesDirectionalDerivatives)
end

"""

    fmi3ProvidesAdjointDerivatives(md::fmi3ModelDescription)

Returns true, if the FMU provides adjoint derivatives

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU provides adjoint derivatives
"""
function fmi3ProvidesAdjointDerivatives(md::fmi3ModelDescription)
    return (md.coSimulation !== nothing && md.coSimulation.providesAdjointDerivatives) || (md.modelExchange !== nothing && md.modelExchange.providesAdjointDerivatives)

end

"""

    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.valueReferences)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of value references and their corresponding names

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}.
"""
function fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.valueReferences)
    dict = Dict{fmi3ValueReference, Array{String}}()
    for vr in vrs
        dict[vr] = fmi3ValueReferenceToString(md, vr)
    end
    return dict
end

"""

    fmi3GetValueReferencesAndNames(fmu::FMU3)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of value references and their corresponding names

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}.
"""
function fmi3GetValueReferencesAndNames(fmu::FMU3)
    fmi3GetValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetNames(md::fmi3ModelDescription; vrs=md.valueReferences, mode=:first)

Returns a array of names corresponding to value references `vrs`

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetNames(md::fmi3ModelDescription; vrs=md.valueReferences, mode=:first)
    names = []
    for vr in vrs
        ns = fmi3ValueReferenceToString(md, vr)

        if mode == :first
            push!(names, ns[1])
        elseif mode == :group
            push!(names, ns)
        elseif mode == :flat
            for n in ns
                push!(names, n)
            end
        else
            @assert false "fmi3GetNames(...) unknown mode `mode`, please choose between `:first`, `:group` and `:flat`."
        end
    end
    return names
end

"""

    fmi3GetNames(fmu::FMU3; vrs=md.valueReferences, mode=:first)

Returns a array of names corresponding to value references `vrs`

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetNames(fmu::FMU3; kwargs...)
    fmi3GetNames(fmu.modelDescription; kwargs...)
end

"""

    fmi3GetModelVariableIndices(md::fmi3ModelDescription; vrs=md.valueReferences)

Returns a array of indices corresponding to value references `vrs`

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)

# Returns
- `names::Array{Integer}`: Returns a array of indices corresponding to value references `vrs`
"""
function fmi3GetModelVariableIndices(md::fmi3ModelDescription; vrs=md.valueReferences)
    indices = []

    for i = 1:length(md.modelVariables)
        if md.modelVariables[i].valueReference in vrs
            push!(indices, i)
        end
    end

    return indices
end

"""

    fmi3GetInputValueReferencesAndNames(md::fmi3ModelDescription)

Returns a dict with (vrs, names of inputs)

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of inputs)
"""
function fmi3GetInputValueReferencesAndNames(md::fmi3ModelDescription)
    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.inputValueReferences)
end

"""

    fmi3GetInputValueReferencesAndNames(fmu::FMU3)

Returns a dict with (vrs, names of inputs)

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of inputs)
"""
function fmi3GetInputValueReferencesAndNames(fmu::FMU3)
    fmi3GetInputValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetInputNames(md::fmi3ModelDescription; vrs=md.inputvalueReferences, mode=:first)

Returns names of inputs

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.inputvalueReferences`: Additional attribute `inputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetInputNames(md::fmi3ModelDescription; kwargs...)
    fmi3GetNames(md; vrs=md.inputValueReferences, kwargs...)
end

"""

    fmi3GetInputNames(fmu::FMU3; vrs=md.inputValueReferences, mode=:first)

Returns names of inputs

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.inputvalueReferences`: Additional attribute `inputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetInputNames(fmu::FMU3; kwargs...)
    fmi3GetInputNames(fmu.modelDescription; kwargs...)
end

"""

    fmi3GetOutputValueReferencesAndNames(md::fmi3ModelDescription)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of value references and their corresponding names

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi3ValueReference}`)

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}.So returns a dict with (vrs, names of outputs)
"""
function fmi3GetOutputValueReferencesAndNames(md::fmi3ModelDescription)
    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.outputValueReferences)
end

"""

    fmi3GetOutputValueReferencesAndNames(fmu::FMU3)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of value references and their corresponding names

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi3ValueReference}`)

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}.So returns a dict with (vrs, names of outputs)
"""
function fmi3GetOutputValueReferencesAndNames(fmu::FMU3)
    fmi3GetOutputValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetOutputNames(md::fmi3ModelDescription; vrs=md.outputvalueReferences, mode=:first)

Returns names of outputs

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetOutputNames(md::fmi3ModelDescription; kwargs...)
    fmi3GetNames(md; vrs=md.outputValueReferences, kwargs...)
end

"""

    fmi3GetOutputNames(fmu::FMU3; vrs=md.outputvalueReferences, mode=:first)

Returns names of outputs

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi3ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`
"""
function fmi3GetOutputNames(fmu::FMU3; kwargs...)
    fmi3GetOutputNames(fmu.modelDescription; kwargs...)
end

"""

    fmi3GetParameterValueReferencesAndNames(md::fmi3ModelDescription)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of parameterValueReferences and their corresponding names

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of parameters).

See also ['fmi3GetValueReferencesAndNames'](@ref).
"""
function fmi3GetParameterValueReferencesAndNames(md::fmi3ModelDescription)
    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.parameterValueReferences)
end

"""

    fmi3GetParameterValueReferencesAndNames(fmu::FMU3)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of parameterValueReferences and their corresponding names

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of parameters).

See also ['fmi3GetValueReferencesAndNames'](@ref).
"""
function fmi3GetParameterValueReferencesAndNames(fmu::FMU3)
    fmi3GetParameterValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetParameterNames(md::fmi3ModelDescription; vrs=md.parameterValueReferences, mode=:first)

Returns names of parameters

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.parameterValueReferences`: Additional attribute `parameterValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.parameterValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetParameterNames(md::fmi3ModelDescription; kwargs...)
    fmi3GetNames(md; vrs=md.parameterValueReferences, kwargs...)
end

"""

    fmi3GetParameterNames(fmu::FMU3; vrs=md.parameterValueReferences, mode=:first)

Returns names of parameters

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.parameterValueReferences`: Additional attribute `parameterValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.parameterValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetParameterNames(fmu::FMU3; kwargs...)
    fmi3GetParameterNames(fmu.modelDescription; kwargs...)
end

"""

    fmi3GetStateValueReferencesAndNames(md::fmi3ModelDescription)

Returns dict(vrs, names of states)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of state value references and their corresponding names.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of states)
"""
function fmi3GetStateValueReferencesAndNames(md::fmi3ModelDescription)
    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.stateValueReferences)
end

"""

    fmi3GetStateValueReferencesAndNames(fmu::FMU3)

Returns dict(vrs, names of states)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of state value references and their corresponding names.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of states)
"""
function fmi3GetStateValueReferencesAndNames(fmu::FMU3)
    fmi3GetStateValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetStateNames(md::fmi3ModelDescription; vrs=md.stateValueReferences, mode=:first)

Returns names of states

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.stateValueReferences`: Additional attribute `parameterValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.stateValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetStateNames(md::fmi3ModelDescription; kwargs...)
    fmi3GetNames(md; vrs=md.stateValueReferences, kwargs...)
end

"""

    fmi3GetStateNames(fmu::FMU3; vrs=md.stateValueReferences, mode=:first)

Returns names of states

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.stateValueReferences`: Additional attribute `parameterValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.stateValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetStateNames(fmu::FMU3; kwargs...)
    fmi3GetStateNames(fmu.modelDescription; kwargs...)
end

"""

fmi3GetDerivateValueReferencesAndNames(md::fmi3ModelDescription)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of derivative value references and their corresponding names

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of derivatives)
See also ['fmi3GetValueReferencesAndNames'](@ref)
"""
function fmi3GetDerivateValueReferencesAndNames(md::fmi3ModelDescription)
    fmi3GetValueReferencesAndNames(md::fmi3ModelDescription; vrs=md.derivativeValueReferences)
end

"""

    fmi3GetDerivateValueReferencesAndNames(fmu::FMU3)

Returns a dictionary `Dict(fmi3ValueReference, Array{String})` of derivative value references and their corresponding names

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{fmi3ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi3ValueReference and values of type Array{String}. So returns a dict with (vrs, names of derivatives)
See also ['fmi3GetValueReferencesAndNames'](@ref)
"""
function fmi3GetDerivateValueReferencesAndNames(fmu::FMU3)
    fmi3GetDerivateValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi3GetDerivativeNames(md::fmi3ModelDescription; vrs=md.derivativeValueReferences, mode=:first)

Returns names of derivatives

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.derivativeValueReferences`: Additional attribute `derivativeValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.derivativeValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetDerivativeNames(md::fmi3ModelDescription; kwargs...)
    fmi3GetNames(md; vrs=md.derivativeValueReferences, kwargs...)
end

"""

    fmi3GetDerivativeNames(fmu::FMU3; vrs=md.derivativeValueReferences, mode=:first)

Returns names of derivatives

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `vrs=md.derivativeValueReferences`: Additional attribute `derivativeValueReferences::Array{fmi3ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.derivativeValueReferences::Array{fmi3ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)

# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi3GetNames'](@ref).
"""
function fmi3GetDerivativeNames(fmu::FMU3; kwargs...)
    fmi3GetDerivativeNames(fmu.modelDescription; kwargs...)
end

"""

    fmi3GetNamesAndDescriptions(md::fmi3ModelDescription)

Returns a dictionary of variables with their descriptions

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].description::Union{String, Nothing}`). (Creates a tuple (name, description) for each i in 1:length(md.modelVariables))
"""
function fmi3GetNamesAndDescriptions(md::fmi3ModelDescription)
    Dict(md.modelVariables[i].name => md.modelVariables[i].description for i = 1:length(md.modelVariables))
end

"""

    fmi3GetNamesAndDescriptions(fmu::FMU3)

Returns a dictionary of variables with their descriptions

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].description::Union{String, Nothing}`). (Creates a tuple (name, description) for each i in 1:length(md.modelVariables))
"""
function fmi3GetNamesAndDescriptions(fmu::FMU3)
    fmi3GetNamesAndDescriptions(fmu.modelDescription)
end

"""

    fmi3GetNamesAndUnits(md::fmi3ModelDescription)

Returns a dictionary of variables with their units

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i]._Real.unit::Union{String, Nothing}`). (Creates a tuple (name, unit) for each i in 1:length(md.modelVariables))
See also [`fmi3GetUnit`](@ref).
"""
function fmi3GetNamesAndUnits(md::fmi3ModelDescription)
    Dict(md.modelVariables[i].name => fmi3GetUnit(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

"""

    fmi3GetNamesAndUnits(fmu::FMU3)

Returns a dictionary of variables with their units

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i]._Real.unit::Union{String, Nothing}`). (Creates a tuple (name, unit) for each i in 1:length(md.modelVariables))
See also [`fmi3GetUnit`](@ref).
"""
function fmi3GetNamesAndUnits(fmu::FMU3)
    fmi3GetNamesAndUnits(fmu.modelDescription)
end

"""

   fmi3GetNamesAndInitials(md::fmi3ModelDescription)

Returns a dictionary of variables with their initials

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, Cuint}`: Returns a dictionary that constructs a hash table with keys of type String and values of type Cuint. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].inital::Union{fmi3Initial, Nothing}`). (Creates a tuple (name,initial) for each i in 1:length(md.modelVariables))
See also [`fmi3GetInitial`](@ref).
"""
function fmi3GetNamesAndInitials(md::fmi3ModelDescription)
    Dict(md.modelVariables[i].name => fmi3GetInitial(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

"""

   fmi3GetNamesAndInitials(fmu::FMU3)

Returns a dictionary of variables with their initials

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{String, Cuint}`: Returns a dictionary that constructs a hash table with keys of type String and values of type Cuint. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].inital::Union{fmi3Initial, Nothing}`). (Creates a tuple (name,initial) for each i in 1:length(md.modelVariables))
See also [`fmi3GetInitial`](@ref).
"""
function fmi3GetNamesAndInitials(fmu::FMU3)
    fmi3GetNamesAndInitials(fmu.modelDescription)
end

"""

    fmi3GetInputNamesAndStarts(md::fmi3ModelDescription)

Returns a dictionary of input variables with their starting values

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, Array{fmi3ValueReferenceFormat}}`: Returns a dictionary that constructs a hash table with keys of type String and values of type fmi3ValueReferenceFormat. So returns a dict with ( `md.modelVariables[i].name::String`, `starts:: Array{fmi3ValueReferenceFormat}` ). (Creates a tuple (name, starts) for each i in inputIndices)
See also ['fmi3GetStartValue'](@ref).
"""
function fmi3GetInputNamesAndStarts(md::fmi3ModelDescription)

    inputIndices = fmi3GetModelVariableIndices(md; vrs=md.inputValueReferences)
    Dict(md.modelVariables[i].name => fmi3GetStartValue(md.modelVariables[i]) for i in inputIndices)
end

"""

    fmi3GetInputNamesAndStarts(md::fmi3ModelDescription)

Returns a dictionary of input variables with their starting values

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `dict::Dict{String, Array{fmi3ValueReferenceFormat}}`: Returns a dictionary that constructs a hash table with keys of type String and values of type fmi3ValueReferenceFormat. So returns a dict with ( `md.modelVariables[i].name::String`, `starts:: Array{fmi3ValueReferenceFormat}` ). (Creates a tuple (name, starts) for each i in inputIndices)
See also ['fmi3GetStartValue'](@ref).
"""
function fmi3GetInputNamesAndStarts(fmu::FMU3)
    fmi3GetInputNamesAndStarts(fmu.modelDescription)
end