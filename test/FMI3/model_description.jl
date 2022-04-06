#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# using FMIImport.FMICore: fmi3VariableNamingConventionFlat
# using FMIImport
# using ZipFile

zipPath = download("https://github.com/modelica/Reference-FMUs/releases/download/v0.0.14/Reference-FMUs-0.0.14.zip")
dir = dirname(zipPath)
zipPath = normpath(zipPath)
zarchive = ZipFile.Reader(zipPath)
path = joinpath(dir, "BouncingBall/")
pathToFmu = joinpath(path, "BouncingBall.fmu")
for f in zarchive.files
    if f.name == "3.0/BouncingBall.fmu"
        if !ispath(path)
            mkdir(path)
        end
      
        numBytes = write(pathToFmu, read(f))
        if numBytes == 0
            print("Not able to read!")
        end
    end
end
close(zarchive)
myFMU = fmi3Load(pathToFmu, ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

@test fmi3GetVersion(myFMU) == "3.0-beta.5"

@test fmi3GetModelName(myFMU) == "BouncingBall"
@test fmi3GetVariableNamingConvention(myFMU) == fmi3VariableNamingConventionFlat
@test fmi3IsCoSimulation(myFMU) == true
@test fmi3IsModelExchange(myFMU) == true
# TODO scheduledExecution
@test fmi3GetInstantiationToken(myFMU) == "{8c4e810f-3df3-4a00-8276-176fa3c9f003}" # TODO update
@test fmi3GetGenerationTool(myFMU) == "Reference FMUs (0278b1e)"
@test fmi3GetGenerationDateAndTime(myFMU) == "[Unknown generation date and time]"
@test fmi3GetNumberOfEventIndicators(myFMU) == 1
@test fmi3CanGetSetState(myFMU) == true
@test fmi3CanSerializeFMUState(myFMU) == true
@test fmi3ProvidesDirectionalDerivatives(myFMU) == false
@test fmi3ProvidesAdjointDerivatives(myFMU) == false

@test fmi3GetDefaultStartTime(myFMU.modelDescription) ≈ 0.0
@test fmi3GetDefaultStopTime(myFMU.modelDescription) ≈ 3.0
@test fmi3GetDefaultTolerance(myFMU.modelDescription) ≈ 1e-4
@test fmi3GetDefaultStepSize(myFMU.modelDescription) === 0.01

fmi3Unload(myFMU)
