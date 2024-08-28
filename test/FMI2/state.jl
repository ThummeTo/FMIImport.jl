#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

using FMIImport.FMICore: fmi2FMUstate

myFMU = loadFMU("SpringPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

comp = fmi2Instantiate!(myFMU; loggingOn = true)
@test comp != 0

@test fmi2EnterInitializationMode(comp) == 0
@test fmi2ExitInitializationMode(comp) == 0

@test fmi2SetupExperiment(comp, fmi2Real(0.0)) == 0

###########################
# Testing state functions #
###########################

if canGetSetFMUState(myFMU) && canSerializeFMUState(myFMU)
    @test fmi2GetReal(comp, "mass.s") == 0.5
    FMUstate = fmi2GetFMUstate(comp)
    @test typeof(FMUstate) == fmi2FMUstate
    len = fmi2SerializedFMUstateSize(comp, FMUstate)
    @test len > 0
    serial = fmi2SerializeFMUstate(comp, FMUstate)
    @test length(serial) == len
    @test typeof(serial) == Array{Char,1}

    fmi2SetReal(comp, "mass.s", fmi2Real(10.0))
    FMUstate = fmi2GetFMUstate(comp)
    @test fmi2GetReal(comp, "mass.s") == 10.0

    FMUstate2 = fmi2DeSerializeFMUstate(comp, serial)
    @test typeof(FMUstate2) == fmi2FMUstate
    fmi2SetFMUstate(comp, FMUstate2)
    @test fmi2GetReal(comp, "mass.s") == 0.5
    fmi2SetFMUstate(comp, FMUstate)
    @test fmi2GetReal(comp, "mass.s") == 10.0
    fmi2FreeFMUstate(comp, FMUstate)
    fmi2FreeFMUstate(comp, FMUstate2)
else
    @info "The FMU provided from the tool `$(ENV["EXPORTINGTOOL"])` does not support state get, set, serialization and deserialization. Skipping related tests."
end

############
# Clean up #
############

@test fmi2Terminate(comp) == 0
unloadFMU(myFMU)
