using FMIBase
using FMIBase.EzXML

# Sucht im entpackten FMU Verzeichnis nach fmi-ls-manifest.xml und fügt dies zur ModelDescription hinzu
function fmi3LoadLayeredStandards!(fmu::FMU3, unzippedAbsPath::String)
    lsRootPath = joinpath(unzippedAbsPath, "extra")

    if !isdir(lsRootPath)
        @debug "Found no 'extra' directory in: $unzippedAbsPath"
        return
    end

    @info "Found Layered Standards ('extra') directory: $lsRootPath"

    for (root, _, files) in walkdir(lsRootPath)
        for file in files
            if file == "fmi-ls-manifest.xml"
                manifestPath = joinpath(root, file)
                @info "Load Layered Standard Manifest: $manifestPath"

                try
                    lsObj =
                        parseLayeredStandardManifest!(fmu.modelDescription, manifestPath)
                    fmu.modelDescriptionLSSA = lsObj
                catch e
                    @warn "Could not parse Layered Standard Manifest ($manifestPath): $e"
                end
            end
        end
    end
end

function parseLayeredStandardManifest!(md::fmi3ModelDescription, pathToManifest::String)
    doc = readxml(pathToManifest)
    root = doc.root

    lsName = haskey(root, "fmi-ls-name") ? root["fmi-ls-name"] : "Unknown"
    @debug "Parse LS: $lsName"

    lsVersion = haskey(root, "fmi-ls-version") ? root["fmi-ls-version"] : "Unknown"
    @debug "Parse LS: $lsVersion"

    lsDescription =
        haskey(root, "fmi-ls-description") ? root["fmi-ls-description"] : "Unknown"
    @debug "Parse LS: $lsDescription"

    lsObj = FMIModelDescriptionLSSA()
    lsObj.name = lsName
    lsObj.version = lsVersion
    lsObj.description = lsDescription

    for node in eachelement(root)
        if node.name == "ModelVariables"
            parseLayeredStandardModelVariables!(md, lsObj, node)
        elseif node.name == "ModelStructure"
            parseLayeredStandardModelStructure!(md, lsObj, node)
        end
    end
    return lsObj
end

function parseLayeredStandardModelVariables!(
    md::fmi3ModelDescription,
    lsObj::FMIModelDescriptionLSSA,
    nodes::EzXML.Node,
)
    for node in eachelement(nodes)
        typename = node.name

        attrDict = Dict{String,String}()

        for attr in eachattribute(node)
            attrDict[attr.name] = attr.content
        end

        if !haskey(attrDict, "valueReference")
            @warn "ModelVariable $typename has no valueReference"
            continue
        end

        vr_raw = attrDict["valueReference"]
        vr = parse(fmi3ValueReference, vr_raw)

        if haskey(attrDict, "previous")
            try
                prev_raw = attrDict["previous"]
                prev_vr = parse(fmi3ValueReference, prev_raw)
                lsObj.previous[vr] = prev_vr
            catch e
                @warn "Could not parse 'previous' for VR $vr: $e"
            end
        end

        isNew = false
        var = nothing

        if haskey(md.valueReferenceIndicies, vr)
            idx = md.valueReferenceIndicies[vr]
            var = md.modelVariables[idx]
            @debug "Merge"

            # Fehlerfall Warnung auswerfen (fallback)
        else
            @warn "ModelVariable $vr not in original ModelDescription -> Fallback"
            isNew = true
            name = "LS_$(typename)_vr_$(vr)"

            # Hab jetzt mal alle möglichen aufgeschrieben
            if typename == "Float32"
                var = fmi3VariableFloat32(name, vr)
            elseif typename == "Float64"
                var = fmi3VariableFloat64(name, vr)
            elseif typename == "Int8"
                var = fmi3VariableInt8(name, vr)
            elseif typename == "UInt8"
                var = fmi3VariableUInt8(name, vr)
            elseif typename == "Int16"
                var = fmi3VariableInt16(name, vr)
            elseif typename == "Int32"
                var = fmi3VariableInt32(name, vr)
            elseif typename == "UInt32"
                var = fmi3VariableUInt32(name, vr)
            elseif typename == "Int64"
                var = fmi3VariableInt64(name, vr)
            elseif typename == "UInt64"
                var = fmi3VariableUInt64(name, vr)
                # elseif typename == "Boolean"
                #        var = fmi3VariableBoolean(name, vr)
                # elseif typename == "String"
                #        var = fmi3VariableString(name, vr)
                # elseif typename == "Binary"
                #        var = fmi3VariableBinary(name, vr)
            elseif typename == "Enumeration"
                var = fmi3VariableEnumeration(name, vr)
                # elseif typename == "Clock"
                #        var = fmi3VariableClock(name, vr)
            else
                @debug "Unknown Type: $typename"
                continue
            end
        end

        # Nicht notwendig (Nur für Fallback noch drinnen)
        if isNew
            push!(md.modelVariables, var)
            push!(md.valueReferences, vr)
            md.valueReferenceIndicies[vr] = length(md.modelVariables)
            md.stringValueReferences[var.name] = vr
        end
    end
end

function parseLayeredStandardModelStructure!(
    md::fmi3ModelDescription,
    lsObj::FMIModelDescriptionLSSA,
    nodes::EzXML.Node,
)
    for node in eachelement(nodes)
        list = nothing

        if node.name == "DiscreteState"
            list = lsObj.discreteStates
        elseif node.name == "ErrorIndicator"
            list = lsObj.errorIndicators
        end

        if list !== nothing && haskey(node, "valueReference")
            try
                vr_raw = node["valueReference"]
                vr = parse(fmi3ValueReference, vr_raw)
                push!(list, vr)
            catch e
                @warn "LS: Could not parse VR in $(node.name): $e"
            end
        end
    end
end
