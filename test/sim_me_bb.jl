#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# Integration test for ME event handling:
# simulates the bouncing ball (state events) and checks that events are detected,
# handled and recorded through the `VectorContinuousCallback` interface.
# For FMI3, this also exercises `setEventFlags!` (`rootsFound` etc. passed to `fmi3EnterEventMode`).

using FMIImport: prepareSolveFMU, finishSolveFMU
using FMIImport.FMIBase: setupODEProblem, setupCallbacks
using FMIImport.FMIBase.SciMLBase: CallbackSet, solve, successful_retcode
using OrdinaryDiffEqTsit5: Tsit5

t_start = 0.0
t_stop = 2.0

myFMU = loadFMU("BouncingBall", "ModelicaReferenceFMUs", "0.0.30", ENV["FMIVERSION"])

c, x0 = prepareSolveFMU(
    myFMU,
    nothing,
    :ME;
    instantiate = true,
    t_start = t_start,
    t_stop = t_stop,
)
@test !isnothing(c)
@test myFMU.hasStateEvents

prob = setupODEProblem(c, x0, (t_start, t_stop))
cbs = setupCallbacks(c, [], nothing, false, nothing, [], nothing, t_start, t_stop, nothing)

sol = solve(prob, Tsit5(); callback = CallbackSet(cbs...))
@test successful_retcode(sol)

# the ball must bounce several times within the simulated time span ...
stateEvents = filter(e -> e.indicator > 0, c.solution.events)
@test length(stateEvents) >= 3

for e in stateEvents
    # the BouncingBall has a single event indicator (the ball height)
    @test e.indicator == 1
    # the velocity flips its sign at the bounce
    @test !isnothing(e.x_left) && !isnothing(e.x_right)
    @test e.x_left[2] * e.x_right[2] <= 0.0
end

# ... but never falls through the ground
@test all(u[1] > -1e-4 for u in sol.u)

if ENV["FMIVERSION"] == "3.0"
    # `rootsFound` (written by `FMIBase.setEventFlags!`, passed to `fmi3EnterEventMode`)
    # must be allocated with one entry per event indicator
    @test length(c.rootsFound) == 1
else
    @info "Roots found check skipped for FMI version $(ENV["FMIVERSION"])"
end

c = finishSolveFMU(myFMU, c; freeInstance = true, terminate = true)
unloadFMU(myFMU)
