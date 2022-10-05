# STATUS: all tests are working, couple of todos to improve package

module FMIImport

using FMICore

using FMICore: fmi2Component, fmi3Instance

# functions that have (currently) no better place 

# Receives one or an array of values and converts it into an Array{typeof(value)} (if not already).
function prepareValue(value)
    if isa(value, Array) && length(size(value)) == 1
        return value
    else
        return [value]
    end

    @assert false "prepareValue(...): Unknown dimension of structure `$dim`."
end 
export prepareValue, prepareValueReference

# wildcards for how a user can pass a fmi[X]ValueReference
fmi2ValueReferenceFormat = Union{Nothing, String, AbstractArray{String,1}, fmi2ValueReference, AbstractArray{fmi2ValueReference,1}, Int64, AbstractArray{Int64,1}, Symbol} 
fmi3ValueReferenceFormat = Union{Nothing, String, AbstractArray{String,1}, fmi3ValueReference, AbstractArray{fmi3ValueReference,1}, Int64, AbstractArray{Int64,1}} 
export fmi2ValueReferenceFormat, fmi3ValueReferenceFormat

### FMI2 ###

include("FMI2_convert.jl")
include("FMI2_c.jl")
include("FMI2_int.jl")
include("FMI2_ext.jl")
include("FMI2_md.jl")
include("FMI2_fmu_to_md.jl")
#include("FMI2_sens.jl")

# FMI2_c.jl
export fmi2CallbackLogger, fmi2CallbackAllocateMemory, fmi2CallbackFreeMemory, fmi2CallbackStepFinished
export fmi2ComponentState, fmi2ComponentStateModelSetableFMUstate, fmi2ComponentStateModelUnderEvaluation, fmi2ComponentStateModelInitialized # TODO might be imported from FMICOre
export fmi2Instantiate, fmi2FreeInstance!, fmi2GetTypesPlatform, fmi2GetVersion
export fmi2SetDebugLogging, fmi2SetupExperiment, fmi2EnterInitializationMode, fmi2ExitInitializationMode, fmi2Terminate, fmi2Reset
export fmi2GetReal!, fmi2SetReal, fmi2GetInteger!, fmi2SetInteger, fmi2GetBoolean!, fmi2SetBoolean, fmi2GetString!, fmi2SetString
export fmi2GetFMUstate!, fmi2SetFMUstate, fmi2FreeFMUstate!, fmi2SerializedFMUstateSize!, fmi2SerializeFMUstate!, fmi2DeSerializeFMUstate!
export fmi2GetDirectionalDerivative!, fmi2SetRealInputDerivatives, fmi2GetRealOutputDerivatives
export fmi2DoStep, fmi2CancelStep, fmi2GetStatus!, fmi2GetRealStatus!, fmi2GetIntegerStatus!, fmi2GetBooleanStatus!, fmi2GetStringStatus!
export fmi2SetTime, fmi2SetContinuousStates, fmi2EnterEventMode, fmi2NewDiscreteStates!, fmi2EnterContinuousTimeMode, fmi2CompletedIntegratorStep!
export fmi2GetDerivatives!, fmi2GetEventIndicators!, fmi2GetContinuousStates!, fmi2GetNominalsOfContinuousStates!

# FMI2_convert.jl
export fmi2StringToValueReference, fmi2ValueReferenceToString, fmi2ModelVariablesForValueReference
export fmi2GetSolutionState, fmi2GetSolutionTime, fmi2GetSolutionValue

# FMI2_int.jl
# almost everything exported in `FMI2_c.jl`
export fmi2GetReal, fmi2GetInteger, fmi2GetString, fmi2GetBoolean
export fmi2GetFMUstate, fmi2SerializedFMUstateSize, fmi2SerializeFMUstate, fmi2DeSerializeFMUstate
export fmi2GetDirectionalDerivative
export fmi2CompletedIntegratorStep

# FMI2_ext.jl
export fmi2Unzip, fmi2Load, loadBinary, fmi2Reload, fmi2Unload, fmi2Instantiate!
export fmi2SampleDirectionalDerivative!
export fmi2GetJacobian, fmi2GetJacobian!, fmi2GetFullJacobian, fmi2GetFullJacobian!
export fmi2Get, fmi2Get!, fmi2Set 
export fmi2GetUnit, fmi2GetInitial, fmi2GetStartValue, fmi2SampleDirectionalDerivative
export fmi2GetContinuousStates

# FMI2_md.jl
export fmi2LoadModelDescription
export fmi2GetDefaultStartTime, fmi2GetDefaultStopTime, fmi2GetDefaultTolerance, fmi2GetDefaultStepSize
export fmi2GetModelName, fmi2GetGUID, fmi2GetGenerationTool, fmi2GetGenerationDateAndTime, fmi2GetVariableNamingConvention, fmi2GetNumberOfEventIndicators, fmi2GetNumberOfStates, fmi2IsCoSimulation, fmi2IsModelExchange
export fmi2DependenciesSupported, fmi2DerivativeDependenciesSupported, fmi2GetModelIdentifier, fmi2CanGetSetState, fmi2CanSerializeFMUstate, fmi2ProvidesDirectionalDerivative
export fmi2GetInputValueReferencesAndNames, fmi2GetOutputValueReferencesAndNames, fmi2GetParameterValueReferencesAndNames, fmi2GetStateValueReferencesAndNames, fmi2GetDerivativeValueReferencesAndNames
export fmi2GetInputNames, fmi2GetOutputNames, fmi2GetParameterNames, fmi2GetStateNames, fmi2GetDerivativeNames
export fmi2GetValueReferencesAndNames, fmi2GetNamesAndDescriptions, fmi2GetNamesAndUnits, fmi2GetNamesAndInitials, fmi2GetInputNamesAndStarts

# FMI2_fmu_to_md.jl
# everything exported in `FMI2_md.jl`



### FMI3 ###

include("FMI3_c.jl")
include("FMI3_convert.jl")
include("FMI3_int.jl")
include("FMI3_ext.jl")
include("FMI3_md.jl")
include("FMI3_fmu_to_md.jl")

# FMI3_c.jl
export fmi3CallbackLogger, fmi3CallbackIntermediateUpdate, fmi3CallbackClockUpdate
export fmi3InstanceState
export fmi3InstantiateModelExchange, fmi3InstantiateCoSimulation, fmi3InstantiateScheduledExecution, fmi3FreeInstance!
export fmi3GetVersion, fmi3SetDebugLogging
export fmi3EnterInitializationMode, fmi3ExitInitializationMode, fmi3Terminate, fmi3Reset
export fmi3GetFloat32!, fmi3SetFloat32, fmi3GetFloat64!, fmi3SetFloat64
export fmi3GetInt8!, fmi3SetInt8, fmi3GetUInt8!, fmi3SetUInt8, fmi3GetInt16!, fmi3SetInt16, fmi3GetUInt16!, fmi3SetUInt16, fmi3GetInt32!, fmi3SetInt32, fmi3GetUInt32!, fmi3SetUInt32, fmi3GetInt64!, fmi3SetInt64, fmi3GetUInt64!, fmi3SetUInt64
export fmi3GetBoolean!, fmi3SetBoolean, fmi3GetString!, fmi3SetString, fmi3GetBinary!, fmi3SetBinary, fmi3GetClock!, fmi3SetClock
export fmi3GetFMUState!, fmi3SetFMUState, fmi3FreeFMUState!, fmi3SerializedFMUStateSize!, fmi3SerializeFMUState!, fmi3DeSerializeFMUState!
export fmi3SetIntervalDecimal, fmi3SetIntervalFraction, fmi3GetIntervalDecimal!, fmi3GetIntervalFraction!, fmi3GetShiftDecimal!, fmi3GetShiftFraction!
export fmi3ActivateModelPartition
export fmi3GetNumberOfVariableDependencies!, fmi3GetVariableDependencies!
export fmi3GetDirectionalDerivative!, fmi3GetAdjointDerivative!, fmi3GetOutputDerivatives
export fmi3EnterConfigurationMode, fmi3ExitConfigurationMode, fmi3GetNumberOfContinuousStates, fmi3GetNumberOfEventIndicators, fmi3GetContinuousStates!, fmi3GetNominalsOfContinuousStates!
export fmi3EvaluateDiscreteStates, fmi3UpdateDiscreteStates, fmi3EnterContinuousTimeMode, fmi3EnterStepMode
export fmi3SetTime, fmi3SetContinuousStates, fmi3GetContinuousStateDerivatives, fmi3GetContinuousStateDerivatives!, fmi3GetEventIndicators!, fmi3CompletedIntegratorStep!, fmi3EnterEventMode, fmi3DoStep!
# TODO check which fmi3GetContinuousDerivatives to export
# FMI3_convert.jl
export fmi3StringToValueReference, fmi3ValueReferenceToString, fmi3ModelVariablesForValueReference
export fmi2GetSolutionState, fmi2GetSolutionTime, fmi2GetSolutionValue

# FMI3_int.jl
export fmi3GetFloat32, fmi3GetFloat64
export fmi3GetInt8, fmi3GetUInt8, fmi3GetInt16, fmi3GetUInt16, fmi3GetInt32, fmi3GetUInt32, fmi3GetInt64, fmi3GetUInt64
export fmi3GetBoolean, fmi3GetString, fmi3GetBinary, fmi3GetClock
export fmi3GetFMUState, fmi3SerializedFMUStateSize, fmi3SerializeFMUState, fmi3DeSerializeFMUState
export fmi3GetDirectionalDerivative
export fmi3GetStartValue, fmi3SampleDirectionalDerivative, fmi3CompletedIntegratorStep


# FMI3_ext.jl
export fmi3Unzip, fmi3Load, fmi3Unload, fmi3InstantiateModelExchange!, fmi3InstantiateCoSimulation!, fmi3InstantiateScheduledExecution!
export fmi3Get, fmi3Get!, fmi3Set 
export fmi3SampleDirectionalDerivative!
export fmi3GetJacobian, fmi3GetJacobian!, fmi3GetFullJacobian, fmi3GetFullJacobian!

# FMI3_md.jl
export fmi3LoadModelDescription
export fmi3GetModelName, fmi3GetInstantiationToken, fmi3GetGenerationTool, fmi3GetGenerationDateAndTime, fmi3GetVariableNamingConvention
export fmi3IsCoSimulation, fmi3IsModelExchange, fmi3IsScheduledExecution 
export fmi3GetDefaultStartTime, fmi3GetDefaultStopTime, fmi3GetDefaultTolerance, fmi3GetDefaultStepSize
export fmi3GetModelIdentifier, fmi3CanGetSetState, fmi3CanSerializeFMUState, fmi3ProvidesDirectionalDerivatives, fmi3ProvidesAdjointDerivatives

# FMI3_fmu_to_md.jl
export fmi3GetNumberOfEventIndicatorsMD
# TODO check if needed
# everything exported in `FMI2_md.jl`


###

fmi2Struct = Union{FMU2, FMU2Component}
fmi3Struct = Union{FMU3, FMU3Instance}
export fmi2Struct, fmi3Struct

fmi2StructMD = Union{FMU2, FMU2Component, fmi2ModelDescription}
fmi3StructMD = Union{FMU3, FMU3Instance, fmi3ModelDescription}
export fmi2StructMD, fmi3StructMD

end # module
