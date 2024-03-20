#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_ext.jl` (external/additional functions)?
# - TODO

using Libdl

"""

    createFMU3

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
function createFMU3(fmuPath, fmuZipPath; type::Union{Symbol, Nothing}=nothing)
    # Create uninitialized FMU
    fmu = FMU3()

    # set paths for fmu handling
    fmu.path = fmuPath
    fmu.zipPath = fmuZipPath

    # set paths for modelExchangeScripting and binary
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi3LoadModelDescription(pathToModelDescription) # TODO Matrix mit Dimensions
    fmu.modelName = fmu.modelDescription.modelName

    # TODO special use case? not complete, some combinations are missing
    if isCoSimulation(fmu.modelDescription) && isModelExchange(fmu.modelDescription) && type==:CS
        fmu.type = fmi3TypeCoSimulation::fmi3Type
    elseif isCoSimulation(fmu.modelDescription) && isModelExchange(fmu.modelDescription) && type==:ME
        fmu.type = fmi3TypeModelExchange::fmi3Type
    elseif isScheduledExecution(fmu.modelDescription) && type==:SE
        fmu.type = fmi3TypeScheduledExecution::fmi3Type
    elseif isCoSimulation(fmu.modelDescription) && (type===nothing || type==:CS)
        fmu.type = fmi3TypeCoSimulation::fmi3Type
    elseif isModelExchange(fmu.modelDescription) && (type===nothing || type==:ME)
        fmu.type = fmi3TypeModelExchange::fmi3Type
    elseif isScheduledExecution(fmu.modelDescription) && (type === nothing || type ==:SE)
        fmu.type = fmi3TypeScheduledExecution::Fmi3Type
    else
        error(unknownFMUType)
    end

    fmuName = getModelIdentifier(fmu.modelDescription) # tmpName[length(tmpName)] TODO

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
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") 

    @info "fmi3Load(...): FMU resources location is `$(fmu.fmuResourceLocation)`"

    if isCoSimulation(fmu) && isModelExchange(fmu) 
        @info "fmi3Load(...): FMU supports both CS and ME, using CS as default if nothing specified." # TODO ScheduledExecution
    end

    fmu.binaryPath = pathToBinary
    loadPointers(fmu)
   
    return fmu
end

"""
    loadPointers(fmu::FMU3)

load pointers to `fmu`\`s c functions from shared library handle (provided by `fmu.libHandle`)
"""
function loadPointers(fmu::FMU3)
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

    if canGetSetFMUState(fmu)
        fmu.cGetFMUState                           = dlsym_opt(fmu.libHandle, :fmi3GetFMUState)
        fmu.cSetFMUState                           = dlsym_opt(fmu.libHandle, :fmi3SetFMUState)
        fmu.cFreeFMUState                          = dlsym_opt(fmu.libHandle, :fmi3FreeFMUState)
    end

    if canSerializeFMUState(fmu)
        fmu.cSerializedFMUStateSize                = dlsym_opt(fmu.libHandle, :fmi3SerializedFMUStateSize)
        fmu.cSerializeFMUState                     = dlsym_opt(fmu.libHandle, :fmi3SerializeFMUState)
        fmu.cDeSerializeFMUState                   = dlsym_opt(fmu.libHandle, :fmi3DeserializeFMUState)
    end

    if providesDirectionalDerivatives(fmu)
        fmu.cGetDirectionalDerivative              = dlsym_opt(fmu.libHandle, :fmi3GetDirectionalDerivative)
    end

    if providesAdjointDerivatives(fmu)
        fmu.cGetAdjointDerivative              = dlsym_opt(fmu.libHandle, :fmi3GetAdjointDerivative)
    end

    # CS specific function calls
    if isCoSimulation(fmu)
        fmu.cGetOutputDerivatives                  = dlsym(fmu.libHandle, :fmi3GetOutputDerivatives)
        fmu.cEnterStepMode                         = dlsym(fmu.libHandle, :fmi3EnterStepMode)
        fmu.cDoStep                                = dlsym(fmu.libHandle, :fmi3DoStep)
    end

    # ME specific function calls
    if isModelExchange(fmu)
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

    if isScheduledExecution(fmu)
        fmu.cSetIntervalDecimal                    = dlsym(fmu.libHandle, :fmi3SetIntervalDecimal)
        fmu.cSetIntervalFraction                   = dlsym(fmu.libHandle, :fmi3SetIntervalFraction)
        fmu.cGetIntervalDecimal                    = dlsym(fmu.libHandle, :fmi3GetIntervalDecimal)
        fmu.cGetIntervalFraction                   = dlsym(fmu.libHandle, :fmi3GetIntervalFraction)
        fmu.cGetShiftDecimal                       = dlsym(fmu.libHandle, :fmi3GetShiftDecimal)
        fmu.cGetShiftFraction                      = dlsym(fmu.libHandle, :fmi3GetShiftFraction)
        fmu.cActivateModelPartition                = dlsym(fmu.libHandle, :fmi3ActivateModelPartition)
    end
end

function unloadPointers(fmu::FMU3)
    # [TODO]: Write a macro for that.
end