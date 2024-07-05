#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport.FMICore: fmi3VariableNamingConventionFlat

myFMU = loadFMU("BouncingBall", "ModelicaReferenceFMUs", "0.0.30", "3.0")

@test fmi3GetVersion(myFMU) == "3.0"

@test getModelName(myFMU) == "BouncingBall"
@test getVariableNamingConvention(myFMU) == fmi3VariableNamingConventionFlat
@test isCoSimulation(myFMU)
@test isModelExchange(myFMU)

# [TODO] scheduledExecution

@test getInstantiationToken(myFMU) == "{1AE5E10D-9521-4DE3-80B9-D0EAAA7D5AF1}" # [TODO] update
@test getGenerationTool(myFMU) == "Reference FMUs (v0.0.30)"
@test getGenerationDateAndTime(myFMU) == "2024-04-18T08:15:35.162720+00:00"
@test getNumberOfEventIndicators(myFMU) == 1
@test canGetSetFMUState(myFMU)
@test canSerializeFMUState(myFMU)
@test !providesDirectionalDerivatives(myFMU)
@test !providesAdjointDerivatives(myFMU)

@test getDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test getDefaultStopTime(myFMU.modelDescription) ≈ 3.0
@test getDefaultTolerance(myFMU.modelDescription) === nothing
@test getDefaultStepSize(myFMU.modelDescription) === 0.01

unloadFMU(myFMU)
