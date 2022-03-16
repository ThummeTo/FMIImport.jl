#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

# What is included in the file `FMI2_ext.jl` (external/additional functions)?
# - new functions, that are useful, but not part of the FMI-spec (example: `fmi2Load`, `fmi2SampleDirectionalDerivative`)

using Libdl
using ZipFile

"""
Create a copy of the .fmu file as a .zip folder and unzips it.
Returns the paths to the zipped and unzipped folders.

Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
"""
function fmi2Unzip(pathToFMU::String; unpackPath=nothing)

    fileNameExt = basename(pathToFMU)
    (fileName, fileExt) = splitext(fileNameExt)
        
    if unpackPath == nothing
        # cleanup=true leads to issues with automatic testing on linux server.
        unpackPath = mktempdir(; prefix="fmijl_", cleanup=false)
    end

    zipPath = joinpath(unpackPath, fileName * ".zip")
    unzippedPath = joinpath(unpackPath, fileName)

    # only copy ZIP if not already there
    if !isfile(zipPath)
        cp(pathToFMU, zipPath; force=true)
    end

    @assert isfile(zipPath) ["fmi2Unzip(...): ZIP-Archive couldn't be copied to `$zipPath`."]

    zipAbsPath = isabspath(zipPath) ?  zipPath : joinpath(pwd(), zipPath)
    unzippedAbsPath = isabspath(unzippedPath) ? unzippedPath : joinpath(pwd(), unzippedPath)

    @assert isfile(zipAbsPath) ["fmi2Unzip(...): Can't deploy ZIP-Archive at `$(zipAbsPath)`."]

    numFiles = 0

    # only unzip if not already done
    if !isdir(unzippedAbsPath)
        mkpath(unzippedAbsPath)

        zarchive = ZipFile.Reader(zipAbsPath)
        for f in zarchive.files
            fileAbsPath = normpath(joinpath(unzippedAbsPath, f.name))

            if endswith(f.name,"/") || endswith(f.name,"\\")
                mkpath(fileAbsPath) # mkdir(fileAbsPath)

                @assert isdir(fileAbsPath) ["fmi2Unzip(...): Can't create directory `$(f.name)` at `$(fileAbsPath)`."]
            else
                # create directory if not forced by zip file folder
                mkpath(dirname(fileAbsPath))

                numBytes = write(fileAbsPath, read(f))
                
                if numBytes == 0
                    @info "fmi2Unzip(...): Written file `$(f.name)`, but file is empty."
                end

                @assert isfile(fileAbsPath) ["fmi2Unzip(...): Can't unzip file `$(f.name)` at `$(fileAbsPath)`."]
                numFiles += 1
            end
        end
        close(zarchive)
    end

    @assert isdir(unzippedAbsPath) ["fmi2Unzip(...): ZIP-Archive couldn't be unzipped at `$(unzippedPath)`."]
    @info "fmi2Unzip(...): Successfully unzipped $numFiles files at `$unzippedAbsPath`."

    (unzippedAbsPath, zipAbsPath)
end

# Checks with dlsym for available function in library.
# Prints an info text and returns C_NULL if not (soft-check).
function dlsym_opt(libHandle, symbol)
    addr = dlsym(libHandle, symbol; throw_error=false)
    if addr == nothing
        @info "This FMU does not support function '$symbol'."
        addr = Ptr{Cvoid}(C_NULL)
    end
    addr
end

"""
Sets the properties of the fmu by reading the modelDescription.xml.
Retrieves all the pointers of binary functions.

Returns the instance of the FMU struct.

Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
"""
function fmi2Load(pathToFMU::String; unpackPath=nothing, type=nothing)
    # Create uninitialized FMU
    fmu = FMU2()

    if startswith(pathToFMU, "http")
        @info "Downloading FMU from `$(pathToFMU)`."
        pathToFMU = download(pathToFMU)
    end

    pathToFMU = normpath(pathToFMU)

    # set paths for fmu handling
    (fmu.path, fmu.zipPath) = fmi2Unzip(pathToFMU; unpackPath=unpackPath)

    # set paths for modelExchangeScripting and binary
    tmpName = splitpath(fmu.path)
    pathToModelDescription = joinpath(fmu.path, "modelDescription.xml")

    # parse modelDescription.xml
    fmu.modelDescription = fmi2LoadModelDescription(pathToModelDescription)
    fmu.modelName = fmu.modelDescription.modelName
    fmu.instanceName = fmu.modelDescription.modelName

    if (fmi2IsCoSimulation(fmu.modelDescription) && fmi2IsModelExchange(fmu.modelDescription) && type==:CS) 
        fmu.type = fmi2TypeCoSimulation::fmi2Type
    elseif (fmi2IsCoSimulation(fmu.modelDescription) && fmi2IsModelExchange(fmu.modelDescription) && type==:ME)
        fmu.type = fmi2TypeModelExchange::fmi2Type
    elseif fmi2IsCoSimulation(fmu.modelDescription) && (type===nothing || type==:CS)
        fmu.type = fmi2TypeCoSimulation::fmi2Type
    elseif fmi2IsModelExchange(fmu.modelDescription) && (type===nothing || type==:ME)
        fmu.type = fmi2TypeModelExchange::fmi2Type
    else
        error(unknownFMUType)
    end

    fmuName = fmi2GetModelIdentifier(fmu.modelDescription; type=fmu.type) # tmpName[length(tmpName)]

    directoryBinary = ""
    pathToBinary = ""

    directories = []
    
    fmuExt = ""
    osStr = ""

    juliaArch = Sys.WORD_SIZE
    @assert (juliaArch == 64 || juliaArch == 32) "fmi2Load(...): Unknown Julia Architecture with $(juliaArch)-bit, must be 64- or 32-bit."
        
    if Sys.iswindows()
        if juliaArch == 64
            directories = [joinpath("binaries", "win64"), joinpath("binaries","x86_64-windows")]
        else 
            directories = [joinpath("binaries", "win32"), joinpath("binaries","i686-windows")]
        end
        osStr = "Windows"
        fmuExt = "dll"
    elseif Sys.islinux()
        if juliaArch == 64
            directories = [joinpath("binaries", "linux64"), joinpath("binaries", "x86_64-linux")]
        else 
            directories = []
        end
        osStr = "Linux"
        fmuExt = "so"
    elseif Sys.isapple()
        if juliaArch == 64
            directories = [joinpath("binaries", "darwin64"), joinpath("binaries", "x86_64-darwin")]
        else 
            directories = []
        end
        osStr = "Mac"
        fmuExt = "dylib"
    else
        @assert false "fmi2Load(...): Unsupported target platform. Supporting Windows, Linux and Mac. Please open an issue if you want to use another OS."
    end

    @assert (length(directories) > 0) "fmi2Load(...): Unsupported architecture. Supporting Julia for Windows (64- and 32-bit), Linux (64-bit) and Mac (64-bit). Please open an issue if you want to use another architecture."
    for directory in directories
        directoryBinary = joinpath(fmu.path, directory)
        if isdir(directoryBinary)
            pathToBinary = joinpath(directoryBinary, "$(fmuName).$(fmuExt)")
            break
        end
    end
    @assert isfile(pathToBinary) "fmi2Load(...): Target platform is $(osStr), but can't find valid FMU binary at `$(pathToBinary)` for path `$(fmu.path)`."

    # make URI ressource location
    tmpResourceLocation = string("file:///", fmu.path)
    tmpResourceLocation = joinpath(tmpResourceLocation, "resources")
    fmu.fmuResourceLocation = replace(tmpResourceLocation, "\\" => "/") # URIs.escapeuri(tmpResourceLocation)

    @info "fmi2Load(...): FMU resources location is `$(fmu.fmuResourceLocation)`"

    if fmi2IsCoSimulation(fmu.modelDescription) && fmi2IsModelExchange(fmu.modelDescription)
        @info "fmi2Load(...): FMU supports both CS and ME, using CS as default if nothing specified."
    end

    fmu.binaryPath = pathToBinary
    loadBinary(fmu)
   
    # dependency matrix 
    # fmu.dependencies

    fmu
end

function loadBinary(fmu::FMU2)
    lastDirectory = pwd()
    cd(dirname(fmu.binaryPath))

    # set FMU binary handler
    fmu.libHandle = dlopen(fmu.binaryPath)

    cd(lastDirectory)

    # retrieve functions
    fmu.cInstantiate                  = dlsym(fmu.libHandle, :fmi2Instantiate)
    fmu.cGetTypesPlatform             = dlsym(fmu.libHandle, :fmi2GetTypesPlatform)
    fmu.cGetVersion                   = dlsym(fmu.libHandle, :fmi2GetVersion)
    fmu.cFreeInstance                 = dlsym(fmu.libHandle, :fmi2FreeInstance)
    fmu.cSetDebugLogging              = dlsym(fmu.libHandle, :fmi2SetDebugLogging)
    fmu.cSetupExperiment              = dlsym(fmu.libHandle, :fmi2SetupExperiment)
    fmu.cEnterInitializationMode      = dlsym(fmu.libHandle, :fmi2EnterInitializationMode)
    fmu.cExitInitializationMode       = dlsym(fmu.libHandle, :fmi2ExitInitializationMode)
    fmu.cTerminate                    = dlsym(fmu.libHandle, :fmi2Terminate)
    fmu.cReset                        = dlsym(fmu.libHandle, :fmi2Reset)
    fmu.cGetReal                      = dlsym(fmu.libHandle, :fmi2GetReal)
    fmu.cSetReal                      = dlsym(fmu.libHandle, :fmi2SetReal)
    fmu.cGetInteger                   = dlsym(fmu.libHandle, :fmi2GetInteger)
    fmu.cSetInteger                   = dlsym(fmu.libHandle, :fmi2SetInteger)
    fmu.cGetBoolean                   = dlsym(fmu.libHandle, :fmi2GetBoolean)
    fmu.cSetBoolean                   = dlsym(fmu.libHandle, :fmi2SetBoolean)

    fmu.cGetString                    = dlsym_opt(fmu.libHandle, :fmi2GetString)
    fmu.cSetString                    = dlsym_opt(fmu.libHandle, :fmi2SetString)

    if fmi2CanGetSetState(fmu.modelDescription)
        fmu.cGetFMUstate                  = dlsym_opt(fmu.libHandle, :fmi2GetFMUstate)
        fmu.cSetFMUstate                  = dlsym_opt(fmu.libHandle, :fmi2SetFMUstate)
        fmu.cFreeFMUstate                 = dlsym_opt(fmu.libHandle, :fmi2FreeFMUstate)
    end

    if fmi2CanSerializeFMUstate(fmu.modelDescription)
        fmu.cSerializedFMUstateSize       = dlsym_opt(fmu.libHandle, :fmi2SerializedFMUstateSize)
        fmu.cSerializeFMUstate            = dlsym_opt(fmu.libHandle, :fmi2SerializeFMUstate)
        fmu.cDeSerializeFMUstate          = dlsym_opt(fmu.libHandle, :fmi2DeSerializeFMUstate)
    end

    if fmi2ProvidesDirectionalDerivative(fmu.modelDescription)
        fmu.cGetDirectionalDerivative     = dlsym_opt(fmu.libHandle, :fmi2GetDirectionalDerivative)
    end

    # CS specific function calls
    if fmi2IsCoSimulation(fmu.modelDescription)
        fmu.cSetRealInputDerivatives      = dlsym(fmu.libHandle, :fmi2SetRealInputDerivatives)
        fmu.cGetRealOutputDerivatives     = dlsym(fmu.libHandle, :fmi2GetRealOutputDerivatives)
        fmu.cDoStep                       = dlsym(fmu.libHandle, :fmi2DoStep)
        fmu.cCancelStep                   = dlsym(fmu.libHandle, :fmi2CancelStep)
        fmu.cGetStatus                    = dlsym(fmu.libHandle, :fmi2GetStatus)
        fmu.cGetRealStatus                = dlsym(fmu.libHandle, :fmi2GetRealStatus)
        fmu.cGetIntegerStatus             = dlsym(fmu.libHandle, :fmi2GetIntegerStatus)
        fmu.cGetBooleanStatus             = dlsym(fmu.libHandle, :fmi2GetBooleanStatus)
        fmu.cGetStringStatus              = dlsym(fmu.libHandle, :fmi2GetStringStatus)
    end

    # ME specific function calls
    if fmi2IsModelExchange(fmu.modelDescription)
        fmu.cEnterContinuousTimeMode      = dlsym(fmu.libHandle, :fmi2EnterContinuousTimeMode)
        fmu.cGetContinuousStates          = dlsym(fmu.libHandle, :fmi2GetContinuousStates)
        fmu.cGetDerivatives               = dlsym(fmu.libHandle, :fmi2GetDerivatives)
        fmu.cSetTime                      = dlsym(fmu.libHandle, :fmi2SetTime)
        fmu.cSetContinuousStates          = dlsym(fmu.libHandle, :fmi2SetContinuousStates)
        fmu.cCompletedIntegratorStep      = dlsym(fmu.libHandle, :fmi2CompletedIntegratorStep)
        fmu.cEnterEventMode               = dlsym(fmu.libHandle, :fmi2EnterEventMode)
        fmu.cNewDiscreteStates            = dlsym(fmu.libHandle, :fmi2NewDiscreteStates)
        fmu.cGetEventIndicators           = dlsym(fmu.libHandle, :fmi2GetEventIndicators)
        fmu.cGetNominalsOfContinuousStates= dlsym(fmu.libHandle, :fmi2GetNominalsOfContinuousStates)
    end
end

"""
TODO: FMI specification reference.

Create a new instance of the given fmu, adds a logger if logginOn == true.

Returns the instance of a new FMU component.

For more information call ?fmi2Instantiate

# Keywords
- `visible` if the FMU should be started with graphic interface, if supported (default=`false`)
- `loggingOn` if the FMU should log and display function calls (default=`false`)
- `externalCallbacks` if an external DLL should be used for the fmi2CallbackFunctions, this may improve readability of logging messages (default=`false`)
"""
function fmi2Instantiate!(fmu::FMU2; visible::Bool = false, loggingOn::Bool = false, externalCallbacks::Bool = false)

    ptrLogger = @cfunction(fmi2CallbackLogger, Cvoid, (Ptr{Cvoid}, Ptr{Cchar}, Cuint, Ptr{Cchar}, Ptr{Cchar}))
    if externalCallbacks
        if fmu.callbackLibHandle == C_NULL
            @assert Sys.iswindows() && Sys.WORD_SIZE == 64 "`externalCallbacks=true` is only supported for Windows 64-bit."
            fmu.callbackLibHandle = dlopen(joinpath(dirname(@__FILE__), "callbackFunctions", "binaries", "win64", "callbackFunctions.dll"))
        end
        ptrLogger = dlsym(fmu.callbackLibHandle, :logger)
    end 
    ptrAllocateMemory = @cfunction(fmi2CallbackAllocateMemory, Ptr{Cvoid}, (Csize_t, Csize_t))
    ptrFreeMemory = @cfunction(fmi2CallbackFreeMemory, Cvoid, (Ptr{Cvoid},))
    ptrStepFinished = C_NULL # ToDo
    fmu.callbackFunctions = fmi2CallbackFunctions(ptrLogger, ptrAllocateMemory, ptrFreeMemory, ptrStepFinished, C_NULL)

    guidStr = "$(fmu.modelDescription.guid)"

    compAddr = fmi2Instantiate(fmu.cInstantiate, pointer(fmu.instanceName), fmu.type, pointer(guidStr), pointer(fmu.fmuResourceLocation), Ptr{fmi2CallbackFunctions}(pointer_from_objref(fmu.callbackFunctions)), fmi2Boolean(visible), fmi2Boolean(loggingOn))

    if compAddr == Ptr{Cvoid}(C_NULL)
        @error "fmi2Instantiate!(...): Instantiation failed!"
        return nothing
    end

    component = nothing

    # check if address is already inside of the component (this may be)
    for c in fmu.components
        if c.compAddr == compAddr
            component = c
            break 
        end
    end

    if component != nothing
        @info "fmi2Instantiate!(...): This component was already registered. This may be because you created the FMU by yourself with FMIExport.jl."
    else
        component = FMU2Component(compAddr, fmu) 
        component.jacobianFct = fmi2GetJacobian!
        push!(fmu.components, component)
    end 

    component
end

"""
Reloads the FMU-binary. This is useful, if the FMU does not support a clean reset implementation.
"""
function fmi2Reload(fmu::FMU2)
    dlclose(fmu.libHandle)
    loadBinary(fmu)
end

"""
Unload a FMU.

Free the allocated memory, close the binaries and remove temporary zip and unziped FMU model description.
"""
function fmi2Unload(fmu::FMU2, cleanUp::Bool = true)

    while length(fmu.components) > 0
        fmi2FreeInstance!(fmu.components[end])
    end

    dlclose(fmu.libHandle)

    # the components are removed from the component list via call to fmi2FreeInstance!
    @assert length(fmu.components) == 0 "fmi2Unload(...): Failure during deleting components, $(length(fmu.components)) remaining in stack."

    if cleanUp
        try
            rm(fmu.path; recursive = true, force = true)
            rm(fmu.zipPath; recursive = true, force = true)
        catch e
            @warn "Cannot delete unpacked data on disc. Maybe some files are opened in another application."
        end
    end
end

"""
This function samples the directional derivative by manipulating corresponding values (central differences).
"""
function fmi2SampleDirectionalDerivative(c::fmi2Component,
                                       vUnknown_ref::Array{fmi2ValueReference},
                                       vKnown_ref::Array{fmi2ValueReference},
                                       steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)

    dvUnknown = zeros(fmi2Real, length(vUnknown_ref), length(vKnown_ref))

    fmi2SampleDirectionalDerivative!(c, vUnknown_ref, vKnown_ref, dvUnknown, steps)

    dvUnknown
end

"""
This function samples the directional derivative by manipulating corresponding values (central differences) and saves in-place.
"""
function fmi2SampleDirectionalDerivative!(c::fmi2Component,
                                          vUnknown_ref::Array{fmi2ValueReference},
                                          vKnown_ref::Array{fmi2ValueReference},
                                          dvUnknown::AbstractArray,
                                          steps::Array{fmi2Real} = ones(fmi2Real, length(vKnown_ref)).*1e-5)
    
    for i in 1:length(vKnown_ref)
        vKnown = vKnown_ref[i]
        origValue = fmi2GetReal(c, vKnown)

        fmi2SetReal(c, vKnown, origValue - steps[i]*0.5)
        negValues = fmi2GetReal(c, vUnknown_ref)

        fmi2SetReal(c, vKnown, origValue + steps[i]*0.5)
        posValues = fmi2GetReal(c, vUnknown_ref)

        fmi2SetReal(c, vKnown, origValue)

        if length(vUnknown_ref) == 1
            dvUnknown[1,i] = (posValues-negValues) ./ steps[i]
        else
            dvUnknown[:,i] = (posValues-negValues) ./ steps[i]
        end
    end

    nothing
end

"""
Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD). 

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi2GetJacobian(comp::FMU2Component, 
                         rdx::Array{fmi2ValueReference}, 
                         rx::Array{fmi2ValueReference}; 
                         steps::Array{fmi2Real} = ones(fmi2Real, length(rdx)).*1e-5)
    mat = zeros(fmi2Real, length(rdx), length(rx))
    fmi2GetJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
For optimization, if the FMU's model description has the optional entry 'dependencies', only dependent variables are sampled/retrieved. This drastically boosts performance for systems with large variable count (like CFD). 

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi2GetJacobian!(jac::Matrix{fmi2Real}, 
                          comp::FMU2Component, 
                          rdx::Array{fmi2ValueReference}, 
                          rx::Array{fmi2ValueReference}; 
                          steps::Array{fmi2Real} = ones(fmi2Real, length(rdx)).*1e-5)

    @assert size(jac) == (length(rdx), length(rx)) ["fmi2GetJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."]

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    ddsupported = fmi2ProvidesDirectionalDerivative(comp.fmu)

    # ToDo: Pick entries based on dependency matrix!
    #depMtx = fmi2GetDependencies(fmu)
    rdx_inds = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rdx)
    rx_inds  = collect(comp.fmu.modelDescription.valueReferenceIndicies[vr] for vr in rx)
    
    for i in 1:length(rx)

        sensitive_rdx_inds = 1:length(rdx)
        sensitive_rdx = rdx

        # sensitive_rdx_inds = Int64[]
        # sensitive_rdx = fmi2ValueReference[]

        # for j in 1:length(rdx)
        #     if depMtx[rdx_inds[j], rx_inds[i]] != fmi2DependencyIndependent
        #         push!(sensitive_rdx_inds, j)
        #         push!(sensitive_rdx, rdx[j])
        #     end
        # end

        if length(sensitive_rdx) > 0
            if ddsupported
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                fmi2GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))
                # jac[sensitive_rdx_inds, i] = fmi2GetDirectionalDerivative!(comp, sensitive_rdx, [rx[i]])
            else 
                # doesn't work because indexed-views can`t be passed by reference (to ccalls)
                fmi2SampleDirectionalDerivative!(comp, sensitive_rdx, [rx[i]], view(jac, sensitive_rdx_inds, i))
                # jac[sensitive_rdx_inds, i] = fmi2SampleDirectionalDerivative(comp, sensitive_rdx, [rx[i]], steps)
            end
        end
    end
     
    return nothing
end

"""
Builds the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian`.

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi2GetFullJacobian(comp::FMU2Component, 
                             rdx::Array{fmi2ValueReference}, 
                             rx::Array{fmi2ValueReference}; 
                             steps::Array{fmi2Real} = ones(fmi2Real, length(rdx)).*1e-5)
    mat = zeros(fmi2Real, length(rdx), length(rx))
    fmi2GetFullJacobian!(mat, comp, rdx, rx; steps=steps)
    return mat
end

"""
Fills the jacobian over the FMU `fmu` for FMU value references `rdx` and `rx`, so that the function returns the jacobian ∂rdx / ∂rx.

If FMI built-in directional derivatives are supported, they are used.
As fallback, directional derivatives will be sampled with central differences.
No performance optimization, for an optimized version use `fmi2GetJacobian!`.

If sampling is used, sampling step size can be set (for each direction individually) using optional argument `steps`.
"""
function fmi2GetFullJacobian!(jac::Matrix{fmi2Real}, 
                              comp::FMU2Component, 
                              rdx::Array{fmi2ValueReference}, 
                              rx::Array{fmi2ValueReference}; 
                              steps::Array{fmi2Real} = ones(fmi2Real, length(rdx)).*1e-5)
    @assert size(jac) == (length(rdx),length(rx)) "fmi2GetFullJacobian!: Dimension missmatch between `jac` $(size(jac)), `rdx` ($length(rdx)) and `rx` ($length(rx))."

    @warn "`fmi2GetFullJacobian!` is for benchmarking only, please use `fmi2GetJacobian`."

    if length(rdx) == 0 || length(rx) == 0
        jac = zeros(length(rdx), length(rx))
        return nothing
    end 

    if fmi2ProvidesDirectionalDerivative(comp.fmu)
        for i in 1:length(rx)
            jac[:,i] = fmi2GetDirectionalDerivative(comp, rdx, [rx[i]])
        end
    else
        jac = fmi2SampleDirectionalDerivative(comp, rdx, rx)
    end

    return nothing
end

function fmi2Get!(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, dstArray::Array)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(dstArray) "fmi2Get!(...): Number of value references doesn't match number of `dstArray` elements."

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi2ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if mv.datatype.datatype == fmi2Real 
            #@assert isa(dstArray[i], Real) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetReal(comp, vr)
        elseif mv.datatype.datatype == fmi2Integer 
            #@assert isa(dstArray[i], Union{Real, Integer}) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetInteger(comp, vr)
        elseif mv.datatype.datatype == fmi2Boolean 
            #@assert isa(dstArray[i], Union{Real, Bool}) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetBoolean(comp, vr)
        elseif mv.datatype.datatype == fmi2String 
            #@assert isa(dstArray[i], String) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(dstArray[i]))`."
            dstArray[i] = fmi2GetString(comp, vr)
        elseif mv.datatype.datatype == fmi2Enum 
            @warn "fmi2Get!(...): Currently not implemented for fmi2Enum."
        else 
            @assert isa(dstArray[i], Real) "fmi2Get!(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end

    return nothing
end

function fmi2Get(comp::FMU2Component, vrs::fmi2ValueReferenceFormat)
    vrs = prepareValueReference(comp, vrs)
    dstArray = Array{Any,1}(undef, length(vrs))
    fmi2Get!(comp, vrs, dstArray)
    return dstArray
end

function fmi2Set(comp::FMU2Component, vrs::fmi2ValueReferenceFormat, srcArray::Array)
    vrs = prepareValueReference(comp, vrs)

    @assert length(vrs) == length(srcArray) "fmi2Set(...): Number of value references doesn't match number of `srcArray` elements."

    for i in 1:length(vrs)
        vr = vrs[i]
        mv = fmi2ModelVariablesForValueReference(comp.fmu.modelDescription, vr)
        mv = mv[1]

        if mv.datatype.datatype == fmi2Real 
            @assert isa(srcArray[i], Real) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Real`, is `$(typeof(srcArray[i]))`."
            fmi2SetReal(comp, vr, srcArray[i])
        elseif mv.datatype.datatype == fmi2Integer 
            @assert isa(srcArray[i], Union{Real, Integer}) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Integer`, is `$(typeof(srcArray[i]))`."
            fmi2SetInteger(comp, vr, Integer(srcArray[i]))
        elseif mv.datatype.datatype == fmi2Boolean 
            @assert isa(srcArray[i], Union{Real, Bool}) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `Bool`, is `$(typeof(srcArray[i]))`."
            fmi2SetBoolean(comp, vr, Bool(srcArray[i]))
        elseif mv.datatype.datatype == fmi2String 
            @assert isa(srcArray[i], String) "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), should be `String`, is `$(typeof(srcArray[i]))`."
            fmi2SetString(comp, vr, srcArray[i])
        elseif mv.datatype.datatype == fmi2Enum 
            @warn "fmi2Set(...): Currently not implemented for fmi2Enum."
        else 
            @assert false "fmi2Set(...): Unknown data type for value reference `$(vr)` at index $(i), is `$(mv.datatype.datatype)`."
        end
    end

    return nothing
end
