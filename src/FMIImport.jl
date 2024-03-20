#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module FMIImport

using FMIBase.Reexport
@reexport using FMIBase

using FMIBase.FMICore
using FMIBase: fast_copy!, invalidate!, check_invalidate!
using FMIBase.Requires

import FMIBase.ChainRulesCore: ignore_derivatives

using RelocatableFolders

import FMIBase: EzXML
include("convert.jl")
include("zip.jl")
include("binary.jl")
include("md_parse.jl")
include("get_set.jl")

### FMI2 ###
include("FMI2/prep.jl")
include("FMI2/c.jl")
include("FMI2/int.jl")
include("FMI2/ext.jl")
include("FMI2/md.jl")

### FMI3 ###
include("FMI3/prep.jl")
include("FMI3/c.jl")
include("FMI3/int.jl")
include("FMI3/ext.jl")
include("FMI3/md.jl")

end # module
