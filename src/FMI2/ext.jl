#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using Libdl

const CB_LIB_PATH = @path joinpath(dirname(@__FILE__), "callbackFunctions", "binaries")

"""
    createFMU2

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
"""
function createFMU2(
    fmuPath,
    fmuZipPath;
    type::Union{Symbol,fmi2Type,Nothing} = nothing,
    logLevel::Union{FMULogLevel,Symbol} = FMULogLevelWarn,
)
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

    # set paths for fmu handling
    fmu.path = fmuPath
    fmu.zipPath = fmuZipPath

    # set paths for modelExchangeScripting and binary
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
        if isCoSimulation(fmu.modelDescription) && isModelExchange(fmu.modelDescription)
            fmu.type = fmi2TypeCoSimulation
            logInfo(
                fmu,
                "createFMU2(...): FMU supports both CS and ME, using CS as default if nothing specified.",
            )

        elseif isCoSimulation(fmu.modelDescription)
            fmu.type = fmi2TypeCoSimulation

        elseif isModelExchange(fmu.modelDescription)
            fmu.type = fmi2TypeModelExchange

        else
            @assert false "FMU neither supports ME nor CS."
        end
    end

    fmuName = getModelIdentifier(fmu.modelDescription; type = fmu.type) # tmpName[length(tmpName)]

    directoryBinary = ""
    pathToBinary = ""

    directories = []

    fmuExt = ""
    osStr = ""

    juliaArch = Sys.WORD_SIZE
    @assert (juliaArch == 64 || juliaArch == 32) "createFMU2(...): Unknown Julia Architecture with $(juliaArch)-bit, must be 64- or 32-bit."

    if Sys.iswindows()
        if juliaArch == 64
            directories =
                [joinpath("binaries", "win64"), joinpath("binaries", "x86_64-windows")]
        else
            directories =
                [joinpath("binaries", "win32"), joinpath("binaries", "i686-windows")]
        end
        osStr = "Windows"
        fmuExt = "dll"
    elseif Sys.islinux()
        if juliaArch == 64
            directories =
                [joinpath("binaries", "linux64"), joinpath("binaries", "x86_64-linux")]
        else
            directories = []
        end
        osStr = "Linux"
        fmuExt = "so"
    elseif Sys.isapple()
        if juliaArch == 64
            directories =
                [joinpath("binaries", "darwin64"), joinpath("binaries", "x86_64-darwin")]
        else
            directories = []
        end
        osStr = "Mac"
        fmuExt = "dylib"
    else
        @assert false "createFMU2(...): Unsupported target platform. Supporting Windows, Linux and Mac. Please open an issue if you want to use another OS/architecture."
    end

    @assert (length(directories) > 0) "createFMU2(...): Unsupported architecture. Supporting Julia for Windows (64- and 32-bit), Linux (64-bit) and Mac (64-bit). Please open an issue if you want to use another architecture."
    for directory in directories
        directoryBinary = joinpath(fmu.path, directory)
        if isdir(directoryBinary)
            pathToBinary = joinpath(directoryBinary, "$(fmuName).$(fmuExt)")
            break
        end
    end
    @assert isfile(pathToBinary) "createFMU2(...): Target platform is $(osStr), but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."

    # make URI ressource location
    tmpResourceLocation = string("file:///", fmu.path)
    tmpResourceLocation = joinpath(tmpResourceLocation, "resources")
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") # URIs.escapeuri(tmpResourceLocation)

    logInfo(fmu, "createFMU2(...): FMU resources location is `$(fmu.fmuResourceLocation)`")

    fmu.binaryPath = pathToBinary
    loadPointers(fmu)

    return fmu
end

"""
    loadPointers(fmu::FMU2)
load pointers to `fmu`\`s c functions from shared library handle (provided by `fmu.libHandle`)
"""
function loadPointers(fmu::FMU2)
    lastDirectory = pwd()
    cd(dirname(fmu.binaryPath))

    # set FMU binary handler
    fmu.libHandle = dlopen(fmu.binaryPath) # , RTLD_NOW|RTLD_GLOBAL

    cd(lastDirectory)

    # retrieve functions
    fmu.cInstantiate = dlsym(fmu.libHandle, :fmi2Instantiate)
    fmu.cGetTypesPlatform = dlsym(fmu.libHandle, :fmi2GetTypesPlatform)
    fmu.cGetVersion = dlsym(fmu.libHandle, :fmi2GetVersion)
    fmu.cFreeInstance = dlsym(fmu.libHandle, :fmi2FreeInstance)
    fmu.cSetDebugLogging = dlsym(fmu.libHandle, :fmi2SetDebugLogging)
    fmu.cSetupExperiment = dlsym(fmu.libHandle, :fmi2SetupExperiment)
    fmu.cEnterInitializationMode = dlsym(fmu.libHandle, :fmi2EnterInitializationMode)
    fmu.cExitInitializationMode = dlsym(fmu.libHandle, :fmi2ExitInitializationMode)
    fmu.cTerminate = dlsym(fmu.libHandle, :fmi2Terminate)
    fmu.cReset = dlsym(fmu.libHandle, :fmi2Reset)
    fmu.cGetReal = dlsym(fmu.libHandle, :fmi2GetReal)
    fmu.cSetReal = dlsym(fmu.libHandle, :fmi2SetReal)
    fmu.cGetInteger = dlsym(fmu.libHandle, :fmi2GetInteger)
    fmu.cSetInteger = dlsym(fmu.libHandle, :fmi2SetInteger)
    fmu.cGetBoolean = dlsym(fmu.libHandle, :fmi2GetBoolean)
    fmu.cSetBoolean = dlsym(fmu.libHandle, :fmi2SetBoolean)
    fmu.cGetString = dlsym_opt(fmu, fmu.libHandle, :fmi2GetString)
    fmu.cSetString = dlsym_opt(fmu, fmu.libHandle, :fmi2SetString)

    if canGetSetFMUState(fmu.modelDescription)
        fmu.cGetFMUstate = dlsym_opt(fmu, fmu.libHandle, :fmi2GetFMUstate)
        fmu.cSetFMUstate = dlsym_opt(fmu, fmu.libHandle, :fmi2SetFMUstate)
        fmu.cFreeFMUstate = dlsym_opt(fmu, fmu.libHandle, :fmi2FreeFMUstate)
    end

    if canSerializeFMUState(fmu.modelDescription)
        fmu.cSerializedFMUstateSize =
            dlsym_opt(fmu, fmu.libHandle, :fmi2SerializedFMUstateSize)
        fmu.cSerializeFMUstate = dlsym_opt(fmu, fmu.libHandle, :fmi2SerializeFMUstate)
        fmu.cDeSerializeFMUstate = dlsym_opt(fmu, fmu.libHandle, :fmi2DeSerializeFMUstate)
    end

    if providesDirectionalDerivatives(fmu.modelDescription)
        fmu.cGetDirectionalDerivative =
            dlsym_opt(fmu, fmu.libHandle, :fmi2GetDirectionalDerivative)
    end

    # CS specific function calls
    if isCoSimulation(fmu.modelDescription)
        fmu.cSetRealInputDerivatives = dlsym(fmu.libHandle, :fmi2SetRealInputDerivatives)
        fmu.cGetRealOutputDerivatives = dlsym(fmu.libHandle, :fmi2GetRealOutputDerivatives)
        fmu.cDoStep = dlsym(fmu.libHandle, :fmi2DoStep)
        fmu.cCancelStep = dlsym(fmu.libHandle, :fmi2CancelStep)
        fmu.cGetStatus = dlsym(fmu.libHandle, :fmi2GetStatus)
        fmu.cGetRealStatus = dlsym(fmu.libHandle, :fmi2GetRealStatus)
        fmu.cGetIntegerStatus = dlsym(fmu.libHandle, :fmi2GetIntegerStatus)
        fmu.cGetBooleanStatus = dlsym(fmu.libHandle, :fmi2GetBooleanStatus)
        fmu.cGetStringStatus = dlsym(fmu.libHandle, :fmi2GetStringStatus)
    end

    # ME specific function calls
    if isModelExchange(fmu.modelDescription)
        fmu.cEnterContinuousTimeMode = dlsym(fmu.libHandle, :fmi2EnterContinuousTimeMode)
        fmu.cGetContinuousStates = dlsym(fmu.libHandle, :fmi2GetContinuousStates)
        fmu.cGetDerivatives = dlsym(fmu.libHandle, :fmi2GetDerivatives)
        fmu.cSetTime = dlsym(fmu.libHandle, :fmi2SetTime)
        fmu.cSetContinuousStates = dlsym(fmu.libHandle, :fmi2SetContinuousStates)
        fmu.cCompletedIntegratorStep = dlsym(fmu.libHandle, :fmi2CompletedIntegratorStep)
        fmu.cEnterEventMode = dlsym(fmu.libHandle, :fmi2EnterEventMode)
        fmu.cNewDiscreteStates = dlsym(fmu.libHandle, :fmi2NewDiscreteStates)
        fmu.cGetEventIndicators = dlsym(fmu.libHandle, :fmi2GetEventIndicators)
        fmu.cGetNominalsOfContinuousStates =
            dlsym(fmu.libHandle, :fmi2GetNominalsOfContinuousStates)
    end
end

function unloadPointers(fmu::FMU2)

    # retrieve functions
    fmu.cInstantiate = @cfunction(
        FMICore.unload_fmi2Instantiate,
        fmi2Component,
        (
            fmi2String,
            fmi2Type,
            fmi2String,
            fmi2String,
            Ptr{fmi2CallbackFunctions},
            fmi2Boolean,
            fmi2Boolean,
        )
    )
    fmu.cGetTypesPlatform = @cfunction(FMICore.unload_fmi2GetTypesPlatform, fmi2String, ())
    fmu.cGetVersion = @cfunction(FMICore.unload_fmi2GetVersion, fmi2String, ())
    fmu.cFreeInstance = @cfunction(FMICore.unload_fmi2FreeInstance, Cvoid, (fmi2Component,))
    fmu.cSetDebugLogging = @cfunction(
        FMICore.unload_fmi2SetDebugLogging,
        fmi2Status,
        (fmi2Component, fmi2Boolean, Csize_t, Ptr{fmi2String})
    )
    fmu.cSetupExperiment = @cfunction(
        FMICore.unload_fmi2SetupExperiment,
        fmi2Status,
        (fmi2Component, fmi2Boolean, fmi2Real, fmi2Real, fmi2Boolean, fmi2Real)
    )
    fmu.cEnterInitializationMode =
        @cfunction(FMICore.unload_fmi2EnterInitializationMode, fmi2Status, (fmi2Component,))
    fmu.cExitInitializationMode =
        @cfunction(FMICore.unload_fmi2ExitInitializationMode, fmi2Status, (fmi2Component,))
    fmu.cTerminate = @cfunction(FMICore.unload_fmi2Terminate, fmi2Status, (fmi2Component,))
    fmu.cReset = @cfunction(FMICore.unload_fmi2Reset, fmi2Status, (fmi2Component,))
    fmu.cGetReal = @cfunction(
        FMICore.unload_fmi2GetReal,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    fmu.cSetReal = @cfunction(
        FMICore.unload_fmi2SetReal,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Real})
    )
    fmu.cGetInteger = @cfunction(
        FMICore.unload_fmi2GetInteger,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    fmu.cSetInteger = @cfunction(
        FMICore.unload_fmi2SetInteger,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Integer})
    )
    fmu.cGetBoolean = @cfunction(
        FMICore.unload_fmi2GetBoolean,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    fmu.cSetBoolean = @cfunction(
        FMICore.unload_fmi2SetBoolean,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2Boolean})
    )
    fmu.cGetString = @cfunction(
        FMICore.unload_fmi2GetString,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )
    fmu.cSetString = @cfunction(
        FMICore.unload_fmi2SetString,
        fmi2Status,
        (fmi2Component, Ptr{fmi2ValueReference}, Csize_t, Ptr{fmi2String})
    )

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
    if isModelExchange(fmu.modelDescription)
        fmu.cEnterContinuousTimeMode = @cfunction(
            FMICore.unload_fmi2EnterContinuousTimeMode,
            fmi2Status,
            (fmi2Component,)
        )
        fmu.cGetContinuousStates = @cfunction(
            FMICore.unload_fmi2GetContinuousStates,
            fmi2Status,
            (fmi2Component, Ptr{fmi2Real}, Csize_t)
        )
        fmu.cGetDerivatives = @cfunction(
            FMICore.unload_fmi2GetDerivatives,
            fmi2Status,
            (fmi2Component, Ptr{fmi2Real}, Csize_t)
        )
        fmu.cSetTime =
            @cfunction(FMICore.unload_fmi2SetTime, fmi2Status, (fmi2Component, fmi2Real))
        fmu.cSetContinuousStates = @cfunction(
            FMICore.unload_fmi2SetContinuousStates,
            fmi2Status,
            (fmi2Component, Ptr{fmi2Real}, Csize_t)
        )
        fmu.cCompletedIntegratorStep = @cfunction(
            FMICore.unload_fmi2CompletedIntegratorStep,
            fmi2Status,
            (fmi2Component, fmi2Boolean, Ptr{fmi2Boolean}, Ptr{fmi2Boolean})
        )
        fmu.cEnterEventMode =
            @cfunction(FMICore.unload_fmi2EnterEventMode, fmi2Status, (fmi2Component,))
        fmu.cNewDiscreteStates = @cfunction(
            FMICore.unload_fmi2NewDiscreteStates,
            fmi2Status,
            (fmi2Component, Ptr{fmi2EventInfo})
        )
        fmu.cGetEventIndicators = @cfunction(
            FMICore.unload_fmi2GetEventIndicators,
            fmi2Status,
            (fmi2Component, Ptr{fmi2Real}, Csize_t)
        )
        fmu.cGetNominalsOfContinuousStates = @cfunction(
            FMICore.unload_fmi2GetNominalsOfContinuousStates,
            fmi2Status,
            (fmi2Component, Ptr{fmi2Real}, Csize_t)
        )
    end
end
