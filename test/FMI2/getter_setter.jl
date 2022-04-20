#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

###############
# Prepare FMU #
###############

myFMU = fmi2Load("IO", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
myFMU.executionConfig.assertOnWarning = true

comp = fmi2Instantiate!(myFMU; loggingOn=false)
@test comp != 0

@test fmi2SetupExperiment(comp, 0.0) == 0

@test fmi2EnterInitializationMode(comp) == 0

realValueReferences = ["p_real", "u_real"]
integerValueReferences = ["p_integer", "u_integer"]
booleanValueReferences = ["p_boolean", "u_boolean"]
stringValueReferences = ["p_string", "p_string"]

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

@test fmi2SetReal(comp, realValueReferences[1], rndReal) == 0
@test fmi2GetReal(comp, realValueReferences[1]) == rndReal
@test fmi2SetReal(comp, realValueReferences[1], -rndReal) == 0
@test fmi2GetReal(comp, realValueReferences[1]) == -rndReal

@test fmi2SetInteger(comp, integerValueReferences[1], rndInteger) == 0
@test fmi2GetInteger(comp, integerValueReferences[1]) == rndInteger
@test fmi2SetInteger(comp, integerValueReferences[1], -rndInteger) == 0
@test fmi2GetInteger(comp, integerValueReferences[1]) == -rndInteger

@test fmi2SetBoolean(comp, booleanValueReferences[1], rndBoolean) == 0
@test fmi2GetBoolean(comp, booleanValueReferences[1]) == rndBoolean
@test fmi2SetBoolean(comp, booleanValueReferences[1], !rndBoolean) == 0
@test fmi2GetBoolean(comp, booleanValueReferences[1]) == !rndBoolean

@test fmi2SetString(comp, stringValueReferences[1], rndString) == 0
@test fmi2GetString(comp, stringValueReferences[1]) == rndString

fmi2Set(comp, 
        [realValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1]], 
        [rndReal,                rndInteger,                rndBoolean,                rndString])
@test fmi2Get(comp, 
                [realValueReferences[1], integerValueReferences[1], booleanValueReferences[1], stringValueReferences[1]]) == 
                [rndReal,                rndInteger,                rndBoolean,                rndString]

##################
# Testing Arrays #
##################

rndReal = [100 * rand(), 100 * rand()]
rndInteger = [round(Integer, 100 * rand()), round(Integer, 100 * rand())]
rndBoolean = [(rand() > 0.5), (rand() > 0.5)]
tmp = Random.randstring(8)
rndString = [tmp, tmp]

cacheReal = [0.0, 0.0]
cacheInteger =  [fmi2Integer(0), fmi2Integer(0)]
cacheBoolean = [fmi2Boolean(false), fmi2Boolean(false)]
cacheString = [pointer(""), pointer("")]

@test fmi2SetReal(comp, realValueReferences, rndReal) == 0
@test fmi2GetReal(comp, realValueReferences) == rndReal
fmi2GetReal!(comp, realValueReferences, cacheReal)
@test cacheReal == rndReal
@test fmi2SetReal(comp, realValueReferences, -rndReal) == 0
@test fmi2GetReal(comp, realValueReferences) == -rndReal
fmi2GetReal!(comp, realValueReferences, cacheReal)
@test cacheReal == -rndReal

@test fmi2SetInteger(comp, integerValueReferences, rndInteger) == 0
@test fmi2GetInteger(comp, integerValueReferences) == rndInteger
fmi2GetInteger!(comp, integerValueReferences, cacheInteger)
@test cacheInteger == rndInteger
@test fmi2SetInteger(comp, integerValueReferences, -rndInteger) == 0
@test fmi2GetInteger(comp, integerValueReferences) == -rndInteger
fmi2GetInteger!(comp, integerValueReferences, cacheInteger)
@test cacheInteger == -rndInteger

@test fmi2SetBoolean(comp, booleanValueReferences, rndBoolean) == 0
@test fmi2GetBoolean(comp, booleanValueReferences) == rndBoolean
fmi2GetBoolean!(comp, booleanValueReferences, cacheBoolean)
@test cacheBoolean == rndBoolean
not_rndBoolean = collect(!b for b in rndBoolean)
@test fmi2SetBoolean(comp, booleanValueReferences, not_rndBoolean) == 0
@test fmi2GetBoolean(comp, booleanValueReferences) == not_rndBoolean
fmi2GetBoolean!(comp, booleanValueReferences, cacheBoolean)
@test cacheBoolean == not_rndBoolean

@test fmi2SetString(comp, stringValueReferences, rndString) == 0
@test fmi2GetString(comp, stringValueReferences) == rndString
fmi2GetString!(comp, stringValueReferences, cacheString)
@test unsafe_string.(cacheString) == rndString

# Testing input/output derivatives
dirs = fmi2GetRealOutputDerivatives(comp, ["y_real"], ones(Int, 1))
@test dirs == -Inf # at this point, derivative is undefined
@test fmi2SetRealInputDerivatives(comp, ["u_real"], ones(Int, 1), zeros(1)) == 0

@test fmi2ExitInitializationMode(comp) == 0
@test fmi2DoStep(comp, 0.1) == 0

dirs = fmi2GetRealOutputDerivatives(comp, ["y_real"], ones(Int, 1))
@test dirs == 0.0

############
# Clean up #
############

fmi2Unload(myFMU)
