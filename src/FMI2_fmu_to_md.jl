#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_fmu_to_md.jl` (FMU to model description)?
# - wrappers to call the model description functions from a FMU-instance [exported]

"""
Returns the number of states of the FMU.
"""
function fmi2GetNumberOfStates(fmu::FMU2)
    fmi2GetNumberOfStates(fmu.modelDescription)
end

function fmi2GetModelName(fmu::FMU2)
    fmi2GetModelName(fmu.modelDescription)
end

function fmi2GetGUID(fmu::FMU2)
    fmi2GetGUID(fmu.modelDescription)
end

function fmi2GetGenerationTool(fmu::FMU2)
    fmi2GetGenerationTool(fmu.modelDescription)
end

function fmi2GetGenerationDateAndTime(fmu::FMU2)
    fmi2GetGenerationDateAndTime(fmu.modelDescription)
end

function fmi2GetVariableNamingConvention(fmu::FMU2)
    fmi2GetVariableNamingConvention(fmu.modelDescription)
end

function fmi2GetNumberOfEventIndicators(fmu::FMU2)
    fmi2GetNumberOfEventIndicators(fmu.modelDescription)
end

function fmi2CanGetSetState(fmu::FMU2)
    fmi2CanGetSetState(fmu.modelDescription)
end

function fmi2CanSerializeFMUstate(fmu::FMU2)
    fmi2CanSerializeFMUstate(fmu.modelDescription)
end

function fmi2ProvidesDirectionalDerivative(fmu::FMU2)
    fmi2ProvidesDirectionalDerivative(fmu.modelDescription)
end

function fmi2IsCoSimulation(fmu::FMU2)
    fmi2IsCoSimulation(fmu.modelDescription)
end

function fmi2IsModelExchange(fmu::FMU2)
    fmi2IsModelExchange(fmu.modelDescription)
end