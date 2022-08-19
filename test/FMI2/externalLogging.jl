#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport: fmi2StatusError, fmi2StatusOK

myFMU = fmi2Load("SpringPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])
myFMU.executionConfig.assertOnWarning = true

### CASE A: Print log ###
comp = fmi2Instantiate!(myFMU; loggingOn=true, externalCallbacks=true)
@test comp != 0

@info "The following warning is forced and not an issue:"
open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi2SetupExperiment(comp) == fmi2StatusOK
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

comp = fmi2Instantiate!(myFMU; loggingOn=true, logStatusError=false, externalCallbacks=true)
@test comp != 0

# # deactivate errors to capture them
# assertOnError = myFMU.executionConfig.assertOnError
# myFMU.executionConfig.assertOnError = false

@info "The following warning is forced and not an issue:"
open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi2ExitInitializationMode(comp) == fmi2StatusError
            end
        end
    end 
end

output = read(joinpath(pwd(), "stdout"), String)
@test output == ""

if VERSION >= v"1.7.0"
    output = read(joinpath(pwd(), "stderr"), String)
    println(output)
    @test startswith(output, "┌ Warning: fmi2ExitInitializationMode(...): Needs to be called in state `fmi2ComponentStateInitializationMode`.\n")
end 

### CASE C: Disable Log ###

comp = fmi2Instantiate!(myFMU; loggingOn=false, externalCallbacks=true)
@test comp != 0

@info "The following warning is forced and not an issue:"
open(joinpath(pwd(), "stdout"), "w") do out
    open(joinpath(pwd(), "stderr"), "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi2SetupExperiment(comp) == fmi2StatusOK
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
fmi2Unload(myFMU)
