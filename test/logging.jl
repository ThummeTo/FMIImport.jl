#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

import FMIImport: fmi2StatusError
using Suppressor

myFMU = fmi2Load("SpringPendulum1D", ENV["EXPORTINGTOOL"], ENV["EXPORTINGVERSION"])

### CASE A: Print log ###
comp = fmi2Instantiate!(myFMU; loggingOn=true)
@test comp != 0

output = @capture_out print(begin
    @test fmi2ExitInitializationMode(comp) == fmi2StatusError
end)
output = read("/tmp/stdout", String)
@test output == "" 

### CASE B: Print log, but catch infos ###

comp = fmi2Instantiate!(myFMU; loggingOn=true, logStatusError=false)
@test comp != 0

open("/tmp/stdout", "w") do out
    open("/tmp/stderr", "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi2ExitInitializationMode(comp) == fmi2StatusError
            end
        end
    end 
end
output = read("/tmp/stdout", String)
@test output == ""
output = read("/tmp/stderr", String)
@test output == ""

### CASE C: Disable Log ###

comp = fmi2Instantiate!(myFMU; loggingOn=false)
@test comp != 0

open("/tmp/stdout", "w") do out
    open("/tmp/stderr", "w") do err
        redirect_stdout(out) do
            redirect_stderr(err) do
                @test fmi2ExitInitializationMode(comp) == fmi2StatusError
            end
        end
    end 
end
output = read("/tmp/stdout", String)
@test output == ""
output = read("/tmp/stderr", String)
@test output == ""

# cleanup
fmi2Unload(myFMU)
