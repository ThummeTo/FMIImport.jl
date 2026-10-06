#
# Copyright (c) 2026 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

const _DeprecatedTSpan = Tuple{Float64,Float64}

function _deprecate_positional_tspan(fname::Symbol)
    Base.depwarn(
        "Passing `tspan` as a positional argument to `$(fname)` is deprecated. Pass it as a keyword argument instead, for example `$(fname)(fmu; tspan=(t_start, t_stop), kwargs...)`.",
        fname,
    )
end

simulate(fmu::FMU, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulate)
    simulate(fmu; tspan = tspan, kwargs...)
end

simulate(fmu::FMU2, c::Union{FMU2Component,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulate)
        simulate(fmu, c; tspan = tspan, kwargs...)
    end

simulate(fmu::FMU3, c::Union{FMU3Instance,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulate)
        simulate(fmu, c; tspan = tspan, kwargs...)
    end

simulate(c::FMUInstance, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulate)
    simulate(c; tspan = tspan, kwargs...)
end

simulateME(fmu::FMU, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateME)
    simulateME(fmu; tspan = tspan, kwargs...)
end

simulateME(fmu::FMU, c::Union{FMUInstance,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulateME)
        simulateME(fmu, c; tspan = tspan, kwargs...)
    end

simulateME(c::FMUInstance, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateME)
    simulateME(c; tspan = tspan, kwargs...)
end

simulateCS(fmu::FMU, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateCS)
    simulateCS(fmu; tspan = tspan, kwargs...)
end

simulateCS(fmu::FMU, c::Union{FMUInstance,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulateCS)
        simulateCS(fmu, c; tspan = tspan, kwargs...)
    end

simulateCS(c::FMUInstance, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateCS)
    simulateCS(c; tspan = tspan, kwargs...)
end

simulateSE(fmu::FMU2, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateSE)
    simulateSE(fmu; tspan = tspan, kwargs...)
end

simulateSE(fmu::FMU3, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateSE)
    simulateSE(fmu; tspan = tspan, kwargs...)
end

simulateSE(fmu::FMU2, c::Union{FMU2Component,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulateSE)
        simulateSE(fmu, c; tspan = tspan, kwargs...)
    end

simulateSE(fmu::FMU3, c::Union{FMU3Instance,Nothing}, tspan::_DeprecatedTSpan; kwargs...) =
    begin
        _deprecate_positional_tspan(:simulateSE)
        simulateSE(fmu, c; tspan = tspan, kwargs...)
    end

simulateSE(c::FMUInstance, tspan::_DeprecatedTSpan; kwargs...) = begin
    _deprecate_positional_tspan(:simulateSE)
    simulateSE(c; tspan = tspan, kwargs...)
end
