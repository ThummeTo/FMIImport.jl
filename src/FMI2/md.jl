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

    fmi2LoadModelDescription(pathToModelDescription::String)

Extract the FMU variables and meta data from the ModelDescription

# Arguments
- `pathToModelDescription::String`: Contains the path to a file name that is selected to be read and converted to an XML document. In order to better extract the variables and meta data in the further process.

# Returns
- `md::fmi2ModelDescription`: Retuns a struct which provides the static information of ModelVariables.

# Source
- [EzXML.jl](https://juliaio.github.io/EzXML.jl/stable/)
"""
function fmi2LoadModelDescription(pathToModelDescription::String)
    md = fmi2ModelDescription()

    md.stringValueReferences = Dict{String, fmi2ValueReference}()
    md.outputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.inputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.stateValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.derivativeValueReferences = Array{fmi2ValueReference}(undef, 0)

    md.enumerations = []

    doc = readxml(pathToModelDescription)

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
            md.typeDefinitions = createSimpleTypes(node)

        elseif node.name == "UnitDefinitions"
            md.unitDefinitions = createUnits(node)

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

    setDefaultsFromDeclaredType!(md.modelVariables, md.typeDefinitions)

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

# helpers to enable parsing of `nothing`
parseStringOrNothing(target_type::Type{String}, src_str::String) = src_str
parseStringOrNothing(target_type, src_str::String) = parse(target_type, src_str)
parseStringOrNothing(target_type, src_str::Nothing) = nothing

# convenient get method with fallback for xml nodes
function getWithDefault(node::EzXML.Node, key::String, default)
    if haskey(node, key)
        return node[key]
    end
    return default
end
getWithDefault(node::EzXML.Node, key::Symbol, default)=getWithDefault(node,string(key), default)

"""
    parseSimpleTypeAttributes!(attr_struct, defnode)

Helper function to read all attributes from `defnode` (a node in an XML description) 
and set the corresponding fields in `attr_struct <: FMICore.fmi2SimpleTypeAttributeStruct`.
"""
parseSimpleTypeAttributes!(attr_struct, defnode) = nothing
function parseSimpleTypeAttributes!(attr_struct::FMICore.fmi2SimpleTypeAttributesReal, defnode)
    for (attr_name, attr_type) in [
        (:quantity, String), (:unit, String), (:displayUnit, String), (:relativeQuantity, Bool),
        (:min, fmi2Real), (:max, fmi2Real), (:nominal, fmi2Real), (:unbounded, Bool)
    ]
        setfield!(
            attr_struct, 
            attr_name, 
            parseStringOrNothing(attr_type, getWithDefault(defnode, attr_name, nothing))
        )
    end 
    return attr_struct
end
function parseSimpleTypeAttributes!(attr_struct::FMICore.fmi2SimpleTypeAttributesInteger, defnode)
    for (attr_name, attr_type) in [(:quantity, String), (:min, fmi2Real), (:max, fmi2Real)]
        setfield!(
            attr_struct, 
            attr_name, 
            parseStringOrNothing(attr_type, getWithDefault(defnode, attr_name, nothing))
        )
    end 
    return attr_struct
end

# helper function to parse simpleType attributes into an appropriate attribute struct
"""
    parseSimpleTypeAttributes(defnode)

Helper function to read the type name and all type attributes from `defnode` 
(a node in an XML description) and return the right `FMICore.fmi2SimpleTypeAttributeStruct`.
"""
function parseSimpleTypeAttributes(defnode, _typename=nothing)
    typename = isnothing(_typename) ? defnode.name : _typename

    # determine right attribute set for `typename`
    attr_struct = if typename == "Real"
        FMICore.fmi2SimpleTypeAttributesReal()
    elseif typename == "Integer"
        FMICore.fmi2SimpleTypeAttributesInteger()
    elseif typename == "String"
        FMICore.fmi2SimpleTypeAttributesString()
    elseif typename == "Boolean"
        FMICore.fmi2SimpleTypeAttributesBoolean()
    elseif typename == "Enumeration"
        FMICore.fmi2SimpleTypeAttributesEnumeration()
    end

    # parse fields in `defnode` and set them in attr_struct
    parseSimpleTypeAttributes!(attr_struct, defnode)
    return attr_struct
end

# helper function to parse variable attributes
function parseModelDescriptionVariable(defnode, _typename=nothing)
    typename = isnothing(_typename) ? defnode.name : _typename
    if typename == "Real"
        typenode = fmi2ModelDescriptionReal()
        if haskey(defnode, "quantity")
            typenode.quantity = defnode["quantity"]
        end
        if haskey(defnode, "unit")
            typenode.unit = defnode["unit"]
        end
        if haskey(defnode, "displayUnit")
            typenode.displayUnit = defnode["displayUnit"]
        end
        if haskey(defnode, "relativeQuantity")
            typenode.relativeQuantity = parseBoolean(defnode["relativeQuantity"])
        end
        if haskey(defnode, "min")
            typenode.min = parseReal(defnode["min"])
        end
        if haskey(defnode, "max")
            typenode.max = parseReal(defnode["max"])
        end
        if haskey(defnode, "nominal")
            typenode.nominal = parseReal(defnode["nominal"])
        end
        if haskey(defnode, "unbounded")
            typenode.unbounded = parseBoolean(defnode["unbounded"])
        end
        if haskey(defnode, "start")
            typenode.start = parseReal(defnode["start"])
        end
        if haskey(defnode, "derivative")
            typenode.derivative = parse(UInt, defnode["derivative"])
        end
    elseif typename == "String"
        typenode = fmi2ModelDescriptionString()
        if haskey(defnode, "start")
            typenode.start = defnode["start"]
        end
        # ToDo: remaining attributes
    elseif typename == "Boolean"
        typenode = fmi2ModelDescriptionBoolean()
        if haskey(defnode, "start")
            typenode.start = parseFMI2Boolean(defnode["start"])
        end
        # ToDo: remaining attributes
    elseif typename == "Integer"
        typenode = fmi2ModelDescriptionInteger()
        if haskey(defnode, "start")
            typenode.start = parseInteger(defnode["start"])
        end
        # ToDo: remaining attributes
    elseif typename == "Enumeration"
        typenode = fmi2ModelDescriptionEnumeration()
        # ToDo: Save start value
        # ToDo: remaining attributes
    else
        @warn "Unknown data type `$(typename)`."
        typenode = nothing
    end
    return typenode
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

        causality = nothing
        if haskey(node, "causality")
            causality = fmi2StringToCausality(node["causality"])

            if causality == fmi2CausalityOutput
                push!(md.outputValueReferences, valueReference)
            elseif causality == fmi2CausalityInput
                push!(md.inputValueReferences, valueReference)
            elseif causality == fmi2CausalityParameter
                push!(md.parameterValueReferences, valueReference)
            end
        end

        variability = nothing
        if haskey(node, "variability")
            variability = fmi2StringToVariability(node["variability"])
        end

        initial = nothing
        if haskey(node, "initial")
            initial = fmi2StringToInitial(node["initial"])
        end

        scalarVariables[index] = fmi2ScalarVariable(name, valueReference, causality, variability, initial)

        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        if haskey(node, "description")
            scalarVariables[index].description = node["description"]
        end

        # type node
        defnode = node.firstelement
        typenode = parseModelDescriptionVariable(defnode)
        if isa(typenode, fmi2ModelDescriptionReal)
            scalarVariables[index].Real = typenode
        elseif isa(typenode, fmi2ModelDescriptionString)
            scalarVariables[index].String = typenode
        elseif isa(typenode, fmi2ModelDescriptionBoolean)
            scalarVariables[index].Boolean = typenode
        elseif isa(typenode, fmi2ModelDescriptionInteger)
            scalarVariables[index].Integer = typenode
        elseif isa(typenode, fmi2ModelDescriptionEnumeration)
            scalarVariables[index].Enumeration = typenode
        end
        
        # generic attributes
        if !isnothing(typenode)
            if haskey(node.firstelement, "declaredType")
                typenode.declaredType = node.firstelement["declaredType"]
            end
        end

        md.stringValueReferences[name] = valueReference

        index += 1
    end

    scalarVariables
end

"""
    setDefaultsWithSimpleType!(variable_description, simple_type)

Helper function to set the attributes of `variable description` according to the attributes 
stored in `simple_type`. However, if a value is set already, it is not overwritten.
"""
setDefaultsWithSimpleType!(variable_description, simple_type)=nothing
# helper to avoid redundant code below:
function setDefaultsWithSimpleType!(attr_struct::T, variable_description) where {
    T<:FMICore.fmi2SimpleTypeAttributeStruct
}
    for attr in fieldnames(T)
        trgt = getfield(variable_description, attr)
        if isnothing(trgt)
            setfield!(variable_description, attr, getfield(attr_struct, attr))
        end
    end
    return nothing
end
# Helper function to set the attributes of `variable description` according to the attributes 
# stored in `simple_type`, for **Real** variables:
function setDefaultsWithSimpleType!(variable_description::FMICore.fmi2ModelDescriptionReal, simple_type)
    attr_struct = simple_type.Real # throws error if `simple_type` has no attribute `Real`
    return setDefaultsWithSimpleType!(attr_struct, variable_description)
end
# Helper function to set the attributes of `variable description` according to the attributes 
# stored in `simple_type`, for **Integer** variables:
function setDefaultsWithSimpleType!(variable_description::FMICore.fmi2ModelDescriptionInteger, simple_type)
    attr_struct = simple_type.Integer
    return setDefaultsWithSimpleType!(attr_struct, variable_description)
end

# TODO
# * once all attributes are implemented for “Enumeration”, define `setDefaultsWithSimpleType`
#   for `fmi2ModelDescriptionEnumeration`.

"""
    setDefaultsFromDeclaredType!(scalarVariables, simpleTypes)

Helper function that sets attributes of scalar variables according to their “declaredType”, 
if applicable.
"""
function setDefaultsFromDeclaredType!(scalarVariables, simpleTypes)
    for svar in scalarVariables
        for nominalType in [:Real, :Integer, :Boolean, :String, :Enumeration]
            variable_description=getproperty(svar, nominalType)
            if !isnothing(variable_description)
                # TODO why is declaredType not initialized to be `nothing`?
                if isdefined(variable_description, :declaredType) && !isnothing(variable_description.declaredType)
                    # `ti` = index of first `fmi2SimpleType` with name matching declaredType
                    ti = findfirst(
                        simpleType -> simpleType.name == variable_description.declaredType,
                        simpleTypes 
                    )
                    if !isnothing(ti)
                        setDefaultsWithSimpleType!(variable_description, simpleTypes[ti])
                    else
                        @warn """
                        Scalar Variable $(svar.name) has declared type $(variable_description.declaredType).
                        However, $(variable_description.declaredType) cannot be found in the list of `fmi2SimpleType`s.
                        """
                    end
                end
                break
            end
        end
    end
end

# Parses the `ModelStructure.Derivatives` of the FMU model description.
function parseUnknown(node::EzXML.Node)
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
                varDep = parseUnknown(node)

                # find states and derivatives
                derSV = md.modelVariables[varDep.index]
                derVR = derSV.valueReference
                stateVR = md.modelVariables[derSV.Real.derivative].valueReference

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

# ToDo: Comment
function parseOutputs(nodes::EzXML.Node, md::fmi2ModelDescription)
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
        sv.Real = fmi2ModelDescriptionReal()
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
            sv.Real.start = type.start
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
            sv.Real.derivative = type.derivative
        end
    end
    if haskey(typenode, "reinit") && type.datatype == fmi2Real
        type.reinit = parseFMI2Boolean(typenode["reinit"])
    end
    type
end

# helper to create a `FMICore.BaseUnit` from a XML-Tag like `<BaseUnit m="1" s="-1"/>`
function parseBaseUnit(node)
    @assert node.name == "BaseUnit"
    unit = FMICore.BaseUnit()
    for siStr in FMICore.SI_UNIT_STRINGS
        if haskey(node, siStr)
            setfield!(unit, Symbol(siStr), parse(Int32, node[siStr]))
        end
    end
    if haskey(node, "factor")
        setfield!(unit, :factor, parse(Float64, node["factor"]))
    end
    if haskey(node, "offset")
        setfield!(unit, :offset, parse(Float64, node["offset"]))
    end
    return unit
end

# helper to create a `FMICore.DisplayUnit` from a XML-Tag like 
# `<DisplayUnit name="TempFahrenheit" factor="1.8" offset="-459.67"/>`
function parseDisplayUnit(node)
    @assert node.name == "DisplayUnit"

    unit = FMICore.DisplayUnit(node["name"])
    if haskey(node, "factor")
        setfield!(unit, :factor, parse(Float64, node["factor"]))
    end
    if haskey(node, "offset")
        setfield!(unit, :offset, parse(Float64, node["offset"]))
    end
    return unit
end

# helper to create a `FMICore.fmi2Unit` from a XML-Tag `<Unit … > … </Unit>`
function parseUnitNode(node)
    name = node["name"]
    unit = fmi2Unit(name)
    for subNode = eachelement(node)
        if subNode.name == "BaseUnit"
            unit.baseUnit = parseBaseUnit(subNode)
        elseif subNode.name == "DisplayUnit"
            displayUnit = parseDisplayUnit(subNode)
            if isnothing(unit.displayUnit)
                unit.displayUnit = FMICore.DisplayUnit[displayUnit]
            else
                push!(unit.displayUnit, displayUnit)
            end
        end
    end
    return unit
end

# helper to create a vector of `FMICore.fmi2Unit` from a node in an XML tree
function createUnits(node::EzXML.Node)
    return parseUnitNode.(eachelement(node))
end

# helper to create a vector of `FMICore.fmi2SimpleType` from a node in an XML tree
function createSimpleTypes(node::EzXML.Node)
    simpleTypes = fmi2SimpleType[]

    for simpleType = eachelement(node)
        name = simpleType["name"]
        description = getWithDefault(simpleType, "description", nothing)
        defnode = firstelement(simpleType)
        attr_struct = parseSimpleTypeAttributes(defnode)
        st = fmi2SimpleType(name, attr_struct, description)
        push!(simpleTypes, st)
    end
    return simpleTypes
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

    fmi2GetDefaultStartTime(md::fmi2ModelDescription)

Returns startTime from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.startTime::Union{Real,Nothing}`: Returns a real value `startTime` from the DefaultExperiment if defined else defaults to `nothing`.
"""
function fmi2GetDefaultStartTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing
        return nothing
    end
    return md.defaultExperiment.startTime
end

"""

    fmi2GetDefaultStopTime(md::fmi2ModelDescription)

Returns stopTime from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.stopTime::Union{Real,Nothing}`: Returns a real value `stopTime` from the DefaultExperiment if defined else defaults to `nothing`.

"""
function fmi2GetDefaultStopTime(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing
        return nothing
    end
    return md.defaultExperiment.stopTime
end

"""

    fmi2GetDefaultTolerance(md::fmi2ModelDescription)

Returns tolerance from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.tolerance::Union{Real,Nothing}`: Returns a real value `tolerance` from the DefaultExperiment if defined else defaults to `nothing`.

"""
function fmi2GetDefaultTolerance(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing
        return nothing
    end
    return md.defaultExperiment.tolerance
end

"""

    fmi2GetDefaultStepSize(md::fmi2ModelDescription)

Returns stepSize from DefaultExperiment if defined else defaults to nothing.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.defaultExperiment.stepSize::Union{Real,Nothing}`: Returns a real value `setpSize` from the DefaultExperiment if defined else defaults to `nothing`.

"""
function fmi2GetDefaultStepSize(md::fmi2ModelDescription)
    if md.defaultExperiment == nothing
        return nothing
    end
    return md.defaultExperiment.stepSize
end

"""

    fmi2GetModelName(md::fmi2ModelDescription)
Returns the tag 'modelName' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.modelName::String`: Returns the tag 'modelName' from the model description.

"""
function fmi2GetModelName(md::fmi2ModelDescription)#, escape::Bool = true)
    md.modelName
end

"""

    fmi2GetGUID(md::fmi2ModelDescription)

Returns the tag 'guid' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.guid::String`: Returns the tag 'guid' from the model description.

"""
function fmi2GetGUID(md::fmi2ModelDescription)
    md.guid
end

"""

    fmi2GetGenerationTool(md::fmi2ModelDescription)

Returns the tag 'generationtool' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.generationTool::Union{String, Nothing}`: Returns the tag 'generationtool' from the model description.

"""
function fmi2GetGenerationTool(md::fmi2ModelDescription)
    md.generationTool
end

"""

    fmi2GetGenerationDateAndTime(md::fmi2ModelDescription)

Returns the tag 'generationdateandtime' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.generationDateAndTime::DateTime`: Returns the tag 'generationdateandtime' from the model description.

"""
function fmi2GetGenerationDateAndTime(md::fmi2ModelDescription)
    md.generationDateAndTime
end

"""

    fmi2GetVariableNamingConvention(md::fmi2ModelDescription)

Returns the tag 'varaiblenamingconvention' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.variableNamingConvention::Union{fmi2VariableNamingConvention, Nothing}`: Returns the tag 'variableNamingConvention' from the model description.

"""
function fmi2GetVariableNamingConvention(md::fmi2ModelDescription)
    md.variableNamingConvention
end

"""

    fmi2GetNumberOfEventIndicators(md::fmi2ModelDescription)

Returns the tag 'numberOfEventIndicators' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `md.numberOfEventIndicators::Union{UInt, Nothing}`: Returns the tag 'numberOfEventIndicators' from the model description.

"""
function fmi2GetNumberOfEventIndicators(md::fmi2ModelDescription)
    md.numberOfEventIndicators
end

"""

    fmi2GetNumberOfStates(md::fmi2ModelDescription)

Returns the number of states of the FMU.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- Returns the length of the `md.valueReferences::Array{fmi2ValueReference}` corresponding to the number of states of the FMU.

"""
function fmi2GetNumberOfStates(md::fmi2ModelDescription)
    length(md.stateValueReferences)
end

"""

    fmi2IsCoSimulation(md::fmi2ModelDescription)

Returns true, if the FMU supports co simulation

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports co simulation

"""
function fmi2IsCoSimulation(md::fmi2ModelDescription)
    return (md.coSimulation != nothing)
end

"""

    fmi2IsModelExchange(md::fmi2ModelDescription)

Returns true, if the FMU supports model exchange

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports model exchange

"""
function fmi2IsModelExchange(md::fmi2ModelDescription)
    return (md.modelExchange != nothing)
end

##################################
# [Sec. 3] information functions #
##################################

"""

    fmi2DependenciesSupported(md::fmi2ModelDescription)

Returns true if the FMU model description contains `dependency` information.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information.

"""
function fmi2DependenciesSupported(md::fmi2ModelDescription)
    if md.modelStructure === nothing
        return false
    end

    return true
end

"""

    fmi2DerivativeDependenciesSupported(md::fmi2ModelDescription)

Returns if the FMU model description contains `dependency` information for `derivatives`.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information for `derivatives`.

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

    fmi2GetModelIdentifier(md::fmi2ModelDescription; type=nothing)

Returns the tag 'modelIdentifier' from CS or ME section.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `type=nothing`: Defines whether a Co-Simulation or Model Exchange is present. (default = nothing)

# Returns
- `md.modelExchange.modelIdentifier::String`: Returns the tag `modelIdentifier` from ModelExchange section.
- `md.coSimulation.modelIdentifier::String`: Returns the tag `modelIdentifier` from CoSimulation section.
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

    fmi2CanGetSetState(md::fmi2ModelDescription)

Returns true, if the FMU supports the getting/setting of states

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU supports the getting/setting of states.

"""
function fmi2CanGetSetState(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canGetAndSetFMUstate) || (md.modelExchange != nothing && md.modelExchange.canGetAndSetFMUstate)
end

"""

    fmi2CanSerializeFMUstate(md::fmi2ModelDescription)

Returns true, if the FMU state can be serialized

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU state can be serialized

"""
function fmi2CanSerializeFMUstate(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.canSerializeFMUstate) || (md.modelExchange != nothing && md.modelExchange.canSerializeFMUstate)
end

"""

    fmi2ProvidesDirectionalDerivative(md::fmi2ModelDescription)

Returns true, if the FMU provides directional derivatives

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU provides directional derivatives

"""
function fmi2ProvidesDirectionalDerivative(md::fmi2ModelDescription)
    return (md.coSimulation != nothing && md.coSimulation.providesDirectionalDerivative) || (md.modelExchange != nothing && md.modelExchange.providesDirectionalDerivative)
end

"""

    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.valueReferences)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of value references and their corresponding names.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}.

"""
function fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.valueReferences)
    dict = Dict{fmi2ValueReference, Array{String}}()
    for vr in vrs
        dict[vr] = fmi2ValueReferenceToString(md, vr)
    end
    return dict
end

"""

    fmi2GetValueReferencesAndNames(fmu::FMU2)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of value references and their corresponding names.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}.

"""
function fmi2GetValueReferencesAndNames(fmu::FMU2)
    fmi2GetValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetNames(md::fmi2ModelDescription; vrs=md.valueReferences, mode=:first)

Returns a array of names corresponding to value references `vrs`.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

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

"""

    fmi2GetNames(fmu::FMU2; vrs=md.valueReferences, mode=:first)

Returns a array of names corresponding to value references `vrs`.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

"""
function fmi2GetNames(fmu::FMU2; kwargs...)
    fmi2GetNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetModelVariableIndices(md::fmi2ModelDescription; vrs=md.valueReferences)

Returns a array of indices corresponding to value references `vrs`

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.valueReferences`: Additional attribute `valueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)

# Returns
- `names::Array{Integer}`: Returns a array of indices corresponding to value references `vrs`

"""
function fmi2GetModelVariableIndices(md::fmi2ModelDescription; vrs=md.valueReferences)
    indices = []

    for i = 1:length(md.modelVariables)
        if md.modelVariables[i].valueReference in vrs
            push!(indices, i)
        end
    end

    return indices
end

"""

    fmi2GetInputValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dict with (vrs, names of inputs).

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.


# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of inputs)

"""
function fmi2GetInputValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.inputValueReferences)
end

"""

    fmi2GetInputValueReferencesAndNames(fmu::FMU2)

Returns a dict with (vrs, names of inputs).

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.


# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of inputs)

"""
function fmi2GetInputValueReferencesAndNames(fmu::FMU2)
    fmi2GetInputValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetInputNames(md::fmi2ModelDescription; vrs=md.inputvalueReferences, mode=:first)

Returns names of inputs.


# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.inputvalueReferences`: Additional attribute `inputvalueReferences::Array{fmi2ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

"""
function fmi2GetInputNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.inputValueReferences, kwargs...)
end

"""

    fmi2GetInputNames(fmu::FMU2; vrs=md.inputValueReferences, mode=:first)

Returns names of inputs.


# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.inputvalueReferences`: Additional attribute `inputvalueReferences::Array{fmi2ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.valueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

"""
function fmi2GetInputNames(fmu::FMU2; kwargs...)
    fmi2GetInputNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetOutputValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of value references and their corresponding names.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi2ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi2ValueReference}`)

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}.So returns a dict with (vrs, names of outputs)

"""
function fmi2GetOutputValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.outputValueReferences)
end

"""

    fmi2GetOutputValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of value references and their corresponding names.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}.So returns a dict with (vrs, names of outputs)

"""
function fmi2GetOutputValueReferencesAndNames(fmu::FMU2)
    fmi2GetOutputValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetOutputNames(md::fmi2ModelDescription; vrs=md.outputvalueReferences, mode=:first)

Returns names of outputs.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi2ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

"""
function fmi2GetOutputNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.outputValueReferences, kwargs...)
end

"""

    fmi2GetOutputNames(fmu::FMU2; vrs=md.outputvalueReferences, mode=:first)

Returns names of outputs.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.outputvalueReferences`: Additional attribute `outputvalueReferences::Array{fmi2ValueReference}` of the Model Description that is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.outputvalueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to value references `vrs`

"""
function fmi2GetOutputNames(fmu::FMU2; kwargs...)
    fmi2GetOutputNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetParameterValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of parameterValueReferences and their corresponding names.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of parameters).

See also ['fmi2GetValueReferencesAndNames'](@ref).
"""
function fmi2GetParameterValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.parameterValueReferences)
end

"""

    fmi2GetParameterValueReferencesAndNames(fmu::FMU2)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of parameterValueReferences and their corresponding names.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of parameters).

See also ['fmi2GetValueReferencesAndNames'](@ref).
"""
function fmi2GetParameterValueReferencesAndNames(fmu::FMU2)
    fmi2GetParameterValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetParameterNames(md::fmi2ModelDescription; vrs=md.parameterValueReferences, mode=:first)

Returns names of parameters.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.parameterValueReferences`: Additional attribute `parameterValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.parameterValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetParameterNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.parameterValueReferences, kwargs...)
end

"""

    fmi2GetParameterNames(fmu::FMU2; vrs=md.parameterValueReferences, mode=:first)

Returns names of parameters.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.parameterValueReferences`: Additional attribute `parameterValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.parameterValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetParameterNames(fmu::FMU2; kwargs...)
    fmi2GetParameterNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetStateValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of state value references and their corresponding names.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of states)

"""
function fmi2GetStateValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.stateValueReferences)
end

"""

    fmi2GetStateValueReferencesAndNames(fmu::FMU2)

Returns dict(vrs, names of states).

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of state value references and their corresponding names.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of states)

"""
function fmi2GetStateValueReferencesAndNames(fmu::FMU2)
    fmi2GetStateValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetStateNames(fmu::FMU2; vrs=md.stateValueReferences, mode=:first)

Returns names of states.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.stateValueReferences`: Additional attribute `parameterValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.stateValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetStateNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.stateValueReferences, kwargs...)
end

"""

    fmi2GetStateNames(fmu::FMU2; vrs=md.stateValueReferences, mode=:first)

Returns names of states.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.stateValueReferences`: Additional attribute `parameterValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.stateValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetStateNames(fmu::FMU2; kwargs...)
    fmi2GetStateNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetDerivateValueReferencesAndNames(md::fmi2ModelDescription)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of derivative value references and their corresponding names.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of derivatives)
See also ['fmi2GetValueReferencesAndNames'](@ref)
"""
function fmi2GetDerivateValueReferencesAndNames(md::fmi2ModelDescription)
    fmi2GetValueReferencesAndNames(md::fmi2ModelDescription; vrs=md.derivativeValueReferences)
end

"""

    fmi2GetDerivateValueReferencesAndNames(fmu::FMU2)

Returns a dictionary `Dict(fmi2ValueReference, Array{String})` of derivative value references and their corresponding names.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{fmi2ValueReference, Array{String}}`: Returns a dictionary that constructs a hash table with keys of type fmi2ValueReference and values of type Array{String}. So returns a dict with (vrs, names of derivatives)
See also ['fmi2GetValueReferencesAndNames'](@ref)
"""
function fmi2GetDerivateValueReferencesAndNames(fmu::FMU2)
    fmi2GetDerivateValueReferencesAndNames(fmu.modelDescription)
end

"""

    fmi2GetDerivativeNames(md::fmi2ModelDescription; vrs=md.derivativeValueReferences, mode=:first)

Returns names of derivatives.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Keywords
- `vrs=md.derivativeValueReferences`: Additional attribute `derivativeValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.derivativeValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetDerivativeNames(md::fmi2ModelDescription; kwargs...)
    fmi2GetNames(md; vrs=md.derivativeValueReferences, kwargs...)
end

"""

    fmi2GetDerivativeNames(fmu::FMU2; vrs=md.derivativeValueReferences, mode=:first)

Returns names of derivatives.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `vrs=md.derivativeValueReferences`: Additional attribute `derivativeValueReferences::Array{fmi2ValueReference}` of the Model Description that  is a handle to a (base type) variable value. Handle and base type uniquely identify the value of a variable. (default = `md.derivativeValueReferences::Array{fmi2ValueReference}`)
- `mode=:first`: If there are multiple names per value reference, availabel modes are `:first` (default, pick only the first one), `:group` (pick all and group them into an array) and `:flat` (pick all, but flat them out into a 1D-array together with all other names)
# Returns
- `names::Array{String}`: Returns a array of names corresponding to parameter value references `vrs`

See also ['fmi2GetNames'](@ref).
"""
function fmi2GetDerivativeNames(fmu::FMU2; kwargs...)
    fmi2GetDerivativeNames(fmu.modelDescription; kwargs...)
end

"""

    fmi2GetNamesAndDescriptions(md::fmi2ModelDescription)

Returns a dictionary of variables with their descriptions.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].description::Union{String, Nothing}`). (Creates a tuple (name, description) for each i in 1:length(md.modelVariables))
"""
function fmi2GetNamesAndDescriptions(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => md.modelVariables[i].description for i = 1:length(md.modelVariables))
end

"""

    fmi2GetNamesAndDescriptions(fmu::FMU2)

Returns a dictionary of variables with their descriptions.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].description::Union{String, Nothing}`). (Creates a tuple (name, description) for each i in 1:length(md.modelVariables))
"""
function fmi2GetNamesAndDescriptions(fmu::FMU2)
    fmi2GetNamesAndDescriptions(fmu.modelDescription)
end

"""

    fmi2GetNamesAndUnits(md::fmi2ModelDescription)

Returns a dictionary of variables with their units.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i]._Real.unit::Union{String, Nothing}`). (Creates a tuple (name, unit) for each i in 1:length(md.modelVariables))
See also [`fmi2GetUnit`](@ref).
"""
function fmi2GetNamesAndUnits(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => fmi2GetUnit(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

"""

    fmi2GetNamesAndUnits(fmu::FMU2)

Returns a dictionary of variables with their units.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{String, String}`: Returns a dictionary that constructs a hash table with keys of type String and values of type String. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i]._Real.unit::Union{String, Nothing}`). (Creates a tuple (name, unit) for each i in 1:length(md.modelVariables))
See also [`fmi2GetUnit`](@ref).
"""
function fmi2GetNamesAndUnits(fmu::FMU2)
    fmi2GetNamesAndUnits(fmu.modelDescription)
end

"""

    fmi2GetNamesAndInitials(md::fmi2ModelDescription)

Returns a dictionary of variables with their initials.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, Cuint}`: Returns a dictionary that constructs a hash table with keys of type String and values of type Cuint. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].inital::Union{fmi2Initial, Nothing}`). (Creates a tuple (name,initial) for each i in 1:length(md.modelVariables))
See also [`fmi2GetInitial`](@ref).
"""
function fmi2GetNamesAndInitials(md::fmi2ModelDescription)
    Dict(md.modelVariables[i].name => fmi2GetInitial(md.modelVariables[i]) for i = 1:length(md.modelVariables))
end

"""

    fmi2GetNamesAndInitials(fmu::FMU2)

Returns a dictionary of variables with their initials.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{String, Cuint}`: Returns a dictionary that constructs a hash table with keys of type String and values of type Cuint. So returns a dict with ( `md.modelVariables[i].name::String`, `md.modelVariables[i].inital::Union{fmi2Initial, Nothing}`). (Creates a tuple (name,initial) for each i in 1:length(md.modelVariables))
See also [`fmi2GetInitial`](@ref).
"""
function fmi2GetNamesAndInitials(fmu::FMU2)
    fmi2GetNamesAndInitials(fmu.modelDescription)
end

"""

    fmi2GetInputNamesAndStarts(md::fmi2ModelDescription)

Returns a dictionary of input variables with their starting values.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `dict::Dict{String, Array{fmi2ValueReferenceFormat}}`: Returns a dictionary that constructs a hash table with keys of type String and values of type fmi2ValueReferenceFormat. So returns a dict with ( `md.modelVariables[i].name::String`, `starts:: Array{fmi2ValueReferenceFormat}` ). (Creates a tuple (name, starts) for each i in inputIndices)
See also ['fmi2GetStartValue'](@ref).
"""
function fmi2GetInputNamesAndStarts(md::fmi2ModelDescription)

    inputIndices = fmi2GetModelVariableIndices(md; vrs=md.inputValueReferences)
    Dict(md.modelVariables[i].name => fmi2GetStartValue(md.modelVariables[i]) for i in inputIndices)
end

"""

    fmi2GetInputNamesAndStarts(fmu::FMU2)

Returns a dictionary of input variables with their starting values.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `dict::Dict{String, Array{fmi2ValueReferenceFormat}}`: Returns a dictionary that constructs a hash table with keys of type String and values of type fmi2ValueReferenceFormat. So returns a dict with ( `md.modelVariables[i].name::String`, `starts:: Array{fmi2ValueReferenceFormat}` ). (Creates a tuple (name, starts) for each i in inputIndices)
See also ['fmi2GetStartValue'](@ref).
"""
function fmi2GetInputNamesAndStarts(fmu::FMU2)
    fmi2GetInputNamesAndStarts(fmu.modelDescription)
end
