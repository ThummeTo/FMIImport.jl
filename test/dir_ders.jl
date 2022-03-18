#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

myFMU = fmi2Load("SpringPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
comp = fmi2Instantiate!(myFMU; loggingOn=false)
@test comp != 0

@test fmi2SetupExperiment(comp) == 0
@test fmi2EnterInitializationMode(comp) == 0
@test fmi2ExitInitializationMode(comp) == 0

numStates = length(myFMU.modelDescription.stateValueReferences)
targetValues = [[0.0, -10.0], [1.0, 0.0]]
dir_ders_buffer = zeros(fmi2Real, numStates)
sample_ders_buffer = zeros(fmi2Real, numStates, 1)
for i in 1:numStates

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

jac = fmi2GetJacobian(comp, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
@test jac ≈ hcat(targetValues...)

jac = fmi2SampleDirectionalDerivative(comp, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
@test jac ≈ hcat(targetValues...)

fmi2Unload(myFMU)
