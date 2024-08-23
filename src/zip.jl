#
# Copyright (c) 2021 Tobias Thummerer, Lars Mikelsons, Josef Kircher
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using FMIBase.ZipFile
import Downloads

"""
    unzip(pathToFMU::String; unpackPath=nothing, cleanup=true)

Create a copy of the .fmu file as a .zip folder and unzips it.
Returns the paths to the zipped and unzipped folders.

# Arguments
- `pathToFMU::String`: The folder path to the .zip folder.

# Keywords
- `unpackPath=nothing`: Via optional argument ```unpackPath```, a path to unpack the FMU can be specified (default: system temporary directory).
- `cleanup=true`: The cleanup option controls whether the temporary directory is automatically deleted when the process exits.

# Returns
- `unzippedAbsPath::String`: Contains the Path to the uzipped Folder.
- `zipAbsPath::String`: Contains the Path to the zipped Folder.

See also [`mktempdir`](https://docs.julialang.org/en/v1/base/file/#Base.Filesystem.mktempdir-Tuple{AbstractString}).
"""
function unzip(pathToFMU::String; unpackPath = nothing, cleanup = true)

    if startswith(pathToFMU, "http")
        pathToFMU = Downloads.download(pathToFMU)
    end

    fileNameExt = basename(pathToFMU)
    (fileName, fileExt) = splitext(fileNameExt)

    if unpackPath == nothing
        # cleanup = true leads to issues with automatic testing on linux server.
        unpackPath = mktempdir(; prefix = "fmijl_", cleanup = cleanup)
    end

    zipPath = joinpath(unpackPath, fileName * ".zip")
    unzippedPath = joinpath(unpackPath, fileName)

    # only copy ZIP if not already there
    if !isfile(zipPath)
        cp(pathToFMU, zipPath; force = true)
    end

    @assert isfile(zipPath) ["unzip(...): ZIP-Archive couldn't be copied to `$zipPath`."]

    zipAbsPath = isabspath(zipPath) ? zipPath : joinpath(pwd(), zipPath)
    unzippedAbsPath = isabspath(unzippedPath) ? unzippedPath : joinpath(pwd(), unzippedPath)

    @assert isfile(zipAbsPath) ["unzip(...): Can't deploy ZIP-Archive at `$(zipAbsPath)`."]

    numFiles = 0

    # only unzip if not already done
    if !isdir(unzippedAbsPath)
        mkpath(unzippedAbsPath)

        zarchive = ZipFile.Reader(zipAbsPath)
        for f in zarchive.files
            fileAbsPath = normpath(joinpath(unzippedAbsPath, f.name))

            if endswith(f.name, "/") || endswith(f.name, "\\")
                mkpath(fileAbsPath) # mkdir(fileAbsPath)

                @assert isdir(fileAbsPath) [
                    "unzip(...): Can't create directory `$(f.name)` at `$(fileAbsPath)`.",
                ]
            else
                # create directory if not forced by zip file folder
                mkpath(dirname(fileAbsPath))

                numBytes = write(fileAbsPath, read(f))

                if numBytes == 0
                    @debug "unzip(...): Written file `$(f.name)`, but file is empty."
                end

                @assert isfile(fileAbsPath) [
                    "unzip(...): Can't unzip file `$(f.name)` at `$(fileAbsPath)`.",
                ]
                numFiles += 1
            end
        end
        close(zarchive)
    end

    @assert isdir(unzippedAbsPath) [
        "unzip(...): ZIP-Archive couldn't be unzipped at `$(unzippedPath)`.",
    ]
    @debug "funzip(...): Successfully unzipped $numFiles files at `$unzippedAbsPath`."

    (unzippedAbsPath, zipAbsPath)
end
