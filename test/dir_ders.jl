#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

pathToFMU = "https://github.com/ThummeTo/FMI.jl/raw/main/model/" * ENV["EXPORTINGTOOL"] * "/SpringPendulum1D.fmu"

myFMU = fmi2Load(pathToFMU)
comp = fmi2Instantiate!(myFMU; loggingOn=false)
@test comp != 0

@test fmi2SetupExperiment(comp) == 0
@test fmi2EnterInitializationMode(comp) == 0
@test fmi2ExitInitializationMode(comp) == 0

targetValues = [[0.0, -10.0], [1.0, 0.0]]
dir_ders_buffer = zeros(fmi2Real, 2)
sample_ders_buffer = zeros(fmi2Real, 2, 1)
for i in 1:fmi2GetNumberOfStates(myFMU)

    if fmi2ProvidesDirectionalDerivative(myFMU)
        # multi derivatives calls
        sample_ders = fmi2SampleDirectionalDerivative(comp, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]])
        fmi2SampleDirectionalDerivative!(comp, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]], sample_ders_buffer)

        @test sum(abs.(sample_ders[:,1] - targetValues[i])) < 1e-3
        @test sum(abs.(sample_ders_buffer[:,1] - targetValues[i])) < 1e-3

        dir_ders = fmi2GetDirectionalDerivative(comp, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]])
        fmi2GetDirectionalDerivative!(comp, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]], dir_ders_buffer)
    
        @test sum(abs.(dir_ders - targetValues[i])) < 1e-3
        @test sum(abs.(dir_ders_buffer - targetValues[i])) < 1e-3

        # single derivative call 
        dir_der = fmi2GetDirectionalDerivative(comp, myFMU.modelDescription.derivativeValueReferences[1], myFMU.modelDescription.stateValueReferences[1])
        @test dir_der == targetValues[1][1]
    else 
        @warn "Skipping directional derivative testing, FMU from $(ENV["EXPORTINGTOOL"]) doesn't support directional derivatives."
    end
end

if ENV["EXPORTINGTOOL"] != "OpenModelica/v1.17.0"
    jac = fmi2GetJacobian(comp, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
    @test jac ≈ hcat(targetValues...)

    jac = fmi2SampleDirectionalDerivative(comp, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
    @test jac ≈ hcat(targetValues...)
end

fmi2Unload(myFMU)
