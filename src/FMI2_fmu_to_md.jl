#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_fmu_to_md.jl` (FMU to model description)?
# - wrappers to call the model description functions from a FMU-instance [exported]

"""

   fmi2GetNumberOfStates(fmu::FMU2)

Returns the number of states of the FMU.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- Returns the length of the `fmu.modelDescription.valueReferences::Array{fmi2ValueReference}` corresponding to the number of states of the FMU.
"""
function fmi2GetNumberOfStates(fmu::FMU2)
    fmi2GetNumberOfStates(fmu.modelDescription)
end

"""

   function fmi2GetModelName(fmu::FMU2)

Returns the tag 'modelName' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.modelName::String`: Returns the tag 'modelName' from the model description.

"""
function fmi2GetModelName(fmu::FMU2)
    fmi2GetModelName(fmu.modelDescription)
end

"""

   fmi2GetGUID(fmu::FMU2)

Returns the tag 'guid' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.guid::String`: Returns the tag 'guid' from the model description.

"""
function fmi2GetGUID(fmu::FMU2)
    fmi2GetGUID(fmu.modelDescription)
end

"""

   fmi2GetGenerationTool(fmu::FMU2)

Returns the tag 'generationtool' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.generationTool::Union{String, Nothing}`: Returns the tag 'generationtool' from the model description.

"""
function fmi2GetGenerationTool(fmu::FMU2)
    fmi2GetGenerationTool(fmu.modelDescription)
end

"""

   fmi2GetGenerationDateAndTime(fmu::FMU2)

Returns the tag 'generationdateandtime' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.generationDateAndTime::DateTime`: Returns the tag 'generationdateandtime' from the model description.

"""
function fmi2GetGenerationDateAndTime(fmu::FMU2)
    fmi2GetGenerationDateAndTime(fmu.modelDescription)
end


   fmi2GetVariableNamingConvention(fmu::FMU2)

Returns the tag 'varaiblenamingconvention' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.variableNamingConvention::Union{fmi2VariableNamingConvention, Nothing}`: Returns the tag 'variableNamingConvention' from the model description.

"""
function fmi2GetVariableNamingConvention(fmu::FMU2)
    fmi2GetVariableNamingConvention(fmu.modelDescription)
end

"""

   fmi2GetNumberOfEventIndicators(fmu::FMU2)

Returns the tag 'numberOfEventIndicators' from the model description.

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `fmu.modelDescription.numberOfEventIndicators::Union{UInt, Nothing}`: Returns the tag 'numberOfEventIndicators' from the model description.

"""
function fmi2GetNumberOfEventIndicators(fmu::FMU2)
    fmi2GetNumberOfEventIndicators(fmu.modelDescription)
end

"""

   fmi2CanGetSetState(fmu::FMU2)

Returns true, if the FMU supports the getting/setting of states

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports the getting/setting of states.

"""
function fmi2CanGetSetState(fmu::FMU2)
    fmi2CanGetSetState(fmu.modelDescription)
end

"""

   fmi2CanSerializeFMUstate(fmu::FMU2)

Returns true, if the FMU state can be serialized

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `::Bool`: Returns true, if the FMU state can be serialized

"""
function fmi2CanSerializeFMUstate(fmu::FMU2)
    fmi2CanSerializeFMUstate(fmu.modelDescription)
end

"""

   fmi2ProvidesDirectionalDerivative(fmu::FMU2)

Returns true, if the FMU provides directional derivatives

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `::Bool`: Returns true, if the FMU provides directional derivatives

"""
function fmi2ProvidesDirectionalDerivative(fmu::FMU2)
    fmi2ProvidesDirectionalDerivative(fmu.modelDescription)
end

"""

   fmi2IsCoSimulation(fmu::FMU2)

Returns true, if the FMU supports co simulation

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports co simulation

"""
function fmi2IsCoSimulation(fmu::FMU2)
    fmi2IsCoSimulation(fmu.modelDescription)
end

"""

   fmi2IsModelExchange(fmu::FMU2)

Returns true, if the FMU supports model exchange

# Arguments
- `fmu::FMU2`: Mutable struct representing a FMU and all it instantiated instances in the FMI 2.0.2 Standard.

# Returns
- `::Bool`: Returns true, if the FMU supports model exchange

"""
function fmi2IsModelExchange(fmu::FMU2)
    fmi2IsModelExchange(fmu.modelDescription)
end
