#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

using FMIImport.FMICore: fmi3FMUState

myFMU = fmi3Load("SpringPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=true)
@test inst != 0

@test fmi3EnterInitializationMode(inst) == 0
@test fmi3ExitInitializationMode(inst) == 0

###########################
# Testing state functions #
###########################

if fmi3CanGetSetState(myFMU) && fmi3CanSerializeFMUstate(myFMU)
    @test fmi3GetFloat64(inst, "mass.s") == 0.5
    FMUState = fmi3GetFMUState(inst)
    @test typeof(FMUState) == fmi3FMUState
    len = fmi3SerializedFMUStateSize(inst, FMUState)
    @test len > 0
    serial = fmi3SerializeFMUState(inst, FMUState)
    @test length(serial) == len
    @test typeof(serial) == Array{Char,1}

    fmi3SetFloat64(inst, "mass.s", 10.0)
    FMUState = fmi3GetFMUState(inst)
    @test fmi3GetFloat64(inst, "mass.s") == 10.0

    FMUState2 = fmi3DeSerializeFMUState(inst, serial)
    @test typeof(FMUState2) == fmi3FMUState
    fmi3SetFMUState(inst, FMUState2)
    @test fmi3GetFloat64(inst, "mass.s") == 0.5
    fmi3SetFMUState(inst, FMUState)
    @test fmi3GetFloat64(inst, "mass.s") == 10.0
    fmi3FreeFMUstate!(inst, FMUState)
    fmi3FreeFMUstate!(inst, FMUState2)
else
    @info "The FMU provided from the tool `$(ENV["EXPORTINGTOOL"])` does not support state get, set, serialization and deserialization. Skipping related tests."
end

############
# Clean up #
############

@test fmi3Terminate(inst) == 0
fmi3Unload(myFMU)
