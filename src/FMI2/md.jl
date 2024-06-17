#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_md.jl` (model description)?
# - [Sec. 1a] the function `fmi2LoadModelDescription` to load/parse the FMI model description [exported]
# - [Sec. 1b] helper functions for the load/parse function [not exported]
# - [Sec. 2]  functions to get values from the model description in the format `fmi2Get[value](md::fmi2ModelDescription)` [exported]
# - [Sec. 3]  additional functions to get useful information from the model description in the format `fmi2Get[value](md::fmi2ModelDescription)` [exported]

using FMIBase.FMICore: fmi2ModelDescriptionModelExchange, fmi2ModelDescriptionCoSimulation, fmi2ModelDescriptionDefaultExperiment, fmi2ModelDescriptionEnumerationItem
using FMIBase.FMICore: fmi2RealAttributesExt, fmi2BooleanAttributesExt, fmi2IntegerAttributesExt, fmi2StringAttributesExt, fmi2EnumerationAttributesExt
using FMIBase.FMICore: fmi2RealAttributes, fmi2BooleanAttributes, fmi2IntegerAttributes, fmi2StringAttributes, fmi2EnumerationAttributes
using FMIBase.FMICore: fmi2ModelDescriptionModelStructure
using FMIBase.FMICore: fmi2DependencyKind

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
"""
function fmi2LoadModelDescription(pathToModelDescription::String)
    md = fmi2ModelDescription()

    md.stringValueReferences = Dict{String, fmi2ValueReference}()
    md.outputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.inputValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.stateValueReferences = Array{fmi2ValueReference}(undef, 0)
    md.derivativeValueReferences = Array{fmi2ValueReference}(undef, 0)

    doc = readxml(pathToModelDescription)

    root = doc.root

    # mandatory
    md.fmiVersion = root["fmiVersion"]
    md.modelName = root["modelName"]
    md.guid = root["guid"]

    # optional
    md.generationTool           = parseNode(root, "generationTool", String; onfail="[Unknown generation tool]")
    md.generationDateAndTime    = parseNode(root, "generationDateAndTime", String; onfail="[Unknown generation date and time]")
    variableNamingConventionStr = parseNode(root, "variableNamingConvention", String; onfail="flat")
    @assert (variableNamingConventionStr == "flat" || variableNamingConventionStr == "structured") ["fmi2ReadModelDescription(...): Unknown entry for `variableNamingConvention=$(variableNamingConventionStr)`."]
    md.variableNamingConvention = (variableNamingConventionStr == "flat" ? fmi2VariableNamingConventionFlat : fmi2VariableNamingConventionStructured)
    md.numberOfEventIndicators  = parseNode(root, "numberOfEventIndicators", Int; onfail=0)
    md.description              = parseNode(root, "description", String; onfail="[Unknown Description]")

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
                md.coSimulation.modelIdentifier                        = parseNode(node, "modelIdentifier")
                md.coSimulation.canHandleVariableCommunicationStepSize = parseNode(node, "canHandleVariableCommunicationStepSize", Bool; onfail=false)
                md.coSimulation.canInterpolateInputs                   = parseNode(node, "canInterpolateInputs", Bool                  ; onfail=false)
                md.coSimulation.maxOutputDerivativeOrder               = parseNode(node, "maxOutputDerivativeOrder", Int               ; onfail=nothing)
                md.coSimulation.canGetAndSetFMUstate                   = parseNode(node, "canGetAndSetFMUstate", Bool                  ; onfail=false)
                md.coSimulation.canSerializeFMUstate                   = parseNode(node, "canSerializeFMUstate", Bool                  ; onfail=false)
                md.coSimulation.providesDirectionalDerivative          = parseNode(node, "providesDirectionalDerivative", Bool         ; onfail=false)
            end

            if node.name == "ModelExchange"
                md.modelExchange = fmi2ModelDescriptionModelExchange()
                md.modelExchange.modelIdentifier                        = parseNode(node, "modelIdentifier")
                md.modelExchange.canGetAndSetFMUstate                   = parseNode(node, "canGetAndSetFMUstate", Bool                 ; onfail=false)
                md.modelExchange.canSerializeFMUstate                   = parseNode(node, "canSerializeFMUstate", Bool                 ; onfail=false)
                md.modelExchange.providesDirectionalDerivative          = parseNode(node, "providesDirectionalDerivative", Bool        ; onfail=false)
            end
            
        elseif node.name == "TypeDefinitions"
            md.typeDefinitions = parseTypeDefinitions(md, node)

        elseif node.name == "UnitDefinitions"
            md.unitDefinitions = parseUnitDefinitions(md, node)

        elseif node.name == "ModelVariables"
            md.modelVariables = parseModelVariables(md, node)

        elseif node.name == "ModelStructure"
            md.modelStructure = fmi2ModelDescriptionModelStructure()

            for element in eachelement(node)
                if element.name == "Derivatives"
                    parseDerivatives(md, element)
                elseif element.name == "InitialUnknowns"
                    parseInitialUnknowns(md, element)
                elseif element.name == "Outputs"
                    parseOutputs(md, element)
                else
                    @warn "Unknown tag `$(element.name)` for node `ModelStructure`."
                end
            end

        elseif node.name == "DefaultExperiment"
            md.defaultExperiment = fmi2ModelDescriptionDefaultExperiment()
            md.defaultExperiment.startTime  = parseNode(node, "startTime", fmi2Real)
            md.defaultExperiment.stopTime   = parseNode(node, "stopTime", fmi2Real)
            md.defaultExperiment.tolerance  = parseNode(node, "tolerance", fmi2Real)
            md.defaultExperiment.stepSize   = parseNode(node, "stepSize", fmi2Real)
        end
    end

    # creating an index for value references (fast look-up for dependencies)
    for i in 1:length(md.valueReferences)
        md.valueReferenceIndicies[md.valueReferences[i]] = i
    end

    # ToDo: setDefaultsFromDeclaredType!(md.modelVariables, md.typeDefinitions)

    return md
end

#######################################
# [Sec. 1b] helpers for load function #
#######################################

# helper function to parse variable or simple type attributes
function parseAttribute(md::fmi2ModelDescription, defnode; ext::Bool=false)

    typename = defnode.name
    typenode = nothing 

    if typename == "Real"

        if ext 
            typenode = fmi2RealAttributesExt()

            typenode.start = parseNode(defnode, "start", fmi2Real)
            typenode.derivative = parseNode(defnode, "derivative", UInt)
            typenode.reinit = parseNode(defnode, "reinit", Bool)
            typenode.declaredType = parseNode(defnode, "declaredType", String)

        else
            typenode = fmi2RealAttributes()
        end
       
        typenode.quantity = parseNode(defnode, "quantity", String)
        typenode.unit = parseNode(defnode, "unit", String)
        typenode.displayUnit = parseNode(defnode, "displayUnit", String)
        typenode.relativeQuantity = parseNode(defnode, "relativeQuantity", Bool)
        typenode.min = parseNode(defnode, "min", fmi2Real)
        typenode.max = parseNode(defnode, "max", fmi2Real)
        typenode.nominal = parseNode(defnode, "nominal", fmi2Real)
        typenode.unbounded = parseNode(defnode, "unbounded", Bool)
      
    elseif typename == "String"

        if ext 
            typenode = fmi2StringAttributesExt()

            typenode.start = parseNode(defnode, "start", String)
            typenode.declaredType = parseNode(defnode, "declaredType", String)
        else
            typenode = fmi2StringAttributes()
        end

    elseif typename == "Boolean"

        if ext 
            typenode = fmi2BooleanAttributesExt()

            typenode.start = parseNode(defnode, "start", Bool)
            typenode.declaredType = parseNode(defnode, "declaredType", String)
        else
            typenode = fmi2BooleanAttributes()
        end

    elseif typename == "Integer"
        
        if ext 
            typenode = fmi2IntegerAttributesExt()

            typenode.start = parseNode(defnode, "start", Int)
            typenode.declaredType = parseNode(defnode, "declaredType", String)
        else
            typenode = fmi2IntegerAttributes()
        end
        
        typenode.quantity = parseNode(defnode, "quantity", String)
        typenode.min = parseNode(defnode, "min", fmi2Integer)
        typenode.max = parseNode(defnode, "max", fmi2Integer)

    elseif typename == "Enumeration"
        
        if ext 
            typenode = fmi2EnumerationAttributesExt()

            typenode.start = parseNode(defnode, "start", fmi2Integer)
            typenode.min = parseNode(defnode, "min", fmi2Integer)
            typenode.max = parseNode(defnode, "max", fmi2Integer)
            typenode.declaredType = parseNode(defnode, "declaredType", String)
        else
            typenode = fmi2EnumerationAttributes()

            # ToDo: Parse items!
            for itemNode in eachelement(defnode)

                if itemNode.name != "Item"
                    @warn "Found item with name `$(itemNode.name)` inside enumeration block, this is not allowed."
                end

                it = fmi2ModelDescriptionEnumerationItem()

                # mandatory
                if haskey(itemNode, "name")
                    it.name = parseNode(itemNode, "name", String)
                else
                    @warn "Enumeration item `$(itemNode.name)` is missing the `name` key. This is not allowed."
                end

                # mandatory
                if haskey(itemNode, "value")
                    it.value = parseNode(itemNode, "value", Int)
                else
                    @warn "Enumeration item `$(itemNode.name)` is missing the `value` key. This is not allowed."
                end

                # optional
                if haskey(itemNode, "description")
                    it.description = parseNode(itemNode, "description", String)
                end

                push!(typenode, it)
            end
        end

        typenode.quantity = parseNode(defnode, "quantity", String)
    else
        @warn "Unknown data type `$(typename)`."
        typenode = nothing
    end
    return typenode
end

# Parses the model variables of the FMU model description.
function parseModelVariables(md::fmi2ModelDescription, nodes::EzXML.Node)
    numberOfVariables = 0
    for node in eachelement(nodes)
        numberOfVariables += 1
    end
    scalarVariables = Array{fmi2ScalarVariable}(undef, numberOfVariables)

    index = 1
    for node in eachelement(nodes)
        name = node["name"]
        valueReference = parseNode(node, "valueReference", fmi2ValueReference)

        causality = nothing
        if haskey(node, "causality")
            causality = stringToCausality(md, node["causality"])

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
            variability = stringToVariability(md, node["variability"])
        end

        initial = nothing
        if haskey(node, "initial")
            initial = stringToInitial(md, node["initial"])
        end

        scalarVariables[index] = fmi2ScalarVariable(name, valueReference, causality, variability, initial)

        if !(valueReference in md.valueReferences)
            push!(md.valueReferences, valueReference)
        end

        scalarVariables[index].description = parseNode(node, "description", String)

        # type node
        defnode = node.firstelement
        typenode = parseAttribute(md, defnode; ext=true)
        if isa(typenode, fmi2RealAttributesExt)
            scalarVariables[index].Real = typenode
        elseif isa(typenode, fmi2StringAttributesExt)
            scalarVariables[index].String = typenode
        elseif isa(typenode, fmi2BooleanAttributesExt)
            scalarVariables[index].Boolean = typenode
        elseif isa(typenode, fmi2IntegerAttributesExt)
            scalarVariables[index].Integer = typenode
        elseif isa(typenode, fmi2EnumerationAttributesExt)
            scalarVariables[index].Enumeration = typenode
        end
        
        # generic attributes
        if !isnothing(typenode)
            typenode.declaredType = parseNode(node.firstelement, "declaredType", String)
        end

        md.stringValueReferences[name] = valueReference

        index += 1
    end

    scalarVariables
end

# Parses the model variables of the FMU model description.
function parseTypeDefinitions(md::fmi2ModelDescription, nodes::EzXML.Node)

    simpleTypes = Array{fmi2SimpleType, 1}()

    for node in eachelement(nodes)

        simpleType = fmi2SimpleType()

        # mandatory 
        simpleType.name = node["name"]

        # attribute node (mandatory)
        defnode = node.firstelement
        simpleType.attribute = parseAttribute(md, defnode; ext=false)

        # optional
        simpleType.description = parseNode(node, "description", String)
        
        push!(simpleTypes, simpleType)
    end

    simpleTypes
end

# Parses the `ModelStructure.Derivatives` of the FMU model description.
function parseUnknown(md::fmi2ModelDescription, node::EzXML.Node)
    if haskey(node, "index")
        varDep = fmi2VariableDependency(parseNode(node, "index", Int))

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
function parseDerivatives(md::fmi2ModelDescription, nodes::EzXML.Node)
    @assert (nodes.name == "Derivatives") "Wrong element name."
    md.modelStructure.derivatives = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknown(md, node)

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
function parseInitialUnknowns(md::fmi2ModelDescription, nodes::EzXML.Node)
    @assert (nodes.name == "InitialUnknowns") "Wrong element name."
    md.modelStructure.initialUnknowns = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknown(md, node)

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
function parseOutputs(md::fmi2ModelDescription, nodes::EzXML.Node)
    @assert (nodes.name == "Outputs") "Wrong element name."
    md.modelStructure.outputs = []
    for node in eachelement(nodes)
        if node.name == "Unknown"
            if haskey(node, "index")
                varDep = parseUnknown(md, node)

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
        sv.Real = fmi2RealAttributeExt()
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
            type.start = parseNode(typenode, "start", fmi2Real)
            sv.Real.start = type.start
        elseif typename == "Integer"
            type.start = parseNode(typenode, "start", fmi2Integer)
        elseif typename == "Boolean"
            type.start = parseNodeBoolean(typenode, "start")
        elseif typename == "Enumeration"
            type.start = parseNode(typenode, "start", fmi2Integer)
        elseif typename == "String"
            type.start = parseNode(typenode, "start")
        else
            @warn "setDatatypeVariables(...) unimplemented start value type $typename"
            type.start = parseNode(typenode, "start")
        end
    end

    if haskey(typenode, "min") && (type.datatype == fmi2Real || type.datatype == fmi2Integer || type.datatype == fmi2Enum)
        type.min = parseNode(typenode, "min", type.datatype)
    end
    if haskey(typenode, "max") && (type.datatype == fmi2Real || type.datatype == fmi2Integer || type.datatype == fmi2Enum)
        type.max = parseNode(typenode, "max", type.datatype)
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
        type.relativeQuantity = parseNode(typenode, "relativeQuantity", fmi2Boolean)
    end
    if haskey(typenode, "nominal") && type.datatype == fmi2Real
        type.nominal = parseNode(typenode, "nominal", fmi2Real)
    end
    if haskey(typenode, "unbounded") && type.datatype == fmi2Real
        type.unbounded = parseNode(typenode, "unbounded", fmi2Boolean)
    end
    if haskey(typenode, "derivative") && type.datatype == fmi2Real
        type.derivative = parseNode(typenode, "derivative", fmi2Integer)
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
function parseBaseUnit(md::fmi2ModelDescription, node)
    @assert node.name == "BaseUnit"
    unit = fmi2BaseUnit()
    for siUnit in FMICore.SI_UNITS
        siStr = String(siUnit)
        if haskey(node, siStr)
            setfield!(unit, Symbol(siStr), parseNode(node, siStr, Int32))
        end
    end
    if haskey(node, "factor")
        setfield!(unit, :factor, parseNode(node, "factor", Float64))
    end
    if haskey(node, "offset")
        setfield!(unit, :offset, parseNode(node, "offset", Float64))
    end
    return unit
end

# helper to create a `FMICore.DisplayUnit` from a XML-Tag like 
# `<DisplayUnit name="TempFahrenheit" factor="1.8" offset="-459.67"/>`
function parseDisplayUnits(::fmi2ModelDescription, node)
    @assert node.name == "DisplayUnit"

    unit = fmi2DisplayUnit(node["name"])
    if haskey(node, "factor")
        setfield!(unit, :factor, parseNode(node, "factor", Float64))
    end
    if haskey(node, "offset")
        setfield!(unit, :offset, parseNode(node, "offset", Float64))
    end
    
    return unit
end

function parseUnitDefinitions(md::fmi2ModelDescription, parentNode)

    units = Vector{fmi2Unit}()

    for node in eachelement(parentNode)

        unit = fmi2Unit(node["name"])

        for subNode = eachelement(node)
            if subNode.name == "BaseUnit"
                unit.baseUnit = parseBaseUnit(md, subNode)

            elseif subNode.name == "DisplayUnit"
                displayUnits = parseDisplayUnits(md, subNode)
                if isnothing(unit.displayUnits)
                    unit.displayUnits = Vector{fmi2DisplayUnit}()
                else
                    push!(unit.displayUnits, displayUnits)
                end
            end
        end

        push!(units, unit)
    end

    return units
end

################################
# [Sec. 2] get value functions #
################################

"""
    getGUID(md::fmi2ModelDescription)

Returns the tag 'guid' from the model description.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `guid::String`: Returns the tag 'guid' from the model description.

"""
function getGUID(md::fmi2ModelDescription)
    md.guid
end
getGUID(fmu::FMU) = getGUID(fmu.modelDescription)
export getGUID

##################################
# [Sec. 3] information functions #
##################################

"""
    isModelStructureAvailable(md::fmi2ModelDescription)

Returns true if the FMU model description contains `dependency` information.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information.

"""
function isModelStructureAvailable(md::fmi2ModelDescription)
    return !isnothing(md.modelStructure)
end
isModelStructureAvailable(fmu::FMU) = isModelStructureAvailable(fmu.modelDescription)
export isModelStructureAvailable

"""
    isModelStructureDerivativesAvailable(md::fmi2ModelDescription)

Returns if the FMU model description contains `dependency` information for `derivatives`.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.

# Returns
- `::Bool`: Returns true, if the FMU model description contains `dependency` information for `derivatives`.

"""
function isModelStructureDerivativesAvailable(md::fmi2ModelDescription)
    if !isModelStructureAvailable(md)
        return false
    end

    der = md.modelStructure.derivatives
    if isnothing(der) || length(der) <= 0
        return false
    end

    return true
end
isModelStructureDerivativesAvailable(fmu::FMU) = isModelStructureDerivativesAvailable(fmu.modelDescription)
export isModelStructureDerivativesAvailable
