#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMICore: fmi2VariableNamingConventionStructured

myFMU = fmi3Load("SpringFrictionPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

@test fmi3GetVersion(myFMU) == "2.0"
@test fmi3GetTypesPlatform(myFMU) == "default"

@test fmi3GetModelName(myFMU) == "SpringFrictionPendulum1D"
@test fmi3GetVariableNamingConvention(myFMU) == fmi2VariableNamingConventionStructured
@test fmi3IsCoSimulation(myFMU) == true
@test fmi3IsModelExchange(myFMU) == true
# TODO scheduledExecution
@test fmi3GetInstantiationToken(myFMU) == "{df491d8d-0598-4495-913e-5b025e54d7f2}" # TODO update
@test fmi3GetGenerationTool(myFMU) == "Dymola Version 2022x (64-bit), 2021-10-08"
@test fmi3GetGenerationDateAndTime(myFMU) == "2022-03-03T15:09:18Z"
@test fmi3GetNumberOfEventIndicators(myFMU) == 24
@test fmi3CanGetSetState(myFMU) == true
@test fmi3CanSerializeFMUstate(myFMU) == true
@test fmi3ProvidesDirectionalDerivative(myFMU) == true

@test fmi3GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test fmi3GetDefaultStopTime(myFMU.modelDescription) ≈ 1.0
@test fmi3GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test fmi3GetDefaultStepSize(myFMU.modelDescription) === nothing

fmi3Unload(myFMU)
