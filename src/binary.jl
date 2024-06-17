#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIBase.EzXML

function dlsym_opt(libHandle, symbol)
    addr = dlsym(libHandle, symbol; throw_error=false)
    if addr == nothing
        logWarning(fmu, "This FMU does not support function '$symbol'.")
        addr = Ptr{Cvoid}(C_NULL)
    end
    addr
end

"""
    reload(fmu::FMU2)

Reloads the FMU-binary. This is useful, if the FMU does not support a clean reset implementation.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
"""
function reload(fmu::FMU)
    dlclose(fmu.libHandle)
    loadPointers(fmu)
end
export reload

function loadFMU(pathToFMU::String; unpackPath=nothing, cleanup=true, type::Union{Symbol, Nothing}=nothing)
    
    unzippedAbsPath, zipAbsPath = unzip(pathToFMU; unpackPath=unpackPath, cleanup=cleanup)

    # read version tag

    doc = readxml(normpath(joinpath(unzippedAbsPath, "modelDescription.xml")))

    root = doc.root
    version = root["fmiVersion"]

    if version == "1.0"
        @assert false "FMI version 1.0 deteted, this is (currently) not supported by FMI.jl."
    elseif version == "2.0"
        return createFMU2(unzippedAbsPath, zipAbsPath; type=type)
    elseif version == "3.0"
        return createFMU3(unzippedAbsPath, zipAbsPath; type=type)
    else
        @assert false, "Unknwon FMI version `$(version)`."
    end
end
export loadFMU

"""
    unloadFMU(fmu::FMU2, cleanUp::Bool=true; secure_pointers::Bool=true)

Unload a FMU.
Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `cleanUp::Bool= true`: Defines if the file and directory should be deleted.

# Keywords
- `secure_pointers=true` whether pointers to C-functions should be overwritten with dummies with Julia assertions, instead of pointing to dead memory (slower, but more user safe)
"""
function unloadFMU(fmu::FMU2, cleanUp::Bool=true; secure_pointers::Bool=true)

    while length(fmu.components) > 0
        c = fmu.components[end]

        # release allocated memory for snapshots (they might be used elsewhere too)
        # if !isnothing(c.solution)
        #     for iter in c.solution.snapshots
        #         t, snapshot = iter 
        #         cleanup!(c, snapshot)
        #     end
        # end

        fmi2FreeInstance!(c)
    end

    # the components are removed from the component list via call to fmi2FreeInstance!
    @assert length(fmu.components) == 0 "fmi2Unload(...): Failure during deleting components, $(length(fmu.components)) remaining in stack."
    
    if secure_pointers
        unloadPointers(fmu)
    end

    dlclose(fmu.libHandle)

    if cleanUp
        try
            rm(fmu.path; recursive = true, force = true)
            rm(fmu.zipPath; recursive = true, force = true)
        catch e
            @warn "Cannot delete unpacked data on disc. Maybe some files are opened in another application."
        end
    end
end
function unloadFMU(fmu::FMU3, cleanUp::Bool=true)

    while length(fmu.instances) > 0
        fmi3FreeInstance!(fmu.instances[end])
    end

    dlclose(fmu.libHandle)

    # the instances are removed from the instances list via call to fmi3FreeInstance!
    @assert length(fmu.instances) == 0 "fmi3Unload(...): Failure during deleting instances, $(length(fmu.instances)) remaining in stack."

    if cleanUp
        try
            rm(fmu.path; recursive = true, force = true)
            rm(fmu.zipPath; recursive = true, force = true)
        catch e
            @warn "Cannot delete unpacked data on disc. Maybe some files are opened in another application."
        end
    end
end
export unloadFMU