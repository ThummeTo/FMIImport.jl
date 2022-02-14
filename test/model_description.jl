#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMICore: fmi2VariableNamingConventionStructured

tool = ENV["EXPORTINGTOOL"]
pathToFMU = "https://github.com/ThummeTo/FMI.jl/raw/main/model/" * ENV["EXPORTINGTOOL"] * "/SpringFrictionPendulum1D.fmu"

myFMU = fmi2Load(pathToFMU)

@test fmi2GetVersion(myFMU) == "2.0"
@test fmi2GetTypesPlatform(myFMU) == "default"

@test fmi2GetModelName(myFMU) == "SpringFrictionPendulum1D"
@test fmi2GetVariableNamingConvention(myFMU) == fmi2VariableNamingConventionStructured
@test fmi2IsCoSimulation(myFMU) == true
@test fmi2IsModelExchange(myFMU) == true

if tool == "Dymola/2020x"
    @test fmi2GetGUID(myFMU) == "{b02421b8-652a-4d48-9ffc-c2b223aa1b94}"
    @test fmi2GetGenerationTool(myFMU) == "Dymola Version 2020x (64-bit), 2019-10-10"
    @test fmi2GetGenerationDateAndTime(myFMU) == "2021-11-23T13:36:30Z"
    @test fmi2GetNumberOfEventIndicators(myFMU) == 24
    @test fmi2CanGetSetState(myFMU) == true
    @test fmi2CanSerializeFMUstate(myFMU) == true
    @test fmi2ProvidesDirectionalDerivative(myFMU) == true

    @test fmi2GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
    @test fmi2GetDefaultStopTime(myFMU.modelDescription) ≈ 1.0
    @test fmi2GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
    @test fmi2GetDefaultStepSize(myFMU.modelDescription) === nothing

elseif tool == "OpenModelica/v1.17.0"
    @test fmi2GetGUID(myFMU) == "{8584aa5b-179e-44ed-9ba6-d557ed34541e}"
    @test fmi2GetGenerationTool(myFMU) == "OpenModelica Compiler OMCompiler v1.17.0"
    @test fmi2GetGenerationDateAndTime(myFMU) == "2021-06-21T11:48:49Z"
    @test fmi2GetNumberOfEventIndicators(myFMU) == 14
    @test fmi2CanGetSetState(myFMU) == false
    @test fmi2CanSerializeFMUstate(myFMU) == false
    @test fmi2ProvidesDirectionalDerivative(myFMU) == false

    @test fmi2GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
    @test fmi2GetDefaultStopTime(myFMU.modelDescription) ≈ 1.0
    @test fmi2GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-6
    @test fmi2GetDefaultStepSize(myFMU.modelDescription) === nothing
else
    @warn "Unknown exporting tool `$tool`. Skipping model description tests."
end

fmi2Unload(myFMU)
