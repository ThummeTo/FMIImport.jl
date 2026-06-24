#
# Copyright (c) 2025 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module SparseArraysExt
using FMIImport, SparseArrays
# TODO: Change parsing logic and dependency fields in md.jl and FMICore UInt -> UInt32 to have it consistent everywhere

# Maps FMI2 dependency kinds to FMI3 dependency index values, we use them in both cases:
# FMI2: 0->dependent, 1->constant, 2->fixed, 3->tunable, 4->discrete
# FMI3: 0->independent, 1->constant, 2->fixed, 3->tunable, 4->discrete, 5->dependent
function fmi2dependencyKindToDependencyIndex(kind::fmi2DependencyKind)
    if kind == fmi2DependencyKindDependent
        return UInt32(5)
    end
    return kind
end

struct DependencyMatrix <: FMIBase.AbstractDependencyMatrix
    matrix::SparseMatrixCSC{UInt32,Int}
    vr_idx_dict::Dict{UInt32,Int}
end

# From FMI3-Standard:  
# If dependencies is not present, it must be assumed that the unknown depends on all knowns. If dependencies is present as empty list, the unknown depends on none of the knowns.

function DependencyMatrix(md::fmi2ModelDescription)
    vrs = [mV.valueReference for mV in md.modelVariables]
    sort!(vrs);
    unique!(vrs)
    vr_idx_dict = Dict{UInt32,Int}(zip(vrs, 1:length(vrs)))
    dep_mtx = spzeros(UInt32, length(vrs), length(vrs))
    @info "Constructing Dependency Matrix"
    # Filter out nothing values from the dependency categories
    dependency_categories = filter(
        !isnothing,
        [
            md.modelStructure.derivatives,
            md.modelStructure.outputs,
            md.modelStructure.initialUnknowns,
        ],
    )
    for dependency_category in dependency_categories
        for dep_info in dependency_category
            dependent_vR = md.modelVariables[dep_info.index].valueReference
            if !isnothing(dep_info.dependencies)
                for (idx, dependency) in enumerate(dep_info.dependencies)
                    dependency_vR = md.modelVariables[dependency].valueReference
                    # "If dependenciesKind is not present, it must be assumed that the unknown vunknown depends on the knowns vknown without a particular structure." -> no dependenciesKind means dependent
                    dependency_kind =
                        isnothing(dep_info.dependenciesKind) ? fmi2DependencyKindDependent :
                        dep_info.dependenciesKind[idx]
                    dep_mtx[vr_idx_dict[dependent_vR], vr_idx_dict[dependency_vR]] =
                        fmi2dependencyKindToDependencyIndex(dependency_kind)
                end
            else
                # this is fmi3DependencyKindDependent, because we use the fmi3-style in both cases
                dep_mtx[vr_idx_dict[dependent_vR], :] .= fmi3DependencyKindDependent
            end
        end
    end
    DependencyMatrix(dep_mtx, vr_idx_dict)
end

function DependencyMatrix(md::fmi3ModelDescription)
    vrs = [mV.valueReference for mV in md.modelVariables]
    sort!(vrs);
    unique!(vrs)
    vr_idx_dict = Dict{UInt32,Int}(zip(vrs, 1:length(vrs)))
    dep_mtx = spzeros(UInt32, length(vrs), length(vrs))
    @info "Constructing Dependency Matrix"
    # Filter out nothing values from the dependency categories
    dependency_categories = filter(
        !isnothing,
        [
            md.modelStructure.continuousStateDerivatives,
            md.modelStructure.outputs,
            md.modelStructure.initialUnknowns,
            md.modelStructure.eventIndicators,
        ],
    )
    for dependency_category in dependency_categories
        for dep_info in dependency_category
            dependent_vR = dep_info.index
            if !isnothing(dep_info.dependencies)
                for (idx, dependency) in enumerate(dep_info.dependencies)
                    dependency_vR = dependency
                    # "If dependenciesKind is not present, it must be assumed that the unknown vunknown depends on the knowns vknown without a particular structure." -> no dependenciesKind means dependent
                    dependency_kind =
                        isnothing(dep_info.dependenciesKind) ? fmi3DependencyKindDependent :
                        dep_info.dependenciesKind[idx]
                    dep_mtx[vr_idx_dict[dependent_vR], vr_idx_dict[dependency_vR]] =
                        dependency_kind
                end
            else
                dep_mtx[vr_idx_dict[dependent_vR], :] .= fmi3DependencyKindDependent
            end
        end
    end
    DependencyMatrix(dep_mtx, vr_idx_dict)
end

function Base.getindex(D::DependencyMatrix, i::UInt32, j::UInt32)
    return D.matrix[D.vr_idx_dict[i], D.vr_idx_dict[j]]
end
function Base.getindex(D::DependencyMatrix, i::Vector{UInt32}, j::Vector{UInt32})
    return D.matrix[getindex.(Ref(D.vr_idx_dict), i), getindex.(Ref(D.vr_idx_dict), j)]
end

function _loadDependencyMatrix!(fmu)
    fmu.executionConfig.load_dep_matrix || return
    fmu.dependencyMatrix = DependencyMatrix(fmu.modelDescription)
    dvrs = fmu.modelDescription.derivativeValueReferences
    svrs = fmu.modelDescription.stateValueReferences
    fmu.jac_prototype = Float64.(fmu.dependencyMatrix[dvrs, svrs])
end

FMIBase.loadDependencyMatrix!(fmu::FMU2) = _loadDependencyMatrix!(fmu)
FMIBase.loadDependencyMatrix!(fmu::FMU3) = _loadDependencyMatrix!(fmu)

end
