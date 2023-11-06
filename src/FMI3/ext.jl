#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_ext.jl` (external/additional functions)?
# - new functions, that are useful, but not part of the FMI-spec (example: `fmi3Load`)

using Libdl
using ZipFile
import Downloads

"""

    fmi3Unzip(pathToFMU::String; unpackPath=nothing, cleanup=true)

Create a copy of the .fmu file as a .zip folder and unzips it.
Returns the paths to the zipped and unzipped folders.

# Arguments
- `pathToFMU::String`: The folder path to the .zip folder.

# Keywords
- `unpackPath=nothing`: Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
- `cleanup=true`: The cleanup option controls whether the temporary directory is automatically deleted when the process exits.

# Returns
- `unzippedAbsPath::String`: Contains the Path to the uzipped Folder.
- `zipAbsPath::String`: Contains the Path to the zipped Folder.

See also [`mktempdir`](https://docs.julialang.org/en/v1/base/file/#Base.Filesystem.mktempdir-Tuple{AbstractString}).
"""
function fmi3Unzip(pathToFMU::String; unpackPath=nothing, cleanup=true)

    fileNameExt = basename(pathToFMU)
    (fileName, fileExt) = splitext(fileNameExt)
        
    if unpackPath === nothing
        # cleanup=true leads to issues with automatic testing on linux server. TODO
        unpackPath = mktempdir(; prefix="fmijl_", cleanup=cleanup)
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

    fmi3Load(pathToFMU::String; unpackPath=nothing, type=nothing, cleanup=true)

Sets the properties of the fmu by reading the modelDescription.xml.
Retrieves all the pointers of binary functions.

# Arguments
- `pathToFMU::String`: The folder path to the .fmu file.

# Keywords
- `unpackPath=nothing`: Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
- `type=nothing`: Defines whether a Co-Simulation or Model Exchange is present
- `cleanup=true`: The cleanup option controls whether the temporary directory is automatically deleted when the process exits.

# Returns
- Returns the instance of the FMU struct.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.4.7  Model Variables

See also .
"""
function fmi3Load(pathToFMU::String; unpackPath=nothing, type=nothing, cleanup=true)
    # Create uninitialized FMU
    fmu = FMU3()

    if startswith(pathToFMU, "http")
        @info "Downloading FMU from `$(pathToFMU)`."
        pathToFMU = download(pathToFMU)
    end

    pathToFMU = normpath(pathToFMU)

    # set paths for fmu handling
    (fmu.path, fmu.zipPath) = fmi3Unzip(pathToFMU; unpackPath=unpackPath, cleanup=cleanup) # TODO

    # set paths for modelExchangeScripting and binary
    tmpName = splitpath(fmu.path)
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi3LoadModelDescription(pathToModelDescription) # TODO Matrix mit Dimensions
    fmu.modelName = fmu.modelDescription.modelName

    # TODO special use case? not complete, some combinations are missing
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

    directories = []

    fmuExt = ""
    osStr = ""

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

"""
    loadBinary(fmu::FMU3)
load pointers to `fmu`\`s c functions from shared library handle (provided by `fmu.libHandle`)
"""
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

    if fmi3CanSerializeFMUState(fmu)
        fmu.cSerializedFMUStateSize                = dlsym_opt(fmu.libHandle, :fmi3SerializedFMUStateSize)
        fmu.cSerializeFMUState                     = dlsym_opt(fmu.libHandle, :fmi3SerializeFMUState)
        fmu.cDeSerializeFMUState                   = dlsym_opt(fmu.libHandle, :fmi3DeserializeFMUState)
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

    fmi3InstantiateModelExchange!(fmu::FMU3; instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
        logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new modelExchange instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU modelExchange instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateModelExchange`](#@ref).
"""
function fmi3InstantiateModelExchange!(fmu::FMU3; instanceName::String = fmu.modelName, type::fmi3Type = fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallBacks::Bool = fmu.executionConfig.externalCallbacks,
    logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar}))

    if externalCallBacks
        if fmu.callbackLibHandle == C_NULL
            @assert Sys.WORD_SIZE == 64 "`externalCallbacks=true` is only supported for 64-bit."

            cbLibPath = joinpath(dirname(@__FILE__), "callbackFunctions", "binaries")
            if Sys.iswindows()
                cbLibPath = joinpath(cbLibPath, "win64", "callbackFunctions.dll")
            elseif Sys.islinux()
                cbLibPath = joinpath(cbLibPath, "linux64", "libcallbackFunctions.so")
            elseif Sys.isapple()
                cbLibPath = joinpath(cbLibPath, "darwin64", "libcallbackFunctions.dylib")
            else
                @error "Unsupported OS"
            end

            # check permission to execute the DLL
            perm = filemode(cbLibPath)
            permRWX = 16895
            if perm != permRWX
                chmod(cbLibPath, permRWX; recursive=true)
            end

            fmu.callbackLibHandle = dlopen(cbLibPath)
        end
        ptrLogger = dlsym(fmu.callbackLibHandle, :logger)
    end
    ptrInstanceEnvironment = Ptr{Cvoid}(pointer_from_objref(instEnv))
    
    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"
    
    compAddr = fmi3InstantiateModelExchange(fmu.cInstantiateModelExchange, pointer(instanceName), pointer(instantiationTokenStr), pointer(fmu.fmuResourceLocation), fmi3Boolean(visible), fmi3Boolean(loggingOn), ptrInstanceEnvironment, ptrLogger)

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
        
        instance = FMU3Instance(compAddr, fmu)
        instance.jacobianUpdate! = fmi3GetJacobian!
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.z_prev  = zeros(fmi3Float64, fmi3GetNumberOfEventIndicators(fmu.modelDescription))
        instance.rootsFound  = zeros(fmi3Int32, fmi3GetNumberOfEventIndicators(fmu.modelDescription))
        instance.stateEvent  = fmi3False
        instance.timeEvent   = fmi3False
        instance.stepEvent   = fmi3False
        instance.type = fmi3TypeModelExchange

        if pushInstances
            push!(fmu.instances, instance)
        end
    end 

    instance
end

"""

    fmi3InstantiateCoSimulation!(fmu::FMU3; instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
        eventModeUsed::Bool = false, ptrIntermediateUpdate=nothing, logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new coSimulation instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `eventModeUsed::Bool = false`: Defines if the FMU instance can use the event mode. (default=`false`)
- `ptrIntermediateUpdate=nothing`: Points to a function handling intermediate Updates (defalut=`nothing`) 
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU coSimulation instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateCoSimulation`](#@ref).
"""
function fmi3InstantiateCoSimulation!(fmu::FMU3; instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
    eventModeUsed::Bool = false, ptrIntermediateUpdate=nothing, logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)
    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar}))
    
    if externalCallbacks
        if fmu.callbackLibHandle == C_NULL
            @assert Sys.WORD_SIZE == 64 "`externalCallbacks=true` is only supported for 64-bit."

            cbLibPath = joinpath(dirname(@__FILE__), "callbackFunctions", "binaries")
            if Sys.iswindows()
                cbLibPath = joinpath(cbLibPath, "win64", "callbackFunctions.dll")
            elseif Sys.islinux()
                cbLibPath = joinpath(cbLibPath, "linux64", "libcallbackFunctions.so")
            elseif Sys.isapple()
                cbLibPath = joinpath(cbLibPath, "darwin64", "libcallbackFunctions.dylib")
            else
                @error "Unsupported OS"
            end

            # check permission to execute the DLL
            perm = filemode(cbLibPath)
            permRWX = 16895
            if perm != permRWX
                chmod(cbLibPath, permRWX; recursive=true)
            end

            fmu.callbackLibHandle = dlopen(cbLibPath)
        end
        ptrLogger = dlsym(fmu.callbackLibHandle, :logger)
    end
    
    if ptrIntermediateUpdate === nothing
        ptrIntermediateUpdate = @cfunction(fmi3CallbackIntermediateUpdate, Cvoid, (Ptr{Cvoid}, fmi3Float64, fmi3Boolean, fmi3Boolean, fmi3Boolean, fmi3Boolean, Ptr{fmi3Boolean}, Ptr{fmi3Float64}))
    end
    if fmu.modelDescription.coSimulation.hasEventMode !== nothing
        mode = eventModeUsed
    else
        mode = false
    end
    ptrInstanceEnvironment = Ptr{Cvoid}(pointer_from_objref(instEnv))
    
    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"
    
    compAddr = fmi3InstantiateCoSimulation(fmu.cInstantiateCoSimulation, pointer(instanceName), pointer(instantiationTokenStr), pointer(fmu.fmuResourceLocation), fmi3Boolean(visible), fmi3Boolean(loggingOn), 
                                            fmi3Boolean(mode), fmi3Boolean(fmu.modelDescription.coSimulation.canReturnEarlyAfterIntermediateUpdate !== nothing), fmu.modelDescription.intermediateUpdateValueReferences, Csize_t(length(fmu.modelDescription.intermediateUpdateValueReferences)), ptrInstanceEnvironment, ptrLogger, ptrIntermediateUpdate)

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
        instance.jacobianUpdate! = fmi3GetJacobian!
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.type = fmi3TypeCoSimulation

        if pushInstances
            push!(fmu.instances, instance)
        end
    end 

    instance
end

# TODO not tested
"""

    fmi3InstantiateScheduledExecution!(fmu::FMU3; ptrlockPreemption::Ptr{Cvoid}, ptrunlockPreemption::Ptr{Cvoid}, instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
        logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

Create a new ScheduledExecution instance of the given fmu, adds a logger if `logginOn == true`.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Keywords
- `ptrlockPreemption::Ptr{Cvoid}`: Points to a function handling locking Preemption
- `ptrunlockPreemption::Ptr{Cvoid}`: Points to a function handling unlocking Preemption
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi3Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushInstances::Bool = true`: Defines if the fmu instances should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi3CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `logStatusOK::Bool=true` whether to log status of kind `fmi3OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi3Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi3Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi3Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi3Fatal` (default=`true`)

# Returns
- Returns the instance of a new FMU ScheduledExecution instance.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model variables
- FMISpec3.0: 2.3.1. Super State: FMU State Setable

See also [`fmi3InstantiateScheduledExecution`](#@ref).
"""
function fmi3InstantiateScheduledExecution!(fmu::FMU3; ptrlockPreemption::Ptr{Cvoid}, ptrunlockPreemption::Ptr{Cvoid}, instanceName::String=fmu.modelName, type::fmi3Type=fmu.type, pushInstances::Bool = true, visible::Bool = false, loggingOn::Bool = fmu.executionConfig.loggingOn, externalCallbacks::Bool = fmu.executionConfig.externalCallbacks, 
    logStatusOK::Bool=true, logStatusWarning::Bool=true, logStatusDiscard::Bool=true, logStatusError::Bool=true, logStatusFatal::Bool=true)

    instEnv = FMU3InstanceEnvironment()
    instEnv.logStatusOK = logStatusOK
    instEnv.logStatusWarning = logStatusWarning
    instEnv.logStatusDiscard = logStatusDiscard
    instEnv.logStatusError = logStatusError
    instEnv.logStatusFatal = logStatusFatal

    ptrLogger = @cfunction(fmi3CallbackLogger, Cvoid, (Ptr{FMU3InstanceEnvironment}, Cuint, Ptr{Cchar}, Ptr{Cchar}))
    if externalCallbacks
        if fmu.callbackLibHandle == C_NULL
            @assert Sys.WORD_SIZE == 64 "`externalCallbacks=true` is only supported for 64-bit."

            cbLibPath = joinpath(dirname(@__FILE__), "callbackFunctions", "binaries")
            if Sys.iswindows()
                cbLibPath = joinpath(cbLibPath, "win64", "callbackFunctions.dll")
            elseif Sys.islinux()
                cbLibPath = joinpath(cbLibPath, "linux64", "libcallbackFunctions.so")
            elseif Sys.isapple()
                cbLibPath = joinpath(cbLibPath, "darwin64", "libcallbackFunctions.dylib")
            else
                @error "Unsupported OS"
            end

            # check permission to execute the DLL
            perm = filemode(cbLibPath)
            permRWX = 16895
            if perm != permRWX
                chmod(cbLibPath, permRWX; recursive=true)
            end

            fmu.callbackLibHandle = dlopen(cbLibPath)
        end
        ptrLogger = dlsym(fmu.callbackLibHandle, :logger)
    end
    ptrClockUpdate = @cfunction(fmi3CallbackClockUpdate, Cvoid, (Ptr{Cvoid}, ))

    ptrInstanceEnvironment = Ptr{FMU3InstanceEnvironment}(pointer_from_objref(instEnv))
    
    instantiationTokenStr = "$(fmu.modelDescription.instantiationToken)"
   
    compAddr = fmi3InstantiateScheduledExecution(fmu.cInstantiateScheduledExecution, pointer(instanceName), pointer(instantiationTokenStr), pointer(fmu.fmuResourceLocation), fmi3Boolean(visible), fmi3Boolean(loggingOn), ptrInstanceEnvironment, ptrLogger, ptrClockUpdate, ptrlockPreemption, ptrunlockPreemption)

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
        instance.jacobianUpdate! = fmi3GetJacobian!
        instance.instanceEnvironment = instEnv
        instance.instanceName = instanceName
        instance.type = fmi3TypeScheduledExecution

        if pushInstances
            push!(fmu.instances, instance)
        end
    end 

    instance
end

"""

    fmi3Reload(fmu::FMU3)

Reloads the FMU-binary. This is useful, if the FMU does not support a clean reset implementation.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3Reload(fmu::FMU3)
    dlclose(fmu.libHandle)
    loadBinary(fmu)
end

"""

    function fmi3Unload(fmu::FMU3, cleanUp::Bool = true)

Unload a FMU.
Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.
- `cleanUp::Bool= true`: Defines if the file, link, or empty directory should be deleted.
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

"""
    fmi3SampleDirectionalDerivative(c::FMU3Instance,
    vUnknown_ref::AbstractArray{fmi3ValueReference},
    vKnown_ref::AbstractArray{fmi3ValueReference},
    steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences).

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
- Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
- Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
- Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
- Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vUnknown_ref::AbstractArray{fmi3ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi3ValueReference}`: Argument `vKnown_ref` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `dvUnkonwn::Array{fmi3Float64}`: Argument `vUnknown_ref` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(see function fmi3GetDirectionalDerivative!).

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model Variables

See also [`fmi3GetDirectionalDerivative!`](@ref) ,[`fmi3GetDirectionalDerivative`](@ref).
"""
function fmi3SampleDirectionalDerivative(c::fmi3Instance,
                                       vUnknown_ref::AbstractArray{fmi3ValueReference},
                                       vKnown_ref::AbstractArray{fmi3ValueReference},
                                       steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(vKnown_ref)).*DEFAULT_SAMPLE_STEP)

    dvUnknown = zeros(fmi3Float64, length(vUnknown_ref), length(vKnown_ref))

    fmi3SampleDirectionalDerivative!(c, vUnknown_ref, vKnown_ref, dvUnknown, steps)

    dvUnknown
end


"""
    fmi3SampleDirectionalDerivative!(c::FMU3Instance,
    vUnknown_ref::AbstractArray{fmi3ValueReference},
    vKnown_ref::AbstractArray{fmi3ValueReference},
    steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences).

Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
- Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknown>` that have type Real.
- Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
- Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Output>` with type Real and variability = `discrete`.
- Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Output>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><ContinuousStateDerivative>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vUnknown_ref::AbstractArray{fmi3ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi3ValueReference}`: Argument `vKnown_ref` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `nothing`

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7  Model Variables

See also [`fmi3GetDirectionalDerivative!`](@ref) ,[`fmi3GetDirectionalDerivative`](@ref).
"""
function fmi3SampleDirectionalDerivative!(c::fmi3Instance,
                                          vUnknown_ref::AbstractArray{fmi3ValueReference},
                                          vKnown_ref::AbstractArray{fmi3ValueReference},
                                          dvUnknown::AbstractArray,
                                          steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(vKnown_ref)).*DEFAULT_SAMPLE_STEP)
    
    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi3GetFloat64(c, vKnown)

        if steps === nothing
            # smaller than 1e-6 leads to issues
            step = max(2.0 * eps(Float32(origValue)), 1e-6)
        else
            step = steps[i]
        end

        fmi3SetFloat64(c, vKnown, origValue - step)
        negValues = fmi3GetFloat64(c, vUnknown_ref)

        fmi3SetFloat64(c, vKnown, origValue + step)
        posValues = fmi3GetFloat64(c, vUnknown_ref)

        fmi3SetFloat64(c, vKnown, origValue)

        if length(vUnknown_ref) == 1
            dvUnknown[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            dvUnknown[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

"""

    fmi3GetJacobian(inst::FMU3Instance,
        rdx::AbstractArray{fmi3ValueReference},
        rx::AbstractArray{fmi3ValueReference};
        steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `rdx::AbstractArray{fmi3ValueReference}`: Argument `rdx` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi3ValueReference}`: Argument `rx` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `mat::Array{fmi3Float64}`: Return `mat` contains the jacobian ∂rdx / ∂rx.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetJacobian(inst::FMU3Instance, 
                         rdx::AbstractArray{fmi3ValueReference}, 
                         rx::AbstractArray{fmi3ValueReference}; 
                         steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    mat = zeros(fmi3Float64, length(rdx), length(rx))
    fmi3GetJacobian!(mat, inst, rdx, rx; steps=steps)
    return mat
end

"""

    function fmi3GetJacobian!(jac::AbstractMatrix{fmi3Float64},
        comp::FMU3Instance,
        rdx::AbstractArray{fmi3ValueReference},
        rx::AbstractArray{fmi3ValueReference};
        steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function stores the jacobian ∂rdx / ∂rx in an AbstractMatrix `jac`.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `jac::AbstractMatrix{fmi3Float64}`: Stores the the jacobian ∂rdx / ∂rx.
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `rdx::AbstractArray{fmi3ValueReference}`: Argument `rdx` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi3ValueReference}`: Argument `rx` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `nothing`

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetJacobian!(jac::Matrix{fmi3Float64}, 
                          inst::FMU3Instance, 
                          rdx::AbstractArray{fmi3ValueReference}, 
                          rx::AbstractArray{fmi3ValueReference}; 
                          steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)

    @assert size(jac) == (length(rdx), length(rx)) ["fmi3GetJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."]

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    ddsupported = fmi3ProvidesDirectionalDerivatives(inst.fmu)

    # ToDo: Pick entries based on dependency matrix!
    #depMtx = fmi3GetDependencies(fmu)
    rdx_inds = collect(inst.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rdx)
    rx_inds  = collect(inst.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rx)
    
    for i in 1:length(rx)

        sensitive_rdx_inds = 1:length(rdx)
        sensitive_rdx = rdx

        # sensitive_rdx_inds = Int64[]
        # sensitive_rdx = fmi3ValueReference[]

        # for j in 1:length(rdx)
        #     if depMtx[rdx_inds[j], rx_inds[i]] != fmi3DependencyIndependent
        #         push!(sensitive_rdx_inds, j)
        #         push!(sensitive_rdx, rdx[j])
        #     end
        # end

        if length(sensitive_rdx) > 0
            if ddsupported
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                fmi3GetDirectionalDerivative!(inst, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))
                # jac[sensitive_rdx_inds, i] = fmi3GetDirectionalDerivative!(inst, sensitive_rdx, [rx[i]])
            else 
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                # try
                fmi3SampleDirectionalDerivative!(inst, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i)) # TODO not implemented
                # catch e
                # jac[sensitive_rdx_inds, i] = fmi3SampleDirectionalDerivative(inst, sensitive_rdx, [rx[i]], steps)
            end
        end
    end
     
    return nothing
end

"""

    fmi3GetFullJacobian(inst::FMU3Instance,
        rdx::AbstractArray{fmi3ValueReference},
        rx::AbstractArray{fmi3ValueReference};
        steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi3GetJacobian`.


# Arguments
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `rdx::AbstractArray{fmi3ValueReference}`: Argument `rdx` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi3ValueReference}`: Argument `rx` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `mat::Array{fmi3Float64}`: Return `mat` contains the jacobian ∂rdx / ∂rx.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables

See also [`fmi3GetFullJacobian!`](@ref)
"""
function fmi3GetFullJacobian(inst::FMU3Instance, 
                             rdx::AbstractArray{fmi3ValueReference}, 
                             rx::AbstractArray{fmi3ValueReference}; 
                             steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    mat = zeros(fmi3Float64, length(rdx), length(rx))
    fmi3GetFullJacobian!(mat, inst, rdx, rx; steps=steps)
    return mat
end

"""

    fmi3GetFullJacobian!(jac::Matrix{fmi3Float64},
        inst::FMU3Instance,
        rdx::AbstractArray{fmi3ValueReference},
        rx::AbstractArray{fmi3ValueReference};
        steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)

Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi3GetJacobian`.


# Arguments
- `jac::AbstractMatrix{fmi3Float64}`: Stores the the jacobian ∂rdx / ∂rx.
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `rdx::AbstractArray{fmi3ValueReference}`: Argument `rdx` contains values of type`fmi3ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi3ValueReference}`: Argument `rx` contains values of type `fmi3ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi3Float64}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `nothing`
"""
function fmi3GetFullJacobian!(jac::Matrix{fmi3Float64}, 
                              inst::FMU3Instance, 
                              rdx::AbstractArray{fmi3ValueReference}, 
                              rx::AbstractArray{fmi3ValueReference}; 
                              steps::AbstractArray{fmi3Float64} = ones(fmi3Float64, length(rdx)).*1e-5)
    @assert size(jac) == (length(rdx),length(rx)) "fmi3GetFullJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."

    @warn "`fmi3GetFullJacobian!` is for benchmarking only, please use `fmi3GetJacobian`."

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    if fmi3ProvidesDirectionalDerivative(inst.fmu)
        for i in 1:length(rx)
            jac[:,i] = fmi3GetDirectionalDerivative(inst, rdx, [rx[i]])
        end
    else
        jac = fmi3SampleDirectionalDerivative(inst, rdx, rx) # TODO not implemented
    end

    return nothing
end

"""
    fmi3Get!(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat, dstArray::AbstractArray)

Stores the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference and returns an array that indicates the Status.

# Arguments
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vrs::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `dstArray::AbstractArray`: Stores the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr (vr = vrs[i]). `dstArray` has the same length as `vrs`.

# Returns
- `retcodes::Array{fmi3Status}`: Returns an array of length length(vrs) with Type `fmi3Status`. Type `fmi3Status` is an enumeration and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values
"""
function fmi3Get!(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat, dstArray::Array)
    vrs = prepareValueReference(inst, vrs)

    @assert length(vrs) == length(dstArray) "fmi3Get!(...): Number of value references doesn't match number of `dstArray` elements."

    retcodes = zeros(fmi3Status, length(vrs)) # fmi3StatusOK

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi3ModelVariablesForValueReference(inst.fmu.modelDescription, vr)
        mv = mv[1]
        # TODO change if dataytype is elimnated
        if isa(mv, FMICore.fmi3VariableFloat32) 
            #@assert isa(dstArray[i], Real) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetFloat32(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableFloat64) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetFloat64(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableInt8) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt8(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableInt16) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt16(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableInt32) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt32(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableInt64)  
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetInt64(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableUInt8) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt8(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableUInt16)
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt16(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableUInt32)
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt32(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableUInt64)
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetUInt64(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableBoolean) 
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetBoolean(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableString)
            #@assert isa(dstArray[i], String) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetString(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableBinary)
            #@assert isa(dstArray[i], String) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi3GetBinary(inst, vr)
        elseif isa(mv, FMICore.fmi3VariableEnumeration)
            @warn "fmi3Get!(...): Currently not implemented for fmi3Enum."
        else 
            @assert isa(dstArray[i], Real) "fmi3Get!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end

    return retcodes
end

"""

    fmi3Get(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat)


Returns the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference in an array.

# Arguments
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vrs::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `dstArray::Array{Any,1}(undef, length(vrs))`: Stores the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr (vr = vrs[i]). `dstArray` is a 1-Dimensional Array that has the same length as `vrs`.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values
"""
function fmi3Get(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat)
    vrs = prepareValueReference(inst, vrs)
    dstArray = Array{Any,1}(undef, length(vrs))
    fmi3Get!(inst, vrs, dstArray)

    if length(dstArray) == 1
        return dstArray[1]
    else
        return dstArray
    end
end

"""
    fmi3Set(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat, srcArray::AbstractArray; filter=nothing)

Stores the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference and returns an array that indicates the Status.

# Arguments
- `inst::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vrs::fmi3ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `srcArray::AbstractArray`: Stores the specific value of `fmi3Variable` containing the modelVariables with the identical fmi3ValueReference to the input variable vr (vr = vrs[i]). `srcArray` has the same length as `vrs`.

# Keywords
- `filter=nothing`: whether the individual values of "fmi3Variable" are to be stored
# Returns
- `retcodes::Array{fmi3Status}`: Returns an array of length length(vrs) with Type `fmi3Status`. Type `fmi3Status` is an enumeration and indicates the success of the function call.
More detailed:
  - `fmi3OK`: all well
  - `fmi3Warning`: things are not quite right, but the computation can continue
  - `fmi3Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi3Error`: the communication step could not be carried out at all
  - `fmi3Fatal`: if an error occurred which corrupted the FMU irreparably

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.2.4 Status Returned by Functions
- FMISpec3.0: 2.2.6.2. Getting and Setting Variable Values
"""
function fmi3Set(inst::FMU3Instance, vrs::fmi3ValueReferenceFormat, srcArray::Array)
    vrs = prepareValueReference(inst, vrs)

    @assert length(vrs) == length(srcArray) "fmi3Set(...): Number of value references doesn't match number of `srcArray` elements."

    retcodes = zeros(fmi3Status, length(vrs)) # fmi3StatusOK

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi3ModelVariablesForValueReference(inst.fmu.modelDescription, vr)
        mv = mv[1]
        if isa(mv, FMICore.fmi3VariableFloat32) 
            #@assert isa(dstArray[i], Real) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            fmi3SetFloat32(inst, vr, srcArray[i])
        elseif isa(mv, FMICore.fmi3VariableFloat64)
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetFloat64(inst, vr, srcArray[i])
        elseif isa(mv, FMICore.fmi3VariableInt8) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetInt8(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableInt16) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetInt16(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableInt32) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetInt32(inst, vr, Int32(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableInt64) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetInt64(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableUInt8) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetUInt8(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableUInt16) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetUInt16(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableUInt32) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetUInt32(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableUInt64) 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            fmi3SetUInt64(inst, vr, Integer(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableBoolean) 
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            fmi3SetBoolean(inst, vr, Bool(srcArray[i]))
        elseif isa(mv, FMICore.fmi3VariableString) 
            #@assert isa(dstArray[i], String) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            fmi3SetString(inst, vr, srcArray[i])
        elseif isa(mv, FMICore.fmi3VariableBinary) 
            #@assert isa(dstArray[i], String) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            fmi3SetBinary(inst, vr, Csize_t(length(srcArray[i])), pointer(srcArray[i])) # TODO fix this
        elseif isa(mv, FMICore.fmi3VariableEnumeration)
            @warn "fmi3Set!(...): Currently not implemented for fmi3Enum."
        else 
            @assert isa(dstArray[i], Real) "fmi3Set!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(typeof(mv))`."
        end
    end
    
    return retcodes
end

function fmi3Set(inst::FMU3Instance, vr::Union{fmi3ValueReference, String}, value)
    vrs = prepareValueReference(inst, vr)

    ret = fmi3Set(inst, vrs, [value])

    return ret[1]
end

"""

    fmi3GetStartValue(md::fmi3ModelDescription, vrs::fmi3ValueReferenceFormat = md.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `md::fmi3ModelDescription`: Struct which provides the static information of ModelVariables.
- `vrs::fmi3ValueReferenceFormat = md.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- first optional function: `starts::Array{fmi3ValueReferenceFormat}`: start/default value for a given value reference
- second optional function:`starts::fmi3ValueReferenceFormat`: start/default value for a given value reference

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetStartValue(md::fmi3ModelDescription, vrs::fmi3ValueReferenceFormat = md.valueReferences)

    vrs = prepareValueReference(md, vrs)

    starts = []

    for vr in vrs
        mvs = fmi3ModelVariablesForValueReference(md, vr)

        if length(mvs) == 0
            @warn "fmi3GetStartValue(...): Found no model variable with value reference $(vr)."
        end

        push!(starts, fmi3GetStartValue(mvs[1]) )
    end

    if length(vrs) == 1
        return starts[1]
    else
        return starts
    end
end

"""

    fmi3GetStartValue(fmu::FMU3, vrs::fmi3ValueReferenceFormat = fmu.modelDescription.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.
- `vrs::fmi3ValueReferenceFormat = md.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- first optional function: `starts::Array{fmi3ValueReferenceFormat}`: start/default value for a given value reference
- second optional function:`starts::fmi3ValueReferenceFormat`: start/default value for a given value reference

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetStartValue(fmu::FMU3, vrs::fmi3ValueReferenceFormat = fmu.modelDescription.valueReferences)
    fmi3GetStartValue(fmu.modelDescription, vrs)
end

"""

    fmi3GetStartValue(c::FMU3Instance, vrs::fmi3ValueReferenceFormat = c.fmu.modelDescription.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `c::FMU3Instance`: Mutable struct represents an instantiated instance of an FMU in the FMI 3.0 Standard.
- `vrs::fmi3ValueReferenceFormat = md.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- first optional function: `starts::Array{fmi3ValueReferenceFormat}`: start/default value for a given value reference
- second optional function:`starts::fmi3ValueReferenceFormat`: start/default value for a given value reference

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetStartValue(c::FMU3Instance, vrs::fmi3ValueReferenceFormat = c.fmu.modelDescription.valueReferences)

    vrs = prepareValueReference(c, vrs)

    starts = []

    for vr in vrs
        mvs = fmi3ModelVariablesForValueReference(c.fmu.modelDescription, vr)

        if length(mvs) == 0
            @warn "fmi3GetStartValue(...): Found no model variable with value reference $(vr)."
        end
        for mv in mvs
            if hasproperty(mv, :start)
                push!(starts, mv.start)
            end
        end
    end

    if length(vrs) == 1
        return starts[1]
    else
        return starts
    end
end

"""

    fmi3GetStartValue(mv::fmi3Variable)

Returns the start/default value for a given value reference.

# Arguments
- `mv::fmi3Variable`: The “ModelVariables” element consists of an ordered set of "ModelVariable” elements. A “ModelVariable” represents a variable of primitive type, like a real or integer variable.
- `vrs::fmi3ValueReferenceFormat = md.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi3ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi3ValueReference, Array{fmi3ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `mv._Real.start`: start/default value for a given ModelVariable. In this case representing a variable of primitive type Real.
- `mv._Integer.start`: start/default value for a given ModelVariable. In this case representing a variable of primitive type Integer.
- `mv._Boolean.start`: start/default value for a given ModelVariable. In this case representing a variable of primitive type Boolean.
- `mv._String.start`: start/default value for a given ModelVariable. In this case representing a variable of primitive type String.
- `mv._Enumeration.start`: start/default value for a given ModelVariable. In this case representing a variable of primitive type Enumeration.


# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""

function fmi3GetStartValue(mv::fmi3Variable)
    if hasproperty(mv, :start)
        return mv.start
    end
end

"""
    function fmi3SampleDirectionalDerivative(c::FMU3Instance,
        vUnknown_ref::Array{fmi3ValueReference},
        vKnown_ref::Array{fmi3ValueReference},
        steps::Array{fmi3Float64} = ones(fmi3Float64, length(vKnown_ref)).*1e-5)

Wrapper for [`fmi3SampleDirectionalDerivative!`](@ref) with `dvUnknown` initialized with zeros

Returning dvUnknown, modified by `fmi3SampleDirectionalDerivative!` call.
"""
function fmi3SampleDirectionalDerivative(c::FMU3Instance,
    vUnknown_ref::Array{fmi3ValueReference},
    vKnown_ref::Array{fmi3ValueReference},
    steps::Array{fmi3Float64} = ones(fmi3Float64, length(vKnown_ref)).*1e-5)

    dvUnknown = zeros(fmi3Float64, length(vUnknown_ref), length(vKnown_ref))

    fmi3SampleDirectionalDerivative!(c, vUnknown_ref, vKnown_ref, dvUnknown, steps)

    dvUnknown
end

function fmi3SampleDirectionalDerivative!(c::FMU3Instance,
    vUnknown_ref::Array{fmi3ValueReference},
    vKnown_ref::Array{fmi3ValueReference},
    dvUnknown::AbstractArray,
    steps::Array{fmi3Float64} = ones(fmi3Float64, length(vKnown_ref)).*1e-5)

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi3GetFloat64(c, vKnown)

        fmi3Set(c, vKnown, origValue - steps[i]*0.5)
        negValues = fmi3GetFloat64(c, vUnknown_ref)

        fmi3Set(c, vKnown, origValue + steps[i]*0.5)
        posValues = fmi3GetFloat64(c, vUnknown_ref)

        fmi3Set(c, vKnown, origValue)

        if length(vUnknown_ref) == 1
            dvUnknown[1,i] = (posValues-negValues) ./ steps[i]
        else
            dvUnknown[:,i] = (posValues-negValues) ./ steps[i]
        end
    end

    nothing
end

"""

    fmi3GetUnit(mv::fmi3Variable)

Returns the `unit` entry of the corresponding model variable.

# Arguments
- `mv::fmi3Variable`: The “ModelVariables” element consists of an ordered set of “ModelVariable” elements. A “ModelVariable” represents a variable of primitive type, like a real or integer variable.

# Returns
- `mv._Float.unit`: Returns the `unit` entry of the corresponding ScalarVariable representing a variable of the primitive type Real. Otherwise `nothing` is returned.
# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables

"""
function fmi3GetUnit(mv::fmi3Variable)
    if mv._Float !== nothing
        return mv._Float.unit
    else
        return nothing
    end
end

"""

    fmi3GetInitial(mv::fmi3Variable)

Returns the `inital` entry of the corresponding model variable.

# Arguments
- `mv::fmi3Variable`: The “ModelVariables” element consists of an ordered set of “ModelVariable” elements. A “ModelVariable” represents a variable of primitive type, like a real or integer variable.

# Returns
- `mv._Float.initial`: Returns the `inital` entry of the corresponding ModelVariable representing a variable of the primitive type Real. Otherwise `nothing` is returned.

# Source
- FMISpec3.0 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec3.0: 2.4.7 Model Variables
"""
function fmi3GetInitial(mv::fmi3Variable)
    return mv.initial
end