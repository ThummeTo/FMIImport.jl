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
instance = fmi3InstantiateModelExchange!(fmu; loggingOn=true)
t_start = 0.0
t_stop = 3.0
dt = 0.01
saveat = t_start:dt:t_stop
success, data = fmi3SimulateCS(fmu, t_start, t_stop; recordValues=["h", "v"], saveat = saveat)
fmiPlot(fmu,["h", "v"], data)
fmi3Unload(fmu)