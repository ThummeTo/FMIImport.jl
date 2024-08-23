#
# Copyright (c) 2021 Frederic Bruder, Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module FMIZooExt

using FMIImport, FMIZoo

function FMIImport.loadFMU(
    modelName::AbstractString,
    tool::AbstractString,
    version::AbstractString,
    fmiversion::AbstractString = "2.0";
    kwargs...,
)
    fname = get_model_filename(modelName, tool, version, fmiversion)
    return FMIImport.loadFMU(fname; kwargs...)
end

end # FMIZooExt
