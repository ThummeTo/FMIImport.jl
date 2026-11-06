#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport.FMICore:
    fmi3VariableNamingConventionFlat,
    fmi3CausalityParameter,
    fmi3CausalityOutput,
    fmi3CausalityLocal,
    fmi3VariabilityConstant,
    fmi3VariabilityFixed,
    fmi3VariabilityTunable,
    fmi3VariabilityContinuous,
    fmi3InitialExact
using FMIImport.EzXML: parsexml, eachelement
using SparseArrays

myFMU = loadFMU("BouncingBall", "ModelicaReferenceFMUs", "0.0.30", "3.0")

@test fmi3GetVersion(myFMU) == "3.0"

@test getModelName(myFMU) == "BouncingBall"
@test getVariableNamingConvention(myFMU) == fmi3VariableNamingConventionFlat
@test isCoSimulation(myFMU)
@test isModelExchange(myFMU)

# [TODO] scheduledExecution

@test getInstantiationToken(myFMU) == "{1AE5E10D-9521-4DE3-80B9-D0EAAA7D5AF1}" # [TODO] update
@test getGenerationTool(myFMU) == "Reference FMUs (v0.0.30)"
@test getGenerationDateAndTime(myFMU) == "2024-04-18T08:15:35.162720+00:00"
@test getNumberOfEventIndicators(myFMU) == 1
@test canGetSetFMUState(myFMU)
@test canSerializeFMUState(myFMU)
@test !providesDirectionalDerivatives(myFMU)
@test !providesAdjointDerivatives(myFMU)

@test getDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test getDefaultStopTime(myFMU.modelDescription) ≈ 3.0
@test getDefaultTolerance(myFMU.modelDescription) === nothing
@test getDefaultStepSize(myFMU.modelDescription) === 0.01

attributes = Dict(
    mv.name => (mv.causality, mv.variability, mv.initial) for
    mv in myFMU.modelDescription.modelVariables
)
@test attributes["g"] == (fmi3CausalityParameter, fmi3VariabilityFixed, fmi3InitialExact)
@test attributes["e"] == (fmi3CausalityParameter, fmi3VariabilityTunable, fmi3InitialExact)
@test attributes["h"] == (fmi3CausalityOutput, fmi3VariabilityContinuous, fmi3InitialExact)
@test attributes["v_min"] == (fmi3CausalityLocal, fmi3VariabilityConstant, fmi3InitialExact)

@test myFMU.modelDescription.numberOfEventIndicators == 1
@test myFMU.modelDescription.eventIndicatorValueReferences == [1]
@test typeof(myFMU.modelDescription.modelStructure.eventIndicators[1]) ==
      fmi3VariableDependency

@test isnothing(
    myFMU.modelDescription.modelStructure.continuousStateDerivatives[1].dependencies,
)


# unit and type definitions
units = Dict(unit.name => unit for unit in myFMU.modelDescription.unitDefinitions)
@test sort(collect(keys(units))) == ["m", "m/s", "m/s2"]
@test (units["m/s2"].baseUnit.m, units["m/s2"].baseUnit.s) == (1, -2)
@test isnothing(units["m/s2"].baseUnit.kg)
@test isempty(units["m/s2"].displayUnits)
types = Dict(type.name => type for type in myFMU.modelDescription.typeDefinitions)
@test sort(collect(keys(types))) == ["Acceleration", "Position", "Velocity"]
@test types["Velocity"] isa fmi3Float64Type
@test (types["Velocity"].quantity, types["Velocity"].unit) == ("Velocity", "m/s")
@test isnothing(types["Velocity"].min)

info(myFMU) # check if there is an error thrown

# DependencyMatrix: EventIndicator (VR=1) has no dependencies attribute -> depends on all knowns
ext = Base.get_extension(FMIImport, :SparseArraysExt)
depMatrix = ext.DependencyMatrix(myFMU.modelDescription)
@test depMatrix isa ext.DependencyMatrix
eventIndicatorVR = myFMU.modelDescription.eventIndicatorValueReferences[1]
stateVRs = myFMU.modelDescription.stateValueReferences
@test all(
    depMatrix[eventIndicatorVR, stateVR] == fmi3DependencyKindDependent for
    stateVR in stateVRs
)

unloadFMU(myFMU)

myFMU = loadFMU("Dahlquist", "ModelicaReferenceFMUs", "0.0.36", "3.0")
@test !isnothing(myFMU.modelDescription.modelStructure.outputs[1].dependencies)

info(myFMU) # check if there is an error thrown

unloadFMU(myFMU)

# all kinds of unit and type definitions
definitions = collect(
    eachelement(
        parsexml(
            """
            <fmiModelDescription>
              <UnitDefinitions>
                <Unit name="rad/s">
                  <BaseUnit s="-1" rad="1"/>
                  <DisplayUnit name="deg/s" factor="57.29577951308232"/>
                  <DisplayUnit name="s/rad" inverse="true"/>
                </Unit>
              </UnitDefinitions>
              <TypeDefinitions>
                <Float32Type name="F32" min="-1.5" relativeQuantity="true"/>
                <Int8Type name="I8" min="-128" max="127"/>
                <UInt64Type name="U64" max="18446744073709551615"/>
                <BooleanType name="B" description="flag"/>
                <StringType name="S"/>
                <BinaryType name="Bin" mimeType="image/png" maxSize="1024"/>
                <EnumerationType name="E" quantity="Option">
                  <Item name="a" value="-1"/>
                  <Item name="b" value="2" description="second"/>
                </EnumerationType>
                <ClockType name="C" intervalVariability="constant" intervalDecimal="0.1" canBeDeactivated="true" priority="2"/>
              </TypeDefinitions>
            </fmiModelDescription>
            """,
        ).root,
    ),
)
md = fmi3ModelDescription()

unit = only(FMIImport.parseUnitDefinitions(md, definitions[1]))
@test unit.name == "rad/s"
@test (unit.baseUnit.s, unit.baseUnit.rad) == (-1, 1)
@test isnothing(unit.baseUnit.m)
@test [displayUnit.name for displayUnit in unit.displayUnits] == ["deg/s", "s/rad"]
@test unit.displayUnits[1].factor == 57.29577951308232
@test isnothing(unit.displayUnits[1].inverse)
@test unit.displayUnits[2].inverse === true

types = FMIImport.parseTypeDefinitions(md, definitions[2])
@test typeof.(types) == [
    fmi3Float32Type,
    fmi3Int8Type,
    fmi3UInt64Type,
    fmi3BooleanType,
    fmi3StringType,
    fmi3BinaryType,
    fmi3EnumerationType,
    fmi3ClockType,
]
@test types[1].min === -1.5f0
@test types[1].relativeQuantity === true
@test (types[2].min, types[2].max) === (fmi3Int8(-128), fmi3Int8(127))
@test types[3].max === typemax(fmi3UInt64)
@test types[4].description == "flag"
@test (types[6].mimeType, types[6].maxSize) == ("image/png", 1024)
@test types[7].quantity == "Option"
@test [(item.name, item.value, item.description) for item in types[7].items] == [("a", -1, nothing), ("b", 2, "second")]
@test types[8].intervalVariability == "constant"
@test (types[8].intervalDecimal, types[8].canBeDeactivated, types[8].priority) ==
      (0.1, true, 2)
