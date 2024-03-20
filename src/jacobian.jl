#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

"""
    sampleJacobian(c::FMU2Component,
                            vUnknown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                            vKnown_ref::AbstractArray{fmi2ValueReference},
                            steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences).

Computes the directional derivatives of an FMU. An FMU has different modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
   - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknowns>` that have type Real.
   - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
   - Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Outputs>` with type Real and variability = `discrete`.
   - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><Derivatives>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes.

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

   Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `dvUnkonwn::Array{fmi2Real}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(see function fmi2GetDirectionalDerivative!).

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2GetDirectionalDerivative!`](@ref).
"""
function sampleJacobian(c::FMU2Component,
                                       vUnknown_ref::AbstractArray{fmi2ValueReference},
                                       vKnown_ref::AbstractArray{fmi2ValueReference},
                                       steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    mtx = zeros(fmi2Real, length(vUnknown_ref), length(vKnown_ref))

    sampleJacobian!(mtx, vUnknown_ref, vKnown_ref, steps)

    return mtx
end

"""
    function sampleJacobian!(mtx::Matrix{<:Real},
                                    c::FMU2Component,
                                    vUnknown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                                    vKnown_ref::Union{AbstractArray{fmi2ValueReference}, Symbol},
                                    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

This function samples the directional derivative by manipulating corresponding values (central differences) and saves in-place.


Computes the directional derivatives of an FMU. An FMU has different Modes and in every Mode an FMU might be described by different equations and different unknowns. The precise definitions are given in the mathematical descriptions of Model Exchange (section 3.1) and Co-Simulation (section 4.1). In every Mode, the general form of the FMU equations are:
𝐯_unknown = 𝐡(𝐯_known, 𝐯_rest)

- `v_unknown`: vector of unknown Real variables computed in the actual Mode:
   - Initialization Mode: unkowns kisted under `<ModelStructure><InitialUnknowns>` that have type Real.
   - Continuous-Time Mode (ModelExchange): The continuous-time outputs and state derivatives. (= the variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` and the variables listed as state derivatives under `<ModelStructure><Derivatives>)`.
   - Event Mode (ModelExchange): The same variables as in the Continuous-Time Mode and additionally variables under `<ModelStructure><Outputs>` with type Real and variability = `discrete`.
   - Step Mode (CoSimulation):  The variables listed under `<ModelStructure><Outputs>` with type Real and variability = `continuous` or `discrete`. If `<ModelStructure><Derivatives>` is present, also the variables listed here as state derivatives.
- `v_known`: Real input variables of function h that changes its value in the actual Mode.
- `v_rest`:Set of input variables of function h that either changes its value in the actual Mode but are non-Real variables, or do not change their values in this Mode, but change their values in other Modes

Computes a linear combination of the partial derivatives of h with respect to the selected input variables 𝐯_known:

   Δv_unknown = (δh / δv_known) Δv_known

# Arguments
- `mtx::Matrix{<:Real}`:Output matrix to store the Jacobian. Its dimensions must be compatible with the number of unknown and known value references.
- `c::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `vUnknown_ref::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model. `vUnknown_ref` can be equated with `v_unknown`(variable described above).
- `vKnown_ref::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.`vKnown_ref` can be equated with `v_known`(variable described above).
- `dvUnknown::AbstractArray{fmi2Real}`: Stores the directional derivative vector values.
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: Step size to be used for numerical differentiation. If nothing, a default value will be chosen automatically.

# Returns
- `nothing`

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

See also [`fmi2GetDirectionalDerivative!`](@ref).
"""
function sampleJacobian!(mtx::Matrix{<:Real},
                                c::FMU2Component,
                                vUnknown_ref::AbstractArray{fmi2ValueReference},
                                vKnown_ref::AbstractArray{fmi2ValueReference},
                                steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    step = 0.0

    negValues = zeros(length(vUnknown_ref))
    posValues = zeros(length(vUnknown_ref))

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            # smaller than 1e-6 leads to issues
            step = max(2.0 * eps(Float32(origValue)), 1e-6)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetReal!(c, vUnknown_ref, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetReal!(c, vUnknown_ref, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if length(vUnknown_ref) == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

function sampleJacobian!(mtx::Matrix{<:Real},
    c::FMU2Component,
    vUnknown_ref::Symbol,
    vKnown_ref::AbstractArray{fmi2ValueReference},
    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert vUnknown_ref == :indicators "vUnknown_ref::Symbol must be `:indicators`!"

    step = 0.0

    len_vUnknown_ref = c.fmu.modelDescription.numberOfEventIndicators

    negValues = zeros(len_vUnknown_ref)
    posValues = zeros(len_vUnknown_ref)

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            step = max(2.0 * eps(Float32(origValue)), 1e-12)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetEventIndicators!(c, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetEventIndicators!(c, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if len_vUnknown_ref == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

function sampleJacobian!(mtx::Matrix{<:Real},
    c::FMU2Component,
    vUnknown_ref::AbstractArray{fmi2ValueReference},
    vKnown_ref::Symbol,
    steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert vKnown_ref == :time "vKnown_ref::Symbol must be `:time`!"

    step = 0.0

    negValues = zeros(length(vUnknown_ref))
    posValues = zeros(length(vUnknown_ref))

    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        if steps === nothing
            step = max(2.0 * eps(Float32(origValue)), 1e-12)
        else
            step = steps[i]
        end

        fmi2SetReal(c, vKnown, origValue - step; track=false)
        fmi2GetEventIndicators!(c, negValues)

        fmi2SetReal(c, vKnown, origValue + step; track=false)
        fmi2GetEventIndicators!(c, posValues)

        fmi2SetReal(c, vKnown, origValue; track=false)

        if length(vUnknown_ref) == 1
            mtx[1,i] = (posValues-negValues) ./ (step * 2.0)
        else
            mtx[:,i] = (posValues-negValues) ./ (step * 2.0)
        end
    end

    nothing
end

"""
    getJacobian(comp::FMU2Component,
                        rdx::AbstractArray{fmi2ValueReference},
                        rx::AbstractArray{fmi2ValueReference};
                        steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.

# Returns
- `mat::Array{fmi2Real}`: Return `mat` contains the jacobian ∂rdx / ∂rx.

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

"""
function getJacobian(comp::FMU2Component,
                         rdx::AbstractArray{fmi2ValueReference},
                         rx::AbstractArray{fmi2ValueReference};
                         steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)
    mat = zeros(fmi2Real, length(rdx), length(rx))
    fmi2GetJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
    getJacobian!(jac::AbstractMatrix{fmi2Real},
                          comp::FMU2Component,
                          rdx::AbstractArray{fmi2ValueReference},
                          rx::AbstractArray{fmi2ValueReference};
                          steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function stores the jacobian ∂rdx / ∂rx in an AbstractMatrix `jac`.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD).

# Arguments
- `jac::AbstractMatrix{fmi2Real}`: A matrix that will hold the computed Jacobian matrix.
- `comp::FMU2Component`: Mutable struct represents an instantiated instance of an FMU in the FMI 2.0.2 Standard.
- `rdx::AbstractArray{fmi2ValueReference}`: Argument `vUnknown_ref` contains values of type`fmi2ValueReference` which are identifiers of a variable value of the model.
- `rx::AbstractArray{fmi2ValueReference}`: Argument `vKnown_ref` contains values of type `fmi2ValueReference` which are identifiers of a variable value of the model.

# Keywords
- `steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)`: Step size to be used for numerical differentiation. If nothing, a default value will be chosen automatically.

# Returns
- `nothing`

# Source
- FMISpec2.0.2 Link: [https://fmi-standard.org/](https://fmi-standard.org/)
- FMISpec2.0.2: 2.2.7  Definition of Model Variables (ModelVariables)

"""
function getJacobian!(jac::AbstractMatrix{fmi2Real},
                          comp::FMU2Component,
                          rdx::AbstractArray{fmi2ValueReference},
                          rx::AbstractArray{fmi2ValueReference};
                          steps::Union{AbstractArray{fmi2Real}, Nothing} = nothing)

    @assert size(jac) == (length(rdx), length(rx)) ["fmi2GetJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` $(length(rdx)) and `rx` $(length(rx))."]

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end

    # ToDo: Pick entries based on dependency matrix!
    #depMtx = fmi2GetDependencies(fmu)
    rdx_inds = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rdx)
    rx_inds  = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rx)

    for i in 1:length(rx)

        sensitive_rdx_inds = 1:length(rdx)
        sensitive_rdx = rdx

        # sensitive_rdx_inds = Int64[]
        # sensitive_rdx = fmi2ValueReference[]

        # for j in 1:length(rdx)
        #     if depMtx[rdx_inds[j], rx_inds[i]] != fmi2DependencyIndependent
        #         push!(sensitive_rdx_inds, j)
        #         push!(sensitive_rdx, rdx[j])
        #     end
        # end

        if length(sensitive_rdx) > 0

            fmi2GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))

            #    jac[sensitive_rdx_inds, i] = fmi2GetDirectionalDerivative(comp, sensitive_rdx, [rx[i]])

        end
    end

    return nothing
end