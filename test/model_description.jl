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

fmi2Unload(myFMU)
