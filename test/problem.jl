#
# Copyright (c) 2026 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMIBase.SciMLBase: solve, successful_retcode
using OrdinaryDiffEqTsit5: Tsit5

t_start = 0.0
t_stop = 1.0
x0 = [0.5, 0.0]

fmuStruct, fmu = getFMUStruct("SpringPendulum1D", :ME; type = :ME)

problem = FMUProblem(fmuStruct, (t_start, t_stop); mode = :ME, u0 = x0)
solution = solve(problem, Tsit5(); showProgress = false)

@test successful_retcode(solution)
@test solution.t[1] == t_start
@test solution.t[end] == t_stop
@test solution.u[1] == x0

@test problem.instance !== nothing
@test problem.problem !== nothing
@test problem.callback !== nothing
@test problem.u0 == x0
@test problem.tspan == (t_start, t_stop)

unloadFMU(fmu)
