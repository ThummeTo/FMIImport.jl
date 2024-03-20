#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

myFMU = loadFMU("Feedthrough", "ModelicaReferenceFMUs", "0.0.20", "3.0")
inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
@test inst != 0

@test fmi3EnterInitializationMode(inst) == 0
# TODO check the value references used and adjust them
# TODO add clocks

float32ValueReferences = ["Float32_discrete_input", "Float32_continuous_input"]
float64ValueReferences = ["Float64_discrete_input", "Float64_tunable_parameter"]
int8ValueReferences = ["Int8_input", "Int8_output"]
int16ValueReferences = ["Int16_input", "Int16_output"]
int32ValueReferences = ["Int32_input", "Int32_output"]
int64ValueReferences = ["Int64_input", "Int64_output"]
uint8ValueReferences = ["UInt8_input", "UInt8_output"]
uint16ValueReferences = ["UInt16_input", "UInt16_output"]
uint32ValueReferences = ["UInt32_input", "UInt32_output"]
uint64ValueReferences = ["UInt64_input", "UInt64_output"]
booleanValueReferences = ["Boolean_input", "Boolean_output"]
stringValueReferences = ["String_parameter", "String_parameter"]
binaryValueReferences = ["Binary_input", "Binary_output"]

#########################
# Testing Single Values #
#########################

rndReal = 100 * rand()
rndInteger = round(Integer, 100 * rand())
rndBoolean = rand() > 0.5
rndString = Random.randstring(12)

cacheReal = 0.0
cacheInteger = 0
cacheBoolean = false
cacheString = ""

@test fmi3SetFloat32(inst, float32ValueReferences[1], Float32(rndReal)) == 0
@test fmi3GetFloat32(inst, float32ValueReferences[1]) == Float32(rndReal)
@test fmi3SetFloat32(inst, float32ValueReferences[1], Float32(-rndReal)) == 0
@test fmi3GetFloat32(inst, float32ValueReferences[1]) == Float32(-rndReal)

@test fmi3SetFloat64(inst, float64ValueReferences[1], rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences[1]) == rndReal
@test fmi3SetFloat64(inst, float64ValueReferences[1], -rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences[1]) == -rndReal

@test fmi3SetInt8(inst, int8ValueReferences[1], Int8(rndInteger)) == 0
@test fmi3GetInt8(inst, int8ValueReferences[1]) == Int8(rndInteger)
@test fmi3SetInt8(inst, int8ValueReferences[1], Int8(-rndInteger)) == 0
@test fmi3GetInt8(inst, int8ValueReferences[1]) == Int8(-rndInteger)

@test fmi3SetInt16(inst, int16ValueReferences[1], Int16(rndInteger)) == 0
@test fmi3GetInt16(inst, int16ValueReferences[1]) == Int16(rndInteger)
@test fmi3SetInt16(inst, int16ValueReferences[1], Int16(-rndInteger)) == 0
@test fmi3GetInt16(inst, int16ValueReferences[1]) == Int16(-rndInteger)

@test fmi3SetInt32(inst, int32ValueReferences[1], Int32(rndInteger)) == 0
@test fmi3GetInt32(inst, int32ValueReferences[1]) == rndInteger
@test fmi3SetInt32(inst, int32ValueReferences[1], Int32(-rndInteger)) == 0
@test fmi3GetInt32(inst, int32ValueReferences[1]) == -rndInteger

@test fmi3SetInt64(inst, int64ValueReferences[1], Int64(rndInteger)) == 0
@test fmi3GetInt64(inst, int64ValueReferences[1]) == Int64(rndInteger)
@test fmi3SetInt64(inst, int64ValueReferences[1], Int64(-rndInteger)) == 0
@test fmi3GetInt64(inst, int64ValueReferences[1]) == Int64(-rndInteger)

@test fmi3SetUInt8(inst, uint8ValueReferences[1], UInt8(rndInteger)) == 0
@test fmi3GetUInt8(inst, uint8ValueReferences[1]) == UInt8(rndInteger)

@test fmi3SetUInt16(inst, uint16ValueReferences[1], UInt16(rndInteger)) == 0
@test fmi3GetUInt16(inst, uint16ValueReferences[1]) == UInt16(rndInteger)

@test fmi3SetUInt32(inst, uint32ValueReferences[1], UInt32(rndInteger)) == 0
@test fmi3GetUInt32(inst, uint32ValueReferences[1]) == UInt32(rndInteger)

@test fmi3SetUInt64(inst, uint64ValueReferences[1], UInt64(rndInteger)) == 0
@test fmi3GetUInt64(inst, uint64ValueReferences[1]) == UInt64(rndInteger)

@test fmi3SetBoolean(inst, booleanValueReferences[1], rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == rndBoolean
@test fmi3SetBoolean(inst, booleanValueReferences[1], !rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == !rndBoolean

@test fmi3SetString(inst, stringValueReferences[1], rndString) == 0
@test fmi3GetString(inst, stringValueReferences[1]) == rndString

@test fmi3SetBinary(inst, binaryValueReferences[1], Csize_t(length(rndString)), pointer(rndString)) == 0
binary = fmi3GetBinary(inst, binaryValueReferences[1])
@test unsafe_string(binary) == rndString

# TODO test after latest PR
setValue(inst, 
        [float64ValueReferences[1], int32ValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]], 
        [rndReal,                Int32(rndInteger),                rndBoolean,                rndString,                rndString])
# @test getValue(inst, 
#                 [float64ValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]]) == 
#                 [rndReal,                Int32(rndInteger),                rndBoolean,                rndString,                unsafe_string(rndString)]

##################
# Testing Arrays #
##################

rndReal = [100 * rand(), 100 * rand()]
rndInteger = [round(Int32, 100 * rand()), round(Int32, 100 * rand())]
rndBoolean = [(rand() > 0.5), (rand() > 0.5)]
tmp = Random.randstring(8)
rndString = [tmp, tmp]

cacheFloat32 = [Float32(0.0), Float32(0.0)]
cacheFloat64 = [0.0, 0.0]
cacheInteger =  [fmi3Int32(0), fmi3Int32(0)]
cacheBoolean = [fmi3Boolean(false), fmi3Boolean(false)]
cacheString = [pointer(""), pointer("")]

# TODO not contained in the FMU
@test fmi3SetFloat32(inst, float32ValueReferences, Float32.(rndReal)) == 0
@test fmi3GetFloat32(inst, float32ValueReferences) == Float32.(rndReal)
fmi3GetFloat32!(inst, float32ValueReferences, cacheFloat32)
@test cacheFloat32 == Float32.(rndReal)
@test fmi3SetFloat32(inst, float32ValueReferences, Float32.(-rndReal)) == 0
@test fmi3GetFloat32(inst, float32ValueReferences) == Float32.(-rndReal)
fmi3GetFloat32!(inst, float32ValueReferences, cacheFloat32)
@test cacheFloat32 == Float32.(-rndReal)

@test fmi3SetFloat64(inst, float64ValueReferences, rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences) == rndReal
fmi3GetFloat64!(inst, float64ValueReferences, cacheFloat64)
@test cacheFloat64 == rndReal
@test fmi3SetFloat64(inst, float64ValueReferences, -rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences) == -rndReal
fmi3GetFloat64!(inst, float64ValueReferences, cacheFloat64)
@test cacheFloat64 == -rndReal

# TODO not contained in the FMU
# @test fmi3SetInt8(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetInt8(inst, integerValueReferences) == rndInteger
# fmi3GetInt8!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetInt8(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetInt8(inst, integerValueReferences) == -rndInteger
# fmi3GetInt8!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetInt16(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetInt16(inst, integerValueReferences) == rndInteger
# fmi3GetInt16!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetInt16(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetInt16(inst, integerValueReferences) == -rndInteger
# fmi3GetInt16!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# TODO only one variable is settable, we want to set at least two
# @test fmi3SetInt32(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetInt32(inst, integerValueReferences) == rndInteger
# fmi3GetInt32!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetInt32(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetInt32(inst, integerValueReferences) == -rndInteger
# fmi3GetInt32!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetInt64(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetInt64(inst, integerValueReferences) == rndInteger
# fmi3GetInt64!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetInt64(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetInt64(inst, integerValueReferences) == -rndInteger
# fmi3GetInt64!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetUInt8(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetUInt8(inst, integerValueReferences) == rndInteger
# fmi3GetUInt8!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetUInt8(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetUInt8(inst, integerValueReferences) == -rndInteger
# fmi3GetUInt8!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetUInt16(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetUInt16(inst, integerValueReferences) == rndInteger
# fmi3GetUInt16!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetUInt16(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetUInt16(inst, integerValueReferences) == -rndInteger
# fmi3GetUInt16!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetUInt32(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetUInt32(inst, integerValueReferences) == rndInteger
# fmi3GetUInt32!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetUInt32(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetUInt32(inst, integerValueReferences) == -rndInteger
# fmi3GetUInt32!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# @test fmi3SetUInt64(inst, integerValueReferences, rndInteger) == 0
# @test fmi3GetUInt64(inst, integerValueReferences) == rndInteger
# fmi3GetUInt64!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == rndInteger
# @test fmi3SetUInt64(inst, integerValueReferences, -rndInteger) == 0
# @test fmi3GetUInt64(inst, integerValueReferences) == -rndInteger
# fmi3GetUInt64!(inst, integerValueReferences, cacheInteger)
# @test cacheInteger == -rndInteger

# TODO only one variable is settable, we want to set at least two
# @test fmi3SetBoolean(inst, booleanValueReferences, rndBoolean) == 0
# @test fmi3GetBoolean(inst, booleanValueReferences) == rndBoolean
# fmi3GetBoolean!(inst, booleanValueReferences, cacheBoolean)
# @test cacheBoolean == rndBoolean
# not_rndBoolean = collect(!b for b in rndBoolean)
# @test fmi3SetBoolean(inst, booleanValueReferences, not_rndBoolean) == 0
# @test fmi3GetBoolean(inst, booleanValueReferences) == not_rndBoolean
# fmi3GetBoolean!(inst, booleanValueReferences, cacheBoolean)
# @test cacheBoolean == not_rndBoolean

# @test fmi3SetString(inst, stringValueReferences, rndString) == 0
# @test fmi3GetString(inst, stringValueReferences) == rndString
# fmi3GetString!(inst, stringValueReferences, cacheString)
# @test unsafe_string.(cacheString) == rndString

# TODO only one variable is settable, we want to set at least two
# @test fmi3SetBinary(inst, binaryValueReferences, Csize_t(length(rndString)), pointer(rndString)) == 0
# binary = FMI.fmi3GetBinary(inst, binaryValueReferences)
# @test unsafe_string(binary) == rndString

# Testing input/output derivatives

# TODO not supported
# myFMU = fmi3Load(pathfmu)
# inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
# @test inst != 0
# @test fmi3EnterInitializationMode(inst) == 0
# dirs = fmi3GetOutputDerivatives(inst, ["h"], ones(Integer, 1))
# @test dirs == -Inf # at this point, derivative is undefined
# # removed @test fmi3SetRealInputDerivatives(inst, ["u_real"], ones(Int, 1), zeros(1)) == 0
# @test fmi3ExitInitializationMode(inst) == 0
# @test fmi3DoStep!(inst, 0.1) == 0

# dirs = fmi3GetOutputDerivatives(inst, ["h"], ones(Int, 1))
# @test dirs == 0.0

############
# Clean up #
############

unloadFMU(myFMU)
