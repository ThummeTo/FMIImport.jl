#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

myFMU = fmi3Load("Feedthrough", "ModelicaReferenceFMUs", "0.0.14")
inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
@test inst != 0

@test fmi3EnterInitializationMode(inst) == 0
# TODO check the value references used and adjust them
# TODO add clocks

float32ValueReferences = ["real_discrete_out", "Float_32_continuous_output"]
float64ValueReferences = ["real_discrete_in", "real_tunable_param"]
integerValueReferences = ["int_in", "int_out"]
booleanValueReferences = ["bool_in", "bool_out"]
stringValueReferences = ["string_param", "string_param"]
binaryValueReferences = ["binary_in", "binary_out"]

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

# TODO not contained in the FMU
# @test fmi3SetFloat32(inst, float32ValueReferences[1], Float32(rndReal)) == 0
# @test fmi3GetFloat32(inst, float32ValueReferences[1]) == rndReal
# @test fmi3SetFloat32(inst, realValueReferences[1], -rndReal) == 0
# @test fmi3GetFloat32(inst, realValueReferences[1]) == -rndReal

@test fmi3SetFloat64(inst, float64ValueReferences[1], rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences[1]) == rndReal
@test fmi3SetFloat64(inst, float64ValueReferences[1], -rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences[1]) == -rndReal

# TODO not contained in the FMU
# @test fmi3SetInt8(inst, integerValueReferences[1], rndInteger) == 0
# @test fmi3GetInt8(inst, integerValueReferences[1]) == rndInteger
# @test fmi3SetInt8(inst, integerValueReferences[1], -rndInteger) == 0
# @test fmi3GetInt8(inst, integerValueReferences[1]) == -rndInteger

# @test fmi3SetInt16(inst, integerValueReferences[2], rndInteger) == 0
# @test fmi3GetInt16(inst, integerValueReferences[2]) == rndInteger
# @test fmi3SetInt16(inst, integerValueReferences[2], -rndInteger) == 0
# @test fmi3GetInt16(inst, integerValueReferences[2]) == -rndInteger

@test fmi3SetInt32(inst, integerValueReferences[1], Int32(rndInteger)) == 0
@test fmi3GetInt32(inst, integerValueReferences[1]) == rndInteger
@test fmi3SetInt32(inst, integerValueReferences[1], Int32(-rndInteger)) == 0
@test fmi3GetInt32(inst, integerValueReferences[1]) == -rndInteger

# TODO not contained in the FMU
# @test fmi3SetInt64(inst, integerValueReferences[1], rndInteger) == 0
# @test fmi3GetInt64(inst, integerValueReferences[1]) == rndInteger
# @test fmi3SetInt64(inst, integerValueReferences[4], -rndInteger) == 0
# @test fmi3GetInt64(inst, integerValueReferences[4]) == -rndInteger

# @test fmi3SetUInt8(inst, integerValueReferences[5], rndInteger) == 0
# @test fmi3GetUInt8(inst, integerValueReferences[5]) == rndInteger
# @test fmi3SetUInt8(inst, integerValueReferences[5], -rndInteger) == 0
# @test fmi3GetUInt8(inst, integerValueReferences[5]) == -rndInteger

# @test fmi3SetUInt16(inst, integerValueReferences[6], rndInteger) == 0
# @test fmi3GetUInt16(inst, integerValueReferences[6]) == rndInteger
# @test fmi3SetUInt16(inst, integerValueReferences[6], -rndInteger) == 0
# @test fmi3GetUInt16(inst, integerValueReferences[6]) == -rndInteger

# @test fmi3SetUInt32(inst, integerValueReferences[7], rndInteger) == 0
# @test fmi3GetUInt32(inst, integerValueReferences[7]) == rndInteger
# @test fmi3SetUInt32(inst, integerValueReferences[7], -rndInteger) == 0
# @test fmi3GetUInt32(inst, integerValueReferences[7]) == -rndInteger

# @test fmi3SetUInt64(inst, integerValueReferences[8], rndInteger) == 0
# @test fmi3GetUInt64(inst, integerValueReferences[8]) == rndInteger
# @test fmi3SetUInt64(inst, integerValueReferences[8], -rndInteger) == 0
# @test fmi3GetUInt64(inst, integerValueReferences[8]) == -rndInteger

@test fmi3SetBoolean(inst, booleanValueReferences[1], rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == rndBoolean
@test fmi3SetBoolean(inst, booleanValueReferences[1], !rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == !rndBoolean

@test fmi3SetString(inst, stringValueReferences[1], rndString) == 0
@test fmi3GetString(inst, stringValueReferences[1]) == rndString

@test fmi3SetBinary(inst, binaryValueReferences[1], Csize_t(length(rndString)), pointer(rndString)) == 0
binary = fmi3GetBinary(inst, binaryValueReferences[1])
@test unsafe_string(binary) == rndString

# TODO conflict with same alias for fmi3 datatypes fmi3Boolean, fmi3UInt8
# fmi3Set(inst, 
#         [float64ValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]], 
#         [rndReal,                rndInteger,                rndBoolean,                rndString,                pointer(rndString)])
# @test fmi3Get(inst, 
#                 [float64ValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]]) == 
#                 [rndReal,                rndInteger,                rndBoolean,                rndString,                unsafe_string(rndString)]

##################
# Testing Arrays #
##################

rndReal = [100 * rand(), 100 * rand()]
rndInteger = [round(Int32, 100 * rand()), round(Int32, 100 * rand())]
rndBoolean = [(rand() > 0.5), (rand() > 0.5)]
tmp = Random.randstring(8)
rndString = [tmp, tmp]

cacheReal = [0.0, 0.0]
cacheInteger =  [fmi3Int32(0), fmi3Int32(0)]
cacheBoolean = [fmi3Boolean(false), fmi3Boolean(false)]
cacheString = [pointer(""), pointer("")]

# TODO not contained in the FMU
# @test fmi3SetFloat32(inst, realValueReferences, rndReal) == 0
# @test fmi3GetFloat32(inst, realValueReferences) == rndReal
# fmi3GetFloat32!(inst, realValueReferences, cacheReal)
# @test cacheReal == rndReal
# @test fmi3SetFloat32(inst, realValueReferences, -rndReal) == 0
# @test fmi3GetFloat32(inst, realValueReferences) == -rndReal
# fmi3GetFloat32!(inst, realValueReferences, cacheReal)
# @test cacheReal == -rndReal

@test fmi3SetFloat64(inst, float64ValueReferences, rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences) == rndReal
fmi3GetFloat64!(inst, float64ValueReferences, cacheReal)
@test cacheReal == rndReal
@test fmi3SetFloat64(inst, float64ValueReferences, -rndReal) == 0
@test fmi3GetFloat64(inst, float64ValueReferences) == -rndReal
fmi3GetFloat64!(inst, float64ValueReferences, cacheReal)
@test cacheReal == -rndReal

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

fmi3Unload(myFMU)
