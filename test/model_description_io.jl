#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMICore: fmi2VariableNamingConventionStructured

myFMU = fmi2Load("IO", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
myFMU.executionConfig.assertOnWarning = true

@test length(fmi2GetNamesToValueReference(myFMU.modelDescription)) == 11
@test length(fmi2GetNamesToValueReference(myFMU)) == 11

@test length(fmi2GetValueRefenceToName(myFMU.modelDescription)) == 11
@test length(fmi2GetValueRefenceToName(myFMU)) == 11

@test length(fmi2GetInputNames(myFMU.modelDescription)) == 3
@test length(fmi2GetInputNames(myFMU)) == 3

@test length(fmi2GetOutputNames(myFMU.modelDescription)) == 3
@test length(fmi2GetOutputNames(myFMU)) == 3

@test length(fmi2GetParameterNames(myFMU.modelDescription)) == 0
@test length(fmi2GetParameterNames(myFMU)) == 0

@test length(fmi2GetStateNames(myFMU.modelDescription)) == 0
@test length(fmi2GetStateNames(myFMU)) == 0

@test length(fmi2GetDerivateNames(myFMU.modelDescription)) == 0
@test length(fmi2GetDerivateNames(myFMU)) == 0

@test length(fmi2GetVariableDescriptions(myFMU.modelDescription)) == 11
@test length(fmi2GetVariableDescriptions(myFMU)) == 11

@test length(fmi2GetVariableUnits(myFMU.modelDescription)) == 11
@test length(fmi2GetVariableUnits(myFMU)) == 11

@test length(fmi2GetStartValues(myFMU.modelDescription)) == 11
@test length(fmi2GetStartValues(myFMU)) == 11


fmi2Unload(myFMU)