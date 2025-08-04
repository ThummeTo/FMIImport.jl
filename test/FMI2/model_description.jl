#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIImport.FMICore: fmi2VariableNamingConventionStructured, fmi2Unit
using SparseArrays

myFMU = loadFMU("SpringFrictionPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

@test fmi2GetVersion(myFMU) == "2.0"
@test fmi2GetTypesPlatform(myFMU) == "default"

@test getModelName(myFMU) == "SpringFrictionPendulum1D"
@test getVariableNamingConvention(myFMU) == fmi2VariableNamingConventionStructured
@test isCoSimulation(myFMU) == true
@test isModelExchange(myFMU) == true

@test getGUID(myFMU) == "{2d426212-3b18-4520-b406-f465d323862a}"
@test getGenerationTool(myFMU) == "Dymola Version 2023x Refresh 1, 2023-04-12"
@test getGenerationDateAndTime(myFMU) == "2024-05-17T09:51:27Z"
@test getNumberOfEventIndicators(myFMU) == 32
@test canGetSetFMUState(myFMU) == true
@test canSerializeFMUState(myFMU) == true
@test providesDirectionalDerivatives(myFMU) == true
# @test dependenciesSupported(myFMU.modelDescription) == true
# @test derivativeDependenciesSupported(myFMU.modelDescription) == true

@test getDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test getDefaultStopTime(myFMU.modelDescription) ≈ 1.0
@test getDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test getDefaultStepSize(myFMU.modelDescription) === nothing

info(myFMU) # check if there is an error thrown

# comfort getters (dictionaries)

@test length(getValueReferencesAndNames(myFMU.modelDescription)) == 42
@test length(getValueReferencesAndNames(myFMU)) == 42

@test length(getInputNames(myFMU.modelDescription)) == 0
@test length(getInputNames(myFMU)) == 0

@test length(getOutputNames(myFMU.modelDescription)) == 0
@test length(getOutputNames(myFMU)) == 0

@test length(getParameterNames(myFMU.modelDescription)) == 12
@test getParameterNames(myFMU) == [
    "fricScale",
    "s0",
    "v0",
    "fixed.s0",
    "spring.c",
    "spring.s_rel0",
    "mass.smax",
    "mass.smin",
    "mass.v_small",
    "mass.L",
    "mass.m",
    "mass.fexp",
]

@test length(getStateNames(myFMU.modelDescription)) == 2
@test length(getStateNames(myFMU)) == 2
@test getStateNames(myFMU; mode = :first) == ["mass.s", "mass.v"]
@test getStateNames(myFMU; mode = :flat) == ["mass.s", "mass.v", "mass.v_relfric"]
@test getStateNames(myFMU; mode = :group) == [["mass.s"], ["mass.v", "mass.v_relfric"]]

@test length(getDerivativeNames(myFMU.modelDescription)) == 2
@test length(getDerivativeNames(myFMU)) == 2
@test getDerivativeNames(myFMU; mode = :first) == ["der(mass.s)", "mass.a_relfric"]
# @test getDerivativeNames(myFMU; mode=:flat) == ["der(mass.s)", "mass.a_relfric", "mass.a", "der(mass.v)"]
@test issetequal(
    getDerivativeNames(myFMU; mode = :flat),
    ["der(mass.s)", "mass.a_relfric", "mass.a", "der(mass.v)"],
)
@test all(
    issetequal.(
        getDerivativeNames(myFMU; mode = :group),
        [["der(mass.s)"], ["mass.a_relfric", "mass.a", "der(mass.v)"]],
    ),
)

@test length(getNamesAndDescriptions(myFMU.modelDescription)) == 50
@test length(getNamesAndDescriptions(myFMU)) == 50

@test length(getNamesAndUnits(myFMU.modelDescription)) == 50
dict = getNamesAndUnits(myFMU)
@test length(dict) == 50
@test dict["der(mass.s)"] == "m/s"
@test dict["mass.F_prop"] == "N.s/m"
@test dict["mass.fexp"] == "s/m"
@test dict["der(mass.v)"] == "m/s2"

@test length(getNamesAndInitials(myFMU.modelDescription)) == 50
dict = getNamesAndInitials(myFMU)
@test length(dict) == 50
@test dict["mass.startForward"] == 0
@test dict["mass.startBackward"] == 0
@test dict["mass.locked"] == 1

# ToDo: Improve test, use another FMU
@test length(getInputNamesAndStarts(myFMU.modelDescription)) == 0
dict = getInputNamesAndStarts(myFMU)
@test length(dict) == 0

@test length(myFMU.modelDescription.unitDefinitions) == 10
@test length(myFMU.modelDescription.typeDefinitions) == 9
@test myFMU.modelDescription.unitDefinitions[5].name == "W"
@test myFMU.modelDescription.unitDefinitions[6].baseUnit.kg == 1
@test myFMU.modelDescription.typeDefinitions[1].name == "Modelica.Units.SI.Acceleration"
stype_attr = myFMU.modelDescription.typeDefinitions[1].Real
@test stype_attr != nothing
@test stype_attr.quantity == "Acceleration"
@test stype_attr.unit == "m/s2"
stype_unit = getUnit(myFMU.modelDescription, myFMU.modelDescription.typeDefinitions[1]);
@test stype_unit isa fmi2Unit
@test stype_unit.name == "m/s2"
@test stype_unit.baseUnit.m == 1
@test stype_unit.baseUnit.s == -2

for sv in myFMU.modelDescription.modelVariables
    declared_type = getDeclaredType(myFMU.modelDescription, sv)
    if !isnothing(declared_type)
        @test isdefined(sv.attribute, :declaredType)
        @test sv.attribute.declaredType == declared_type.name

        # is the correct `fmi2Unit` found?
        if !isnothing(sv.attribute.unit)
            sv_unit = getUnit(myFMU.modelDescription, sv)
            @test sv_unit isa fmi2Unit
            @test sv_unit.name == sv.attribute.unit
        end
    end
end
# Test DependencyMatrix creation and state derivative dependencies
# Access DependencyMatrix from the extension when SparseArrays is loaded
depMatrix = Base.get_extension(FMIImport, :SparseArraysExt).DependencyMatrix(myFMU.modelDescription)
@test depMatrix isa Base.get_extension(FMIImport, :SparseArraysExt).DependencyMatrix

stateVRs = myFMU.modelDescription.stateValueReferences
derivativeVRs = myFMU.modelDescription.derivativeValueReferences

# Test getting dependencies of first derivative on first state
dep_value = depMatrix[derivativeVRs[1], stateVRs[1]]
@test dep_value isa UInt32

# Test getting dependencies of all derivatives on all states
dep_matrix_subset = depMatrix[derivativeVRs, stateVRs]
@test size(dep_matrix_subset) == (length(derivativeVRs), length(stateVRs))
@test dep_matrix_subset == UInt32[0x00000000 0x00000002; 0x00000005 0x00000005]

unloadFMU(myFMU)

myFMU = loadFMU("BouncingBall", "ModelicaReferenceFMUs", "0.0.30", "2.0")
@test isnothing(myFMU.modelDescription.modelStructure.derivatives[1].dependencies)

info(myFMU) # check if there is an error thrown

unloadFMU(myFMU)

myFMU = loadFMU("Dahlquist", "ModelicaReferenceFMUs", "0.0.30", "2.0")
@test !isnothing(myFMU.modelDescription.modelStructure.outputs[1].dependencies)

info(myFMU) # check if there is an error thrown

unloadFMU(myFMU)
