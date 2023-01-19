#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport.FMICore: fmi3VariableNamingConventionFlat

myFMU = fmi3Load("BouncingBall", "ModelicaReferenceFMUs", "0.0.20")

@test fmi3GetVersion(myFMU) == "3.0"

@test fmi3GetModelName(myFMU) == "BouncingBall"
@test fmi3GetVariableNamingConvention(myFMU) == fmi3VariableNamingConventionFlat
@test fmi3IsCoSimulation(myFMU) == true
@test fmi3IsModelExchange(myFMU) == true
# TODO scheduledExecution
@test fmi3GetInstantiationToken(myFMU) == "{1AE5E10D-9521-4DE3-80B9-D0EAAA7D5AF1}" # TODO update
@test fmi3GetGenerationTool(myFMU) == "Reference FMUs (v0.0.20)"
@test fmi3GetGenerationDateAndTime(myFMU) == "[Unknown generation date and time]"
@test fmi3GetNumberOfEventIndicators(myFMU) == 1
@test fmi3CanGetSetState(myFMU) == true
@test fmi3CanSerializeFMUState(myFMU) == true
@test fmi3ProvidesDirectionalDerivatives(myFMU) == false
@test fmi3ProvidesAdjointDerivatives(myFMU) == false

@test fmi3GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test fmi3GetDefaultStopTime(myFMU.modelDescription) ≈ 3.0
#@test fmi3GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test fmi3GetDefaultStepSize(myFMU.modelDescription) === 0.01

fmi3Unload(myFMU)
