#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_ext.jl` (external/additional functions)?
# - new functions, that are useful, but not part of the FMI-spec (example: `fmi3Load`)

using Libdl
using ZipFile

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
Sets the properties of the fmu by reading the modelDescription.xml.
Retrieves all the pointers of binary functions.
Returns the instance of the FMU struct.
Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
"""
function fmi3Load(pathToFMU::String; unpackPath=nothing, type=nothing)
    # Create uninitialized FMU
    fmu = FMU3()

    if startswith(pathToFMU, "http")
        @info "Downloading FMU from `$(pathToFMU)`."
        pathToFMU = download(pathToFMU)
    end

    fmu.instances = []

    pathToFMU = normpath(pathToFMU)

    # set paths for fmu handling
    (fmu.path, fmu.zipPath) = fmi3Unzip(pathToFMU; unpackPath=unpackPath) # TODO

    # set paths for modelExchangeScripting and binary
    tmpName = splitpath(fmu.path)
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi3LoadModelDescription(pathToModelDescription) # TODO Matrix mit Dimensions
    fmu.modelName = fmu.modelDescription.modelName
    fmu.instanceName = fmu.modelDescription.modelName

    # TODO special use case?
    if (fmi3IsCoSimulation(fmu.modelDescription) && fmi3IsModelExchange(fmu.modelDescription) && type==:CS) 
        fmu.type = fmi3TypeCoSimulation::fmi3Type
    elseif (fmi3IsCoSimulation(fmu.modelDescription) && fmi3IsModelExchange(fmu.modelDescription) && type==:ME)
        fmu.type = fmi3TypeModelExchange::fmi3Type
    elseif fmi3IsScheduledExecution(fmu.modelDescription) && type==:SE
        fmu.type = fmi3TypeScheduledExecution::fmi3Type
    elseif fmi3IsCoSimulation(fmu.modelDescription) && (type===nothing || type==:CS)
        fmu.type = fmi3TypeCoSimulation::fmi3Type
    elseif fmi3IsModelExchange(fmu.modelDescription) && (type===nothing || type==:ME)
        fmu.type = fmi3TypeModelExchange::fmi3Type
    elseif fmi3IsScheduledExecution(fmu.modelDescription) && (type === nothing || type ==:SE)
        fmu.type = fmi3TypeScheduledExecution::Fmi3Type
    else
        error(unknownFMUType)
    end

    fmuName = fmi3GetModelIdentifier(fmu.modelDescription) # tmpName[length(tmpName)] TODO

    directoryBinary = ""
    pathToBinary = ""

    juliaArch = Sys.WORD_SIZE
    @assert (juliaArch == 64 || juliaArch == 32) "fmi3Load(...): Unknown Julia Architecture with $(juliaArch)-bit, must be 64- or 32-bit."
    
    if Sys.iswindows()
        if juliaArch == 64
            directories = [joinpath("binaries", "win64"), joinpath("binaries","x86_64-windows")]
        else 
            directories = [joinpath("binaries", "win32"), joinpath("binaries","i686-windows")]
        end
        osStr = "Windows"
        fmuExt = "dll"
    elseif Sys.islinux()
        if juliaArch == 64
            directories = [joinpath("binaries", "linux64"), joinpath("binaries", "x86_64-linux")]
        else 
            directories = []
        end
        osStr = "Linux"
        fmuExt = "so"
    elseif Sys.isapple()
        if juliaArch == 64
            directories = [joinpath("binaries", "darwin64"), joinpath("binaries", "x86_64-darwin")]
        else 
            directories = []
        end
        osStr = "Mac"
        fmuExt = "dylib"
    else
        @assert false "fmi3Load(...): Unsupported target platform. Supporting Windows, Linux and Mac. Please open an issue if you want to use another OS."
    end

    @assert (length(directories) > 0) "fmi3Load(...): Unsupported architecture. Supporting Julia for Windows (64- and 32-bit), Linux (64-bit) and Mac (64-bit). Please open an issue if you want to use another architecture."
    for directory in directories
        directoryBinary = joinpath(fmu.path, directory)
        if isdir(directoryBinary)
            pathToBinary = joinpath(directoryBinary, "$(fmuName).$(fmuExt)")
            break
        end
    end
    @assert isfile(pathToBinary) "fmi3Load(...): Target platform is $(osStr), but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."

    # make URI ressource location
    tmpResourceLocation = string("file:///", fmu.path)
    tmpResourceLocation = joinpath(tmpResourceLocation, "resources")
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") # URIs.escapeuri(tmpResourceLocation)

    @info "fmi3Load(...): FMU resources location is `$(fmu.fmuResourceLocation)`"

    if fmi3IsCoSimulation(fmu) && fmi3IsModelExchange(fmu) 
        @info "fmi3Load(...): FMU supports both CS and ME, using CS as default if nothing specified." # TODO ScheduledExecution
    end

    fmu.binaryPath = pathToBinary
    loadBinary(fmu)
   
    # dependency matrix 
    # fmu.dependencies

    fmu
end

function loadBinary(fmu::FMU3)
    lastDirectory = pwd()
    cd(dirname(fmu.binaryPath))

    # set FMU binary handler
    fmu.libHandle = dlopen(fmu.binaryPath)

    cd(lastDirectory)

    # retrieve functions 
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

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.compAddr == compAddr
            instance = c
            break 
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateModelExchange!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        previous_z  = zeros(fmi3Float64, fmi3GetEventIndicators(fmu.modelDescription))
        rootsFound  = zeros(fmi3Int32, fmi3GetEventIndicators(fmu.modelDescription))
        stateEvent  = fmi3False
        timeEvent   = fmi3False
        stepEvent   = fmi3False
        instance = FMU3Instance(compAddr, fmu, previous_z, rootsFound, stateEvent, timeEvent, stepEvent)
        push!(fmu.instances, instance)
    end 

    instance
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
    if fmu.modelDescription.coSimulation.hasEventMode !== nothing
        mode = eventModeUsed
    else
        mode = false
    end

    compAddr = fmi3InstantiateCoSimulation(fmu.cInstantiateCoSimulation, pointer(fmu.instanceName), pointer(fmu.modelDescription.instantiationToken), pointer(fmu.fmuResourceLocation), fmi3Boolean(visible), fmi3Boolean(loggingOn), 
                                            fmi3Boolean(mode), fmi3Boolean(fmu.modelDescription.coSimulation.canReturnEarlyAfterIntermediateUpdate !== nothing), fmu.modelDescription.intermediateUpdateValueReferences, Csize_t(length(fmu.modelDescription.intermediateUpdateValueReferences)), fmu.instanceEnvironment, ptrLogger, ptrIntermediateUpdate)

    if compAddr == Ptr{Cvoid}(C_NULL)
        @error "fmi3InstantiateCoSimulation!(...): Instantiation failed!"
        return nothing
    end

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.compAddr == compAddr
            instance = c
            break 
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateCoSimulation!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        instance = FMU3Instance(compAddr, fmu)
        push!(fmu.instances, instance)
    end 

    instance
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

    instance = nothing

    # check if address is already inside of the instance (this may be)
    for c in fmu.instances
        if c.compAddr == compAddr
            instance = c
            break 
        end
    end

    if instance !== nothing
        @info "fmi3InstantiateScheduledExecution!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        instance = FMU3Instance(compAddr, fmu)
        push!(fmu.instances, instance)
    end 

    instance
end

"""
Reloads the FMU-binary. This is useful, if the FMU does not support a clean reset implementation.
"""
function fmi3Reload(fmu::FMU3)
    dlclose(fmu.libHandle)
    loadBinary(fmu)
end


"""
Unload a FMU.
Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.
"""
function fmi3Unload(fmu::FMU3, cleanUp::Bool = true)

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

# TODO fmi2SampleDirectionalDerivative

"""
Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD). 

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi3GetJacobian(comp::FMU3Instance, 
                         rdx::Array{fmi3ValueReference}, 
                         rx::Array{fmi3ValueReference}; 
                         steps::Array{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    mat = zeros(fmi3Float64, length(rdx), length(rx))
    fmi3GetJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD). 

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi3GetJacobian!(jac::Matrix{fmi3GetFloat64}, 
                          comp::FMU3Instance, 
                          rdx::Array{fmi3ValueReference}, 
                          rx::Array{fmi3ValueReference}; 
                          steps::Array{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)

    @assert size(jac) == (length(rdx), length(rx)) ["fmi2GetJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."]

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    ddsupported = fmi3ProvidesDirectionalDerivative(comp.fmu)

    # ToDo: Pick entries based on dependency matrix!
    #depMtx = fmi2GetDependencies(fmu)
    rdx_inds = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rdx)
    rx_inds  = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rx)
    
    for i in 1:length(rx)

        sensitive_rdx_inds = 1:length(rdx)
        sensitive_rdx = rdx

        # sensitive_rdx_inds = Int64[]
        # sensitive_rdx = fmi2ValueReference[]

        # for j in 1:length(rdx)
        #     if depMtx[rdx_inds[j], rx_inds[i]] != fmi2DependencyIndependent
        #         push!(sensitive_rdx_inds, j)
        #         push!(sensitive_rdx, rdx[j])
        #     end
        # end

        if length(sensitive_rdx) > 0
            if ddsupported
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                fmi3GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))
                # jac[sensitive_rdx_inds, i] = fmi2GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]])
            else 
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                # fmi3SampleDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i)) TODO not implemented
                # jac[sensitive_rdx_inds, i] = fmi2SampleDirectionalDerivative(comp, sensitive_rdx, [rx[i]], steps)
            end
        end
    end
     
    return nothing
end

"""
Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian`.

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi3GetFullJacobian(comp::FMU3Instance, 
                             rdx::Array{fmi3ValueReference}, 
                             rx::Array{fmi3ValueReference}; 
                             steps::Array{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    mat = zeros(fmi3Float64, length(rdx), length(rx))
    fmi2GetFullJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian!`.

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi3GetFullJacobian!(jac::Matrix{fmi3Float64}, 
                              comp::FMU3Instance, 
                              rdx::Array{fmi3ValueReference}, 
                              rx::Array{fmi3ValueReference}; 
                              steps::Array{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    @assert size(jac) == (length(rdx),length(rx)) "fmi3GetFullJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."

    @warn "`fmi3GetFullJacobian!` is for benchmarking only, please use `fmi3GetJacobian`."

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    if fmi3ProvidesDirectionalDerivative(comp.fmu)
        for i in 1:length(rx)
            jac[:,i] = fmi3GetDirectionalDerivative(comp, rdx, [rx[i]])
        end
    else
        # jac = fmi3SampleDirectionalDerivative(comp, rdx, rx) TODO not implemented
    end

    return nothing
end

function fmi3Get!(comp::FMU3Instance, vrs::fmi3ValueReferenceFormat, dstArray::Array)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(dstArray) "fmi3Get!(...): Number of value references doesn't match number of `dstArray` elements."

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi3ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if mv.datatype.datatype == fmi3Float32 
            #@assert isa(dstArray[i], Real) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetFloat32(comp, vr)
        elseif mv.datatype.datatype == fmi3Float64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetFloat64(comp, vr)
        elseif mv.datatype.datatype == fmi3Int8 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt8(comp, vr)
        elseif mv.datatype.datatype == fmi3Int16 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt16(comp, vr)
        elseif mv.datatype.datatype == fmi3Int32 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt32(comp, vr)
        elseif mv.datatype.datatype == fmi3GetInt64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt64(comp, vr)
        elseif mv.datatype.datatype == fmi3UInt8 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt8(comp, vr)
        elseif mv.datatype.datatype == fmi3UInt16 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt16(comp, vr)
        elseif mv.datatype.datatype == fmi3UInt32 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt32(comp, vr)
        elseif mv.datatype.datatype == fmi3GetUInt64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt64(comp, vr)
        elseif mv.datatype.datatype == fmi3Boolean 
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetBoolean(comp, vr)
        elseif mv.datatype.datatype == fmi3String 
            #@assert isa(dstArray[i], String) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetString(comp, vr)
        elseif mv.datatype.datatype == fmi3String 
            #@assert isa(dstArray[i], String) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetString(comp, vr)
        elseif mv.datatype.datatype == fmi3Binary 
            #@assert isa(dstArray[i], String) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetBinary(comp, vr)
        elseif mv.datatype.datatype == fmi3Enum 
            @warn "fmi3Get!(...): Currently not implemented for fmi2Enum."
        else 
            @assert isa(dstArray[i], Real) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end

    return nothing
end

function fmi3Get(comp::FMU3Instance, vrs::fmi3ValueReferenceFormat)
    vrs = prepareValueReference(comp, vrs)
    dstArray = Array{Any,1}(undef, length(vrs))
    fmi2Get!(comp, vrs, dstArray)
    return dstArray
end

function fmi3Set(comp::FMU3Instance, vrs::fmi3ValueReferenceFormat, srcArray::Array)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(srcArray) "fmi3Set(...): Number of value references doesn't match number of `srcArray` elements."

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi3ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if mv.datatype.datatype == fmi3Float32 
            #@assert isa(dstArray[i], Real) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetFloat32(comp, vr, srcArray[i])
        elseif mv.datatype.datatype == fmi3Float64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetFloat64(comp, vr, srcArray[i])
        elseif mv.datatype.datatype == fmi3Int8 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetInt8(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3Int16 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetInt16(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3Int32 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetInt32(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3SetInt64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetInt64(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3UInt8 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetUInt8(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3UInt16 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetUInt16(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3UInt32 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetUInt32(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3SetUInt64 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetUInt64(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi3Boolean 
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetBoolean(comp, vr, Bool(srcArray[i]))
        elseif mv.datatype.datatype == fmi3String 
            #@assert isa(dstArray[i], String) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetString(comp, vr, srcArray[i])
        elseif mv.datatype.datatype == fmi3Binary 
            #@assert isa(dstArray[i], String) "fmi2Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3SetBinary(comp, vr, pointer(srcArray[i])) # TODO fix this
        elseif mv.datatype.datatype == fmi3Enum 
            @warn "fmi3Set!(...): Currently not implemented for fmi2Enum."
        else 
            @assert isa(dstArray[i], Real) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end
    
    return nothing
end