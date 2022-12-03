#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport.ForwardDiff 
# ToDo: Add Zygote tests (for rrules)

# load demo FMU
fmu = fmi2Load("SpringPendulumExtForce1D", "Dymola", "2022x"; type=:ME) # ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

# enable time gradient evaluation (disabled by default for performance reasons)
fmu.executionConfig.eval_t_gradients = true

# prepare (allocate) an FMU instance
c, x0 = FMIImport.prepareSolveFMU(fmu, nothing, fmu.type, nothing, nothing, nothing, nothing, nothing, nothing, 0.0, 0.0, nothing)

x = [1.0, 1.0]
x_refs = fmu.modelDescription.stateValueReferences
u = [2.0]
u_refs = fmu.modelDescription.inputValueReferences
y = [0.0, 0.0]
y_refs = fmu.modelDescription.outputValueReferences
t = 0.0

# evaluation: set state, get state derivative (out-of-place)
y, dx = fmu(;x=x)

# evaluation: set state, get state derivative in-place
y, dx = fmu(;x=x, dx=dx)

# evaluation: set state and inputs, get state derivative (out-of-place)
y, dx = fmu(;x=x, u=u, u_refs=u_refs)

# evaluation: set state and inputs, get state derivative (out-of-place) and outputs (in-place)
y, dx = fmu(;x=x, u=u, u_refs=u_refs, y=y, y_refs=y_refs)

# evaluation: set state and inputs, get state derivative (in-place) and outputs (in-place)
y, dx = fmu(;x=x, u=u, u_refs=u_refs, y=y, y_refs=y_refs, dx=dx)

# Jacobian A=∂dx/∂x
_f = _x -> fmu(;x=_x)[2]
_f(x)
j = ForwardDiff.jacobian(_f, x)

@test c.solution.evals_∂ẋ_∂x == length(x)
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 0
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 0
@test c.solution.evals_∂y_∂t == 0

# Jacobian B=∂dx/∂u
_f = _u -> fmu(;x=x, u=_u, u_refs=u_refs)[2]
_f(u)
j = ForwardDiff.jacobian(_f, u)

@test c.solution.evals_∂ẋ_∂x == length(x_refs)+length(u_refs)
@test c.solution.evals_∂ẋ_∂u == length(u_refs)
@test c.solution.evals_∂y_∂x == 0
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 0
@test c.solution.evals_∂y_∂t == 0

# Jacobian C=∂y/∂x
_f = _x -> fmu(;x=_x, y=y, y_refs=y_refs)[1]
_f(x)
j = ForwardDiff.jacobian(_f, x)

@test c.solution.evals_∂ẋ_∂x == length(x_refs)+length(u_refs)+length(x_refs)
@test c.solution.evals_∂ẋ_∂u == length(u_refs)
@test c.solution.evals_∂y_∂x == length(x_refs)
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 0
@test c.solution.evals_∂y_∂t == 0

# Jacobian D=∂y/∂u
_f = _u -> fmu(;x=x, u=_u, u_refs=u_refs, y=y, y_refs=y_refs)[1]
_f(u)
j = ForwardDiff.jacobian(_f, u)

@test c.solution.evals_∂ẋ_∂x == length(x_refs)+length(u_refs)+length(x_refs)+length(u_refs)
@test c.solution.evals_∂ẋ_∂u == length(u_refs)*2
@test c.solution.evals_∂y_∂x == length(x_refs)+length(u_refs)
@test c.solution.evals_∂y_∂u == length(u_refs)
@test c.solution.evals_∂ẋ_∂t == 0
@test c.solution.evals_∂y_∂t == 0

# explicit time derivative ∂dx/∂t
_f = _t -> fmu(;x=x, t=_t)[2]
_f(t)
j = ForwardDiff.derivative(_f, t)

@test c.solution.evals_∂ẋ_∂x == length(x_refs)+length(u_refs)+length(x_refs)+length(u_refs)+length(x_refs)
@test c.solution.evals_∂ẋ_∂u == length(u_refs)*2
@test c.solution.evals_∂y_∂x == length(x_refs)+length(u_refs)
@test c.solution.evals_∂y_∂u == length(u_refs)
@test c.solution.evals_∂ẋ_∂t == 1
@test c.solution.evals_∂y_∂t == 0

# explicit time derivative ∂y/∂t 
_f = _t -> fmu(;x=x, y=y, y_refs=y_refs, t=_t)[1]
_f(t)
j = ForwardDiff.derivative(_f, t)

@test c.solution.evals_∂ẋ_∂x == length(x_refs)+length(u_refs)+length(x_refs)+length(u_refs)+length(x_refs)
@test c.solution.evals_∂ẋ_∂u == length(u_refs)*2
@test c.solution.evals_∂y_∂x == length(x_refs)+length(u_refs)
@test c.solution.evals_∂y_∂u == length(u_refs)
@test c.solution.evals_∂ẋ_∂t == 1
@test c.solution.evals_∂y_∂t == 1

# clean up
fmiUnload(fmu)