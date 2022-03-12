#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_fmu_to_md.jl` (FMU to model description)?
# - wrappers to call the model description functions from a FMU-instance [exported]

function fmi3GetModelName(fmu::FMU3)
    fmi3GetModelName(fmu.modelDescription)
end

function fmi3GetInstantiationToken(fmu::FMU3)
    fmi3GetInstantiationToken(fmu.modelDescription)
end

function fmi3GetGenerationTool(fmu::FMU3)
    fmi3GetGenerationTool(fmu.modelDescription)
end

function fmi3GetGenerationDateAndTime(fmu::FMU3)
    fmi3GetGenerationDateAndTime(fmu.modelDescription)
end

function fmi3GetVariableNamingConvention(fmu::FMU3)
    fmi3GetVariableNamingConvention(fmu.modelDescription)
end

function fmi3CanGetSetState(fmu::FMU3)
    fmi3CanGetSetState(fmu.modelDescription)
end

function fmi3CanSerializeFMUstate(fmu::FMU3)
    fmi3CanSerializeFMUstate(fmu.modelDescription)
end

function fmi3ProvidesDirectionalDerivatives(fmu::FMU3)
    fmi3ProvidesDirectionalDerivative(fmu.modelDescription)
end

function fmi3ProvidesAdjointDerivatives(fmu::FMU3)
    fmi3ProvidesAdjointDerivative(fmu.modelDescription)
end

function fmi3IsCoSimulation(fmu::FMU3)
    fmi3IsCoSimulation(fmu.modelDescription)
end

function fmi3IsModelExchange(fmu::FMU3)
    fmi3IsModelExchange(fmu.modelDescription)
end

function fmi3IsScheduledExecution(fmu::FMU3)
    fmi3IsScheduledExecution(fmu.modelDescription)
end
