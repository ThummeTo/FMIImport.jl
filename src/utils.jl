#
# Copyright (c) 2022 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import SciMLSensitivity.ForwardDiff
import SciMLSensitivity.ReverseDiff

# check if scalar/vector is ForwardDiff.Dual
function isdual(e)
    return false 
end
function isdual(e::ForwardDiff.Dual{T, V, N}) where {T, V, N}
    return true
end
function isdual(e::AbstractVector{<:ForwardDiff.Dual{T, V, N}}) where {T, V, N}
    return true
end

# check if scalar/vector is ForwardDiff.Dual
function istracked(e)
    return false 
end
function istracked(e::ReverseDiff.TrackedReal) 
    return true
end
function istracked(e::AbstractVector{<:ReverseDiff.TrackedReal}) 
    return true
end

# check types (Tag, Variable, Number) of ForwardDiff.Dual scalar/vector
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

function rd_set!(dst::AbstractArray{<:Real}, src::AbstractArray{<:Real})

    @assert length(dst) == length(src) "rd_set! dimension mismatch"

    if istracked(src)
        if istracked(dst)
            dst[:] = src

            # for i in 1:length(dst)
            #     dst[i] = src[i]
            # end
        else 
            dst[:] = collect(ReverseDiff.value(e) for e in src)

            # for i in 1:length(dst)
            #     dst[i] = ForwardDiff.value(e)
            # end
        end
        
    else 
        if istracked(dst)

            #@info "dst [$(length(dst))]: $dst"
            #@info "src [$(length(src))]: $src"
            #@info "$(collect(dst[i] for i in 1:length(dst)))"
           
            dst[:] = collect(ReverseDiff.TrackedReal(ReverseDiff.value(src[i]), 0.0    ) for i in 1:length(dst))
            #dst[:] = collect(ReverseDiff.TrackedReal(ReverseDiff.value(src[i]), ReverseDiff.deriv(dst[i]), ReverseDiff.tape(dst[i])    ) for i in 1:length(dst))
            #dst[:] = collect(ReverseDiff.TrackedReal(ReverseDiff.value(src[i]), ReverseDiff.deriv(dst[i])  ) for i in 1:length(dst))

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

# makes Reals from ReverseDiff.TrackedXXX scalar/vector
function untrack(e::AbstractArray)
    return collect(untrack(c) for c in e)
end
function untrack(e::Tuple)
    return (collect(untrack(c) for c in e)...,)
end
function untrack(e::ReverseDiff.TrackedReal)
    return ReverseDiff.value(e)
end
function untrack(e::ReverseDiff.TrackedArray)
    return ReverseDiff.value(e)
end
function untrack(::Nothing)
    return nothing
end
function untrack(e)
    return e
end

# makes Reals from ForwardDiff/ReverseDiff.TrackedXXX scalar/vector
function unsense(e::AbstractArray)
    return collect(unsense(c) for c in e)
end
function unsense(e::Tuple)
    return (collect(unsense(c) for c in e)...,)
end
function unsense(e::ReverseDiff.TrackedReal)
    return ReverseDiff.value(e)
end
function unsense(e::ReverseDiff.TrackedArray)
    return ReverseDiff.value(e)
end
function unsense(e::ForwardDiff.Dual)
    return ForwardDiff.value(e)
end
function unsense(::Nothing)
    return nothing
end
function unsense(e)
    return e
end

# checks if integrator has NaNs (that is not good...)
function assert_integrator_valid(integrator)
    @assert !isnan(integrator.opts.internalnorm(integrator.u, integrator.t)) "NaN in `integrator.u` @ $(integrator.t)."
end
