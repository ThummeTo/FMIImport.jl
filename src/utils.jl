#
# Copyright (c) 2022 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_sens.jl`?
# - calling function for FMU2 and FMU2Component
# - ForwardDiff- and ChainRulesCore-Sensitivities over FMUs
# - ToDo: colouring of dependency types (known from model description) for fast jacobian build-ups

import ForwardDiff

# check if scalar/vector is ForwardDiff.dual
function isdual(e)
    return false 
end
function isdual(e::ForwardDiff.Dual{T, V, N}) where {T, V, N}
    return true
end
function isdual(e::AbstractVector{<:ForwardDiff.Dual{T, V, N}}) where {T, V, N}
    return true
end

# check types (Tag, Variable, Number) of ForwardDiff.dual scalar/vector
function fd_eltypes(e::ForwardDiff.Dual{T, V, N}) where {T, V, N}
    return (T, V, N)
end
function fd_eltypes(e::AbstractVector{<:ForwardDiff.Dual{T, V, N}}) where {T, V, N}
    return (T, V, N)
end

# overwrites a ForwardDiff.Dual in-place 
# inheritates partials
function fd_set!(dst::AbstractArray{<:Real}, src::AbstractArray{<:Real})
    if isdual(src)
        if isdual(dst)
            dst[:] = src

            # for i in 1:length(dst)
            #     dst[i] = src[i]
            # end
        else 
            dst[:] = collect(ForwardDiff.value(e) for e in src)

            # for i in 1:length(dst)
            #     dst[i] = ForwardDiff.value(e)
            # end
        end
        
    else 
        if isdual(dst)
            T, V, N = fd_eltypes(dst)

            dst[:] = collect(ForwardDiff.Dual{T, V, N}(V(src[i]), ForwardDiff.partials(dst[i])    ) for i in 1:length(dst))

            # for i in 1:length(dst)
            #     dst[i] = ForwardDiff.Dual{T, V, N}(V(src[i]), ForwardDiff.partials(dst[i])    ) 
            # end
        else
            dst[:] = src

            # for i in 1:length(dst)
            #     dst[i] = src[i]
            # end
        end
    end

    return nothing
end

# makes Reals from ForwardDiff.Dual scalar/vector
function undual(e::AbstractArray)
    return collect(undual(c) for c in e)
end
function undual(e::Tuple)
    return (collect(undual(c) for c in e)...,)
end
function undual(e::ForwardDiff.Dual)
    return ForwardDiff.value(e)
end
function undual(::Nothing)
    return nothing
end
function undual(e)
    return e
end

# checks if integrator has NaNs (that is not good...)
function assert_integrator_valid(integrator)
    @assert !isnan(integrator.opts.internalnorm(integrator.u, integrator.t)) "NaN in `integrator.u` @ $(integrator.t)."
end
