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

@test fmi2GetGUID(myFMU) == "{2e178ad3-5e9b-48ec-a7b2-baa5669efc0c}"
@test fmi2GetGenerationTool(myFMU) == "Dymola Version 2022x (64-bit), 2021-10-08"
@test fmi2GetGenerationDateAndTime(myFMU) == "2022-05-19T06:54:12Z"
@test fmi2GetNumberOfEventIndicators(myFMU) == 24
@test fmi2CanGetSetState(myFMU) == true
@test fmi2CanSerializeFMUstate(myFMU) == true
@test fmi2ProvidesDirectionalDerivative(myFMU) == true
@test fmi2DependenciesSupported(myFMU.modelDescription) == true
@test fmi2DerivativeDependenciesSupported(myFMU.modelDescription) == true

@test fmi2GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test fmi2GetDefaultStopTime(myFMU.modelDescription) ≈ 1.0
@test fmi2GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test fmi2GetDefaultStepSize(myFMU.modelDescription) === nothing

# comfort getters (dictionaries)

@test length(fmi2GetValueReferencesAndNames(myFMU.modelDescription)) == 42
@test length(fmi2GetValueReferencesAndNames(myFMU)) == 42

@test length(fmi2GetInputNames(myFMU.modelDescription)) == 0
@test length(fmi2GetInputNames(myFMU)) == 0

@test length(fmi2GetOutputNames(myFMU.modelDescription)) == 0
@test length(fmi2GetOutputNames(myFMU)) == 0

@test length(fmi2GetParameterNames(myFMU.modelDescription)) == 0
@test length(fmi2GetParameterNames(myFMU)) == 0

@test length(fmi2GetStateNames(myFMU.modelDescription)) == 2
@test length(fmi2GetStateNames(myFMU)) == 2
@test fmi2GetStateNames(myFMU; mode=:first) == ["mass.s", "mass.v"]
@test fmi2GetStateNames(myFMU; mode=:flat) == ["mass.s", "mass.v", "mass.v_relfric"]
@test fmi2GetStateNames(myFMU; mode=:group) == [["mass.s"], ["mass.v", "mass.v_relfric"]]

@test length(fmi2GetDerivativeNames(myFMU.modelDescription)) == 2
@test length(fmi2GetDerivativeNames(myFMU)) == 2
@test fmi2GetDerivativeNames(myFMU; mode=:first) == ["der(mass.s)", "mass.a_relfric"]
@test fmi2GetDerivativeNames(myFMU; mode=:flat) == ["der(mass.s)", "mass.a_relfric", "mass.a", "der(mass.v)"]
@test fmi2GetDerivativeNames(myFMU; mode=:group) == [["der(mass.s)"], ["mass.a_relfric", "mass.a", "der(mass.v)"]]

@test length(fmi2GetNamesAndDescriptions(myFMU.modelDescription)) == 50
@test length(fmi2GetNamesAndDescriptions(myFMU)) == 50

@test length(fmi2GetNamesAndUnits(myFMU.modelDescription)) == 50
dict = fmi2GetNamesAndUnits(myFMU)
@test length(dict) == 50
@test dict["der(mass.s)"] == "m/s"
@test dict["mass.F_prop"] == "N.s/m"
@test dict["mass.fexp"] == "s/m"
@test dict["der(mass.v)"] == "m/s2"

@test length(fmi2GetNamesAndInitials(myFMU.modelDescription)) == 50
dict = fmi2GetNamesAndInitials(myFMU)
@test length(dict) == 50
@test dict["mass.startForward"] == 0
@test dict["mass.startBackward"] == 0
@test dict["mass.locked"] == 1

# ToDo: Improve test, use another FMU
@test length(fmi2GetInputNamesAndStarts(myFMU.modelDescription)) == 0
dict = fmi2GetInputNamesAndStarts(myFMU)
@test length(dict) == 0

fmi2Unload(myFMU)