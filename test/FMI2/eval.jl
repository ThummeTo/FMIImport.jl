using PkgEval
using FMIImport

config = Configuration(; julia="1.8");

package = Package(; name="FMIImport");

@info "PkgEval"
result = evaluate([config], [package])

@info "Result"
println(result)

@info "Log"
println(result.log)