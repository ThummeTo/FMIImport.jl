using FMI
using HTTP
using ZipFile

r = HTTP.request("GET", "https://github.com/modelica/Reference-FMUs/releases/latest/")
HTTP.status(r)
print(HTTP.headers(r))
print(HTTP.body(r))
HTTP.URI("https://github.com/modelica/Reference-FMUs/releases/latest/")
HTTP.uri("https://github.com/modelica/Reference-FMUs/releases/latest/")
r1 = HTTP.post("https://github.com/modelica/Reference-FMUs/releases/latest/")

test = download("https://github.com/modelica/Reference-FMUs/releases/download/v0.0.14/Reference-FMUs-0.0.14.zip")
# path = joinpath(test)
path = normpath(test)
zarchive = ZipFile.Reader(path)
for f in zarchive.files
    print(f)
end
fmi3Load(path)
# fmu = fmi3Load("model/fmi3/BouncingBall/BouncingBall.fmu")
# instance = fmi3InstantiateCoSimulation!(fmu; loggingOn=true)
# t_start = 0.0
# t_stop = 3.0
# dt = 0.01
# saveat = t_start:dt:t_stop
# success, data = fmi3SimulateCS(fmu, t_start, t_stop; recordValues=["h", "v"], saveat = saveat)
# fmiPlot(fmu,["h", "v"], data)
# fmi3Unload(fmu)