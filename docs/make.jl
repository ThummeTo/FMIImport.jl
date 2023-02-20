#
# Copyright (c) 2021 Tobias Thummerer, Johannes Stoljar, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using Documenter, FMIImport

makedocs(sitename="FMIImport.jl",
        format = Documenter.HTML(
            collapselevel = 1,
            sidebar_sitename = false,
            edit_link = nothing
        ),
        modules = [FMIImport],
        checkdocs = :exports,
        pages= Any[
            "Introduction" => "index.md"
            "Examples" =>  "overview.md"
            "FMI2 Library Functions" => "fmi2_library.md"
            "FMI3 Library Functions" => "fmi3_library.md"
            "Related Publication" => "related.md"
            "Contents" => "contents.md"
            ]
        )

deploydocs(repo = "github.com/ThummeTo/FMIImport.jl.git", devbranch = "main")
