#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport: fmi3StatusError

using FMIImport
using ZipFile

zipPath = download("https://github.com/modelica/Reference-FMUs/releases/download/v0.0.14/Reference-FMUs-0.0.14.zip")
# path = joinpath(test)
dir = dirname(zipPath)
zipPath = normpath(zipPath)
zarchive = ZipFile.Reader(zipPath)
path = joinpath(dir, "BouncingBall/")
pathToFmu = joinpath(path, "BouncingBall.fmu")
for f in zarchive.files
    #println(f.name)
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

# myFMU = fmi3Load(pathToFmu, ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
myFMU = fmi3Load(pathToFmu)
### CASE A: Print log ###
inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=true)
@test inst != 0

open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi3ExitInitializationMode(inst) == fmi3StatusError
            end
        end
    end 
end
# ToDo: this test is wrong / not working (capture doesn't work for color output)
#output = read(joinpath(pwd(), "stdout"), String)
#@test output == "" 
#output = read(joinpath(pwd(), "stderr"), String)
#@test output == "" 

### CASE B: Print log, but catch infos ###

inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=true, logStatusError=false)
@test inst != 0

open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi3ExitInitializationMode(inst) == fmi3StatusError
            end
        end
    end 
end
output = read(joinpath(pwd(), "stdout"), String)
@test output == ""
output = read(joinpath(pwd(), "stderr"), String)
@test output == ""

### CASE C: Disable Log ###

inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
@test inst != 0

open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi3ExitInitializationMode(inst) == fmi3StatusError
            end
        end
    end 
end
# ToDo: this test is wrong / not working (capture doesn't work for color output)
#output = read(joinpath(pwd(), "stdout"), String)
#@test output == ""
#output = read(joinpath(pwd(), "stderr"), String)
#@test output == ""

# cleanup
fmi3Unload(myFMU)
