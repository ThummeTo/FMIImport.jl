using Revise
using FMIImport
using FMIBase
using Test
using FMI
using FMIZoo

const FMU_PATH = get_model_filename("NBouncingBalls_1", "BouncingBall_lssa", "v1", "3.0")

fmu = loadFMU(FMU_PATH)

@testset "Layered Standard Integration Test" begin

    @test isdefined(fmu, :modelDescriptionLSSA)
    
    ls = fmu.modelDescriptionLSSA
    
    if isnothing(ls)
        @warn "'modelDescriptionLSSA' is 'nothing'. Import failed."
    else
        @info "Found Layered Standard Object." 
        
        println("Name: ", ls.name)
        println("Version: ", ls.version)
        
        # XML: <Float64 valueReference="108" previous="100"/> (pre(h1) -> h1)
        # XML: <Float64 valueReference="109" previous="102"/> (pre(v1) -> v1)
        
        # h
        target_vr_h = UInt32(108) 
        expected_prev_h = UInt32(100)

        # v
        target_vr_v = UInt32(109) 
        expected_prev_v = UInt32(102)

        @testset "Previous State Mapping" begin
            # h
            @test haskey(ls.previous, target_vr_h)
            if haskey(ls.previous, target_vr_h)
                println("VR $target_vr_h (pre_h) -> previous VR: $(ls.previous[target_vr_h])")
                @test ls.previous[target_vr_h] == expected_prev_h
            end

            # v
            @test haskey(ls.previous, target_vr_v)
            if haskey(ls.previous, target_vr_v)
                println("VR $target_vr_v (pre_v) -> previous VR: $(ls.previous[target_vr_v])")
                @test ls.previous[target_vr_v] == expected_prev_v
            end
        end

        # XML: <DiscreteState valueReference="107"/> (bounce_count1)
        # XML: <ErrorIndicator valueReference="110"/> (error_h_start1)
        
        @testset "ModelStructure Mapping" begin
            # Discrete State
            discrete_vr = UInt32(107)
            if discrete_vr in ls.discreteStates
                println("Found: DiscreteState VR $discrete_vr.")
                @test true
            else
                @warn "DiscreteState VR $discrete_vr is missing."
                println("Existing DiscreteStates: ", ls.discreteStates)
                @test false
            end

            # Error Indicator
            error_ind_vr = UInt32(110)
            if error_ind_vr in ls.errorIndicators
                println("Found: ErrorIndicator VR $error_ind_vr.")
                @test true
            else
                @warn "ErrorIndicator VR $error_ind_vr is missing."
                println("Existing ErrorIndicators: ", ls.errorIndicators)
                @test false
            end
        end
    end
end

unloadFMU(fmu)