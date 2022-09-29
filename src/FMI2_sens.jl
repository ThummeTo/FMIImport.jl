#
# Copyright (c) 2022 Tobias Thummerer, Lars Mikelsons, Johannes Stoljar
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_sens.jl`?
# - calling function for FMU2
# - ForwardDiff- and ChainRulesCore-Sensitivities over FMUs
# - colouring of dependency types (known from model description) for fast jacobian build-ups

using ForwardDiff
import ToggleableAsserts: @toggled_assert

function (c::FMU2Component)(;dx::Union{AbstractArray{<:Real}, Nothing}=nothing,
                             y::Union{AbstractArray{<:Real}, Nothing}=nothing,
                             y_refs::Union{AbstractArray{fmi2ValueReference}, Nothing}=nothing,
                             x::Union{AbstractArray{<:Real}, Nothing}=nothing, 
                             u::Union{AbstractArray{<:Real}, Nothing}=nothing,
                             u_refs::Union{AbstractArray{fmi2ValueReference}, Nothing}=nothing,
                             t::Union{Real, Nothing}=nothing)

    if fmu.type == :ME
        @toggled_assert dx == nothing "Keyword `dx==nothing` is invalid for ME-FMUs."
        @toggled_assert x == nothing "Keyword `x==nothing` is invalid for ME-FMUs."
    elseif fmu.type == :CS 
        @toggled_assert dx != nothing "Keyword `dx!=nothing` is invalid for ME-FMUs."
        @toggled_assert x != nothing "Keyword `x!=nothing` is invalid for ME-FMUs."
    else 
        @toggled_assert false "Unknown FMU2 type."
    end

    eval!(c, dx, y, y_refs, x, u, u_refs, t)
end

function eval!(c::FMU2Component, 
                 dx::Union{AbstractArray{<:Real}, Nothing},
                 y::Union{AbstractArray{<:Real}, Nothing},
                 y_refs::Union{AbstractArray{fmi2ValueReference}, Nothing},
                 x::Union{AbstractArray{<:Real}, Nothing}, 
                 u::Union{AbstractArray{<:Real}, Nothing},
                 u_refs::Union{AbstractArray{fmi2ValueReference}, Nothing},
                 t::Union{Real, Nothing})

    @toggled_assert !all(isa.(x, ForwardDiff.Dual)) "eval!(...): Wrong dispatched: `x` is ForwardDiff.Dual, please open an issue with MWE."
    @toggled_assert u == nothing || !all(isa.(u, ForwardDiff.Dual)) "eval!(...): Wrong dispatched: `u` is ForwardDiff.Dual, please open an issue with MWE."
    @toggled_assert t == nothing || !isa(t, ForwardDiff.Dual) "eval!(...): Wrong dispatched: `t` is ForwardDiff.Dual, please open an issue with MWE."
    
    # set state
    if x != nothing
        fmi2SetContinuousStates(c, x)
    end

    # set time
    if t != nothing
        fmi2SetTime(c, t)
    end

    # set input
    if u != nothing
        fmi2SetReal(c, u_refs, u)
    end

    # get derivative
    if dx != nothing
        if all(isa.(dx, ForwardDiff.Dual))
            dx_tmp = collect(ForwardDiff.value(e) for e in dx)
            fmi2GetDerivatives!(c, dx_tmp)
            T, V, N = fd_eltypes(dx)
            dx[:] = collect(ForwardDiff.Dual{T, V, N}(dx_tmp[i], ForwardDiff.partials(dx[i])    ) for i in 1:length(dx))
        else 
            fmi2GetDerivatives!(c, dx)
        end
    end

    # get output 
    if y != nothing
        if all(isa.(y, ForwardDiff.Dual))
            y_tmp = collect(ForwardDiff.value(e) for e in y)
            fmi2GetReal!(c, y_refs, y_tmp)
            T, V, N = fd_eltypes(y)
            y[:] = collect(ForwardDiff.Dual{T, V, N}(y_tmp[i], ForwardDiff.partials(y[i])    ) for i in 1:length(y))
        else 
            fmi2GetReal!(c, y_refs, y)
        end
    end

    return y, dx
end

# ForwardDiff-Dispatch for fx
function eval!(c::FMU2Component, 
               dx::Union{AbstractArray{<:Real}, Nothing},
               y::Union{AbstractArray{<:Real}, Nothing},
               y_refs::Union{AbstractArray{fmi2ValueReference}, Nothing},
               x::Union{AbstractArray{<:ForwardDiff.Dual{Tx, Vx, Nx}}, Nothing}, 
               u::Union{AbstractArray{<:ForwardDiff.Dual{Tu, Vu, Nu}}, Nothing},
               u_refs::Union{AbstractArray{fmi2ValueReference}, Nothing},
               t::Union{ForwardDiff.Dual{Tt, Vt, Nt}, Nothing}) where {Tx, Vx, Nx, Tu, Vu, Nu, Tt, Vt, Nt}

    ȧrgs = []
    args = []

    push!(ȧrgs, NoTangent())
    push!(args, eval!)

    push!(ȧrgs, NoTangent())
    push!(args, c)

    #######

    dx_set = (dx != nothing)
    y_set  = (y != nothing)
    x_set  = (x != nothing)
    u_set  = (u != nothing)
    t_set  = (t != nothing)

    if dx_set
        push!(ȧrgs, collect(ForwardDiff.partials(e) for e in dx))
        push!(args, collect(ForwardDiff.value(e) for e in dx))
    else 
        push!(ȧrgs, NoTangent())
        push!(args, dx)
    end

    if y_set
        push!(ȧrgs, collect(ForwardDiff.partials(e) for e in y))
        push!(args, collect(ForwardDiff.value(e) for e in y))
    else 
        push!(ȧrgs, NoTangent())
        push!(args, y)
    end

    if x_set
        push!(ȧrgs, collect(ForwardDiff.partials(e) for e in x))
        push!(args, collect(ForwardDiff.value(e) for e in x))
    else 
        push!(ȧrgs, NoTangent())
        push!(args, x)
    end

    if u_set
        push!(ȧrgs, collect(ForwardDiff.partials(e) for e in u))
        push!(args, collect(ForwardDiff.value(e) for e in u))
    else 
        push!(ȧrgs, NoTangent())
        push!(args, u)
    end

    if t_set
        push!(ȧrgs, ForwardDiff.partials(t))
        push!(args, ForwardDiff.value(t))
    else 
        push!(ȧrgs, NoTangent())
        push!(args, t)
    end

    ȧrgs = (ȧrgs...,)
    args = (args...,)
        
    # frule calls `eval! with non-FD`
    _c, _dx, _y, _y_refs, _x, _u, _u_refs, _t = ChainRulesCore.frule(ȧrgs, args...)

    y_fd = []
    dx_fd = []

    for i in 1:length(_y)
        is = NoTangent()
        
        if dx_set
            is = sdx[i]#.values
        end
        if x_set
            is = sx[i]#.values
        end

        if p_set
            is = sp[i]#.values
        end
        if t_set
            is = st[i]#.values
        end

        #display("dx: $dx")
        #display("sdx: $sdx")

        #partials = (isdx, isx, isp, ist)

        #display(partials)
        

        #V = Float64 
        #N = length(partials)
        #display("$T $V $N")

        #display(is)

        @assert is != ZeroTangent() && is != NoTangent() "is: $(is)"

        push!(y, ForwardDiff.Dual{Ty, Vy, Ny}(sy[i], is    )   ) #  ForwardDiff.Partials{N, V}(partials)
    end 

    y_fd, dx_fd
end

# function test(a, b)
#     println("$(typeof(a))   $(typeof(b))")
#     x = sum(a) + sum(b) 
#     y = sum(a) - sum(b)
#     x, y
# end

# using ForwardDiff
ForwardDiff.gradient(a -> test(a, ones(100)), ones(100))