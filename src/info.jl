#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""
     info(fmu)

Print information about the FMU.

# Arguments 
- `fmu::FMU`: The FMU you are interessted in.

# Further reading
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
"""
function info(fmu::FMU2)
    println("#################### Begin information for FMU ####################")

    println("\tModel name:\t\t\t$(getModelName(fmu))")
    println("\tFMI-Version:\t\t\t$(fmi2GetVersion(fmu))")
    println("\tGUID:\t\t\t\t$(fmi2GetGUID(fmu))")
    println("\tGeneration tool:\t\t$(getGenerationTool(fmu))")
    println("\tGeneration time:\t\t$(generationDateAndTime(fmu))")
    print("\tVar. naming conv.:\t\t")
    if fmi2GetVariableNamingConvention(fmu) == fmi2VariableNamingConventionFlat
        println("flat")
    elseif fmi2GetVariableNamingConvention(fmu) == fmi2VariableNamingConventionStructured
        println("structured")
    else
        println("[unknown]")
    end
    println("\tEvent indicators:\t\t$(fmi2GetNumberOfEventIndicators(fmu))")

    println("\tInputs:\t\t\t\t$(length(fmu.modelDescription.inputValueReferences))")
    for vr in fmu.modelDescription.inputValueReferences
        println("\t\t$(vr) $(fmi2ValueReferenceToString(fmu, vr))")
    end

    println("\tOutputs:\t\t\t$(length(fmu.modelDescription.outputValueReferences))")
    for vr in fmu.modelDescription.outputValueReferences
        println("\t\t$(vr) $(fmi2ValueReferenceToString(fmu, vr))")
    end

    println("\tStates:\t\t\t\t$(length(fmu.modelDescription.stateValueReferences))")
    for vr in fmu.modelDescription.stateValueReferences
        println("\t\t$(vr) $(fmi2ValueReferenceToString(fmu, vr))")
    end

    println("\tSupports Co-Simulation:\t\t$(fmi2IsCoSimulation(fmu))")
    if fmi2IsCoSimulation(fmu)
        println("\t\tModel identifier:\t$(fmu.modelDescription.coSimulation.modelIdentifier)")
        println("\t\tGet/Set State:\t\t$(fmu.modelDescription.coSimulation.canGetAndSetFMUstate)")
        println("\t\tSerialize State:\t$(fmu.modelDescription.coSimulation.canSerializeFMUstate)")
        println("\t\tDir. Derivatives:\t$(fmu.modelDescription.coSimulation.providesDirectionalDerivative)")

        println("\t\tVar. com. steps:\t$(fmu.modelDescription.coSimulation.canHandleVariableCommunicationStepSize)")
        println("\t\tInput interpol.:\t$(fmu.modelDescription.coSimulation.canInterpolateInputs)")
        println("\t\tMax order out. der.:\t$(fmu.modelDescription.coSimulation.maxOutputDerivativeOrder)")
    end

    println("\tSupports Model-Exchange:\t$(fmi2IsModelExchange(fmu))")
    if fmi2IsModelExchange(fmu)
        println("\t\tModel identifier:\t$(fmu.modelDescription.modelExchange.modelIdentifier)")
        println("\t\tGet/Set State:\t\t$(fmu.modelDescription.modelExchange.canGetAndSetFMUstate)")
        println("\t\tSerialize State:\t$(fmu.modelDescription.modelExchange.canSerializeFMUstate)")
        println("\t\tDir. Derivatives:\t$(fmu.modelDescription.modelExchange.providesDirectionalDerivative)")
    end

    println("##################### End information for FMU #####################")
end
function info(fmu::FMU3)
    println("#################### Begin information for FMU ####################")

    println("\tModel name:\t\t\t$(fmi3GetModelName(fmu))")
    println("\tFMI-Version:\t\t\t$(fmi3GetVersion(fmu))")
    println("\tInstantiation Token:\t\t\t\t$(fmi3GetInstantiationToken(fmu))")
    println("\tGeneration tool:\t\t$(fmi3GetGenerationTool(fmu))")
    println("\tGeneration time:\t\t$(fmi3GetGenerationDateAndTime(fmu))")
    print("\tVar. naming conv.:\t\t")
    if fmi3GetVariableNamingConvention(fmu) == fmi3VariableNamingConventionFlat
        println("flat")
    elseif fmi3GetVariableNamingConvention(fmu) == fmi3VariableNamingConventionStructured
        println("structured")
    else 
        println("[unknown]")
    end
    println("\tEvent indicators:\t\t$(fmi3GetNumberOfEventIndicators(fmu))")

    println("\tInputs:\t\t\t\t$(length(fmu.modelDescription.inputValueReferences))")
    for vr in fmu.modelDescription.inputValueReferences
        println("\t\t$(vr) $(fmi3ValueReferenceToString(fmu, vr))")
    end

    println("\tOutputs:\t\t\t$(length(fmu.modelDescription.outputValueReferences))")
    for vr in fmu.modelDescription.outputValueReferences
        println("\t\t$(vr) $(fmi3ValueReferenceToString(fmu, vr))")
    end

    println("\tStates:\t\t\t\t$(length(fmu.modelDescription.stateValueReferences))")
    for vr in fmu.modelDescription.stateValueReferences
        println("\t\t$(vr) $(fmi3ValueReferenceToString(fmu, vr))")
    end

    println("\tSupports Co-Simulation:\t\t$(fmi3IsCoSimulation(fmu))")
    if fmi3IsCoSimulation(fmu)
        println("\t\tModel identifier:\t$(fmu.modelDescription.coSimulation.modelIdentifier)")
        println("\t\tGet/Set State:\t\t$(fmu.modelDescription.coSimulation.canGetAndSetFMUstate)")
        println("\t\tSerialize State:\t$(fmu.modelDescription.coSimulation.canSerializeFMUstate)")
        println("\t\tDir. Derivatives:\t$(fmu.modelDescription.coSimulation.providesDirectionalDerivatives)")
        println("\t\tAdj. Derivatives:\t$(fmu.modelDescription.coSimulation.providesAdjointDerivatives)")
        println("\t\tEvent Mode:\t$(fmu.modelDescription.coSimulation.hasEventMode)")

        println("\t\tVar. com. steps:\t$(fmu.modelDescription.coSimulation.canHandleVariableCommunicationStepSize)")
        println("\t\tInput interpol.:\t$(fmu.modelDescription.coSimulation.canInterpolateInputs)")
        println("\t\tMax order out. der.:\t$(fmu.modelDescription.coSimulation.maxOutputDerivativeOrder)")
    end

    println("\tSupports Model-Exchange:\t$(fmi3IsModelExchange(fmu))")
    if fmi3IsModelExchange(fmu)
        println("\t\tModel identifier:\t$(fmu.modelDescription.modelExchange.modelIdentifier)")
        println("\t\tGet/Set State:\t\t$(fmu.modelDescription.modelExchange.canGetAndSetFMUstate)")
        println("\t\tSerialize State:\t$(fmu.modelDescription.modelExchange.canSerializeFMUstate)")
        println("\t\tDir. Derivatives:\t$(fmu.modelDescription.modelExchange.providesDirectionalDerivatives)")
        println("\t\tAdj. Derivatives:\t$(fmu.modelDescription.modelExchange.providesAdjointDerivatives)")
    end

    println("\tSupports Scheduled-Execution:\t$(fmi3IsScheduledExecution(fmu))")
    if fmi3IsScheduledExecution(fmu)
        println("\t\tModel identifier:\t$(fmu.modelDescription.scheduledExecution.modelIdentifier)")
        println("\t\tGet/Set State:\t\t$(fmu.modelDescription.scheduledExecution.canGetAndSetFMUstate)")
        println("\t\tSerialize State:\t$(fmu.modelDescription.scheduledExecution.canSerializeFMUstate)")
        println("\t\tNeeds Execution Tool:\t$(fmu.modelDescription.scheduledExecution.needsExecutionTool)")
        println("\t\tInstantiated Once Per Process:\t$(fmu.modelDescription.scheduledExecution.canBeInstantiatedOnlyOncePerProcess)")
        println("\t\tPer Element Dependencies:\t$(fmu.modelDescription.scheduledExecution.providesPerElementDependencies)")
        
        println("\t\tDir. Derivatives:\t$(fmu.modelDescription.scheduledExecution.providesDirectionalDerivatives)")
        println("\t\tAdj. Derivatives:\t$(fmu.modelDescription.scheduledExecution.providesAdjointDerivatives)")
    end

    println("##################### End information for FMU #####################")
end
export info
