#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""
    getState(solution::FMUSolution, i::fmi2ValueReferenceFormat; isIndex::Bool=false)

Returns the solution state for a given value reference `i` (for `isIndex=false`) or the i-th state (for `isIndex=true`). 
"""
function getState(solution::FMUSolution, vrs::fmi2ValueReferenceFormat; isIndex::Bool=false)

    indices = []

    if isIndex
        if length(vrs) == 1
            indices = [vrs]
        else
            indices = vrs
        end
    else
        ignore_derivatives() do
            vrs = prepareValueReference(solution.component.fmu, vrs)

            if !isnothing(solution.states)
                for vr in vrs
                    found = false
                    for i in 1:length(solution.component.fmu.modelDescription.stateValueReferences)
                        if solution.component.fmu.modelDescription.stateValueReferences[i] == vr
                            push!(indices, i)
                            found = true 
                            break
                        end
                    end
                    @assert found "Couldn't find the index for value reference `$(vr)`! This is probably because this value reference does not belong to a system state."
                end
            end

        end # ignore_derivatives
    end

    # found something
    if length(indices) == length(vrs)

        if length(vrs) == 1  # single value
            return collect(u[indices[1]] for u in solution.states.u)

        else # multi value
            return collect(collect(u[indices[i]] for u in solution.states.u) for i in 1:length(indices))

        end
    end

    return nothing
end
export getState

"""
    getStateDerivative(solution::FMUSolution, i::fmi2ValueReferenceFormat; isIndex::Bool=false)

Returns the solution state derivative for a given value reference `i` (for `isIndex=false`) or the i-th state (for `isIndex=true`). 
"""
function getStateDerivative(solution::FMUSolution, vrs::fmi2ValueReferenceFormat; isIndex::Bool=false, order::Integer=1)
    indices = []

    if isIndex
        if length(vrs) == 1
            indices = [vrs]
        else
            indices = vrs
        end
    else
        ignore_derivatives() do
            vrs = prepareValueReference(solution.component.fmu, vrs)

            if !isnothing(solution.states)
                for vr in vrs
                    found = false
                    for i in 1:length(solution.component.fmu.modelDescription.stateValueReferences)
                        if solution.component.fmu.modelDescription.stateValueReferences[i] == vr
                            push!(indices, i)
                            found = true 
                            break
                        end
                    end
                    @assert found "Couldn't find the index for value reference `$(vr)`! This is probably because this value reference does not belong to a system state."
                end
            end

        end # ignore_derivatives
    end

    # found something
    if length(indices) == length(vrs)

        if length(vrs) == 1  # single value
            return collect(solution.states(t, Val{order})[indices[1]] for t in solution.states.t)

        else # multi value
            return collect(collect(solution.states(t, Val{order})[indices[i]] for t in solution.states.t) for i in 1:length(indices))
        end
    end

    return nothing
end
export getStateDerivative

"""
    getValue(solution::FMU2Solution, i::fmi2ValueReferenceFormat; isIndex::Bool=false)

Returns the values for a given value reference `i` (for `isIndex=false`) or the i-th value (for `isIndex=true`). 
Recording of values must be enabled.
"""
function FMIBase.getValue(solution::FMUSolution, vrs::fmi2ValueReferenceFormat; isIndex::Bool=false)

    indices = []

    if isIndex
        if length(vrs) == 1
            indices = [vrs]
        else
            indices = vrs
        end
    else
        ignore_derivatives() do
            vrs = prepareValueReference(solution.component.fmu, vrs)

            if !isnothing(solution.values)
                for vr in vrs
                    found = false
                    for i in 1:length(solution.valueReferences)
                        if solution.valueReferences[i] == vr
                            push!(indices, i)
                            found = true 
                            break
                        end
                    end
                    @assert found "Couldn't find the index for value reference `$(vr)`! This is probably because this value reference does not exist for this system."
                end
            end

        end # ignore_derivatives
    end

    # found something
    if length(indices) == length(vrs)

        if length(vrs) == 1  # single value
            return collect(u[indices[1]] for u in solution.values.saveval)

        else # multi value
            return collect(collect(u[indices[i]] for u in solution.values.saveval) for i in 1:length(indices))

        end
    end

    return nothing
end
export getValue

"""
    getTime(solution::FMU2Solution)

Returns the points in time of the solution `solution`. 
"""
function getTime(solution::FMUSolution)
    if !isnothing(solution.states)
        return solution.states.t
    elseif !isnothing(solution.values)
        return solution.values.t
    else
        return nothing
    end
end
export getTime