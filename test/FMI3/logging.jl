#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

myFMU = loadFMU("BouncingBall", "ModelicaReferenceFMUs", "0.0.20", "3.0")
myFMU.executionConfig.assertOnError = false

### CASE A: Print log ###
inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=true)
@test inst != 0

@info "The following warning is forced and not an issue:"
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

@info "The following warning is forced and not an issue:"
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

if VERSION >= v"1.7.0"
    output = read(joinpath(pwd(), "stderr"), String)
    @test startswith(output, "┌ Warning: fmi3ExitInitializationMode(...): Needs to be called in state `fmi3InstanceStateInitializationMode`.\n")
end 

### CASE C: Disable Log ###

inst = fmi3InstantiateCoSimulation!(myFMU; loggingOn=false)
@test inst != 0

@info "The following warning is forced and not an issue:"
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
myFMU.executionConfig.assertOnError = true
unloadFMU(myFMU)
