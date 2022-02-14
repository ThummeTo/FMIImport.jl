#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_ext.jl` (external/additional functions)?
# - new functions, that are useful, but not part of the FMI-spec (example: `fmi3Load`)

using Libdl
using ZipFile

"""
Sets the properties of the fmu by reading the modelDescription.xml.
Retrieves all the pointers of binary functions.
Returns the instance of the FMU struct.
Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
"""
function fmi3Load(pathToFMU::String; unpackPath=nothing)
    # Create uninitialized FMU
    fmu = FMU3()
    fmu.components = []

    pathToFMU = normpath(pathToFMU)

    # set paths for fmu handling
    (fmu.path, fmu.zipPath) = fmi3Unzip(pathToFMU; unpackPath=unpackPath) # TODO

    # set paths for modelExchangeScripting and binary
    tmpName = splitpath(fmu.path)
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi3ReadModelDescription(pathToModelDescription) # TODO Matrix mit Dimensions
    fmu.modelName = fmu.modelDescription.modelName
    fmu.instanceName = fmu.modelDescription.modelName
    fmuName = fmi3GetModelIdentifier(fmu.modelDescription) # tmpName[length(tmpName)] TODO

    directoryBinary = ""
    pathToBinary = ""

    if Sys.iswindows()
        directories = [joinpath("binaries", "win64"), joinpath("binaries", "x86_64-windows")]
        for directory in directories
            directoryBinary = joinpath(fmu.path, directory)
            if isdir(directoryBinary)
                pathToBinary = joinpath(directoryBinary, "$(fmuName).dll")
                break
            end
        end
        @assert isfile(pathToBinary) "Target platform is Windows, but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."
    elseif Sys.islinux()
        directories = [joinpath("binaries", "linux64"), joinpath("binaries", "x86_64-linux")]
        for directory in directories
            directoryBinary = joinpath(fmu.path, directory)
            if isdir(directoryBinary)
                pathToBinary = joinpath(directoryBinary, "$(fmuName).so")
                break
            end
        end
        @assert isfile(pathToBinary) "Target platform is Linux, but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."
    elseif Sys.isapple()
        directories = [joinpath("binaries", "darwin64"), joinpath("binaries", "x86_64-darwin")]
        for directory in directories
            directoryBinary = joinpath(fmu.path, directory)
            if isdir(directoryBinary)
                pathToBinary = joinpath(directoryBinary, "$(fmuName).dylib")
                break
            end
        end
        @assert isfile(pathToBinary) "Target platform is macOS, but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."
    else
        @assert false "Unsupported target platform. Supporting Windows64, Linux64 and Mac64."
    end

    lastDirectory = pwd()
    cd(directoryBinary)

    # set FMU binary handler
    fmu.libHandle = dlopen(pathToBinary)

    cd(lastDirectory)

    if fmi3IsCoSimulation(fmu) 
        fmu.type = fmi3CoSimulation::fmi3Type
    elseif fmi3IsModelExchange(fmu) 
        fmu.type = fmi3ModelExchange::fmi3Type
    elseif fmi3IsScheduledExecution(fmu) 
        fmu.type = fmi3ScheduledExecution::fmi3Type
    else
        error(unknownFMUType)
    end

    if fmi3IsCoSimulation(fmu) && fmi3IsModelExchange(fmu) 
        @info "fmi3Load(...): FMU supports both CS and ME, using CS as default if nothing specified." # TODO ScheduledExecution
    end

    # make URI ressource location
    tmpResourceLocation = string("file:///", fmu.path)
    tmpResourceLocation = joinpath(tmpResourceLocation, "resources")
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") # URIs.escapeuri(tmpResourceLocation)

    @info "fmi3Load(...): FMU resources location is `$(fmu.fmuResourceLocation)`"

    # # retrieve functions 
    fmu.cInstantiateModelExchange                  = dlsym(fmu.libHandle, :fmi3InstantiateModelExchange)
    fmu.cInstantiateCoSimulation                   = dlsym(fmu.libHandle, :fmi3InstantiateCoSimulation)
    fmu.cInstantiateScheduledExecution             = dlsym(fmu.libHandle, :fmi3InstantiateScheduledExecution)
    fmu.cGetVersion                                = dlsym(fmu.libHandle, :fmi3GetVersion)
    fmu.cFreeInstance                              = dlsym(fmu.libHandle, :fmi3FreeInstance)
    fmu.cSetDebugLogging                           = dlsym(fmu.libHandle, :fmi3SetDebugLogging)
    fmu.cEnterConfigurationMode                    = dlsym(fmu.libHandle, :fmi3EnterConfigurationMode)
    fmu.cExitConfigurationMode                     = dlsym(fmu.libHandle, :fmi3ExitConfigurationMode)
    fmu.cEnterInitializationMode                   = dlsym(fmu.libHandle, :fmi3EnterInitializationMode)
    fmu.cExitInitializationMode                    = dlsym(fmu.libHandle, :fmi3ExitInitializationMode)
    fmu.cTerminate                                 = dlsym(fmu.libHandle, :fmi3Terminate)
    fmu.cReset                                     = dlsym(fmu.libHandle, :fmi3Reset)
    fmu.cEvaluateDiscreteStates                    = dlsym(fmu.libHandle, :fmi3EvaluateDiscreteStates)
    fmu.cGetNumberOfVariableDependencies           = dlsym(fmu.libHandle, :fmi3GetNumberOfVariableDependencies)
    fmu.cGetVariableDependencies                   = dlsym(fmu.libHandle, :fmi3GetVariableDependencies)

    fmu.cGetFloat32                                = dlsym(fmu.libHandle, :fmi3GetFloat32)
    fmu.cSetFloat32                                = dlsym(fmu.libHandle, :fmi3SetFloat32)
    fmu.cGetFloat64                                = dlsym(fmu.libHandle, :fmi3GetFloat64)
    fmu.cSetFloat64                                = dlsym(fmu.libHandle, :fmi3SetFloat64)
    fmu.cGetInt8                                   = dlsym(fmu.libHandle, :fmi3GetInt8)
    fmu.cSetInt8                                   = dlsym(fmu.libHandle, :fmi3SetInt8)
    fmu.cGetUInt8                                  = dlsym(fmu.libHandle, :fmi3GetUInt8)
    fmu.cSetUInt8                                  = dlsym(fmu.libHandle, :fmi3SetUInt8)
    fmu.cGetInt16                                  = dlsym(fmu.libHandle, :fmi3GetInt16)
    fmu.cSetInt16                                  = dlsym(fmu.libHandle, :fmi3SetInt16)
    fmu.cGetUInt16                                 = dlsym(fmu.libHandle, :fmi3GetUInt16)
    fmu.cSetUInt16                                 = dlsym(fmu.libHandle, :fmi3SetUInt16)
    fmu.cGetInt32                                  = dlsym(fmu.libHandle, :fmi3GetInt32)
    fmu.cSetInt32                                  = dlsym(fmu.libHandle, :fmi3SetInt32)
    fmu.cGetUInt32                                 = dlsym(fmu.libHandle, :fmi3GetUInt32)
    fmu.cSetUInt32                                 = dlsym(fmu.libHandle, :fmi3SetUInt32)
    fmu.cGetInt64                                  = dlsym(fmu.libHandle, :fmi3GetInt64)
    fmu.cSetInt64                                  = dlsym(fmu.libHandle, :fmi3SetInt64)
    fmu.cGetUInt64                                 = dlsym(fmu.libHandle, :fmi3GetUInt64)
    fmu.cSetUInt64                                 = dlsym(fmu.libHandle, :fmi3SetUInt64)
    fmu.cGetBoolean                                = dlsym(fmu.libHandle, :fmi3GetBoolean)
    fmu.cSetBoolean                                = dlsym(fmu.libHandle, :fmi3SetBoolean)

    fmu.cGetString                                 = dlsym_opt(fmu.libHandle, :fmi3GetString)
    fmu.cSetString                                 = dlsym_opt(fmu.libHandle, :fmi3SetString)
    fmu.cGetBinary                                 = dlsym_opt(fmu.libHandle, :fmi3GetBinary)
    fmu.cSetBinary                                 = dlsym_opt(fmu.libHandle, :fmi3SetBinary)

    if fmi3CanGetSetState(fmu)
        fmu.cGetFMUState                           = dlsym_opt(fmu.libHandle, :fmi3GetFMUState)
        fmu.cSetFMUState                           = dlsym_opt(fmu.libHandle, :fmi3SetFMUState)
        fmu.cFreeFMUState                          = dlsym_opt(fmu.libHandle, :fmi3FreeFMUState)
    end

    if fmi3CanSerializeFMUstate(fmu)
        fmu.cSerializedFMUStateSize                = dlsym_opt(fmu.libHandle, :fmi3SerializedFMUStateSize)
        fmu.cSerializeFMUState                     = dlsym_opt(fmu.libHandle, :fmi3SerializeFMUState)
        fmu.cDeSerializeFMUState                   = dlsym_opt(fmu.libHandle, :fmi3DeSerializeFMUState)
    end

    if fmi3ProvidesDirectionalDerivatives(fmu)
        fmu.cGetDirectionalDerivative              = dlsym_opt(fmu.libHandle, :fmi3GetDirectionalDerivative)
    end

    if fmi3ProvidesAdjointDerivatives(fmu)
        fmu.cGetAdjointDerivative              = dlsym_opt(fmu.libHandle, :fmi3GetAdjointDerivative)
    end

    # CS specific function calls
    if fmi3IsCoSimulation(fmu)
        fmu.cGetOutputDerivatives                  = dlsym(fmu.libHandle, :fmi3GetOutputDerivatives)
        fmu.cEnterStepMode                         = dlsym(fmu.libHandle, :fmi3EnterStepMode)
        fmu.cDoStep                                = dlsym(fmu.libHandle, :fmi3DoStep)
    end

    # ME specific function calls
    if fmi3IsModelExchange(fmu)
        fmu.cGetNumberOfContinuousStates           = dlsym(fmu.libHandle, :fmi3GetNumberOfContinuousStates)
        fmu.cGetNumberOfEventIndicators            = dlsym(fmu.libHandle, :fmi3GetNumberOfEventIndicators)
        fmu.cGetContinuousStates                   = dlsym(fmu.libHandle, :fmi3GetContinuousStates)
        fmu.cGetNominalsOfContinuousStates         = dlsym(fmu.libHandle, :fmi3GetNominalsOfContinuousStates)
        fmu.cEnterContinuousTimeMode               = dlsym(fmu.libHandle, :fmi3EnterContinuousTimeMode)
        fmu.cSetTime                               = dlsym(fmu.libHandle, :fmi3SetTime)
        fmu.cSetContinuousStates                   = dlsym(fmu.libHandle, :fmi3SetContinuousStates)
        fmu.cGetContinuousStateDerivatives         = dlsym(fmu.libHandle, :fmi3GetContinuousStateDerivatives) 
        fmu.cGetEventIndicators                    = dlsym(fmu.libHandle, :fmi3GetEventIndicators)
        fmu.cCompletedIntegratorStep               = dlsym(fmu.libHandle, :fmi3CompletedIntegratorStep)
        fmu.cEnterEventMode                        = dlsym(fmu.libHandle, :fmi3EnterEventMode)        
        fmu.cUpdateDiscreteStates                  = dlsym(fmu.libHandle, :fmi3UpdateDiscreteStates)
    end

    if fmi3IsScheduledExecution(fmu)
        fmu.cSetIntervalDecimal                    = dlsym(fmu.libHandle, :fmi3SetIntervalDecimal)
        fmu.cSetIntervalFraction                   = dlsym(fmu.libHandle, :fmi3SetIntervalFraction)
        fmu.cGetIntervalDecimal                    = dlsym(fmu.libHandle, :fmi3GetIntervalDecimal)
        fmu.cGetIntervalFraction                   = dlsym(fmu.libHandle, :fmi3GetIntervalFraction)
        fmu.cGetShiftDecimal                       = dlsym(fmu.libHandle, :fmi3GetShiftDecimal)
        fmu.cGetShiftFraction                      = dlsym(fmu.libHandle, :fmi3GetShiftFraction)
        fmu.cActivateModelPartition                = dlsym(fmu.libHandle, :fmi3ActivateModelPartition)
    end
    # initialize further variables TODO check if needed
    fmu.jac_x = zeros(Float64, fmu.modelDescription.numberOfContinuousStates)
    fmu.jac_t = -1.0
    fmu.jac_dxy_x = zeros(fmi2Real,0,0)
    fmu.jac_dxy_u = zeros(fmi2Real,0,0)
   
    # dependency matrix 
    # fmu.dependencies

    fmu
end

"""
Create a copy of the .fmu file as a .zip folder and unzips it.
Returns the paths to the zipped and unzipped folders.
Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
"""
function fmi3Unzip(pathToFMU::String; unpackPath=nothing)

    fileNameExt = basename(pathToFMU)
    (fileName, fileExt) = splitext(fileNameExt)
        
    if unpackPath === nothing
        # cleanup=true leads to issues with automatic testing on linux server.
        unpackPath = mktempdir(; prefix="fmijl_", cleanup=false)
    end

    zipPath = joinpath(unpackPath, fileName * ".zip")
    unzippedPath = joinpath(unpackPath, fileName)

    # only copy ZIP if not already there
    if !isfile(zipPath)
        cp(pathToFMU, zipPath; force=true)
    end

    @assert isfile(zipPath) ["fmi3Unzip(...): ZIP-Archive couldn't be copied to `$zipPath`."]

    zipAbsPath = isabspath(zipPath) ?  zipPath : joinpath(pwd(), zipPath)
    unzippedAbsPath = isabspath(unzippedPath) ? unzippedPath : joinpath(pwd(), unzippedPath)

    @assert isfile(zipAbsPath) ["fmi3Unzip(...): Can't deploy ZIP-Archive at `$(zipAbsPath)`."]

    numFiles = 0

    # only unzip if not already done
    if !isdir(unzippedAbsPath)
        mkpath(unzippedAbsPath)

        zarchive = ZipFile.Reader(zipAbsPath)
        for f in zarchive.files
            fileAbsPath = normpath(joinpath(unzippedAbsPath, f.name))

            if endswith(f.name,"/") || endswith(f.name,"\\")
                mkpath(fileAbsPath) # mkdir(fileAbsPath)

                @assert isdir(fileAbsPath) ["fmi3Unzip(...): Can't create directory `$(f.name)` at `$(fileAbsPath)`."]
            else
                # create directory if not forced by zip file folder
                mkpath(dirname(fileAbsPath))

                numBytes = write(fileAbsPath, read(f))
                
                if numBytes == 0
                    @info "fmi3Unzip(...): Written file `$(f.name)`, but file is empty."
                end

                @assert isfile(fileAbsPath) ["fmi3Unzip(...): Can't unzip file `$(f.name)` at `$(fileAbsPath)`."]
                numFiles += 1
            end
        end
        close(zarchive)
    end

    @assert isdir(unzippedAbsPath) ["fmi3Unzip(...): ZIP-Archive couldn't be unzipped at `$(unzippedPath)`."]
    @info "fmi3Unzip(...): Successfully unzipped $numFiles files at `$unzippedAbsPath`."

    (unzippedAbsPath, zipAbsPath)
end

"""
Unload a FMU.
Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.
"""
function fmi3Unload(fmu::FMU3, cleanUp::Bool = true)

    while length(fmu.components) > 0
        fmi3FreeInstance!(fmu.components[end])
    end

    dlclose(fmu.libHandle)

    # the components are removed from the component list via call to fmi3FreeInstance!
    @assert length(fmu.components) == 0 "fmi3Unload(...): Failure during deleting components, $(length(fmu.components)) remaining in stack."

    if cleanUp
        try
            rm(fmu.path; recursive = true, force = true)
            rm(fmu.zipPath; recursive = true, force = true)
        catch e
            @warn "Cannot delete unpacked data on disc. Maybe some files are opened in another application."
        end
    end
end

"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable
Create a new instance of the given fmu, adds a logger if logginOn == true.
Returns the instance of a new FMU component.
For more information call ?fmi3InstantiateModelExchange
"""
function fmi3InstantiateModelExchange!(fmu::FMU3; visible::Bool = false, loggingOn::Bool = false)

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{Cvoid}, Ptr{Cchar}, Cuint, Ptr{Cchar}))

    compAddr = fmi3InstantiateModelExchange(fmu.cInstantiateModelExchange, fmu.instanceName, fmu.modelDescription.instantiationToken, fmu.fmuResourceLocation, fmi3Boolean(visible), fmi3Boolean(loggingOn), fmu.instanceEnvironment, ptrLogger)

    if compAddr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateModelExchange!(...): Instantiation failed!"
        return nothing
    end
    previous_z  = zeros(fmi3Float64, fmi3GetEventIndicators(fmu.modelDescription))
    rootsFound  = zeros(fmi3Int32, fmi3GetEventIndicators(fmu.modelDescription))
    stateEvent  = fmi3False
    timeEvent   = fmi3False
    stepEvent   = fmi3False
    component = fmi3Component(compAddr, fmu, previous_z, rootsFound, stateEvent, timeEvent, stepEvent)
    push!(fmu.components, component)
    component
end

"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable
Create a new instance of the given fmu, adds a logger if logginOn == true.
Returns the instance of a new FMU component.
For more information call ?fmi3InstantiateCoSimulation
"""
function fmi3InstantiateCoSimulation!(fmu::FMU3; visible::Bool = false, loggingOn::Bool = false, eventModeUsed::Bool = false, ptrIntermediateUpdate=nothing)

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{Cvoid}, Ptr{Cchar}, Cuint, Ptr{Cchar}))
    if ptrIntermediateUpdate === nothing
        ptrIntermediateUpdate = @cfunction(fmi3CallbackIntermediateUpdate, Cvoid, (Ptr{Cvoid}, fmi3Float64, fmi3Boolean, fmi3Boolean, fmi3Boolean, fmi3Boolean, Ptr{fmi3Boolean}, Ptr{fmi3Float64}))
    end
    if fmu.modelDescription.CShasEventMode 
        mode = eventModeUsed
    else
        mode = false
    end

    compAddr = fmi3InstantiateCoSimulation(fmu.cInstantiateCoSimulation, fmu.instanceName, fmu.modelDescription.instantiationToken, fmu.fmuResourceLocation, fmi3Boolean(visible), fmi3Boolean(loggingOn), 
                                            fmi3Boolean(mode), fmi3Boolean(fmu.modelDescription.CScanReturnEarlyAfterIntermediateUpdate), fmu.modelDescription.intermediateUpdateValueReferences, Csize_t(length(fmu.modelDescription.intermediateUpdateValueReferences)), fmu.instanceEnvironment, ptrLogger, ptrIntermediateUpdate)

    if compAddr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateCoSimulation!(...): Instantiation failed!"
        return nothing
    end

    component = fmi3Component(compAddr, fmu)
    push!(fmu.components, component)
    component
end

# TODO not tested
"""
Source: FMISpec3.0, Version D5ef1c1:: 2.3.1. Super State: FMU State Setable
Create a new instance of the given fmu, adds a logger if logginOn == true.
Returns the instance of a new FMU component.
For more information call ?fmi3InstantiateScheduledExecution
"""
function fmi3InstantiateScheduledExecution!(fmu::FMU3, ptrlockPreemption::Ptr{Cvoid}, ptrunlockPreemption::Ptr{Cvoid}; visible::Bool = false, loggingOn::Bool = false)

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{Cvoid}, Ptr{Cchar}, Cuint, Ptr{Cchar}))
    ptrClockUpdate = @cfunction(fmi3CallbackClockUpdate, Cvoid, (Ptr{Cvoid}, ))

    compAddr = fmi3InstantiateScheduledExecution(fmu.cInstantiateScheduledExecution, fmu.instanceName, fmu.modelDescription.instantiationToken, fmu.fmuResourceLocation, fmi3Boolean(visible), fmi3Boolean(loggingOn), fmu.instanceEnvironment, ptrLogger, ptrClockUpdate, ptrlockPreemption, ptrunlockPreemption)

    if compAddr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateScheduledExecution!(...): Instantiation failed!"
        return nothing
    end

    component = fmi3Component(compAddr, fmu)
    push!(fmu.components, component)
    component
end
