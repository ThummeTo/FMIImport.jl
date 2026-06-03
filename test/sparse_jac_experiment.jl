using FMIImport, SparseArrays
using FMI
using OrdinaryDiffEq
using DifferentialQ
using SciMLBase: remake, ODEFunction
using FMIZoo
using BenchmarkTools
fmu = loadFMU("redacted")
# fmu = loadFMU("Dahlquist", "ModelicaReferenceFMUs", "0.0.39", "3.0")
fmu.executionConfig.handleStateEvents = false
fmu.executionConfig.handleTimeEvents = false
# Build jac_prototype from the dependency matrix
ext = Base.get_extension(FMIImport, :SparseArraysExt)
dep = ext.DependencyMatrix(fmu.modelDescription)
dvrs = fmu.modelDescription.derivativeValueReferences
svrs = fmu.modelDescription.stateValueReferences
jp = Float64.(dep[dvrs, svrs] .!= 0)

println("Jacobian prototype ($(size(jp,1))×$(size(jp,2)), nnz=$(nnz(jp))):")
display(jp)

# Reference solve via simulateME — keep instance alive so we can access c.problem
tspan = (0.0, 5.0)
sol_ref = simulateME(fmu, tspan; solver=Rodas5P(autodiff=AutoFiniteDiff()), freeInstance=false)
c = sol_ref.instance

# Remake the ODEProblem with jac_prototype and re-solve
prob_sparse = remake(c.problem; f=ODEFunction{true}(c.problem.f.f; jac_prototype=jp))
@btime sol_sparse = solve(prob_sparse, Rodas5P(autodiff=AutoFiniteDiff()))

println("\nSparse solve final state: $(sol_sparse.u[end])")
println("Max deviation from reference: $(maximum(abs.(sol_sparse(tspan[2]) .- sol_sparse.u[end])))")

unloadFMU(fmu)
