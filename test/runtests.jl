#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport
using Test
import Random
using FMIZoo

using FMIImport.FMICore: fmi2Integer, fmi2Boolean, fmi2Real, fmi2String

exportingToolsWindows = [("Dymola", "2022x")]
exportingToolsLinux = [("Dymola", "2022x")]

function runtestsFMI2(exportingTool)
    ENV["EXPORTINGTOOL"] = exportingTool[1]
    ENV["EXPORTINGVERSION"] = exportingTool[2]

    @testset "Testing FMUs exported from $exportingTool" begin
        @testset "Functions for fmi2Component" begin
            @testset "Variable Getters / Setters" begin
                include("FMI2/getter_setter.jl")
            end
            @testset "State Manipulation" begin
                include("FMI2/state.jl")
            end
            @testset "Directional derivatives" begin
                include("FMI2/dir_ders.jl")
            end
        end

        @testset "Model Description Parsing" begin
            include("FMI2/model_description.jl")
        end

        @testset "Logging" begin
            include("FMI2/logging.jl")
        end
    end
end

function runtestsFMI3(exportingTool)
    ENV["EXPORTINGTOOL"] = exportingTool[1]
    ENV["EXPORTINGVERSION"] = exportingTool[2]

    @testset "Testing FMUs exported from $exportingTool" begin
        # @testset "Functions for fmi2Component" begin
        #     @testset "Variable Getters / Setters" begin
        #         include("FMI3/getter_setter.jl")
        #     end
        #     @testset "State Manipulation" begin
        #         include("FMI3/state.jl")
        #     end
        #     @testset "Directional derivatives" begin
        #         include("FMI3/dir_ders.jl")
        #     end
        # end

        # @testset "Model Description Parsing" begin
        #     include("FMI3/model_description.jl")
        # end

        # @testset "Logging" begin
        #     include("FMI3/logging.jl")
        # end
    
    @testset "Testing Reference FMUs" begin
        
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
