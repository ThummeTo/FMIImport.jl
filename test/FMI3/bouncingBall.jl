using FMIImport
# using HTTP
using ZipFile
# using GitHub

# r = HTTP.request("GET", "https://github.com/modelica/Reference-FMUs/releases/latest/")
# HTTP.status(r)
# print(HTTP.headers(r))
# print(HTTP.body(r))
# HTTP.URI("https://github.com/modelica/Reference-FMUs/releases/latest/")
# HTTP.uri("https://github.com/modelica/Reference-FMUs/releases/latest/")
# r1 = HTTP.post("https://github.com/modelica/Reference-FMUs/releases/latest/")

# GitHub.createSTat

zipPath = download("https://github.com/modelica/Reference-FMUs/releases/download/v0.0.14/Reference-FMUs-0.0.14.zip")
# path = joinpath(test)
dir = dirname(zipPath)
zipPath = normpath(zipPath)
zarchive = ZipFile.Reader(zipPath)
path = joinpath(dir, "BouncingBall/")
# path = "C:/Users/Josef/Documents/"
for f in zarchive.files
    #println(f.name)
    if f.name == "3.0/BouncingBall.fmu"
        if !ispath(path)
            mkdir(path)
        end
        numBytes = write(joinpath(path, "BouncingBall.fmu"), read(f))
        if numBytes == 0
            print("Not able to read!")
        end
    end
end
close(zarchive)
fmu = fmi3Load(joinpath(path, "BouncingBall.fmu"))
instance = fmi3InstantiateCoSimulation!(fmu; loggingOn=true)
test1 = fmi3GetNumberOfContinuousStates(instance)
test2 = fmi3GetNumberOfEventIndicators(instance)
instance = fmi3InstantiateModelExchange!(fmu; loggingOn=true)
fmi3EnterInitializationMode(instance, 0.0, 10.0)
# TODO adding test for directional& adjoint derivatives
for i in 1:2
    for j in 1:2
        println(fmi3GetDirectionalDerivative(instance, fmu.modelDescription.derivativeValueReferences[i], fmu.modelDescription.stateValueReferences[j]))
        println(fmi3GetAdjointDerivative(instance, fmu.modelDescription.derivativeValueReferences[i], fmu.modelDescription.stateValueReferences[j]))
    end
end
fmi3ExitInitializationMode(instance)

fmi3EnterEventMode(instance, true, false, [Int32(2)], UInt64(0), false)
fmi3GetDirectionalDerivative(instance, fmu.modelDescription.derivativeValueReferences[1], fmu.modelDescription.stateValueReferences[1])
fmi3GetAdjointDerivative(instance, fmu.modelDescription.derivativeValueReferences[1], fmu.modelDescription.stateValueReferences[1])
fmi3EnterStepMode(instance)
fmi3GetDirectionalDerivative(instance, fmu.modelDescription.derivativeValueReferences[1], fmu.modelDescription.stateValueReferences[2])
fmi3GetAdjointDerivative(instance, fmu.modelDescription.derivativeValueReferences, fmu.modelDescription.stateValueReferences[1])
fmi3Terminate(instance)

fmi3GetOutputDerivatives(instance, UInt32(1), Int32(1))
fmi3Unload(instance)