#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIBase.FMICore: getAttributes, fmi2ScalarVariable
using FMIBase: handleEvents

import FMIImport: fmi2VariabilityConstant, fmi2InitialApprox, fmi2InitialExact
function setBeforeInitialization(mv::fmi2ScalarVariable)
    
    causality, variability, initial = getAttributes(mv)
    return variability != fmi2VariabilityConstant && initial ∈ (fmi2InitialApprox, fmi2InitialExact)
end

import FMIImport: fmi2CausalityInput, fmi2CausalityParameter, fmi2VariabilityTunable
function setInInitialization(mv::fmi2ScalarVariable)

    causality, variability, initial = getAttributes(mv)
    return causality == fmi2CausalityInput || (causality != fmi2CausalityParameter && variability == fmi2VariabilityTunable) || (variability != fmi2VariabilityConstant && initial == fmi2InitialExact)
end

function prepareSolveFMU(fmu::FMU2, c::Union{Nothing, FMU2Component}, type::fmi2Type=fmu.type; 
    instantiate::Union{Nothing, Bool}=fmu.executionConfig.instantiate, 
    freeInstance::Union{Nothing, Bool}=fmu.executionConfig.freeInstance, 
    terminate::Union{Nothing, Bool}=fmu.executionConfig.terminate, 
    reset::Union{Nothing, Bool}=fmu.executionConfig.reset, 
    setup::Union{Nothing, Bool}=fmu.executionConfig.setup, 
    parameters::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    t_start::Real=0.0, 
    t_stop::Union{Real, Nothing}=nothing, 
    tolerance::Union{Real, Nothing}=nothing,
    x0::Union{AbstractArray{<:Real}, Nothing}=nothing, 
    inputs::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    cleanup::Bool=false, 
    handleEvents=handleEvents,
    instantiateKwargs...)

    ignore_derivatives() do

        # instantiate (hard)
        if instantiate
            # remove old one if we missed it (callback)
            if cleanup && c != nothing
                c = finishSolveFMU(fmu, c; freeInstance=freeInstance, terminate=terminate)
            end

            c = fmi2Instantiate!(fmu; type=type, instantiateKwargs...)
        else # use existing instance
            if c === nothing
                if hasCurrentInstance(fmu)
                    c = getCurrentInstance(fmu)
                else
                    @warn "Found no FMU instance, but executionConfig doesn't force allocation. Allocating one.\nUse `fmi2Instantiate(fmu)` to prevent this message."
                    c = fmi2Instantiate!(fmu; type=type, instantiateKwargs...)
                end
            end
        end

        @assert !isnothing(c) "No FMU instance available, allocate one or use `fmu.executionConfig.instantiate=true`."

        # soft terminate (if necessary)
        # if terminate
        #     retcode = fmi2Terminate(c; soft=true)
        #     @assert retcode == fmi2StatusOK "fmi2Simulate(...): Termination failed with return code $(retcode)."
        # end

        # soft reset (if necessary)
        if reset
            retcode = fmi2Reset(c; soft=true)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Reset failed with return code $(retcode)."
        end 

        # setup experiment (hard)
        if setup
            retcode = fmi2SetupExperiment(c, t_start, t_stop; tolerance=tolerance)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting up experiment failed with return code $(retcode)."
        end

        # parameters
        if parameters !== nothing
            retcodes = setValue(c, collect(keys(parameters)), collect(values(parameters)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end

        # inputs
        if inputs !== nothing
            retcodes = setValue(c, collect(keys(inputs)), collect(values(inputs)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # start state
        if !isnothing(x0)
            #retcode = fmi2SetContinuousStates(c, x0)
            #@assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = setValue(c, fmu.modelDescription.stateValueReferences, x0; filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial states failed with return code $(retcode)."
        end

        # enter (hard)
        if setup
            retcode = fmi2EnterInitializationMode(c)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Entering initialization mode failed with return code $(retcode)."
        end

        # parameters
        if parameters !== nothing
            retcodes = setValue(c, collect(keys(parameters)), collect(values(parameters)); filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial parameters failed with return code $(retcodes)."
        end
            
        # inputs
        if inputs !== nothing
            retcodes = setValue(c, collect(keys(inputs)), collect(values(inputs)); filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcodes)."
        end

        # start state
        if !isnothing(x0)
            #retcode = fmi2SetContinuousStates(c, x0)
            #@assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = setValue(c, fmu.modelDescription.stateValueReferences, x0; filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcodes)."

            # safe start state in component
            c.x = copy(x0)
        end

        # exit setup (hard)
        if setup
            retcode = fmi2ExitInitializationMode(c)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Exiting initialization mode failed with return code $(retcode)."
        end

        # allocate a solution object
        c.solution = FMUSolution(c)

        # ME specific
        if type == fmi2TypeModelExchange
            if isnothing(x0) && !c.fmu.isZeroState
                x0 = fmi2GetContinuousStates(c)
            end

            if instantiate || reset # we have a fresh instance 
                @debug "[NEW INST]"
                handleEvents(c) 
            end

            c.fmu.hasStateEvents = (c.fmu.modelDescription.numberOfEventIndicators > 0)
            c.fmu.hasTimeEvents = isTrue(c.eventInfo.nextEventTimeDefined)
        end
    end

    return c, x0
end
function prepareSolveFMU(fmu::FMU2, c::Union{Nothing, FMU2Component}, type::Symbol; kwargs...)
    if type == :CS
        return prepareSolveFMU(fmu, c, fmi2TypeCoSimulation; kwargs...)
    elseif type == :ME
        return prepareSolveFMU(fmu, c, fmi2TypeModelExchange; kwargs...)
    elseif type == :SE
        @assert false "FMU type `SE` is not supported in FMI2!"
    else
        @assert false "Unknwon FMU type `$(type)`"
    end
end

function finishSolveFMU(fmu::FMU2, c::FMU2Component;
    freeInstance::Union{Nothing, Bool}=nothing, 
    terminate::Union{Nothing, Bool}=nothing,
     popComponent::Bool=true)

    if isnothing(c) 
        return 
    end

    ignore_derivatives() do
        if terminate === nothing 
            terminate = fmu.executionConfig.terminate
        end

        if freeInstance === nothing 
            freeInstance = fmu.executionConfig.freeInstance
        end

        # soft terminate (if necessary)
        if terminate
            retcode = fmi2Terminate(c; soft=true)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Termination failed with return code $(retcode)."
        end

        # freeInstance (hard)
        if freeInstance
            fmi2FreeInstance!(c; popComponent=popComponent) # , doccall=freeInstance
            c = nothing
        end
    end

    return c
end