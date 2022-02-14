#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_fmu_to_md.jl` (FMU to model description)?
# - wrappers to call the model description functions from a FMU-instance [exported]

function fmi3GetModelName(fmu::FMU2)
    fmi3GetModelName(fmu.modelDescription)
end

function fmi3GetInstantiationToken(fmu::FMU2)
    fmi3GetInstantiationToken(fmu.modelDescription)
end

function fmi3GetGenerationTool(fmu::FMU2)
    fmi3GetGenerationTool(fmu.modelDescription)
end

function fmi3GetGenerationDateAndTime(fmu::FMU2)
    fmi3GetGenerationDateAndTime(fmu.modelDescription)
end

function fmi3GetVariableNamingConvention(fmu::FMU2)
    fmi3GetVariableNamingConvention(fmu.modelDescription)
end

function fmi3CanGetSetState(fmu::FMU2)
    fmi3CanGetSetState(fmu.modelDescription)
end

function fmi3CanSerializeFMUstate(fmu::FMU2)
    fmi3CanSerializeFMUstate(fmu.modelDescription)
end

function fmi3ProvidesDirectionalDerivative(fmu::FMU2)
    fmi3ProvidesDirectionalDerivative(fmu.modelDescription)
end

function fmi3ProvidesAdjointDerivatives(fmu::FMU2)
    fmi3ProvidesAdjointDerivatives(fmu.modelDescription)
end

function fmi3IsCoSimulation(fmu::FMU2)
    fmi3IsCoSimulation(fmu.modelDescription)
end

function fmi3IsModelExchange(fmu::FMU2)
    fmi3IsModelExchange(fmu.modelDescription)
end

function fmi3IsScheduledExecution(fmu::FMU2)
    fmi3IsScheduledExecution(fmu.modelDescription)
end