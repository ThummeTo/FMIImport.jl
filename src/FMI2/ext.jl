#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_ext.jl` (external/additional functions)?
# - new functions, that are useful, but not part of the FMI-spec (example: `fmi2Load`, `fmi2SampleJacobian`)

using Libdl
using ZipFile
import Downloads

const CB_LIB_PATH = @path joinpath(dirname(@__FILE__), "callbackFunctions", "binaries")

"""
    fmi2Unzip(pathToFMU::String; unpackPath=nothing, cleanup=true)

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
function fmi2Unzip(pathToFMU::String; unpackPath=nothing, cleanup=true)

    fileNameExt = basename(pathToFMU)
    (fileName, fileExt) = splitext(fileNameExt)

    if unpackPath == nothing
        # cleanup=true leads to issues with automatic testing on linux server.
        unpackPath = mktempdir(; prefix="fmijl_", cleanup=cleanup)
    end

    zipPath = joinpath(unpackPath, fileName * ".zip")
    unzippedPath = joinpath(unpackPath, fileName)

    # only copy ZIP if not already there
    if !isfile(zipPath)
        cp(pathToFMU, zipPath; force=true)
    end

    @assert isfile(zipPath) ["fmi2Unzip(...): ZIP-Archive couldn't be copied to `$zipPath`."]

    zipAbsPath = isabspath(zipPath) ?  zipPath : joinpath(pwd(), zipPath)
    unzippedAbsPath = isabspath(unzippedPath) ? unzippedPath : joinpath(pwd(), unzippedPath)

    @assert isfile(zipAbsPath) ["fmi2Unzip(...): Can't deploy ZIP-Archive at `$(zipAbsPath)`."]

    numFiles = 0

    # only unzip if not already done
    if !isdir(unzippedAbsPath)
        mkpath(unzippedAbsPath)

        zarchive = ZipFile.Reader(zipAbsPath)
        for f in zarchive.files
            fileAbsPath = normpath(joinpath(unzippedAbsPath, f.name))

            if endswith(f.name,"/") || endswith(f.name,"\\")
                mkpath(fileAbsPath) # mkdir(fileAbsPath)

                @assert isdir(fileAbsPath) ["fmi2Unzip(...): Can't create directory `$(f.name)` at `$(fileAbsPath)`."]
            else
                # create directory if not forced by zip file folder
                mkpath(dirname(fileAbsPath))

                numBytes = write(fileAbsPath, read(f))

                if numBytes == 0
                    @debug "fmi2Unzip(...): Written file `$(f.name)`, but file is empty."
                end

                @assert isfile(fileAbsPath) ["fmi2Unzip(...): Can't unzip file `$(f.name)` at `$(fileAbsPath)`."]
                numFiles += 1
            end
        end
        close(zarchive)
    end

    @assert isdir(unzippedAbsPath) ["fmi2Unzip(...): ZIP-Archive couldn't be unzipped at `$(unzippedPath)`."]
    @debug "fmi2Unzip(...): Successfully unzipped $numFiles files at `$unzippedAbsPath`."

    (unzippedAbsPath, zipAbsPath)
end

# Checks with dlsym for available function in library.
# Prints an info text and returns C_NULL if not (soft-check).
# TODO used in FMI3_ext.jl too other spot to put it?
function dlsym_opt(libHandle, symbol)
    addr = dlsym(libHandle, symbol; throw_error=false)
    if addr == nothing
        logWarning(fmu, "This FMU does not support function '$symbol'.")
        addr = Ptr{Cvoid}(C_NULL)
    end
    addr
end

"""
    fmi2Load(pathToFMU::String;
                unpackPath=nothing,
                type=nothing,
                cleanup=true)

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
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

"""
function fmi2Load(pathToFMU::String; unpackPath::Union{String, Nothing}=nothing, type::Union{Symbol, fmi2Type, Nothing}=nothing, cleanup::Bool=true, logLevel::Union{FMULogLevel, Symbol}=FMULogLevelWarn)
    # Create uninitialized FMU

    if isa(logLevel, Symbol)
        if logLevel == :info
            logLevel = FMULogLevelInfo
        elseif logLevel == :warn
            logLevel = FMULogLevelWarn
        elseif logLevel == :error
            logLevel = FMULogLevelError
        else
            @assert false "Unknown logLevel symbol: `$(logLevel)`, supported are `:info`, `:warn` and `:error`."
        end
    end
    fmu = FMU2(logLevel)

    if startswith(pathToFMU, "http")
        logInfo(fmu, "Downloading FMU from `$(pathToFMU)`.")
        pathToFMU = Downloads.download(pathToFMU)
    end

    pathToFMU = normpath(pathToFMU)

    # set paths for fmu handling
    (fmu.path, fmu.zipPath) = fmi2Unzip(pathToFMU; unpackPath=unpackPath, cleanup=cleanup)

    # set paths for modelExchangeScripting and binary
    tmpName = splitpath(fmu.path)
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi2LoadModelDescription(pathToModelDescription)
    fmu.modelName = fmu.modelDescription.modelName
    fmu.isZeroState = (length(fmu.modelDescription.stateValueReferences) == 0)

    if isa(type, fmi2Type)
        fmu.type = type

    elseif isa(type, Symbol)
        if type == :ME
            fmu.type = fmi2TypeModelExchange
        elseif type == :CS
            fmu.type = fmi2TypeCoSimulation
        else
            @assert "Unknwon type symbol `$(type)`, supported is `:ME` and `:CS`."
        end

    else # type==nothing
        if fmi2IsCoSimulation(fmu.modelDescription) && fmi2IsModelExchange(fmu.modelDescription)
            fmu.type = fmi2TypeCoSimulation
            logInfo(fmu, "fmi2Load(...): FMU supports both CS and ME, using CS as default if nothing specified.")

        elseif fmi2IsCoSimulation(fmu.modelDescription)
            fmu.type = fmi2TypeCoSimulation

        elseif fmi2IsModelExchange(fmu.modelDescription)
            fmu.type = fmi2TypeModelExchange

        else
            @assert false "FMU neither supports ME nor CS."
        end
    end

    fmuName = fmi2GetModelIdentifier(fmu.modelDescription; type=fmu.type) # tmpName[length(tmpName)]

    directoryBinary = ""
    pathToBinary = ""

    directories = []

    fmuExt = ""
    osStr = ""

    juliaArch = Sys.WORD_SIZE
    @assert (juliaArch == 64 || juliaArch == 32) "fmi2Load(...): Unknown Julia Architecture with $(juliaArch)-bit, must be 64- or 32-bit."

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
        @assert false "fmi2Load(...): Unsupported target platform. Supporting Windows, Linux and Mac. Please open an issue if you want to use another OS/architecture."
    end

    @assert (length(directories) > 0) "fmi2Load(...): Unsupported architecture. Supporting Julia for Windows (64- and 32-bit), Linux (64-bit) and Mac (64-bit). Please open an issue if you want to use another architecture."
    for directory in directories
        directoryBinary = joinpath(fmu.path, directory)
        if isdir(directoryBinary)
            pathToBinary = joinpath(directoryBinary, "$(fmuName).$(fmuExt)")
            break
        end
    end
    @assert isfile(pathToBinary) "fmi2Load(...): Target platform is $(osStr), but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."

    # make URI ressource location
    tmpResourceLocation = string("file:///", fmu.path)
    tmpResourceLocation = joinpath(tmpResourceLocation, "resources")
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") # URIs.escapeuri(tmpResourceLocation)

    logInfo(fmu, "fmi2Load(...): FMU resources location is `$(fmu.fmuResourceLocation)`")

    fmu.binaryPath = pathToBinary
    loadBinary(fmu)

    return fmu
end

"""
    loadBinary(fmu::FMU2)
load pointers to `fmu`\`s c functions from shared library handle (provided by `fmu.libHandle`)
"""
function loadBinary(fmu::FMU2)
    lastDirectory = pwd()
    cd(dirname(fmu.binaryPath))

    # set FMU binary handler
    fmu.libHandle = dlopen(fmu.binaryPath) # , RTLD_NOW|RTLD_GLOBAL

    cd(lastDirectory)

    # retrieve functions
    fmu.cInstantiate                  = dlsym(fmu.libHandle, :fmi2Instantiate)
    fmu.cGetTypesPlatform             = dlsym(fmu.libHandle, :fmi2GetTypesPlatform)
    fmu.cGetVersion                   = dlsym(fmu.libHandle, :fmi2GetVersion)
    fmu.cFreeInstance                 = dlsym(fmu.libHandle, :fmi2FreeInstance)
    fmu.cSetDebugLogging              = dlsym(fmu.libHandle, :fmi2SetDebugLogging)
    fmu.cSetupExperiment              = dlsym(fmu.libHandle, :fmi2SetupExperiment)
    fmu.cEnterInitializationMode      = dlsym(fmu.libHandle, :fmi2EnterInitializationMode)
    fmu.cExitInitializationMode       = dlsym(fmu.libHandle, :fmi2ExitInitializationMode)
    fmu.cTerminate                    = dlsym(fmu.libHandle, :fmi2Terminate)
    fmu.cReset                        = dlsym(fmu.libHandle, :fmi2Reset)
    fmu.cGetReal                      = dlsym(fmu.libHandle, :fmi2GetReal)
    fmu.cSetReal                      = dlsym(fmu.libHandle, :fmi2SetReal)
    fmu.cGetInteger                   = dlsym(fmu.libHandle, :fmi2GetInteger)
    fmu.cSetInteger                   = dlsym(fmu.libHandle, :fmi2SetInteger)
    fmu.cGetBoolean                   = dlsym(fmu.libHandle, :fmi2GetBoolean)
    fmu.cSetBoolean                   = dlsym(fmu.libHandle, :fmi2SetBoolean)
    fmu.cGetString                    = dlsym_opt(fmu.libHandle, :fmi2GetString)
    fmu.cSetString                    = dlsym_opt(fmu.libHandle, :fmi2SetString)

    if fmi2CanGetSetState(fmu.modelDescription)
        fmu.cGetFMUstate                  = dlsym_opt(fmu.libHandle, :fmi2GetFMUstate)
        fmu.cSetFMUstate                  = dlsym_opt(fmu.libHandle, :fmi2SetFMUstate)
        fmu.cFreeFMUstate                 = dlsym_opt(fmu.libHandle, :fmi2FreeFMUstate)
    end

    if fmi2CanSerializeFMUstate(fmu.modelDescription)
        fmu.cSerializedFMUstateSize       = dlsym_opt(fmu.libHandle, :fmi2SerializedFMUstateSize)
        fmu.cSerializeFMUstate            = dlsym_opt(fmu.libHandle, :fmi2SerializeFMUstate)
        fmu.cDeSerializeFMUstate          = dlsym_opt(fmu.libHandle, :fmi2DeSerializeFMUstate)
    end

    if fmi2ProvidesDirectionalDerivative(fmu.modelDescription)
        fmu.cGetDirectionalDerivative     = dlsym_opt(fmu.libHandle, :fmi2GetDirectionalDerivative)
    end

    # CS specific function calls
    if fmi2IsCoSimulation(fmu.modelDescription)
        fmu.cSetRealInputDerivatives      = dlsym(fmu.libHandle, :fmi2SetRealInputDerivatives)
        fmu.cGetRealOutputDerivatives     = dlsym(fmu.libHandle, :fmi2GetRealOutputDerivatives)
        fmu.cDoStep                       = dlsym(fmu.libHandle, :fmi2DoStep)
        fmu.cCancelStep                   = dlsym(fmu.libHandle, :fmi2CancelStep)
        fmu.cGetStatus                    = dlsym(fmu.libHandle, :fmi2GetStatus)
        fmu.cGetRealStatus                = dlsym(fmu.libHandle, :fmi2GetRealStatus)
        fmu.cGetIntegerStatus             = dlsym(fmu.libHandle, :fmi2GetIntegerStatus)
        fmu.cGetBooleanStatus             = dlsym(fmu.libHandle, :fmi2GetBooleanStatus)
        fmu.cGetStringStatus              = dlsym(fmu.libHandle, :fmi2GetStringStatus)
    end

    # ME specific function calls
    if fmi2IsModelExchange(fmu.modelDescription)
        fmu.cEnterContinuousTimeMode      = dlsym(fmu.libHandle, :fmi2EnterContinuousTimeMode)
        fmu.cGetContinuousStates          = dlsym(fmu.libHandle, :fmi2GetContinuousStates)
        fmu.cGetDerivatives               = dlsym(fmu.libHandle, :fmi2GetDerivatives)
        fmu.cSetTime                      = dlsym(fmu.libHandle, :fmi2SetTime)
        fmu.cSetContinuousStates          = dlsym(fmu.libHandle, :fmi2SetContinuousStates)
        fmu.cCompletedIntegratorStep      = dlsym(fmu.libHandle, :fmi2CompletedIntegratorStep)
        fmu.cEnterEventMode               = dlsym(fmu.libHandle, :fmi2EnterEventMode)
        fmu.cNewDiscreteStates            = dlsym(fmu.libHandle, :fmi2NewDiscreteStates)
        fmu.cGetEventIndicators           = dlsym(fmu.libHandle, :fmi2GetEventIndicators)
        fmu.cGetNominalsOfContinuousStates= dlsym(fmu.libHandle, :fmi2GetNominalsOfContinuousStates)
    end
end

function unloadBinary(fmu::FMU2)

    # retrieve functions
    fmu.cInstantiate                  = @cfunction(FMICore.unload_fmi2Instantiate, fmi2Component, (fmi2String, fmi2Type, fmi2String, fmi2String, Ptr{fmi2CallbackFunctions}, fmi2Boolean, fmi2Boolean))
    fmu.cGetTypesPlatform             = @cfunction(FMICore.unload_fmi2GetTypesPlatform, fmi2String, ())
    fmu.cGetVersion                   = @cfunction(FMICore.unload_fmi2GetVersion, fmi2String, ())
    fmu.cFreeInstance                 = @cfunction(FMICore.unload_fmi2FreeInstance, Cvoid, (fmi2Component,))
    fmu.cSetDebugLogging              = @cfunction(FMICore.unload_fmi2SetDebugLogging, fmi2Status, (fmi2Component, fmi2Boolean, Csize_t, Ptr{fmi2String}))
    fmu.cSetupExperiment              = @cfunction(FMICore.unload_fmi2SetupExperiment, fmi2Status, (fmi2Component, fmi2Boolean, fmi2Real, fmi2Real, fmi2Boolean, fmi2Real))
    fmu.cEnterInitializationMode      = @cfunction(FMICore.unload_fmi2EnterInitializationMode, fmi2Status, (fmi2Component,))
    fmu.cExitInitializationMode       = @cfunction(FMICore.unload_fmi2ExitInitializationMode, fmi2Status, (fmi2Component,))
    fmu.cTerminate                    = @cfunction(FMICore.unload_fmi2Terminate, fmi2Status, (fmi2Component,))
    fmu.cReset                        = @cfunction(FMICore.unload_fmi2Reset, fmi2Status, (fmi2Component,))
    fmu.cGetReal                      = @cfunction(FMICore.unload_fmi2GetReal, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real}))
    fmu.cSetReal                      = @cfunction(FMICore.unload_fmi2SetReal, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real}))
    fmu.cGetInteger                   = @cfunction(FMICore.unload_fmi2GetInteger, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}))
    fmu.cSetInteger                   = @cfunction(FMICore.unload_fmi2SetInteger, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer}))
    fmu.cGetBoolean                   = @cfunction(FMICore.unload_fmi2GetBoolean, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean}))
    fmu.cSetBoolean                   = @cfunction(FMICore.unload_fmi2SetBoolean, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean}))
    fmu.cGetString                    = @cfunction(FMICore.unload_fmi2GetString, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String}))
    fmu.cSetString                    = @cfunction(FMICore.unload_fmi2SetString, fmi2Status, (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String}))

    # ToDo: Implement for pecial functions!
    # if fmi2CanGetSetState(fmu.modelDescription)
    #     fmu.cGetFMUstate                  = FMICore.unload_fmi2GetFMUstate
    #     fmu.cSetFMUstate                  = FMICore.unload_fmi2SetFMUstate
    #     fmu.cFreeFMUstate                 = FMICore.unload_fmi2FreeFMUstate
    # end

    # if fmi2CanSerializeFMUstate(fmu.modelDescription)
    #     fmu.cSerializedFMUstateSize       = FMICore.unload_fmi2SerializedFMUstateSize
    #     fmu.cSerializeFMUstate            = FMICore.unload_fmi2SerializeFMUstate
    #     fmu.cDeSerializeFMUstate          = FMICore.unload_fmi2DeSerializeFMUstate
    # end

    # if fmi2ProvidesDirectionalDerivative(fmu.modelDescription)
    #     fmu.cGetDirectionalDerivative     = FMICore.unload_fmi2GetDirectionalDerivative
    # end

    # ToDo: CS specific function calls
    # if fmi2IsCoSimulation(fmu.modelDescription)
    #     fmu.cSetRealInputDerivatives      = FMICore.unload_fmi2SetRealInputDerivatives
    #     fmu.cGetRealOutputDerivatives     = FMICore.unload_fmi2GetRealOutputDerivatives
    #     fmu.cDoStep                       = FMICore.unload_fmi2DoStep
    #     fmu.cCancelStep                   = FMICore.unload_fmi2CancelStep
    #     fmu.cGetStatus                    = FMICore.unload_fmi2GetStatus
    #     fmu.cGetRealStatus                = FMICore.unload_fmi2GetRealStatus
    #     fmu.cGetIntegerStatus             = FMICore.unload_fmi2GetIntegerStatus
    #     fmu.cGetBooleanStatus             = FMICore.unload_fmi2GetBooleanStatus
    #     fmu.cGetStringStatus              = FMICore.unload_fmi2GetStringStatus
    # end

    # ME specific function calls
    if fmi2IsModelExchange(fmu.modelDescription)
        fmu.cEnterContinuousTimeMode      = @cfunction(FMICore.unload_fmi2EnterContinuousTimeMode, fmi2Status, (fmi2Component,))
        fmu.cGetContinuousStates          = @cfunction(FMICore.unload_fmi2GetContinuousStates, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
        fmu.cGetDerivatives               = @cfunction(FMICore.unload_fmi2GetDerivatives, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
        fmu.cSetTime                      = @cfunction(FMICore.unload_fmi2SetTime, fmi2Status, (fmi2Component, fmi2Real))
        fmu.cSetContinuousStates          = @cfunction(FMICore.unload_fmi2SetContinuousStates, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
        fmu.cCompletedIntegratorStep      = @cfunction(FMICore.unload_fmi2CompletedIntegratorStep, fmi2Status, (fmi2Component, fmi2Boolean, Ptr{fmi2Boolean}, Ptr{fmi2Boolean}))
        fmu.cEnterEventMode               = @cfunction(FMICore.unload_fmi2EnterEventMode, fmi2Status, (fmi2Component,))
        fmu.cNewDiscreteStates            = @cfunction(FMICore.unload_fmi2NewDiscreteStates, fmi2Status, (fmi2Component, Ptr{fmi2EventInfo}))
        fmu.cGetEventIndicators           = @cfunction(FMICore.unload_fmi2GetEventIndicators, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
        fmu.cGetNominalsOfContinuousStates= @cfunction(FMICore.unload_fmi2GetNominalsOfContinuousStates, fmi2Status, (fmi2Component, Ptr{fmi2Real}, Csize_t))
    end
end

lk_fmi2Instantiate = ReentrantLock()
"""
    fmi2Instantiate!(fmu::FMU2;
                        instanceName::String=fmu.modelName,
                        type::fmi2Type=fmu.type,
                        pushComponents::Bool = true,
                        visible::Bool = false,
                        loggingOn::Bool = fmu.executionConfig.loggingOn,
                        externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
                        logStatusOK::Bool=true,
                        logStatusWarning::Bool=true,
                        logStatusDiscard::Bool=true,
                        logStatusError::Bool=true,
                        logStatusFatal::Bool=true,
                        logStatusPending::Bool=true)

Create a new instance of the given fmu, adds a logger if logginOn == true.
# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Keywords
- `instanceName::String=fmu.modelName`: Name of the instance
- `type::fmi2Type=fmu.type`: Defines whether a Co-Simulation or Model Exchange is present
- `pushComponents::Bool = true`: Defines if the fmu components should be pushed in the application.
- `visible::Bool = false` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn::Bool = fmu.executionConfig.loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks::Bool = fmu.executionConfig.externalCallbacks` if an external shared library should be used for the fmi2CallbackFunctions, this may improve readability of logging messages (default=`false`)
- `logStatusOK::Bool=true` whether to log status of kind `fmi2OK` (default=`true`)
- `logStatusWarning::Bool=true` whether to log status of kind `fmi2Warning` (default=`true`)
- `logStatusDiscard::Bool=true` whether to log status of kind `fmi2Discard` (default=`true`)
- `logStatusError::Bool=true` whether to log status of kind `fmi2Error` (default=`true`)
- `logStatusFatal::Bool=true` whether to log status of kind `fmi2Fatal` (default=`true`)
- `logStatusPending::Bool=true` whether to log status of kind `fmi2Pending` (default=`true`)

# Returns
- Returns the instance of a new FMU component.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2Instantiate`](#@ref).
"""
function fmi2Instantiate!(fmu::FMU2;
                            instanceName::String=fmu.modelName,
                            type::fmi2Type=fmu.type,
                            pushComponents::Bool = true,
                            visible::Bool = false,
                            loggingOn::Bool = fmu.executionConfig.loggingOn,
                            externalCallbacks::Bool = fmu.executionConfig.externalCallbacks,
                            logStatusOK::Bool=true,
                            logStatusWarning::Bool=true,
                            logStatusDiscard::Bool=true,
                            logStatusError::Bool=true,
                            logStatusFatal::Bool=true,
                            logStatusPending::Bool=true)

    compEnv = FMU2ComponentEnvironment()
    compEnv.logStatusOK = logStatusOK
    compEnv.logStatusWarning = logStatusWarning
    compEnv.logStatusDiscard = logStatusDiscard
    compEnv.logStatusError = logStatusError
    compEnv.logStatusFatal = logStatusFatal
    compEnv.logStatusPending = logStatusPending

    ptrLogger = @cfunction(fmi2CallbackLogger, Cvoid, (Ptr{FMU2ComponentEnvironment}, Ptr{Cchar}, Cuint, Ptr{Cchar}, Ptr{Cchar}))
    if externalCallbacks
        if fmu.callbackLibHandle == C_NULL
            @assert Sys.WORD_SIZE == 64 "`externalCallbacks=true` is only supported for 64-bit."

            cbLibPath = CB_LIB_PATH
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
    ptrAllocateMemory = @cfunction(fmi2CallbackAllocateMemory, Ptr{Cvoid}, (Csize_t, Csize_t))
    ptrFreeMemory = @cfunction(fmi2CallbackFreeMemory, Cvoid, (Ptr{Cvoid},))
    ptrStepFinished = C_NULL # ToDo
    ptrComponentEnvironment = Ptr{FMU2ComponentEnvironment}(pointer_from_objref(compEnv))
    callbackFunctions = fmi2CallbackFunctions(ptrLogger, ptrAllocateMemory, ptrFreeMemory, ptrStepFinished, ptrComponentEnvironment)

    guidStr = "$(fmu.modelDescription.guid)"

    global lk_fmi2Instantiate

    lock(lk_fmi2Instantiate) do

        component = nothing
        compAddr = fmi2Instantiate(fmu.cInstantiate, pointer(instanceName), type, pointer(guidStr), pointer(fmu.fmuResourceLocation), Ptr{fmi2CallbackFunctions}(pointer_from_objref(callbackFunctions)), fmi2Boolean(visible), fmi2Boolean(loggingOn))

        if compAddr == Ptr{Cvoid}(C_NULL)
            @error "fmi2Instantiate!(...): Instantiation failed, see error messages above.\nIf no error messages, enable FMU debug logging.\nIf logging is on and no messages are printed before this, the FMU might not log errors."
            return nothing
        end

        # check if address is already inside of the components (this may be in FMIExport.jl)
        for c in fmu.components
            if c.compAddr == compAddr
                component = c
                break
            end
        end

        if !isnothing(component)
            logWarning(fmu, "fmi2Instantiate!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl.")
        else
            component = FMU2Component(compAddr, fmu)

            component.callbackFunctions = callbackFunctions
            component.instanceName = instanceName
            component.type = type

            if pushComponents
                push!(fmu.components, component)
            end
        end

        component.componentEnvironment = compEnv
        component.loggingOn = loggingOn
        component.visible = visible

        # Jacobians

        # smpFct = (mtx, ∂f_refs, ∂x_refs) -> fmi2SampleJacobian!(mtx, component, ∂f_refs, ∂x_refs)
        # updFct = nothing
        # if fmi2ProvidesDirectionalDerivative(fmu)
        #     updFct = (mtx, ∂f_refs, ∂x_refs) -> fmi2GetJacobian!(mtx, component, ∂f_refs, ∂x_refs)
        # else
        #     updFct = smpFct
        # end

        # component.∂ẋ_∂x = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)
        # component.∂ẋ_∂u = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)
        # component.∂ẋ_∂p = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)

        # component.∂y_∂x = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)
        # component.∂y_∂u = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)
        # component.∂y_∂p = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, updFct)

        # component.∂e_∂x = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, smpFct)
        # component.∂e_∂u = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, smpFct)
        # component.∂e_∂p = FMICore.FMU2Jacobian{fmi2Real, fmi2ValueReference}(component, smpFct)

        # register component for current thread
        fmu.threadComponents[Threads.threadid()] = component
    end

    return getCurrentComponent(fmu)
end

"""
    fmi2Reload(fmu::FMU2)

Reloads the FMU-binary. This is useful, if the FMU does not support a clean reset implementation.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2Reload(fmu::FMU2)
    dlclose(fmu.libHandle)
    loadBinary(fmu)
end

"""
    fmi2Unload(fmu::FMU2, cleanUp::Bool = true)

Unload a FMU.
Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `cleanUp::Bool= true`: Defines if the file and directory should be deleted.

# Keywords
- `secure_pointers=true` whether pointers to C-functions should be overwritten with dummies with Julia assertions, instead of pointing to dead memory (slower, but more user safe)
"""
function fmi2Unload(fmu::FMU2, cleanUp::Bool = true; secure_pointers::Bool=true)

    while length(fmu.components) > 0
        fmi2FreeInstance!(fmu.components[end])
    end

    # the components are removed from the component list via call to fmi2FreeInstance!
    @assert length(fmu.components) == 0 "fmi2Unload(...): Failure during deleting components, $(length(fmu.components)) remaining in stack."

    if secure_pointers
        unloadBinary(fmu)
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

"""
    fmi2SampleJacobian(c::FMU2Component,
                            vUnknown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                            vKnown_ref::AbstractArray{fmi2ValueReference},
                            steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences).

Computes the directional derivatives of an FMU. An FMU has different modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
   - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknowns>` that have type Real.
   - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
   - Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Outputs>` with type Real and variability = `discrete`.
   - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><Derivatives>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes.

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

   Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `dvUnkonwn::Array{fmi2Real}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(see function fmi2GetDirectionalDerivative!).

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2GetDirectionalDerivative!`](@ref).
"""
function fmi2SampleJacobian(c::FMU2Component,
                                       vUnknown_ref::AbstractArray{fmi2ValueReference},
                                       vKnown_ref::AbstractArray{fmi2ValueReference},
                                       steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    mtx = zeros(fmi2Real, length(vUnknown_ref), length(vKnown_ref))

    fmi2SampleJacobian!(mtx, vUnknown_ref, vKnown_ref, steps)

    return mtx
end

"""
    function fmi2SampleJacobian!(mtx::Matrix{<:Real},
                                    c::FMU2Component,
                                    vUnknown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                                    vKnown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                                    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences) and saves in-place.


Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
   - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknowns>` that have type Real.
   - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
   - Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Outputs>` with type Real and variability = `discrete`.
   - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><Derivatives>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

   Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `mtx::Matrix{<:Real}`:Output matrix to store the Jacobian. Its dimensions must be compatible with the number of unknown and known value references.
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `dvUnknown::AbstractArray{fmi2Real}`: Stores the directional derivative vector values.
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: Step size to be used for numerical differentiation. If nothing, a default value will be chosen automatically.

# Returns
- `nothing`

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2GetDirectionalDerivative!`](@ref).
"""
function fmi2SampleJacobian!(mtx::Matrix{<:Real},
                                c::FMU2Component,
                                vUnknown_ref::AbstractArray{fmi2ValueReference},
                                vKnown_ref::AbstractArray{fmi2ValueReference},
                                steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    step = 0.0

    negValues = zeros(length(vUnknown_ref))
    posValues = zeros(length(vUnknown_ref))

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            # smaller than 1e-6 leads to issues
            step = max(2.0 * eps(Float32(origValue)), 1e-6)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetReal!(c, vUnknown_ref, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetReal!(c, vUnknown_ref, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if length(vUnknown_ref) == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

function fmi2SampleJacobian!(mtx::Matrix{<:Real},
    c::FMU2Component,
    vUnknown_ref::Symbol,
    vKnown_ref::AbstractArray{fmi2ValueReference},
    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert vUnknown_ref == :indicators "vUnknown_ref::Symbol must be `:indicators`!"

    step = 0.0

    len_vUnknown_ref = c.fmu.modelDescription.numberOfEventIndicators

    negValues = zeros(len_vUnknown_ref)
    posValues = zeros(len_vUnknown_ref)

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            step = max(2.0 * eps(Float32(origValue)), 1e-12)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetEventIndicators!(c, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetEventIndicators!(c, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if len_vUnknown_ref == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

function fmi2SampleJacobian!(mtx::Matrix{<:Real},
    c::FMU2Component,
    vUnknown_ref::AbstractArray{fmi2ValueReference},
    vKnown_ref::Symbol,
    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert vKnown_ref == :time "vKnown_ref::Symbol must be `:time`!"

    step = 0.0

    negValues = zeros(length(vUnknown_ref))
    posValues = zeros(length(vUnknown_ref))

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            step = max(2.0 * eps(Float32(origValue)), 1e-12)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetEventIndicators!(c, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetEventIndicators!(c, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if length(vUnknown_ref) == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

"""
    fmi2GetJacobian(comp::FMU2Component,
                        rdx::AbstractArray{fmi2ValueReference},
                        rx::AbstractArray{fmi2ValueReference};
                        steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `mat::Array{fmi2Real}`: Return `mat` contains the jacobian ∂rdx / ∂rx.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

"""
function fmi2GetJacobian(comp::FMU2Component,
                         rdx::AbstractArray{fmi2ValueReference},
                         rx::AbstractArray{fmi2ValueReference};
                         steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)
    mat = zeros(fmi2Real, length(rdx), length(rx))
    fmi2GetJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
    fmi2GetJacobian!(jac::AbstractMatrix{fmi2Real},
                          comp::FMU2Component,
                          rdx::AbstractArray{fmi2ValueReference},
                          rx::AbstractArray{fmi2ValueReference};
                          steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function stores the jacobian ∂rdx / ∂rx in an AbstractMatrix `jac`.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `jac::AbstractMatrix{fmi2Real}`: A matrix that will hold the computed Jacobian matrix.
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: Step size to be used for numerical differentiation. If nothing, a default value will be chosen automatically.

# Returns
- `nothing`

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

"""
function fmi2GetJacobian!(jac::AbstractMatrix{fmi2Real},
                          comp::FMU2Component,
                          rdx::AbstractArray{fmi2ValueReference},
                          rx::AbstractArray{fmi2ValueReference};
                          steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert size(jac) == (length(rdx), length(rx)) ["fmi2GetJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` $(length(rdx)) and `rx` $(length(rx))."]

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end

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

            fmi2GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))

            #    jac[sensitive_rdx_inds, i] = fmi2GetDirectionalDerivative(comp, sensitive_rdx, [rx[i]])

        end
    end

    return nothing
end

"""
    fmi2GetFullJacobian(comp::FMU2Component,
                            rdx::AbstractArray{fmi2ValueReference},
                            rx::AbstractArray{fmi2ValueReference};
                            steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian`.


# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `mat::Array{fmi2Real}`: Return `mat` contains the jacobian ∂rdx / ∂rx.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2GetFullJacobian!`](@ref)
"""
function fmi2GetFullJacobian(comp::FMU2Component,
                             rdx::AbstractArray{fmi2ValueReference},
                             rx::AbstractArray{fmi2ValueReference};
                             steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)
    mat = zeros(fmi2Real, length(rdx), length(rx))
    fmi2GetFullJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""


    fmi2GetFullJacobian!(jac::AbstractMatrix{fmi2Real},
                              comp::FMU2Component,
                              rdx::AbstractArray{fmi2ValueReference},
                              rx::AbstractArray{fmi2ValueReference};
                              steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian!`.

# Arguments
- `jac::AbstractMatrix{fmi2Real}`: Stores the the jacobian ∂rdx / ∂rx.
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: Step size to be used for numerical differentiation.
If nothing, a default value will be chosen automatically.

# Returns
- `nothing`
"""
function fmi2GetFullJacobian!(jac::AbstractMatrix{fmi2Real},
                              comp::FMU2Component,
                              rdx::AbstractArray{fmi2ValueReference},
                              rx::AbstractArray{fmi2ValueReference};
                              steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)
    @assert size(jac) == (length(rdx),length(rx)) "fmi2GetFullJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."

    @warn "`fmi2GetFullJacobian!` is for benchmarking only, please use `fmi2GetJacobian`."

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end

    if fmi2ProvidesDirectionalDerivative(comp.fmu)
        for i in 1:length(rx)
            jac[:,i] = fmi2GetDirectionalDerivative(comp, rdx, [rx[i]])
        end
    else
        jac = fmi2SampleJacobian(comp, rdx, rx)
    end

    return nothing
end

"""
    fmi2Get!(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, dstArray::AbstractArray)

Stores the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference and returns an array that indicates the Status.

# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vrs::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `dstArray::AbstractArray`: Stores the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference to the input variable vr (vr = vrs[i]). `dstArray` has the same length as `vrs`.

# Returns
- `retcodes::Array{fmi2Status}`: Returns an array of length length(vrs) with Type `fmi2Status`. Type `fmi2Status` is an enumeration and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions

"""
function fmi2Get!(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, dstArray::AbstractArray)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(dstArray) "fmi2Get!(...): Number of value references doesn't match number of `dstArray` elements."

    retcodes = zeros(fmi2Status, length(vrs)) # fmi2StatusOK

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi2ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if mv.Real != nothing
            #@assert isa(dstArray[i], Real) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetReal(comp, vr)
        elseif mv.Integer != nothing
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetInteger(comp, vr)
        elseif mv.Boolean != nothing
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetBoolean(comp, vr)
        elseif mv.String != nothing
            #@assert isa(dstArray[i], String) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetString(comp, vr)
        elseif mv.Enumeration != nothing
            @warn "fmi2Get!(...): Currently not implemented for fmi2Enum."
        else
            @assert isa(dstArray[i], Real) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end

    return retcodes
end

"""
    fmi2Get(comp::FMU2Component, vrs::fmi2ValueReferenceFormat)


Returns the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference in an array.

# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vrs::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `dstArray::Array{Any,1}(undef, length(vrs))`: Stores the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference to the input variable vr (vr = vrs[i]). `dstArray` is a 1-Dimensional Array that has the same length as `vrs`.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
"""
function fmi2Get(comp::FMU2Component, vrs::fmi2ValueReferenceFormat)
    vrs = prepareValueReference(comp, vrs)
    dstArray = Array{Any,1}(undef, length(vrs))
    fmi2Get!(comp, vrs, dstArray)

    if length(dstArray) == 1
        return dstArray[1]
    else
        return dstArray
    end
end


"""
    fmi2Set(comp::FMU2Component,
                vrs::fmi2ValueReferenceFormat,
                srcArray::AbstractArray;
                filter=nothing)

Stores the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference and returns an array that indicates the Status.

# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vrs::fmi2ValueReferenceFormat`: wildcards for how a user can pass a fmi[X]ValueReference
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`
- `srcArray::AbstractArray`: Stores the specific value of `fmi2ScalarVariable` containing the modelVariables with the identical fmi2ValueReference to the input variable vr (vr = vrs[i]). `srcArray` has the same length as `vrs`.

# Keywords
- `filter=nothing`: It is applied to each ModelVariable to determine if it should be updated.

# Returns
- `retcodes::Array{fmi2Status}`: Returns an array of length length(vrs) with Type `fmi2Status`. Type `fmi2Status` is an enumeration and indicates the success of the function call.
More detailed:
  - `fmi2OK`: all well
  - `fmi2Warning`: things are not quite right, but the computation can continue
  - `fmi2Discard`: if the slave computed successfully only a subinterval of the communication step
  - `fmi2Error`: the communication step could not be carried out at all
  - `fmi2Fatal`: if an error occurred which corrupted the FMU irreparably
  - `fmi2Pending`: this status is returned if the slave executes the function asynchronously

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.23]: 2.1.6 Initialization, Termination, and Resetting an FMU
- FMISpec2.0.2[p.18]: 2.1.3 Status Returned by Functions
"""
function fmi2Set(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, srcArray::AbstractArray; filter=nothing)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(srcArray) "fmi2Set(...): Number of value references doesn't match number of `srcArray` elements."

    retcodes = zeros(fmi2Status, length(vrs)) # fmi2StatusOK

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi2ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if filter === nothing || filter(mv)

            if mv.Real != nothing
                @assert isa(srcArray[i], Real) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(srcArray[i]))`."
                retcodes[i] = fmi2SetReal(comp, vr, srcArray[i])
            elseif mv.Integer != nothing
                @assert isa(srcArray[i], Union{Real, Integer}) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(srcArray[i]))`."
                retcodes[i] = fmi2SetInteger(comp, vr, Integer(srcArray[i]))
            elseif mv.Boolean != nothing
                @assert isa(srcArray[i], Union{Real, Bool}) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(srcArray[i]))`."
                retcodes[i] = fmi2SetBoolean(comp, vr, Bool(srcArray[i]))
            elseif mv.String != nothing
                @assert isa(srcArray[i], String) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(srcArray[i]))`."
                retcodes[i] = fmi2SetString(comp, vr, srcArray[i])
            elseif mv.Enumeration != nothing
                @assert isa(srcArray[i], Union{Real, Integer}) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Enumeration` (`Integer`), is `$(typeof(srcArray[i]))`."
                retcodes[i] = fmi2SetInteger(comp, vr, Integer(srcArray[i]))
            else
                @assert false "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
            end

        end
    end

    return retcodes
end

function fmi2Set(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, src; filter=nothing)
    fmi2Set(comp, vrs, [src]; filter=filter)
end

"""
    fmi2GetStartValue(md::fmi2ModelDescription, vrs::fmi2ValueReferenceFormat = md.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.
- `vrs::fmi2ValueReferenceFormat = md.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `starts::Array{fmi2ValueReferenceFormat}`: start/default value for a given value reference

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetStartValue(md::fmi2ModelDescription, vrs::fmi2ValueReferenceFormat = md.valueReferences)

    vrs = prepareValueReference(md, vrs)

    starts = []

    for vr in vrs
        mvs = fmi2ModelVariablesForValueReference(md, vr)

        if length(mvs) == 0
            @warn "fmi2GetStartValue(...): Found no model variable with value reference $(vr)."
        end

        push!(starts, fmi2GetStartValue(mvs[1]) )
    end

    if length(vrs) == 1
        return starts[1]
    else
        return starts
    end
end

"""
    fmi2GetStartValue(fmu::FMU2, vrs::fmi2ValueReferenceFormat = fmu.modelDescription.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `vrs::fmi2ValueReferenceFormat = fmu.modelDescription.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `starts::fmi2ValueReferenceFormat`: start/default value for a given value reference

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetStartValue(fmu::FMU2, vrs::fmi2ValueReferenceFormat = fmu.modelDescription.valueReferences)
    fmi2GetStartValue(fmu.modelDescription, vrs)
end

"""
    fmi2GetStartValue(c::FMU2Component, vrs::fmi2ValueReferenceFormat = c.fmu.modelDescription.valueReferences)

Returns the start/default value for a given value reference.

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vrs::fmi2ValueReferenceFormat = c.fmu.modelDescription.valueReferences`: wildcards for how a user can pass a fmi[X]ValueReference (default = md.valueReferences)
More detailed: `fmi2ValueReferenceFormat = Union{Nothing, String, Array{String,1}, fmi2ValueReference, Array{fmi2ValueReference,1}, Int64, Array{Int64,1}, Symbol}`

# Returns
- `starts::fmi2ValueReferenceFormat`: start/default value for a given value reference

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetStartValue(c::FMU2Component, vrs::fmi2ValueReferenceFormat = c.fmu.modelDescription.valueReferences)

    vrs = prepareValueReference(c, vrs)

    starts = []

    for vr in vrs
        mvs = fmi2ModelVariablesForValueReference(c.fmu.modelDescription, vr)

        if length(mvs) == 0
            @warn "fmi2GetStartValue(...): Found no model variable with value reference $(vr)."
        end

        if mvs[1].Real != nothing
            push!(starts, mvs[1].Real.start)
        elseif mvs[1].Integer != nothing
            push!(starts, mvs[1].Integer.start)
        elseif mvs[1].Boolean != nothing
            push!(starts, mvs[1].Boolean.start)
        elseif mvs[1].String != nothing
            push!(starts, mvs[1].String.start)
        elseif mvs[1].Enumeration != nothing
            push!(starts, mvs[1].Enumeration.start)
        else
            @assert false "fmi2GetStartValue(...): Value reference $(vr) has no data type."
        end
    end

    if length(vrs) == 1
        return starts[1]
    else
        return starts
    end
end

"""
    fmi2GetStartValue(mv::fmi2ScalarVariable)

Returns the start/default value for a given value reference.

# Arguments
- `mv::fmi2ScalarVariable`: The “ModelVariables” element consists of an ordered set of “ScalarVariable” elements. A “ScalarVariable” represents a variable of primitive type, like a real or integer variable.

# Returns
- `mv._Real.start`: start/default value for a given ScalarVariable. In this case representing a variable of primitive type Real.
- `mv._Integer.start`: start/default value for a given ScalarVariable. In this case representing a variable of primitive type Integer.
- `mv._Boolean.start`: start/default value for a given ScalarVariable. In this case representing a variable of primitive type Boolean.
- `mv._String.start`: start/default value for a given ScalarVariable. In this case representing a variable of primitive type String.
- `mv._Enumeration.start`: start/default value for a given ScalarVariable. In this case representing a variable of primitive type Enumeration.


# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetStartValue(mv::fmi2ScalarVariable)
    if mv.Real != nothing
        return mv.Real.start
    elseif mv.Integer != nothing
        return mv.Integer.start
    elseif mv.Boolean != nothing
        return mv.Boolean.start
    elseif mv.String != nothing
        return mv.String.start
    elseif mv.Enumeration != nothing
        return mv.Enumeration.start
    else
        @assert false "fmi2GetStartValue(...): Variable $(mv) has no data type."
    end
end

"""
    fmi2GetUnit(mv::fmi2ScalarVariable)

Returns the `unit` entry (a string) of the corresponding model variable.

# Arguments
- `fmi2GetStartValue(mv::fmi2ScalarVariable)`: The “ModelVariables” element consists of an ordered set of “ScalarVariable” elements. A “ScalarVariable” represents a variable of primitive type, like a real or integer variable.

# Returns
- `mv.Real.unit`: Returns the `unit` entry of the corresponding ScalarVariable representing a variable of the primitive type Real. Otherwise `nothing` is returned.
# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetUnit(mv::fmi2ScalarVariable)
    if !isnothing(mv.Real)
        return mv.Real.unit
    else
        return nothing
    end
end

"""
    fmi2GetUnit(st::fmi2SimpleType)

Returns the `unit` entry (a string) of the corresponding simple type `st` if it has the
attribute `Real` and `nothing` otherwise.

# Source
- FMISpec2.0.3 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.3: 2.2.3 Definition of Types (TypeDefinitions)
"""
function fmi2GetUnit(st::fmi2SimpleType)
    if hasproperty(st, :Real)
        return st.Real.unit
    else
        return nothing
    end
end

# ToDo: update Docu!
"""
    fmi2GetUnit(md::fmi2ModelDescription, mv::fmi2ScalarVariable)

Returns the `unit` of the corresponding model variable `mv` as a `fmi2Unit` if it is
defined in `md.unitDefinitions`.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.
- `mv::fmi2ScalarVariable`: The “ModelVariables” element consists of an ordered set of “ScalarVariable” elements. A “ScalarVariable” represents a variable of primitive type, like a real or integer variable.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetUnit(md::fmi2ModelDescription, mv::Union{fmi2ScalarVariable, fmi2SimpleType}) # ToDo: Multiple Dispatch!
    unit_str = fmi2GetUnit(mv)
    if !isnothing(unit_str)
        ui = findfirst(unit -> unit.name == unit_str, md.unitDefinitions)
        if !isnothing(ui)
            return md.unitDefinitions[ui]
        end
    end
    return nothing
end

"""
    fmi2GetDeclaredType(md::fmi2ModelDescription, mv::fmi2ScalarVariable)

Returns the `fmi2SimpleType` of the corresponding model variable `mv` as defined in
`md.typeDefinitions`.
If `mv` does not have a declared type, return `nothing`.
If `mv` has a declared type, but it is not found, issue a warning and return `nothing`.

# Arguments
- `md::fmi2ModelDescription`: Struct which provides the static information of ModelVariables.
- `mv::fmi2ScalarVariable`: The “ModelVariables” element consists of an ordered set of “ScalarVariable” elements. A “ScalarVariable” represents a variable of primitive type, like a real or integer variable.

# Source
- FMISpec2.0.3 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.3: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetDeclaredType(md::fmi2ModelDescription, mv::fmi2ScalarVariable)
    if isdefined(mv.attribute, :declaredType)
        dt = mv.attribute.declaredType
        if !isnothing(dt)
            for simple_type in md.typeDefinitions
                if dt == simple_type.name
                    return simple_type
                end
            end
            @warn "`fmi2GetDeclaredType`: Could not find a type definition with name \"$(dt)\" in the `typeDefinitions` of $(md)."
        end
    end
    return nothing
end

# TODO with the new `fmi2SimpleType` definition this function is superfluous...remove?
"""
    fmi2GetSimpleTypeAttributeStruct(st::fmi2SimpleType)

Returns the attribute structure for the simple type `st`.
Depending on definition, this is either `st.Real`, `st.Integer`, `st.String`,
`st.Boolean` or `st.Enumeration`.

# Arguments
- `st::fmi2SimpleType`: Struct which provides the information on custom SimpleTypes.

# Source
- FMISpec2.0.3 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.3[p.40]: 2.2.3 Definition of Types (TypeDefinitions)
"""
function fmi2GetSimpleTypeAttributeStruct(st::fmi2SimpleType)
    return typeof(st.attribute)
end

"""
    fmi2GetInitial(mv::fmi2ScalarVariable)

Returns the `inital` entry of the corresponding model variable.

# Arguments
- `fmi2GetStartValue(mv::fmi2ScalarVariable)`: The “ModelVariables” element consists of an ordered set of “ScalarVariable” elements. A “ScalarVariable” represents a variable of primitive type, like a real or integer variable.

# Returns
- `mv.Real.unit`: Returns the `inital` entry of the corresponding ScalarVariable representing a variable of the primitive type Real. Otherwise `nothing` is returned.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)
"""
function fmi2GetInitial(mv::fmi2ScalarVariable)
    return mv.initial
end

"""
    fmi2SampleJacobian(c::FMU2Component,
                            vUnknown_ref::Array{fmi2ValueReference},
                            vKnown_ref::Array{fmi2ValueReference},
                            steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)

This function samples the directional derivative by manipulating corresponding values (central differences).

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
- `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
- `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::Array{fmi2ValueReference}`:  Argument `vUnKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` is the Array of the vector values of Real input variables of function h that changes its value in the actual Mode.
- `vKnown_ref::Array{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` is the Array of the vector values of Real input variables of function h that changes its value in the actual Mode.
- `steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5`: Predefined step size vector `steps`, where all entries have the value 1e-5.

# Returns
- `dvUnknown::Arrya{fmi2Real}`: stores the samples of the directional derivative

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)
"""
function fmi2SampleJacobian(c::FMU2Component,
                                       vUnknown_ref::Array{fmi2ValueReference},
                                       vKnown_ref::Array{fmi2ValueReference},
                                       steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)

    dvUnknown = zeros(fmi2Real, length(vUnknown_ref), length(vKnown_ref))

    fmi2SampleJacobian!(c, vUnknown_ref, vKnown_ref, dvUnknown, steps)

    dvUnknown
end

"""
    fmi2SampleJacobian!(c::FMU2Component,
                            vUnknown_ref::Array{fmi2ValueReference},
                            vKnown_ref::Array{fmi2ValueReference},
                            dvUnknown::AbstractArray,
                            steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)

This function samples the directional derivative by manipulating corresponding values (central differences) and saves in-place.

# Arguments
- `str::fmi2Struct`:  Representative for an FMU in the FMI 2.0.2 Standard.
More detailed: `fmi2Struct = Union{FMU2, FMU2Component}`
 - `str::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.
 - `str::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::Array{fmi2ValueReference}`:  Argument `vUnKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` is the Array of the vector values of Real input variables of function h that changes its value in the actual Mode.
- `vKnown_ref::Array{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` is the Array of the vector values of Real input variables of function h that changes its value in the actual Mode.
- `dvUnknown::AbstractArray`: stores the samples of the directional derivative
- `steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5`: current time stepsize

# Returns
- `nothing `

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2[p.16]: 2.1.2 Platform Dependent Definitions (fmi2TypesPlatform.h)

"""
function fmi2SampleJacobian!(c::FMU2Component,
                                          vUnknown_ref::Array{fmi2ValueReference},
                                          vKnown_ref::Array{fmi2ValueReference},
                                          dvUnknown::AbstractArray,
                                          steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        fmi2SetReal(c, vKnown, origValue - steps[i]*0.5)
        negValues = fmi2GetReal(c, vUnknown_ref)

        fmi2SetReal(c, vKnown, origValue + steps[i]*0.5)
        posValues = fmi2GetReal(c, vUnknown_ref)

        fmi2SetReal(c, vKnown, origValue)

        if length(vUnknown_ref) == 1
            dvUnknown[1,i] = (posValues-negValues) ./ steps[i]
        else
            dvUnknown[:,i] = (posValues-negValues) ./ steps[i]
        end
    end

    nothing
end
