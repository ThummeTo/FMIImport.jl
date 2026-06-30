#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport
using Test
import Random
using FMIZoo
include("sparsity.jl")

# solvers 
using DifferentiationInterface: AutoFiniteDiff, AutoForwardDiff
using OrdinaryDiffEqRosenbrock: Rodas5
using OrdinaryDiffEqTsit5: Tsit5
using Sundials

using FMIImport.FMICore: fmi2Integer, fmi2Boolean, fmi2Real, fmi2String
using FMIImport.FMICore:
    fmi3Float32,
    fmi3Float64,
    fmi3Int8,
    fmi3UInt8,
    fmi3Int16,
    fmi3UInt16,
    fmi3Int32,
    fmi3UInt32,
    fmi3Int64,
    fmi3UInt64
using FMIImport.FMICore: fmi3Boolean, fmi3String, fmi3Binary

exportingToolsWindows = [("Dymola", "2023x")]
exportingToolsLinux = [("Dymola", "2023x")]

function runtestsFMI2(exportingTool)
    ENV["EXPORTINGTOOL"] = exportingTool[1]
    ENV["EXPORTINGVERSION"] = exportingTool[2]

    # enable assertions for warnings/errors for all default execution configurations 
    for exec in FMU_EXECUTION_CONFIGURATIONS
        exec.assertOnError = true
        exec.assertOnWarning = true
    end

    @testset "Testing FMUs exported from $exportingTool" begin
        @testset "Functions for FMU2Component" begin
            @testset "Variable Getters / Setters" begin
                include("FMI2/getter_setter.jl")
            end
            @testset "State Manipulation" begin
                include("FMI2/state.jl")
            end
        end

        @testset "Model Description Parsing" begin
            include("FMI2/model_description.jl")
        end

        @testset "Logging" begin
            include("FMI2/logging.jl")
        end
        @testset "Logging with externalCallbacks" begin
            include("FMI2/externalLogging.jl")
        end

        testSparsity("2.0")
    end
end

function runtestsFMI3(exportingTool)
    ENV["EXPORTINGTOOL"] = exportingTool[1]
    ENV["EXPORTINGVERSION"] = exportingTool[2]

    # enable assertions for warnings/errors for all default execution configurations 
    for exec in FMU_EXECUTION_CONFIGURATIONS
        exec.assertOnError = true
        exec.assertOnWarning = true
    end

    @testset "Testing FMUs exported from $exportingTool" begin
        @testset "Functions for fmi3Instance" begin
            @testset "Variable Getters / Setters" begin
                include("FMI3/getter_setter.jl")
            end
            @testset "State Manipulation" begin
                include("FMI3/state.jl")
            end
        end

        @testset "Model Description Parsing" begin
            include("FMI3/model_description.jl")
        end

        @testset "Logging" begin
            include("FMI3/logging.jl")
        end

        @testset "LS-SA Import" begin
            if Sys.iswindows()
                include("FMI3/lssa.jl")
            else
                @info "LSSA tests running on Windows only for now."
            end
        end

        testSparsity("3.0")
    end
end

const fmuStructs = ("FMU", "INSTANCE")

function getFMUStruct(
    modelname,
    mode,
    tool = ENV["EXPORTINGTOOL"],
    version = ENV["EXPORTINGVERSION"],
    fmiversion = ENV["FMIVERSION"],
    fmustruct = ENV["FMUSTRUCT"];
    kwargs...,
)

    # choose FMU or FMUInstance
    if endswith(modelname, ".fmu")
        fmu = FMIImport.loadFMU(modelname; kwargs...)
    else
        fmu = FMIImport.loadFMU(modelname, tool, version, fmiversion; kwargs...)
    end

    if fmustruct == "FMU"
        return fmu, fmu

    elseif fmustruct == "INSTANCE"
        inst, _ = FMIImport.prepareSolveFMU(fmu, nothing, mode; loggingOn = true)
        @test !isnothing(inst)
        return inst, fmu

    else
        @assert false "Unknown fmuStruct, variable `FMUSTRUCT` = `$(fmustruct)`"
    end
end

function runtestsCommon(exportingTool)

    ENV["EXPORTINGTOOL"] = exportingTool[1]
    ENV["EXPORTINGVERSION"] = exportingTool[2]

    # enable assertions for warnings/errors for all default execution configurations 
    for exec in FMU_EXECUTION_CONFIGURATIONS
        exec.assertOnError = true
        exec.assertOnWarning = true
    end

    for fmiversion in (2.0, 3.0)
        ENV["FMIVERSION"] = fmiversion

        @testset "Testing FMI $(ENV["FMIVERSION"]) FMUs exported from $(ENV["EXPORTINGTOOL"]) $(ENV["EXPORTINGVERSION"])" begin

            for fmustruct in fmuStructs
                ENV["FMUSTRUCT"] = fmustruct

                @testset "Functions for $(ENV["FMUSTRUCT"])" begin

                    @info "CS Simulation (sim_CS.jl)"
                    @testset "CS Simulation" begin
                        include("sim_CS.jl")
                    end

                    @info "ME Simulation (sim_ME.jl)"
                    @testset "ME Simulation" begin
                        include("sim_ME.jl")
                    end

                    @info "ME Simulation (sim_ME_bb.jl)"
                    @testset "ME Simulation: Bouncing Ball" begin
                        include("sim_ME_bb.jl")
                    end

                    @info "SE Simulation (sim_SE.jl)"
                    if fmiversion == 3.0
                        @testset "SE Simulation" begin
                            include("sim_SE.jl")
                        end
                    else
                        @info "Skipping SE tests for FMI $(fmiversion), because this is not supported by the corresponding FMI version."
                    end

                    @info "Simulation FMU without states (sim_zero_state.jl)"
                    @testset "Simulation FMU without states" begin
                        include("sim_zero_state.jl")
                    end

                end
            end
        end
    end

end

@testset "FMIImport.jl" begin
    if Sys.iswindows()
        @info "Automated testing is supported on Windows."
        for exportingTool in exportingToolsWindows
            runtestsFMI2(exportingTool)
            runtestsFMI3(exportingTool)
            runtestsCommon(exportingTool)
        end
    elseif Sys.islinux()
        @info "Automated testing is supported on Linux."
        for exportingTool in exportingToolsLinux
            runtestsFMI2(exportingTool)
            runtestsFMI3(exportingTool)
            runtestsCommon(exportingTool)
        end
    elseif Sys.isapple()
        @warn "Test-sets are currrently using Windows- and Linux-FMUs, automated testing for macOS is currently not supported."
    end
end
