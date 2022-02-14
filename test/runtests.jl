#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport
using Test
import Random

using FMIImport.FMICore: fmi2Integer, fmi2Boolean, fmi2Real, fmi2String

exportingToolsWindows = ["Dymola/2020x", "OpenModelica/v1.17.0"]
exportingToolsLinux = ["OpenModelica/v1.17.0"]

function runtests(exportingTool)
    ENV["EXPORTINGTOOL"] = exportingTool

    @testset "Testing FMUs exported from $exportingTool" begin
        @testset "Functions for fmi2Component" begin
            @testset "Variable Getters / Setters" begin
                include("getter_setter.jl")
            end
            @testset "State Manipulation" begin
                include("state.jl")
            end
            @testset "Directional derivatives" begin
                include("dir_ders.jl")
            end
        end

        @testset "Model Description Parsing" begin
            include("model_description.jl")
        end
    end
end

@testset "FMIImport.jl" begin
    if Sys.iswindows()
        @info "Automated testing is supported on Windows."
        for exportingTool in exportingToolsWindows
            runtests(exportingTool)
        end
    elseif Sys.islinux()
        @info "Automated testing is supported on Linux."
        for exportingTool in exportingToolsLinux
            runtests(exportingTool)
        end
    elseif Sys.isapple()
        @warn "Test-sets are currrently using Windows- and Linux-FMUs, automated testing for macOS is currently not supported."
    end
end
