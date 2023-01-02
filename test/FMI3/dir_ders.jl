#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

myFMU = fmi3Load("BouncingBall", "ModelicaReferenceFMUs", "0.0.20")

inst = fmi3InstantiateModelExchange!(myFMU; loggingOn=true)
@test inst != 0

@test fmi3EnterInitializationMode(inst) == 0
@test fmi3ExitInitializationMode(inst) == 0

numStates = length(myFMU.modelDescription.stateValueReferences)
targetValues = [[0.0, 0.0], [1.0, 0.0]]
dir_ders_buffer = zeros(fmi3Float64, numStates)
sample_ders_buffer = zeros(fmi3Float64, numStates, 1)
for i in 1:numStates

    if fmi3ProvidesDirectionalDerivatives(myFMU)
        # multi derivatives calls
        sample_ders = fmi3SampleDirectionalDerivative(inst, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]])
        fmi3SampleDirectionalDerivative!(inst, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]], sample_ders_buffer)

        @test sum(abs.(sample_ders[:,1] - targetValues[i])) < 1e-3
        @test sum(abs.(sample_ders_buffer[:,1] - targetValues[i])) < 1e-3

        dir_ders = fmi3GetDirectionalDerivative(inst, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]])
        fmi3GetDirectionalDerivative!(inst, myFMU.modelDescription.derivativeValueReferences, [myFMU.modelDescription.stateValueReferences[i]], dir_ders_buffer)
    
        @test sum(abs.(dir_ders - targetValues[i])) < 1e-3
        @test sum(abs.(dir_ders_buffer - targetValues[i])) < 1e-3

        # single derivative call 
        dir_der = fmi3GetDirectionalDerivative(inst, myFMU.modelDescription.derivativeValueReferences[1], myFMU.modelDescription.stateValueReferences[1])
        @test dir_der == targetValues[1][1]
    else 
        @warn "Skipping directional derivative testing, this FMU from $(ENV["EXPORTINGTOOL"]) doesn't support directional derivatives."
    end
end

# Bug in the FMU
jac = fmi3GetJacobian(inst, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
@test jac ≈ hcat(targetValues...)

jac = fmi3SampleDirectionalDerivative(inst, myFMU.modelDescription.derivativeValueReferences, myFMU.modelDescription.stateValueReferences)
@test jac ≈ hcat(targetValues...)

fmi3Unload(myFMU)
