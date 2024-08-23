#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# Prints value references, but shortens if the number exceeds `max`.
function printValueReferences(fmu, vrs; max = 10)
    len = length(vrs)
    if len <= max
        for vr in vrs
            println("\t\t$(vr) $(valueReferenceToString(fmu, vr))")
        end
    else
        half = floor(Integer, max) - 1
        for vr in vrs[1:half]
            println("\t\t$(vr) $(valueReferenceToString(fmu, vr))")
        end
        println(".")
        println(".")
        println(".")
        for vr in vrs[len-half:end]
            println("\t\t$(vr) $(valueReferenceToString(fmu, vr))")
        end
    end
    nothing
end

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
    println("\tGUID:\t\t\t\t$(getGUID(fmu))")
    println("\tGeneration tool:\t\t$(getGenerationTool(fmu))")
    println("\tGeneration time:\t\t$(getGenerationDateAndTime(fmu))")
    print("\tVar. naming conv.:\t\t")
    if getVariableNamingConvention(fmu) == fmi2VariableNamingConventionFlat
        println("flat")
    elseif getVariableNamingConvention(fmu) == fmi2VariableNamingConventionStructured
        println("structured")
    else
        println("[unknown]")
    end
    println("\tEvent indicators:\t\t$(getNumberOfEventIndicators(fmu))")

    println("\tInputs:\t\t\t\t$(length(fmu.modelDescription.inputValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.inputValueReferences)

    println("\tOutputs:\t\t\t$(length(fmu.modelDescription.outputValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.outputValueReferences)

    println("\tStates:\t\t\t\t$(length(fmu.modelDescription.stateValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.stateValueReferences)

    println("\tParameters:\t\t\t\t$(length(fmu.modelDescription.parameterValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.parameterValueReferences)

    println("\tSupports Co-Simulation:\t\t$(isCoSimulation(fmu))")
    if isCoSimulation(fmu)
        println(
            "\t\tModel identifier:\t$(fmu.modelDescription.coSimulation.modelIdentifier)",
        )
        println(
            "\t\tGet/Set State:\t\t$(fmu.modelDescription.coSimulation.canGetAndSetFMUstate)",
        )
        println(
            "\t\tSerialize State:\t$(fmu.modelDescription.coSimulation.canSerializeFMUstate)",
        )
        println(
            "\t\tDir. Derivatives:\t$(fmu.modelDescription.coSimulation.providesDirectionalDerivative)",
        )

        println(
            "\t\tVar. com. steps:\t$(fmu.modelDescription.coSimulation.canHandleVariableCommunicationStepSize)",
        )
        println(
            "\t\tInput interpol.:\t$(fmu.modelDescription.coSimulation.canInterpolateInputs)",
        )
        println(
            "\t\tMax order out. der.:\t$(fmu.modelDescription.coSimulation.maxOutputDerivativeOrder)",
        )
    end

    println("\tSupports Model-Exchange:\t$(isModelExchange(fmu))")
    if isModelExchange(fmu)
        println(
            "\t\tModel identifier:\t$(fmu.modelDescription.modelExchange.modelIdentifier)",
        )
        println(
            "\t\tGet/Set State:\t\t$(fmu.modelDescription.modelExchange.canGetAndSetFMUstate)",
        )
        println(
            "\t\tSerialize State:\t$(fmu.modelDescription.modelExchange.canSerializeFMUstate)",
        )
        println(
            "\t\tDir. Derivatives:\t$(fmu.modelDescription.modelExchange.providesDirectionalDerivative)",
        )
    end

    println("##################### End information for FMU #####################")
end
function info(fmu::FMU3)
    println("#################### Begin information for FMU ####################")

    println("\tModel name:\t\t\t$(getModelName(fmu))")
    println("\tFMI-Version:\t\t\t$(fmi3GetVersion(fmu))")
    println("\tInstantiation Token:\t\t\t\t$(getInstantiationToken(fmu))")
    println("\tGeneration tool:\t\t$(getGenerationTool(fmu))")
    println("\tGeneration time:\t\t$(getGenerationDateAndTime(fmu))")
    print("\tVar. naming conv.:\t\t")
    if getVariableNamingConvention(fmu) == fmi3VariableNamingConventionFlat
        println("flat")
    elseif getVariableNamingConvention(fmu) == fmi3VariableNamingConventionStructured
        println("structured")
    else
        println("[unknown]")
    end
    println("\tEvent indicators:\t\t$(getNumberOfEventIndicators(fmu))")

    println("\tInputs:\t\t\t\t$(length(fmu.modelDescription.inputValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.inputValueReferences)

    println("\tOutputs:\t\t\t$(length(fmu.modelDescription.outputValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.outputValueReferences)

    println("\tStates:\t\t\t\t$(length(fmu.modelDescription.stateValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.stateValueReferences)

    println("\tParameters:\t\t\t\t$(length(fmu.modelDescription.parameterValueReferences))")
    printValueReferences(fmu, fmu.modelDescription.parameterValueReferences)

    println("\tSupports Co-Simulation:\t\t$(isCoSimulation(fmu))")
    if isCoSimulation(fmu)
        println(
            "\t\tModel identifier:\t$(fmu.modelDescription.coSimulation.modelIdentifier)",
        )
        println(
            "\t\tGet/Set State:\t\t$(fmu.modelDescription.coSimulation.canGetAndSetFMUState)",
        )
        println(
            "\t\tSerialize State:\t$(fmu.modelDescription.coSimulation.canSerializeFMUState)",
        )
        println(
            "\t\tDir. Derivatives:\t$(fmu.modelDescription.coSimulation.providesDirectionalDerivatives)",
        )
        println(
            "\t\tAdj. Derivatives:\t$(fmu.modelDescription.coSimulation.providesAdjointDerivatives)",
        )
        println("\t\tEvent Mode:\t$(fmu.modelDescription.coSimulation.hasEventMode)")

        println(
            "\t\tVar. com. steps:\t$(fmu.modelDescription.coSimulation.canHandleVariableCommunicationStepSize)",
        )
        println(
            "\t\tInput interpol.:\t$(fmu.modelDescription.coSimulation.canInterpolateInputs)",
        )
        println(
            "\t\tMax order out. der.:\t$(fmu.modelDescription.coSimulation.maxOutputDerivativeOrder)",
        )
    end

    println("\tSupports Model-Exchange:\t$(isModelExchange(fmu))")
    if isModelExchange(fmu)
        println(
            "\t\tModel identifier:\t$(fmu.modelDescription.modelExchange.modelIdentifier)",
        )
        println(
            "\t\tGet/Set State:\t\t$(fmu.modelDescription.modelExchange.canGetAndSetFMUState)",
        )
        println(
            "\t\tSerialize State:\t$(fmu.modelDescription.modelExchange.canSerializeFMUState)",
        )
        println(
            "\t\tDir. Derivatives:\t$(fmu.modelDescription.modelExchange.providesDirectionalDerivatives)",
        )
        println(
            "\t\tAdj. Derivatives:\t$(fmu.modelDescription.modelExchange.providesAdjointDerivatives)",
        )
    end

    println("\tSupports Scheduled-Execution:\t$(isScheduledExecution(fmu))")
    if isScheduledExecution(fmu)
        println(
            "\t\tModel identifier:\t$(fmu.modelDescription.scheduledExecution.modelIdentifier)",
        )
        println(
            "\t\tGet/Set State:\t\t$(fmu.modelDescription.scheduledExecution.canGetAndSetFMUState)",
        )
        println(
            "\t\tSerialize State:\t$(fmu.modelDescription.scheduledExecution.canSerializeFMUState)",
        )
        println(
            "\t\tNeeds Execution Tool:\t$(fmu.modelDescription.scheduledExecution.needsExecutionTool)",
        )
        println(
            "\t\tInstantiated Once Per Process:\t$(fmu.modelDescription.scheduledExecution.canBeInstantiatedOnlyOncePerProcess)",
        )
        println(
            "\t\tPer Element Dependencies:\t$(fmu.modelDescription.scheduledExecution.providesPerElementDependencies)",
        )

        println(
            "\t\tDir. Derivatives:\t$(fmu.modelDescription.scheduledExecution.providesDirectionalDerivatives)",
        )
        println(
            "\t\tAdj. Derivatives:\t$(fmu.modelDescription.scheduledExecution.providesAdjointDerivatives)",
        )
    end

    println("##################### End information for FMU #####################")
end
export info
