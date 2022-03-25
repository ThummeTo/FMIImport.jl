#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

myFMU = fmi3Load("IO", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
@test inst != 0

@test fmi3EnterInitializationMode(inst) == 0
# TODO check the value references used and adjust them
# TODO add clocks
realValueReferences = ["p_real", "u_real"]
integerValueReferences = ["p_integer", "u_integer"]
booleanValueReferences = ["p_boolean", "u_boolean"]
stringValueReferences = ["p_string", "p_string"]
binaryValueReferences = []

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

@test fmi3SetFloat32(inst, realValueReferences[1], rndReal) == 0
@test fmi3GetFloat32(inst, realValueReferences[1]) == rndReal
@test fmi3SetFloat32(inst, realValueReferences[1], -rndReal) == 0
@test fmi3GetFloat32(inst, realValueReferences[1]) == -rndReal

@test fmi3SetFloat64(inst, realValueReferences[2], rndReal) == 0
@test fmi3GetFloat64(inst, realValueReferences[2]) == rndReal
@test fmi3SetFloat64(inst, realValueReferences[2], -rndReal) == 0
@test fmi3GetFloat64(inst, realValueReferences[2]) == -rndReal

@test fmi3SetInt8(inst, integerValueReferences[1], rndInteger) == 0
@test fmi3GetInt8(inst, integerValueReferences[1]) == rndInteger
@test fmi3SetInt8(inst, integerValueReferences[1], -rndInteger) == 0
@test fmi3GetInt8(inst, integerValueReferences[1]) == -rndInteger

@test fmi3SetInt16(inst, integerValueReferences[2], rndInteger) == 0
@test fmi3GetInt16(inst, integerValueReferences[2]) == rndInteger
@test fmi3SetInt16(inst, integerValueReferences[2], -rndInteger) == 0
@test fmi3GetInt16(inst, integerValueReferences[2]) == -rndInteger

@test fmi3SetInt32(inst, integerValueReferences[3], rndInteger) == 0
@test fmi3GetInt32(inst, integerValueReferences[3]) == rndInteger
@test fmi3SetInt32(inst, integerValueReferences[3], -rndInteger) == 0
@test fmi3GetInt32(inst, integerValueReferences[3]) == -rndInteger

@test fmi3SetInt64(inst, integerValueReferences[4], rndInteger) == 0
@test fmi3GetInt64(inst, integerValueReferences[4]) == rndInteger
@test fmi3SetInt64(inst, integerValueReferences[4], -rndInteger) == 0
@test fmi3GetInt64(inst, integerValueReferences[4]) == -rndInteger

@test fmi3SetUInt8(inst, integerValueReferences[5], rndInteger) == 0
@test fmi3GetUInt8(inst, integerValueReferences[5]) == rndInteger
@test fmi3SetUInt8(inst, integerValueReferences[5], -rndInteger) == 0
@test fmi3GetUInt8(inst, integerValueReferences[5]) == -rndInteger

@test fmi3SetUInt16(inst, integerValueReferences[6], rndInteger) == 0
@test fmi3GetUInt16(inst, integerValueReferences[6]) == rndInteger
@test fmi3SetUInt16(inst, integerValueReferences[6], -rndInteger) == 0
@test fmi3GetUInt16(inst, integerValueReferences[6]) == -rndInteger

@test fmi3SetUInt32(inst, integerValueReferences[7], rndInteger) == 0
@test fmi3GetUInt32(inst, integerValueReferences[7]) == rndInteger
@test fmi3SetUInt32(inst, integerValueReferences[7], -rndInteger) == 0
@test fmi3GetUInt32(inst, integerValueReferences[7]) == -rndInteger

@test fmi3SetUInt64(inst, integerValueReferences[8], rndInteger) == 0
@test fmi3GetUInt64(inst, integerValueReferences[8]) == rndInteger
@test fmi3SetUInt64(inst, integerValueReferences[8], -rndInteger) == 0
@test fmi3GetUInt64(inst, integerValueReferences[8]) == -rndInteger

@test fmi3SetBoolean(inst, booleanValueReferences[1], rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == rndBoolean
@test fmi3SetBoolean(inst, booleanValueReferences[1], !rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences[1]) == !rndBoolean

@test fmi3SetString(inst, stringValueReferences[1], rndString) == 0
@test fmi3GetString(inst, stringValueReferences[1]) == rndString

@test fmi3SetBinary(fmu, binaryValueReferences[1], Csize_t(length(rndString)), pointer(rndString)) == 0
binary = FMI.fmi3GetBinary(fmu, binaryValueReferences[1])
@test unsafe_string(binary) == rndString

fmi3Set(inst, 
        [realValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]], 
        [rndReal,                rndInteger,                rndBoolean,                rndString,                pointer(rndString)])
@test fmi3Get(inst, 
                [realValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1], binaryValueReferences[1]]) == 
                [rndReal,                rndInteger,                rndBoolean,                rndString,                unsafe_string(rndString)]

##################
# Testing Arrays #
##################

rndReal = [100 * rand(), 100 * rand()]
rndInteger = [round(Integer, 100 * rand()), round(Integer, 100 * rand())]
rndBoolean = [(rand() > 0.5), (rand() > 0.5)]
tmp = Random.randstring(8)
rndString = [tmp, tmp]

cacheReal = [0.0, 0.0]
cacheInteger =  [fmi3Int32(0), fmi3Int32(0)]
cacheBoolean = [fmi3Boolean(false), fmi3Boolean(false)]
cacheString = [pointer(""), pointer("")]

@test fmi3SetFloat32(inst, realValueReferences, rndReal) == 0
@test fmi3GetFloat32(inst, realValueReferences) == rndReal
fmi3GetFloat32!(inst, realValueReferences, cacheReal)
@test cacheReal == rndReal
@test fmi3SetFloat32(inst, realValueReferences, -rndReal) == 0
@test fmi3GetFloat32(inst, realValueReferences) == -rndReal
fmi3GetFloat32!(inst, realValueReferences, cacheReal)
@test cacheReal == -rndReal

@test fmi3SetFloat64(inst, realValueReferences, rndReal) == 0
@test fmi3GetFloat64(inst, realValueReferences) == rndReal
fmi3GetFloat64!(inst, realValueReferences, cacheReal)
@test cacheReal == rndReal
@test fmi3SetFloat64(inst, realValueReferences, -rndReal) == 0
@test fmi3GetFloat64(inst, realValueReferences) == -rndReal
fmi3GetFloat64!(inst, realValueReferences, cacheReal)
@test cacheReal == -rndReal

@test fmi3SetInt8(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetInt8(inst, integerValueReferences) == rndInteger
fmi3GetInt8!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetInt8(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetInt8(inst, integerValueReferences) == -rndInteger
fmi3GetInt8!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetInt16(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetInt16(inst, integerValueReferences) == rndInteger
fmi3GetInt16!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetInt16(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetInt16(inst, integerValueReferences) == -rndInteger
fmi3GetInt16!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetInt32(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetInt32(inst, integerValueReferences) == rndInteger
fmi3GetInt32!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetInt32(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetInt32(inst, integerValueReferences) == -rndInteger
fmi3GetInt32!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetInt64(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetInt64(inst, integerValueReferences) == rndInteger
fmi3GetInt64!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetInt64(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetInt64(inst, integerValueReferences) == -rndInteger
fmi3GetInt64!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetUInt8(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetUInt8(inst, integerValueReferences) == rndInteger
fmi3GetUInt8!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetUInt8(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetUInt8(inst, integerValueReferences) == -rndInteger
fmi3GetUInt8!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetUInt16(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetUInt16(inst, integerValueReferences) == rndInteger
fmi3GetUInt16!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetUInt16(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetUInt16(inst, integerValueReferences) == -rndInteger
fmi3GetUInt16!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetUInt32(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetUInt32(inst, integerValueReferences) == rndInteger
fmi3GetUInt32!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetUInt32(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetUInt32(inst, integerValueReferences) == -rndInteger
fmi3GetUInt32!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetUInt64(inst, integerValueReferences, rndInteger) == 0
@test fmi3GetUInt64(inst, integerValueReferences) == rndInteger
fmi3GetUInt64!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi3SetUInt64(inst, integerValueReferences, -rndInteger) == 0
@test fmi3GetUInt64(inst, integerValueReferences) == -rndInteger
fmi3GetUInt64!(inst, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi3SetBoolean(inst, booleanValueReferences, rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences) == rndBoolean
fmi3GetBoolean!(inst, booleanValueReferences, cacheBoolean)
@test cacheBoolean == rndBoolean
not_rndBoolean = collect(!b for b in rndBoolean)
@test fmi3SetBoolean(inst, booleanValueReferences, not_rndBoolean) == 0
@test fmi3GetBoolean(inst, booleanValueReferences) == not_rndBoolean
fmi3GetBoolean!(inst, booleanValueReferences, cacheBoolean)
@test cacheBoolean == not_rndBoolean

@test fmi3SetString(inst, stringValueReferences, rndString) == 0
@test fmi3GetString(inst, stringValueReferences) == rndString
fmi3GetString!(inst, stringValueReferences, cacheString)
@test unsafe_string.(cacheString) == rndString

# TODO update
@test fmi3SetBinary(fmu, binaryValueReferences, Csize_t(length(rndString)), pointer(rndString)) == 0
binary = FMI.fmi3GetBinary(fmu, binaryValueReferences)
@test unsafe_string(binary) == rndString

# Testing input/output derivatives
dirs = fmi3GetOutputDerivatives(inst, ["y_real"], ones(Int, 1))
@test dirs == -Inf # at this point, derivative is undefined
# removed @test fmi3SetRealInputDerivatives(inst, ["u_real"], ones(Int, 1), zeros(1)) == 0
@test fmi3ExitInitializationMode(inst) == 0
@test fmi3DoStep(inst, 0.1) == 0

dirs = fmi3GetOutputDerivatives(inst, ["y_real"], ones(Int, 1))
@test dirs == 0.0

############
# Clean up #
############

fmi3Unload(myFMU)
