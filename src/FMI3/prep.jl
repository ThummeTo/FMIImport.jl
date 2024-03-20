#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function setBeforeInitialization(mv::FMIImport.fmi3Variable)
    return mv.variability != fmi3VariabilityConstant && mv.initial ∈ (fmi3InitialApprox, fmi3InitialExact)
end

function setInInitialization(mv::FMIImport.fmi3Variable)
    return mv.causality == fmi3CausalityInput || (mv.causality != fmi3CausalityParameter && mv.variability == fmi3VariabilityTunable) || (mv.variability != fmi3VariabilityConstant && mv.initial == fmi3InitialExact)
end

function prepareSolveFMU(fmu::FMU3, c::Union{Nothing, FMU3Instance}, type::fmi3Type=fmu.type;
    instantiate::Union{Nothing, Bool}=nothing, 
    freeInstance::Union{Nothing, Bool}=nothing, 
    terminate::Union{Nothing, Bool}=nothing, 
    reset::Union{Nothing, Bool}=nothing, 
    setup::Union{Nothing, Bool}=nothing, 
    parameters::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    t_start::Real=0.0, 
    t_stop::Union{Real, Nothing}=nothing, 
    tolerance::Union{Real, Nothing}=nothing,
    x0::Union{AbstractArray{<:Real}, Nothing}=nothing, 
    inputs::Union{Dict{<:Any, <:Any}, Nothing}=nothing, 
    cleanup::Bool=false, 
    handleEvents=handleEvents)

    ignore_derivatives() do
        if instantiate === nothing 
            instantiate = fmu.executionConfig.instantiate
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
    
        c = nothing
    
        # instantiate (hard)
        if instantiate
            if type == fmi3TypeCoSimulation
                c = fmi3InstantiateCoSimulation!(fmu)
            elseif type == fmi3TypeModelExchange
                c = fmi3InstantiateModelExchange!(fmu)
            else
                c = fmi3InstantiateScheduledExecution!(fmu)
            end
        else
            if c === nothing
                if length(fmu.instances) > 0
                    c = fmu.instances[end]
                else
                    @warn "Found no FMU instance, but executionConfig doesn't force allocation. Allocating one. Use `fmi3Instantiate(fmu)` to prevent this message."
                    if type == fmi3TypeCoSimulation
                        c = fmi3InstantiateCoSimulation!(fmu)
                    elseif type == fmi3TypeModelExchange
                        c = fmi3InstantiateModelExchange!(fmu)
                    else
                        c = fmi3InstantiateScheduledExecution!(fmu)
                    end
                end
            end
        end
    
        @assert c !== nothing "No FMU instance available, allocate one or use `fmu.executionConfig.instantiate=true`."
    
        # soft terminate (if necessary)
        if terminate
            retcode = fmi3Terminate(c; soft=true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Termination failed with return code $(retcode)."
        end
    
        # soft reset (if necessary)
        if reset
            retcode = fmi3Reset(c; soft=true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Reset failed with return code $(retcode)."
        end 
    
        # setup experiment (hard)
        # TODO this part is handled by fmi3EnterInitializationMode
        # if setup
        #     retcode = fmi2SetupExperiment(c, t_start, t_stop; tolerance=tolerance)
        #     @assert retcode == fmi3StatusOK "fmi3Simulate(...): Setting up experiment failed with return code $(retcode)."
        # end
    
        # parameters
        if parameters !== nothing
            retcodes = fmi3Set(c, collect(keys(parameters)), collect(values(parameters)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end
    
        # inputs
        inputs = nothing
        if inputFunction !== nothing && inputValueReferences !== nothing
            # set inputs
            inputs = Dict{fmi3ValueReference, Any}()
    
            inputValues = nothing
            if hasmethod(inputFunction, Tuple{FMU3Instance, fmi3Float64}) # CS
              inputValues = inputFunction(c, t_start)
            else # ME
                inputValues = inputFunction(c, nothing, t_start)
            end
    
            for i in 1:length(inputValueReferences)
                vr = inputValueReferences[i]
                inputs[vr] = inputValues[i]
            end
        end
    
        # inputs
        if inputs !== nothing
            retcodes = fmi3Set(c, collect(keys(inputs)), collect(values(inputs)); filter=setBeforeInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end
    
        # start state
        if x0 !== nothing
            #retcode = fmi3SetContinuousStates(c, x0)
            #@assert retcode == fmi3StatusOK "fmi3Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = fmi3Set(c, fmu.modelDescription.stateValueReferences, x0; filter=setBeforeInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end
    
        # enter (hard)
        if setup
            retcode = fmi3EnterInitializationMode(c, t_start, t_stop; tolerance = tolerance)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Entering initialization mode failed with return code $(retcode)."
        end
    
        # parameters
        if parameters !== nothing
            retcodes = fmi3Set(c, collect(keys(parameters)), collect(values(parameters)); filter=setInInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial parameters failed with return code $(retcode)."
        end
    
        if inputs !== nothing
            retcodes = fmi3Set(c, collect(keys(inputs)), collect(values(inputs)); filter=setInInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end
    
        # start state
        if x0 !== nothing
            #retcode = fmi3SetContinuousStates(c, x0)
            #@assert retcode == fmi3StatusOK "fmi3Simulate(...): Setting initial state failed with return code $(retcode)."
            retcodes = fmi3Set(c, fmu.modelDescription.stateValueReferences, x0; filter=setInInitialization)
            @assert all(retcodes .== fmi3StatusOK) "fmi3Simulate(...): Setting initial inputs failed with return code $(retcode)."
        end
    
        # exit setup (hard)
        if setup
            retcode = fmi3ExitInitializationMode(c)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Exiting initialization mode failed with return code $(retcode)."
        end
    
        if type == fmi3TypeModelExchange
            if x0 === nothing
                x0 = fmi3GetContinuousStates(c)
            end
        end
    end

    return c, x0
end

# Handles events and returns the values and nominals of the changed continuous states.
function handleEvents(c::FMU3Instance)

    @assert c.state == fmi2ComponentStateEventMode "handleEvents(...): Must be in event mode!"

    # invalidate all cached jacobians/gradients 
    invalidate!(c.∂ẋ_∂x) 
    invalidate!(c.∂ẋ_∂u)
    invalidate!(c.∂ẋ_∂p)  
    invalidate!(c.∂y_∂x) 
    invalidate!(c.∂y_∂u)
    invalidate!(c.∂y_∂p)
    invalidate!(c.∂e_∂x) 
    invalidate!(c.∂e_∂u)
    invalidate!(c.∂e_∂p)
    invalidate!(c.∂ẋ_∂t)
    invalidate!(c.∂y_∂t)
    invalidate!(c.∂e_∂t)

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

function finishSolveFMU(fmu::FMU3, c::FMU3Instance;
    freeInstance::Union{Nothing, Bool}=nothing, 
    terminate::Union{Nothing, Bool}=nothing,
    popComponent::Bool=true)

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
            retcode = fmi3Terminate(c; soft=true)
            @assert retcode == fmi3StatusOK "fmi3Simulate(...): Termination failed with return code $(retcode)."
        end
    
        # freeInstance (hard)
        if freeInstance
            fmi3FreeInstance!(c)
        end
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