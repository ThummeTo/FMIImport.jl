#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMICore: fmi2VariableNamingConventionStructured

myFMU = fmi2Load("SpringFrictionPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
myFMU.executionConfig.assertOnWarning = true

@test fmi2GetVersion(myFMU) == "2.0"
@test fmi2GetTypesPlatform(myFMU) == "default"

@test fmi2GetModelName(myFMU) == "SpringFrictionPendulum1D"
@test fmi2GetVariableNamingConvention(myFMU) == fmi2VariableNamingConventionStructured
@test fmi2IsCoSimulation(myFMU) == true
@test fmi2IsModelExchange(myFMU) == true

@test fmi2GetGUID(myFMU) == "{df491d8d-0598-4495-913e-5b025e54d7f2}"
@test fmi2GetGenerationTool(myFMU) == "Dymola Version 2022x (64-bit), 2021-10-08"
@test fmi2GetGenerationDateAndTime(myFMU) == "2022-03-03T15:09:18Z"
@test fmi2GetNumberOfEventIndicators(myFMU) == 24
@test fmi2CanGetSetState(myFMU) == true
@test fmi2CanSerializeFMUstate(myFMU) == true
@test fmi2ProvidesDirectionalDerivative(myFMU) == true

@test fmi2GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test fmi2GetDefaultStopTime(myFMU.modelDescription) ≈ 1.0
@test fmi2GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test fmi2GetDefaultStepSize(myFMU.modelDescription) === nothing

@test length(fmi2GetNamesToValueReference(myFMU.modelDescription)) == 50
@test length(fmi2GetNamesToValueReference(myFMU)) == 50

@test length(fmi2GetValueRefenceToName(myFMU.modelDescription)) == 42
@test length(fmi2GetValueRefenceToName(myFMU)) == 42

@test length(fmi2GetInputNames(myFMU.modelDescription)) == 0
@test length(fmi2GetInputNames(myFMU)) == 0

@test length(fmi2GetOutputNames(myFMU.modelDescription)) == 0
@test length(fmi2GetOutputNames(myFMU)) == 0

@test length(fmi2GetParameterNames(myFMU.modelDescription)) == 0
@test length(fmi2GetParameterNames(myFMU)) == 0

@test length(fmi2GetStateNames(myFMU.modelDescription)) == 3
@test length(fmi2GetStateNames(myFMU)) == 3
@test fmi2GetStateNames(myFMU) == ["mass.s", "mass.v", "mass.v_relfric"]

@test length(fmi2GetDerivateNames(myFMU.modelDescription)) == 2
@test length(fmi2GetDerivateNames(myFMU)) == 2
@test fmi2GetDerivateNames(myFMU) == ["der(mass.s)", "der(mass.v)"]

@test length(fmi2GetVariableDescriptions(myFMU.modelDescription)) == 50
@test length(fmi2GetVariableDescriptions(myFMU)) == 50


@test length(fmi2GetVariableUnits(myFMU.modelDescription)) == 50
@test length(fmi2GetVariableUnits(myFMU)) == 50
@test fmi2GetVariableUnits(myFMU)["der(mass.s)"] == "m/s"
@test fmi2GetVariableUnits(myFMU)["mass.F_prop"] == "N.s/m"
@test fmi2GetVariableUnits(myFMU)["mass.fexp"] == "s/m"
@test fmi2GetVariableUnits(myFMU)["der(mass.v)"] == "m/s2"

@test length(fmi2GetStartValues(myFMU.modelDescription)) == 50
@test length(fmi2GetStartValues(myFMU)) == 50
@test fmi2GetStartValues(myFMU)["mass.startForward"] == 0
@test fmi2GetStartValues(myFMU)["mass.startBackward"] == 0
@test fmi2GetStartValues(myFMU)["mass.locked"] == 1

fmi2Unload(myFMU)