#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI3_fmu_to_md.jl` (FMU to model description)?
# - wrappers to call the model description functions from a FMU-instance [exported]

"""

   fmi3GetNumberOfStates(fmu::FMU3)

Returns the number of states of the FMU.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- Returns the length of the `fmu.modelDescription.valueReferences::Array{fmi3ValueReference}` corresponding to the number of states of the FMU.
"""
function fmi3GetNumberOfStates(fmu::FMU3)
    fmi3GetNumberOfStates(fmu.modelDescription)
end

"""

    fmi3GetModelName(fmu::FMU3)

Returns the tag 'modelName' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.modelName::String`: Returns the tag 'modelName' from the model description.    
"""
function fmi3GetModelName(fmu::FMU3)
    fmi3GetModelName(fmu.modelDescription)
end

"""

fmi3GetInstantiationToken(fmu::FMU3)

Returns the tag 'instantiationToken' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.instantiationToken::String`: Returns the tag 'instantiationToken' from the model description.
"""
function fmi3GetInstantiationToken(fmu::FMU3)
    fmi3GetInstantiationToken(fmu.modelDescription)
end

"""

    fmi3GetGenerationTool(fmu::FMU3)

Returns the tag 'generationtool' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.generationTool::Union{String, Nothing}`: Returns the tag 'generationtool' from the model description.
"""
function fmi3GetGenerationTool(fmu::FMU3)
    fmi3GetGenerationTool(fmu.modelDescription)
end

"""

    fmi3GetGenerationDateAndTime(fmu::FMU3)

Returns the tag 'generationdateandtime' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.generationDateAndTime::DateTime`: Returns the tag 'generationdateandtime' from the model description.
"""
function fmi3GetGenerationDateAndTime(fmu::FMU3)
    fmi3GetGenerationDateAndTime(fmu.modelDescription)
end

"""

    fmi3GetVariableNamingConvention(fmu::FMU3)

Returns the tag 'varaiblenamingconvention' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.variableNamingConvention::Union{fmi2VariableNamingConvention, Nothing}`: Returns the tag 'variableNamingConvention' from the model description.
"""
function fmi3GetVariableNamingConvention(fmu::FMU3)
    fmi3GetVariableNamingConvention(fmu.modelDescription)
end

#TODO check if MD ending is needed in FMI.jl
"""

    fmi3GetNumberOfEventIndicators(fmu::FMU3)

Returns the tag 'numberOfEventIndicators' from the model description.

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `fmu.modelDescription.numberOfEventIndicators::Union{UInt, Nothing}`: Returns the tag 'numberOfEventIndicators' from the model description.
"""
function fmi3GetNumberOfEventIndicators(fmu::FMU3)
    fmi3GetNumberOfEventIndicators(fmu.modelDescription)
end

"""

    fmi3CanGetSetState(fmu::FMU3)

Returns true, if the FMU supports the getting/setting of states

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports the getting/setting of states.
"""
function fmi3CanGetSetState(fmu::FMU3)
    fmi3CanGetSetState(fmu.modelDescription)
end

"""

    fmi3CanSerializeFMUstate(fmu::FMU3)

Returns true, if the FMU state can be serialized

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU state can be serialized
"""
function fmi3CanSerializeFMUState(fmu::FMU3)
    fmi3CanSerializeFMUState(fmu.modelDescription)
end

"""

    fmi3ProvidesDirectionalDerivatives(fmu::FMU3)

Returns true, if the FMU provides directional derivatives

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU provides directional derivatives
"""
function fmi3ProvidesDirectionalDerivatives(fmu::FMU3)
    fmi3ProvidesDirectionalDerivatives(fmu.modelDescription)
end

"""

    fmi3ProvidesAdjointDerivatives(fmu::FMU3)

Returns true, if the FMU provides adjoint derivatives

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU provides adjoint derivatives
"""
function fmi3ProvidesAdjointDerivatives(fmu::FMU3)
    fmi3ProvidesAdjointDerivatives(fmu.modelDescription)
end

"""

    fmi3IsCoSimulation(fmu::FMU3)

Returns true, if the FMU supports co simulation

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports co simulation
"""
function fmi3IsCoSimulation(fmu::FMU3)
    fmi3IsCoSimulation(fmu.modelDescription)
end

"""

    fmi3IsModelExchange(fmu::FMU3)

Returns true, if the FMU supports model exchange

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports model exchange
"""
function fmi3IsModelExchange(fmu::FMU3)
    fmi3IsModelExchange(fmu.modelDescription)
end

"""

    fmi3IsScheduledExecution(fmu::FMU3)

Returns true, if the FMU supports scheduled execution

# Arguments
- `fmu::FMU3`: Mutable struct representing a FMU and all it instantiated instances in the FMI 3.0 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports scheduled execution
"""
function fmi3IsScheduledExecution(fmu::FMU3)
    fmi3IsScheduledExecution(fmu.modelDescription)
end