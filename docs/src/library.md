# [Library Functions](@id library)

```@index
```


## FMI 2

### FMI Common Concepts for Model Exchange and Co-Simulation
In both cases, FMI defines an input/output block of a dynamic model where the distribution of the block, the
platform dependent header file, several access functions, as well as the schema files are identical

#### Reading the model description (FMI2_md.jl / FMI2_c.jl)
This section documents functions to inquire information about the model description of an FMU

##### load/parse the FMI model description
```@docs
fmi2LoadModelDescription
```
##### get value functions
```@docs
fmi2GetDefaultStartTime
fmi2GetDefaultStopTime
fmi2GetDefaultTolerance
fmi2GetDefaultStepSize
fmi2GetModelName
fmi2GetGUID
fmi2GetGenerationTool
fmi2GetGenerationDateAndTime
fmi2GetVariableNamingConvention
fmi2GetNumberOfEventIndicators
fmi2GetNumberOfStates
fmi2IsCoSimulation
fmi2IsModelExchange
```

##### information functions

```@docs
fmi2DependenciesSupported
fmi2DerivativeDependenciesSupported
fmi2GetModelIdentifier
fmi2CanGetSetState
fmi2CanSerializeFMUstate
fmi2ProvidesDirectionalDerivative
fmi2GetValueReferencesAndNames
fmi2GetNames
fmi2GetModelVariableIndices
fmi2GetInputValueReferencesAndNames
fmi2GetInputNames
fmi2GetOutputValueReferencesAndNames
fmi2GetOutputNames
fmi2GetParameterValueReferencesAndNames
fmi2GetParameterNames
fmi2GetStateValueReferencesAndNames
fmi2GetStateNames
fmi2GetDerivateValueReferencesAndNames
fmi2GetDerivativeNames
fmi2GetNamesAndDescriptions
fmi2GetNamesAndUnits
fmi2GetNamesAndInitials
fmi2GetInputNamesAndStarts
fmi2GetVersion
fmi2GetTypesPlatform
fmi2Info
```

###  Creation, Destruction and Logging of FMU Instances
This section documents functions that deal with instantiation, destruction and logging of FMUs

```@docs
fmi2Instantiate!
fmi2FreeInstance!
fmi2SetDebugLogging

```

### Initialization, Termination, and Resetting an FMU
This section documents functions that deal with initialization, termination, resetting of an FMU.

```@docs
fmiSimulate
fmiSimulateCS
fmiSimulateME
fmi2SetupExperiment
fmi2EnterInitializationMode
fmi2ExitInitializationMode
fmi2Terminate
fmi2Reset
```
### Getting and Setting Variable Values
FMI2 and FMI3 contain different functions for this paragraph, therefore reference to the specific function in the FMIImport documentation.
- [FMI2]()
- [FMI3]() TODo Link
All variable values of an FMU are identified with a variable handle called “value reference”. The handle is
defined in the modelDescription.xml file (as attribute “valueReference” in element
“ScalarVariable”). Element “valueReference” might not be unique for all variables. If two or more
variables of the same base data type (such as fmi2Real) have the same valueReference, then they
have identical values but other parts of the variable definition might be different [(for example, min/max
attributes)].

```@docs
fmiGet
fmiGet!
fmiSet
fmi2GetReal
fmi2GetReal!
fmi2GetInteger
fmi2GetInteger!
fmi2GetBoolean
fmi2GetBoolean!
fmi2GetString
fmi2GetString!
fmi2SetReal
fmi2SetInteger
fmi2SetBoolean
fmi2SetString
```


### Getting and Setting the Complete FMU State
FMI2 and FMI3 contain different functions for this paragraph, therefore reference to the specific function in the FMIImport documentation.
- [FMI2]()
- [FMI3]() TODo Link

TODO Ref FMIImport -> unterschiedliche Funktionen in FMI2 und FMI3 [FMIImport](https://thummeto.github.io/FMIImport.jl/dev/library/#library)
The FMU has an internal state consisting of all values that are needed to continue a simulation. This internal state consists especially of the values of the continuous-time states, iteration variables, parameter values, input values, delay buffers, file identifiers, and FMU internal status information. With the functionsof this section, the internal FMU state can be copied and the pointer to this copy is returned to the environment. The FMU state copy can be set as actual FMU state, in order to continue the simulationfrom it.

```@docs
fmiGetFMUstat
fmiSetFMUstate
fmiFreeFMUstate!
fmiSerializedFMUstateSize!
fmiSerializeFMUstate!
fmiDeSerializeFMUstate!
```

### Getting Partial Dervatives
FMI2 and FMI3 contain different functions for this paragraph, therefore reference to the specific function in the FMIImport documentation.
- [FMI2]()
- [FMI3]() TODo Link
It is optionally possible to provide evaluation of partial derivatives for an FMU. For Model Exchange, this
means computing the partial derivatives at a particular time instant. For Co-Simulation, this means to
compute the partial derivatives at a particular communication point. One function is provided to compute
directional derivatives. This function can be used to construct the desired partial derivative matrices.

```@docs
fmi2GetDirectionalDerivative!
fmi2SetRealInputDerivatives
fmi2GetRealOutputDerivatives!
fmi2SampleDirectionalDerivative
fmiSampleDirectionalDerivative!
```

## FMI for Model Exchange
FMI2 and FMI3 contain different functions for this paragraph, therefore reference to the specific function in the FMIImport documentation.
- [FMI2]()
- [FMI3]() TODo Link

This chapter contains the interface description to access the equations of a dynamic system from a C
program.

###  Providing Independent Variables and Re-initialization of Caching
Depending on the situation, different variables need to be computed. In order to be efficient, it is important that the interface requires only the computation of variables that are needed in the present context. The state derivatives shall be reused from the previous call. This feature is called “caching of variables” in the sequel. Caching requires that the model evaluation can detect when the input arguments, like time or states, have changed.

```@docs
fmi2SetTime
fmi2SetContinuousStates
fmi2SetReal
fmi2SetInteger
fmi2SetBoolean
fmi2SetString
```

### Evaluation of Model Equations
This section contains the core functions to evaluate the model equations

```@docs
fmi2EnterEventMode
fmi2NewDiscreteStates
fmi2EnterContinuousTimeMode
fmi2CompletedIntegratorStep
fmi2GetDerivatives!
fmi2GetEventIndicators!
fmi2GetContinuousStates!
fmi2GetNominalsOfContinuousStates!
```

## FMI for CO-Simulation
This chapter defines the Functional Mock-up Interface (FMI) for the coupling of two or more simulation
models in a co-simulation environment (FMI for Co-Simulation). Co-simulation is a rather general
approach to the simulation of coupled technical systems and coupled physical phenomena in
engineering with focus on instationary (time-dependent) problems.


### Transfer of Input / Output Values and Parameters
In order to enable the slave to interpolate the continuous real inputs between communication steps, the
derivatives of the inputs with respect to time can be provided. Also, higher derivatives can be set to allow
higher order interpolation.

```@docs
fmi2SetRealInputDerivatives
fmi2GetRealOutputDerivatives
```

### Computation
The computation of time steps is controlled by the following function.

```@docs
fmi2DoStep
fmi2CancelStep
```

### Retrieving Status Information from the Slave
Status information is retrieved from the slave by the following functions:

```@docs
fmi2GetStatus!
fmi2GetRealStatus!
fmi2GetIntegerStatus!
fmi2GetBooleanStatus!
fmi2GetStringStatus!
```

## Self-developed functions
These new functions, that are useful, but not part of the FMI-spec (example: `fmi2Load`, `fmi2SampleDirectionalDerivative`)
### Conversion functions

```@docs
fmi2StringToValueReference
fmi2ModelVariablesForValueReference
fmi2StringToValueReference
fmi2ValueReferenceToString
fmi2GetSolutionState
fmi2GetSolutionValue
fmi2GetSolutionTime
```

### external/additional functions

```@docs
fmi2Unzip
fmi2Load
fmi2Instantiate!
fmi2Reload
fmi2Unload
fmi2SampleDirectionalDerivative
fmi2SampleDirectionalDerivative!
fmi2GetJacobian
fmi2GetJacobian!
fmi2GetFullJacobian
fmi2GetFullJacobian!
fmi2Get!
fmi2Get
fmi2Set
fmi2GetStartValue
fmi2GetUnit
fmi2GetInitial
fmi2SampleDirectionalDerivative
fmi2SampleDirectionalDerivative!
```

### Visualize simulation results

```@docs
fmiPlot
```
