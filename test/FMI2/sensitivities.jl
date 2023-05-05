#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import SciMLSensitivity.ForwardDiff 
import SciMLSensitivity.Zygote
import SciMLSensitivity.ReverseDiff

# load demo FMU
fmu = fmi2Load("SpringPendulumExtForce1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"]; type=:ME)

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
p_refs = fmu.modelDescription.parameterValueReferences
p = zeros(length(p_refs))
dx = [0.0, 0.0]
t = 0.0

function reset!(c::FMIImport.FMU2Component)
    c.solution.evals_∂ẋ_∂x = 0
    c.solution.evals_∂ẋ_∂u = 0
    c.solution.evals_∂y_∂x = 0
    c.solution.evals_∂y_∂u = 0
    c.solution.evals_∂ẋ_∂t = 0
    c.solution.evals_∂y_∂t = 0
    c.solution.evals_∂ẋ_∂p = 0
    c.solution.evals_∂y_∂p = 0

    @test length(dx) == length(fmu.modelDescription.derivativeValueReferences)
    @test length(y) == length(fmu.modelDescription.outputValueReferences)
end

# evaluation: set state, get state derivative (out-of-place)
ydx = fmu(;x=x)

# evaluation: set state, get state derivative in-place
ydx = fmu(;x=x, dx=dx)

# evaluation: set state and inputs, get state derivative (out-of-place)
ydx = fmu(;x=x, u=u, u_refs=u_refs)

# evaluation: set state and inputs, get state derivative (out-of-place) and outputs (in-place)
ydx = fmu(;x=x, u=u, u_refs=u_refs, y=y, y_refs=y_refs)

# evaluation: set state and inputs, get state derivative (in-place) and outputs (in-place)
ydx = fmu(;x=x, u=u, u_refs=u_refs, y=y, y_refs=y_refs, dx=dx)

# evaluation: set state and inputs, parameters, get state derivative (in-place) and outputs (in-place)
ydx = fmu(;x=x, u=u, u_refs=u_refs, y=y, y_refs=y_refs, dx=dx, p=p, p_refs=p_refs)

# known results
atol= 1e-8
A = [0.0 1.0; -10.0 0.0]
B = [0.0; 1.0]
C = [0.0 1.0; -10.0 0.0]
D = [0.0; 1.0]
E = [0.0   0.0  0.0   0.0   0.0  0.0;
     0.0  10.0  0.1  10.0  -3.0  5.0]
F = [0.0   0.0  0.0   0.0   0.0  0.0;
     0.0  10.0  0.1  10.0  -3.0  5.0]
dx_t = [0.0, 0.0]
y_t = [0.0, 0.0]

# Test build-in derivatives (slow) only for jacobian A
fmu.executionConfig.JVPBuiltInDerivatives = true

_f = _x -> fmu(;x=_x)
_f(x)
j_fwd = ForwardDiff.jacobian(_f, x)
j_zyg = Zygote.jacobian(_f, x)[1]
j_rwd = ReverseDiff.jacobian(_f, x)
j_smp = fmi2SampleJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.stateValueReferences)
j_get = fmi2GetJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.stateValueReferences)

@test isapprox(j_fwd, A; atol=atol)
@test isapprox(j_zyg, A; atol=atol)
@test isapprox(j_rwd, A; atol=atol)
@test isapprox(j_smp, A; atol=atol)
@test isapprox(j_get, A; atol=atol)

# End: Test build-in derivatives (slow) only for jacobian A
fmu.executionConfig.JVPBuiltInDerivatives = false
reset!(c)

# Jacobian A=∂dx/∂x
_f = _x -> fmu(;x=_x)
_f(x)
j_fwd = ForwardDiff.jacobian(_f, x)
j_zyg = Zygote.jacobian(_f, x)[1]
j_rwd = ReverseDiff.jacobian(_f, x)
j_smp = fmi2SampleJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.stateValueReferences)
j_get = fmi2GetJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.stateValueReferences)

@test isapprox(j_fwd, A; atol=atol)
@test isapprox(j_zyg, A; atol=atol)
@test isapprox(j_rwd, A; atol=atol)
@test isapprox(j_smp, A; atol=atol)
@test isapprox(j_get, A; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 4+2
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 0
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 2+2
@test c.solution.evals_∂y_∂t == 0
reset!(c)

# Jacobian B=∂dx/∂u
_f = _u -> fmu(;x=x, u=_u, u_refs=u_refs)
_f(u)
j_fwd = ForwardDiff.jacobian(_f, u)
j_zyg = Zygote.jacobian(_f, u)[1]
j_rwd = ReverseDiff.jacobian(_f, u)
j_smp = fmi2SampleJacobian(c, fmu.modelDescription.derivativeValueReferences, u_refs)
j_get = fmi2GetJacobian(c, fmu.modelDescription.derivativeValueReferences, u_refs)

@test isapprox(j_fwd, B; atol=atol)
@test isapprox(j_zyg, B; atol=atol)
@test isapprox(j_rwd, B; atol=atol)
@test isapprox(j_smp, B; atol=atol)
@test isapprox(j_get, B; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 3+2
@test c.solution.evals_∂ẋ_∂u == 3+2
@test c.solution.evals_∂y_∂x == 0
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 2+2
@test c.solution.evals_∂y_∂t == 0
reset!(c)

# Jacobian C=∂y/∂x (in-place)
_f = _x -> fmu(;x=_x, y=y, y_refs=y_refs)[1:length(y_refs)]
_f(x)
j_fwd = ForwardDiff.jacobian(_f, x)
j_zyg = Zygote.jacobian(_f, x)[1]
j_rwd = ReverseDiff.jacobian(_f, x)
j_smp = fmi2SampleJacobian(c, y_refs, fmu.modelDescription.stateValueReferences)
j_get = fmi2GetJacobian(c, y_refs, fmu.modelDescription.stateValueReferences)

@test isapprox(j_fwd, C; atol=atol)
@test isapprox(j_zyg, C; atol=atol)
@test isapprox(j_rwd, C; atol=atol)
@test isapprox(j_smp, C; atol=atol)
@test isapprox(j_get, C; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 2+4
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 2+4
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 4
@test c.solution.evals_∂y_∂t == 4
reset!(c)

# Jacobian C=∂y/∂x (out-of-place)
_f = _x -> fmu(;x=_x, y_refs=y_refs)[1:length(y_refs)]
_f(x)
j_fwd = ForwardDiff.jacobian(_f, x)
j_zyg = Zygote.jacobian(_f, x)[1]
j_rwd = ReverseDiff.jacobian(_f, x)

@test isapprox(j_fwd, C; atol=atol)
@test isapprox(j_zyg, C; atol=atol)
@test isapprox(j_rwd, C; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 6
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 6
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 4
@test c.solution.evals_∂y_∂t == 4
reset!(c)

# Jacobian D=∂y/∂u (in-place)
_f = _u -> fmu(;x=x, u=_u, u_refs=u_refs, y=y, y_refs=y_refs)[1:length(y_refs)]
_f(u)
j_fwd = ForwardDiff.jacobian(_f, u)
j_zyg = Zygote.jacobian(_f, u)[1]
j_rwd = ReverseDiff.jacobian(_f, u)
j_smp = fmi2SampleJacobian(c, y_refs, u_refs)
j_get = fmi2GetJacobian(c, y_refs, u_refs)

@test isapprox(j_fwd, D; atol=atol)
@test isapprox(j_zyg, D; atol=atol)
@test isapprox(j_rwd, D; atol=atol)
@test isapprox(j_smp, D; atol=atol)
@test isapprox(j_get, D; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 5
@test c.solution.evals_∂ẋ_∂u == 5
@test c.solution.evals_∂y_∂x == 5
@test c.solution.evals_∂y_∂u == 5
@test c.solution.evals_∂ẋ_∂t == 4
@test c.solution.evals_∂y_∂t == 4
reset!(c)

# Jacobian D=∂y/∂u (out-of-place)
_f = _u -> fmu(;x=x, u=_u, u_refs=u_refs, y_refs=y_refs)[1:length(y_refs)]
_f(u)
j_fwd = ForwardDiff.jacobian(_f, u)
j_zyg = Zygote.jacobian(_f, u)[1]
j_rwd = ReverseDiff.jacobian(_f, u)

@test isapprox(j_fwd, D; atol=atol)
@test isapprox(j_zyg, D; atol=atol)
@test isapprox(j_rwd, D; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 5
@test c.solution.evals_∂ẋ_∂u == 5
@test c.solution.evals_∂y_∂x == 5
@test c.solution.evals_∂y_∂u == 5
@test c.solution.evals_∂ẋ_∂t == 4
@test c.solution.evals_∂y_∂t == 4
reset!(c)

# explicit time derivative ∂dx/∂t
_f = _t -> fmu(;x=x, t=_t)
_f(t)
j_fwd = ForwardDiff.derivative(_f, t)
j_zyg = Zygote.jacobian(_f, t)[1]

# ReverseDiff has no `derivative` function for scalars
_f = _t -> fmu(;x=x, t=_t[1])
j_rwd = ReverseDiff.jacobian(_f, [t])

@test isapprox(j_fwd, dx_t; atol=atol)
@test isapprox(j_zyg, dx_t; atol=atol)
@test isapprox(j_rwd, dx_t; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 5
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 0
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 5
@test c.solution.evals_∂y_∂t == 0
reset!(c)

# explicit time derivative ∂y/∂t 
_f = _t -> fmu(;x=x, y=y, y_refs=y_refs, t=_t)[1:length(y_refs)]
_f(t)
j_fwd = ForwardDiff.derivative(_f, t)
j_zyg = Zygote.jacobian(_f, t)[1]

# ReverseDiff has no `derivative` function for scalars
_f = _t -> fmu(;x=x, t=_t[1])
j_rwd = ReverseDiff.jacobian(_f, [t])

@test isapprox(j_fwd, y_t; atol=atol)
@test isapprox(j_zyg, y_t; atol=atol)
@test isapprox(j_rwd, y_t; atol=atol)

@test c.solution.evals_∂ẋ_∂x == 5
@test c.solution.evals_∂ẋ_∂u == 0
@test c.solution.evals_∂y_∂x == 3
@test c.solution.evals_∂y_∂u == 0
@test c.solution.evals_∂ẋ_∂t == 5
@test c.solution.evals_∂y_∂t == 3
reset!(c)

# Jacobian E=∂dx/∂p
_f = _p -> fmu(;x=x, p=_p, p_refs=p_refs)
_f(p)
j_fwd = ForwardDiff.jacobian(_f, p)
j_zyg = Zygote.jacobian(_f, p)[1]
j_rwd = ReverseDiff.jacobian(_f, p)
j_smp = fmi2SampleJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.parameterValueReferences)
j_get = fmi2GetJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.parameterValueReferences)

@test isapprox(j_fwd, E; atol=atol)
@test isapprox(j_zyg, E; atol=atol)
@test isapprox(j_rwd, E; atol=atol)
@test isapprox(j_smp, E; atol=atol)
@test isapprox(j_get, E; atol=atol)

reset!(c)

# Jacobian F=∂y/∂p
_f = _p -> fmu(;x=x, p=_p, p_refs=p_refs, y_refs=y_refs)[1:length(y_refs)]
_f(p)
j_fwd = ForwardDiff.jacobian(_f, p)
j_zyg = Zygote.jacobian(_f, p)[1]
j_rwd = ReverseDiff.jacobian(_f, p)
j_smp = fmi2SampleJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.parameterValueReferences)
j_get = fmi2GetJacobian(c, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.parameterValueReferences)

@test isapprox(j_fwd, F; atol=atol)
@test isapprox(j_zyg, F; atol=atol)
@test isapprox(j_rwd, F; atol=atol)
@test isapprox(j_smp, F; atol=atol)
@test isapprox(j_get, F; atol=atol)

reset!(c)

# clean up
fmi2Unload(fmu)