#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMICore: getAttributes, fmi2ScalarVariable

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

function prepareSolveFMU(fmu::FMU2, 
    c::Union{Nothing, FMU2Component}, 
    type::fmi2Type, 
    instantiate::Union{Nothing, Bool}=nothing, 
    freeInstance::Union{Nothing, Bool}=nothing, 
    terminate::Union{Nothing, Bool}=nothing, 
    reset::Union{Nothing, Bool}=nothing, 
    setup::Union{Nothing, Bool}=nothing, 
    parameters::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    t_start::Real=0.0, 
    t_stop::Union{Real, Nothing}=nothing, 
    tolerance::Union{Real, Nothing}=nothing;
    x0::Union{AbstractArray{<:Real}, Nothing}=nothing, 
    inputs::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    cleanup::Bool=false, 
    handleEvents=handleEvents)

    ignore_derivatives() do
        if instantiate === nothing 
            instantiate = fmu.executionConfig.instantiate
        end

        if freeInstance === nothing 
            freeInstance = fmu.executionConfig.freeInstance
        end

        if terminate === nothing 
            terminate = fmu.executionConfig.terminate
        end

        if reset === nothing 
            reset = fmu.executionConfig.reset 
        end

        if setup === nothing 
            setup = fmu.executionConfig.setup 
        end 

        # instantiate (hard)
        if instantiate
            # remove old one if we missed it (callback)
            if cleanup && c != nothing
                c = finishSolveFMU(fmu, c, freeInstance, terminate)
            end

            c = fmi2Instantiate!(fmu; type=type)
        else # use existing instance
            if c === nothing
                if hasCurrentComponent(fmu)
                    c = getCurrentComponent(fmu)
                else
                    @warn "Found no FMU instance, but executionConfig doesn't force allocation. Allocating one.\nUse `fmi2Instantiate(fmu)` to prevent this message."
                    c = fmi2Instantiate!(fmu; type=type)
                end
            end
        end

        @assert c != nothing "No FMU instance available, allocate one or use `fmu.executionConfig.instantiate=true`."

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
            retcodes = fmi2Set(c, collect(keys(parameters)), collect(values(parameters)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end

        # inputs
        if inputs !== nothing
            retcodes = fmi2Set(c, collect(keys(inputs)), collect(values(inputs)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end

        # start state
        if x0 !== nothing
            #retcode = fmi2SetContinuousStates(c, x0)
            #@assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = fmi2Set(c, fmu.modelDescription.stateValueReferences, x0; filter=setBeforeInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial states failed with return code $(retcode)."
        end

        # enter (hard)
        if setup
            retcode = fmi2EnterInitializationMode(c)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Entering initialization mode failed with return code $(retcode)."
        end

        # parameters
        if parameters !== nothing
            retcodes = fmi2Set(c, collect(keys(parameters)), collect(values(parameters)); filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial parameters failed with return code $(retcodes)."
        end
            
        # inputs
        if inputs !== nothing
            retcodes = fmi2Set(c, collect(keys(inputs)), collect(values(inputs)); filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcodes)."
        end

        # start state
        if x0 !== nothing
            #retcode = fmi2SetContinuousStates(c, x0)
            #@assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = fmi2Set(c, fmu.modelDescription.stateValueReferences, x0; filter=setInInitialization)
            @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial inputs failed with return code $(retcodes)."
        end

        # exit setup (hard)
        if setup
            retcode = fmi2ExitInitializationMode(c)
            @assert retcode == fmi2StatusOK "fmi2Simulate(...): Exiting initialization mode failed with return code $(retcode)."
        end

        # allocate a solution object
        c.solution = FMU2Solution(c)

        # ME specific
        if type == fmi2TypeModelExchange
            if x0 == nothing && !c.fmu.isZeroState
                x0 = fmi2GetContinuousStates(c)
            end

            if instantiate || reset # we have a fresh instance 
                @debug "[NEW INST]"
                handleEvents(c) 
            end
        end
    end

    return c, x0
end


# Handles events and returns the values and nominals of the changed continuous states.
function handleEvents(c::FMU2Component)

    @assert c.state == fmi2ComponentStateEventMode "handleEvents(...): Must be in event mode!"

    #@debug "Handle Events..."

    # trigger the loop
    c.eventInfo.newDiscreteStatesNeeded = fmi2True

    valuesOfContinuousStatesChanged = fmi2False
    nominalsOfContinuousStatesChanged = fmi2False
    nextEventTimeDefined = fmi2False
    nextEventTime = 0.0

    numCalls = 0
    while c.eventInfo.newDiscreteStatesNeeded == fmi2True
        numCalls += 1
        fmi2NewDiscreteStates!(c, c.eventInfo)

        if c.eventInfo.valuesOfContinuousStatesChanged == fmi2True
            valuesOfContinuousStatesChanged = fmi2True
        end

        if c.eventInfo.nominalsOfContinuousStatesChanged == fmi2True
            nominalsOfContinuousStatesChanged = fmi2True
        end

        if c.eventInfo.nextEventTimeDefined == fmi2True
            nextEventTimeDefined = fmi2True
            nextEventTime = c.eventInfo.nextEventTime
        end

        if c.eventInfo.terminateSimulation == fmi2True
            @error "handleEvents(...): FMU throws `terminateSimulation`!"
        end

        @assert numCalls <= c.fmu.executionConfig.maxNewDiscreteStateCalls "handleEvents(...): `fmi2NewDiscreteStates!` exceeded $(c.fmu.executionConfig.maxNewDiscreteStateCalls) calls, this may be an error in the FMU. If not, you can change the max value for this FMU in `fmu.executionConfig.maxNewDiscreteStateCalls`."
    end

    c.eventInfo.valuesOfContinuousStatesChanged = valuesOfContinuousStatesChanged
    c.eventInfo.nominalsOfContinuousStatesChanged = nominalsOfContinuousStatesChanged
    c.eventInfo.nextEventTimeDefined = nextEventTimeDefined
    c.eventInfo.nextEventTime = nextEventTime

    @assert fmi2EnterContinuousTimeMode(c) == fmi2StatusOK "FMU is not in state continuous time after event handling."

    return nothing
end

function prepareSolveFMU(fmu::Vector{FMU2}, c::AbstractVector{Union{FMU2Component, Nothing}}, type::fmi2Type, instantiate::Union{Nothing, Bool}, freeInstance::Union{Nothing, Bool}, terminate::Union{Nothing, Bool}, reset::Union{Nothing, Bool}, setup::Union{Nothing, Bool}, parameters::Union{Vector{Union{Dict{<:Any, <:Any}, Nothing}}, Nothing}, t_start, t_stop, tolerance;
    x0::Union{Vector{Union{Array{<:Real}, Nothing}}, Nothing}=nothing, initFct=nothing, cleanup::Bool=false, 
    handleEvents=handleEvents)

    ignore_derivatives() do
        for i in 1:length(fmu)

            if instantiate === nothing
                instantiate = fmu[i].executionConfig.instantiate
            end

            if freeInstance === nothing 
                freeInstance = fmu[i].executionConfig.freeInstance
            end

            if terminate === nothing 
                terminate = fmu[i].executionConfig.terminate
            end

            if reset === nothing
                reset = fmu[i].executionConfig.reset
            end

            if setup === nothing
                setup = fmu[i].executionConfig.setup
            end

            # instantiate (hard)
            if instantiate
                # remove old one if we missed it (callback)
                if cleanup && c[i] != nothing
                    c[i] = finishSolveFMU(fmu[i], c[i], freeInstance, terminate)
                end

                c[i] = fmi2Instantiate!(fmu[i]; type=type)
                @debug "[NEW INST]"
            else
                if c[i] === nothing
                    if length(fmu[i].components) > 0
                        c[i] = getCurrentComponent(fmu[i])
                    else
                        @warn "Found no FMU instance, but executionConfig doesn't force allocation. Allocating one. Use `fmi2Instantiate(fmu)` to prevent this message."
                        c[i] = fmi2Instantiate!(fmu[i]; type=type)
                    end
                end
            end

            # soft terminate (if necessary)
            # if terminate
            #     retcode = fmi2Terminate(c[i]; soft=true)
            #     @assert retcode == fmi2StatusOK "fmi2Simulate(...): Termination failed with return code $(retcode)."
            # end

            # soft reset (if necessary)
            if reset
                retcode = fmi2Reset(c[i]; soft=true)
                @assert retcode == fmi2StatusOK "fmi2Simulate(...): Reset failed with return code $(retcode)."
            end

            # enter setup (hard)
            if setup
                retcode = fmi2SetupExperiment(c[i], t_start, t_stop; tolerance=tolerance)
                @assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting up experiment failed with return code $(retcode)."

                retcode = fmi2EnterInitializationMode(c[i])
                @assert retcode == fmi2StatusOK "fmi2Simulate(...): Entering initialization mode failed with return code $(retcode)."
            end

            if x0 !== nothing
                if x0[i] !== nothing
                    retcode = fmi2SetContinuousStates(c[i], x0[i])
                    @assert retcode == fmi2StatusOK "fmi2Simulate(...): Setting initial state failed with return code $(retcode)."
                end
            end

            if parameters !== nothing
                if parameters[i] !== nothing
                    retcodes = fmi2Set(c[i], collect(keys(parameters[i])), collect(values(parameters[i])) )
                    @assert all(retcodes .== fmi2StatusOK) "fmi2Simulate(...): Setting initial parameters failed with return code $(retcode)."
                end
            end

            if initFct !== nothing
                initFct()
            end

            # exit setup (hard)
            if setup
                retcode = fmi2ExitInitializationMode(c[i])
                @assert retcode == fmi2StatusOK "fmi2Simulate(...): Exiting initialization mode failed with return code $(retcode)."
            end

            if type == fmi2TypeModelExchange
                if x0 === nothing
                    if x0[i] === nothing
                        x0[i] = fmi2GetContinuousStates(c[i])
                    end
                end

                if instantiate || reset # we have a fresh instance 
                    @debug "[NEW INST]"
                    handleEvents(c[i]) 
                end
            end

            c[i].solution = FMU2Solution(c[i])
        end

    end # ignore_derivatives

    return c, x0
end

function finishSolveFMU(fmu::FMU2, c::FMU2Component, freeInstance::Union{Nothing, Bool}, terminate::Union{Nothing, Bool}; popComponent::Bool=true)

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
        fmi2FreeInstance!(c; popComponent=popComponent, doccall=freeInstance)
        c = nothing
    end

    return c
end

function finishSolveFMU(fmu::Vector{FMU2}, c::AbstractVector{Union{FMU2Component, Nothing}}, freeInstance::Union{Nothing, Bool}, terminate::Union{Nothing, Bool})

    ignore_derivatives() do
        for i in 1:length(fmu)
            if terminate === nothing
                terminate = fmu[i].executionConfig.terminate
            end

            if freeInstance === nothing
                freeInstance = fmu[i].executionConfig.freeInstance
            end

            if c[i] != nothing

                # soft terminate (if necessary)
                if terminate
                    retcode = fmi2Terminate(c[i]; soft=true)
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