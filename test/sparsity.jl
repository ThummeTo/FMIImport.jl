#
# Copyright (c) 2024 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using SparseArrays

function testSparsity(fmiversion::String)
    tool = ENV["EXPORTINGTOOL"]
    version = ENV["EXPORTINGVERSION"]

    @testset "Sparsity FMI $fmiversion" begin
        fmu = loadFMU("SpringPendulum1D", tool, version, fmiversion)

        @testset "DependencyMatrix auto-loaded on loadFMU" begin
            @test fmu.dependencyMatrix isa FMIBase.AbstractDependencyMatrix
            @test fmu.jac_prototype isa AbstractMatrix

            n_deriv = length(fmu.modelDescription.derivativeValueReferences)
            n_states = length(fmu.modelDescription.stateValueReferences)
            @test size(fmu.jac_prototype) == (n_deriv, n_states)
        end

        @testset "load_dep_matrix opt-out" begin
            fmu.dependencyMatrix = nothing
            fmu.jac_prototype = nothing
            cfg = FMUExecutionConfiguration()
            cfg.load_dep_matrix = false
            fmu.executionConfig = cfg
            loadDependencyMatrix!(fmu)
            @test isnothing(fmu.dependencyMatrix)
            @test isnothing(fmu.jac_prototype)
        end

        unloadFMU(fmu)
    end
end
