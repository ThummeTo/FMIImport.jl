fmu = FMI.fmi3Load("model/fmi3/VanDerPol.fmu")
instance1 = FMI.fmi3InstantiateModelExchange!(fmu; loggingOn = true)
instance = FMI.fmi3InstantiateCoSimulation!(fmu; loggingOn=true)
t_start = 0.0
t_stop = 10.0
dt = 0.001
saveat = t_start:dt:t_stop
success, data = FMI.fmi3SimulateCS(fmu, t_start, t_stop; recordValues=["x0", "x1"], saveat=saveat)
success, data = FMI.fmi3SimulateME(fmu, t_start, t_stop; recordValues=["x0", "x1"], dtmax=0.01)
FMI.fmiPlot(fmu,["x0", "x1"], data)

FMI.fmi3GetFMUState(fmu)
FMI.fmi3Unload(fmu)
