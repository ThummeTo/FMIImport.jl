#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIBase: isEventMode, isContinuousTimeMode, isTrue, isStatusOK
using FMIBase: handleEvents, getDiscreteStates

function setBeforeInitialization(mv::FMIImport.fmi3Variable)
    return mv.variability != fmi3VariabilityConstant &&
           mv.initial ∈ (fmi3InitialApprox, fmi3InitialExact)
end

function setInInitialization(mv::FMIImport.fmi3Variable)
    return mv.causality == fmi3CausalityInput ||
           (
               mv.causality != fmi3CausalityParameter &&
               mv.variability == fmi3VariabilityTunable
           ) ||
           (mv.variability != fmi3VariabilityConstant && mv.initial == fmi3InitialExact)
end

function prepareSolveFMU(
    fmu::FMU3,
    c::Union{Nothing,FMU3Instance},
    type::fmi3Type = fmu.type;
    instantiate::Union{Nothing,Bool} = fmu.executionConfig.instantiate,
    freeInstance::Union{Nothing,Bool} = fmu.executionConfig.freeInstance,
    terminate::Union{Nothing,Bool} = fmu.executionConfig.terminate,
    reset::Union{Nothing,Bool} = fmu.executionConfig.reset,
    setup::Union{Nothing,Bool} = fmu.executionConfig.setup,
    parameters::Union{Dict{<:Any,<:Any},Nothing} = nothing,
    t_start::Real = 0.0,
    t_stop::Union{Real,Nothing} = nothing,
    tolerance::Union{Real,Nothing} = nothing,
    x0::Union{AbstractArray{<:Real},Nothing} = nothing,
    inputs::Union{Dict{<:Any,<:Any},Nothing} = nothing,
    cleanup::Bool = false,
    handleEvents = handleEvents,
    instantiateKwargs...,
)

    ignore_derivatives() do

        autoInstantiated = false

        c = nothing

        # instantiate (hard)
        if instantiate
            if type == fmi3TypeCoSimulation
                c = fmi3InstantiateCoSimulation!(fmu; instantiateKwargs...)
            elseif type == fmi3TypeModelExchange
                c = fmi3InstantiateModelExchange!(fmu; instantiateKwargs...)
            elseif type == fmi3TypeScheduledExecution
                c = fmi3InstantiateScheduledExecution!(fmu; instantiateKwargs...)
            else
                @assert false "Unknown fmi3Type `$(type)`"
            end
        else
            if c === nothing
                if length(fmu.instances) > 0
                    c = fmu.instances[end]
                else
                    @warn "Found no FMU instance, but executionConfig doesn't force allocation. Allocating one. Use `fmi3Instantiate[TYPE](fmu)` to prevent this message."
                    if type == fmi3TypeCoSimulation
                        c = fmi3InstantiateCoSimulation!(fmu; instantiateKwargs...)
                        autoInstantiated = true
                    elseif type == fmi3TypeModelExchange
                        c = fmi3InstantiateModelExchange!(fmu; instantiateKwargs...)
                        autoInstantiated = true
                    elseif type == fmi3TypeScheduledExecution
                        c = fmi3InstantiateScheduledExecution!(fmu; instantiateKwargs...)
                        autoInstantiated = true
                    else
                        @assert false "Unknown FMU type `$(type)`."
                    end
                end
            end
        end

        @assert !isnothing(c) "No FMU instance available, allocate one or use `fmu.executionConfig.instantiate=true`."

        # soft terminate (if necessary)
        if terminate
            retcode = fmi3Terminate(c; soft = true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Termination failed with return code $(retcode)."
        end

        # soft reset (if necessary)
        if reset
            retcode = fmi3Reset(c; soft = true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Reset failed with return code $(retcode)."
        end

        # setup experiment (hard)
        # [Note] this part is handled by fmi3EnterInitializationMode

        # parameters
        if !isnothing(parameters)
            retcodes = setValue(
                c,
                collect(keys(parameters)),
                collect(values(parameters));
                filter = setBeforeInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end

        # inputs
        if !isnothing(inputs)
            retcodes = setValue(
                c,
                collect(keys(inputs)),
                collect(values(inputs));
                filter = setBeforeInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # start state
        if !isnothing(x0)
            #retcode = fmi3SetContinuousStates(c, x0)
            #@assert retcode == fmi3StatusOK "fmi3Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = setValue(
                c,
                fmu.modelDescription.stateValueReferences,
                x0;
                filter = setBeforeInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # enter (hard)
        if setup
            retcode = fmi3EnterInitializationMode(c, t_start, t_stop; tolerance = tolerance)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Entering initialization mode failed with return code $(retcode)."
        end

        # parameters
        if parameters !== nothing
            retcodes = setValue(
                c,
                collect(keys(parameters)),
                collect(values(parameters));
                filter = setInInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end

        if inputs !== nothing
            retcodes = setValue(
                c,
                collect(keys(inputs)),
                collect(values(inputs));
                filter = setInInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # start state
        if x0 !== nothing
            #retcode = fmi3SetContinuousStates(c, x0)
            #@assert retcode == fmi3StatusOK "fmi3Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = setValue(
                c,
                fmu.modelDescription.stateValueReferences,
                x0;
                filter = setInInitialization,
            )
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # exit setup (hard)
        if setup
            retcode = fmi3ExitInitializationMode(c)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Exiting initialization mode failed with return code $(retcode)."
        end

        # allocate a solution object
        c.solution = FMUSolution(c)

        # ME specific
        if type == fmi3TypeModelExchange
            if isnothing(x0) && !c.fmu.isZeroState
                x0 = fmi3GetContinuousStates(c)
            else
                # Info: this is just for consistency, value is not used.
                fmi3GetContinuousStates(c)
            end

            # if c.fmu.isDummyDiscrete
            #     c.x_d = [0.0]
            #     if isnothing(x0)
            #         x0 = c.x_d
            #     else
            #         x0 = vcat(x0, c.x_d)
            #     end
            # else
            #     c.x_d = getDiscreteStates(c)
            # end
            c.x_d = getDiscreteStates(c)

            c.x_nominals = fmi3GetNominalsOfContinuousStates(c)

            if instantiate || reset # autoInstantiated 
                @debug "[AUTO] setup"

                if !setup
                    fmi3EnterInitializationMode(c, t_start, t_stop; tolerance = tolerance)
                    fmi3ExitInitializationMode(c)
                end

                handleEvents(c)
            end

            c.fmu.hasStateEvents = (c.fmu.modelDescription.numberOfEventIndicators > 0)
            c.fmu.hasTimeEvents = isTrue(c.nextEventTimeDefined)
        end

    end

    return c, x0
end
function prepareSolveFMU(fmu::FMU3, c::Union{Nothing,FMU3Instance}, type::Symbol; kwargs...)
    if type == :CS
        return prepareSolveFMU(fmu, c, fmi3TypeCoSimulation; kwargs...)
    elseif type == :ME
        return prepareSolveFMU(fmu, c, fmi3TypeModelExchange; kwargs...)
    elseif type == :SE
        return prepareSolveFMU(fmu, c, fmi3TypeScheduledExecution; kwargs...)
    else
        @assert false "Unknown FMU type `$(type)`"
    end
end

function finishSolveFMU(
    fmu::FMU3,
    c::FMU3Instance;
    freeInstance::Union{Nothing,Bool} = nothing,
    terminate::Union{Nothing,Bool} = nothing,
    popComponent::Bool = true,
)

    if isnothing(c)
        return
    end

    ignore_derivatives() do
        if c === nothing
            return
        end

        if terminate === nothing
            terminate = fmu.executionConfig.terminate
        end

        if freeInstance === nothing
            freeInstance = fmu.executionConfig.freeInstance
        end

        # soft terminate (if necessary)
        if terminate
            retcode = fmi3Terminate(c; soft = true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Termination failed with return code $(retcode)."
        end

        # freeInstance (hard)
        if freeInstance
            fmi3FreeInstance!(c)
        end
    end

    return c
end

function finishSolveFMU(
    fmu::Vector{FMU2},
    c::AbstractVector{Union{FMU2Component,Nothing}},
    freeInstance::Union{Nothing,Bool},
    terminate::Union{Nothing,Bool},
)

    ignore_derivatives() do
        for i = 1:length(fmu)
            if terminate === nothing
                terminate = fmu[i].executionConfig.terminate
            end

            if freeInstance === nothing
                freeInstance = fmu[i].executionConfig.freeInstance
            end

            if c[i] != nothing

                # soft terminate (if necessary)
                if terminate
                    retcode = fmi2Terminate(c[i]; soft = true)
                    @assert retcode == fmi2StatusOK "fmi2Simulate(...): Termination failed with return code $(retcode)."
                end

                if freeInstance
                    fmi2FreeInstance!(c[i])
                    @debug "[RELEASED INST]"
                end
                c[i] = nothing
            end
        end

    end # ignore_derivatives

    return c
end
