#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module PlotsExt

import Plots
import FMIImport.FMIBase: FMU

"""
    Plots.plot(fmu::FMU, 
                args...;
                plotkwargs...)

Runs a FMU simulation, plots the solution, and returns a new figure.

# Arguments
- `fmu::FMU`: FMU to simulate and plot
- `args...`: Arguments, that are passed on to Plots.plot

# Keywords
- `plotkwargs...`: Keyword arguments, that are passed on to Plots.plot
"""
function Plots.plot(fmu::FMU, plotargs...; plotkwargs...)
    solution = simulate(fmu)
    fig = Plots.plot(solution, plotargs...; plotkwargs...)
    return fig
end

"""
    Plots.plot!(fig::Plots.Plot, fmu::FMU,
                args...;
                plotkwargs...)

Runs a FMU simulation, plots the solution into `fig` and returns the figure again.

# Arguments
- `fig::Plots.Plot`: Figure to plot into
- `fmu::FMU`: FMU to simulate and plot
- `args...`: Arguments, that are passed on to Plots.plot

# Keywords
- `plotkwargs...`: Keyword arguments, that are passed on to Plots.plot
"""
function Plots.plot!(
    fig::Plots.Plot,
    fmu::FMU,
    plotargs...;
    plotkwargs...,
)
    solution = simulate(fmu)
    fig = Plots.plot!(fig, solution, plotargs...; plotkwargs...)
    return fig
end

end # PlotsExt.jl
