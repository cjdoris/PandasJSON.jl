module PandasJSON

import JSON3
import Tables
import SnoopPrecompile: @precompile_all_calls

include("read.jl")
include("write.jl")
include("guess_orient.jl")

const _json_examples = [
    (joinpath(dirname(@__DIR__), "examples", "frame-$id-$orient.json"), (; orient))
    for id in ["01", "02", "03", "04"]
    for orient in ["columns", "index", "records", "split", "table", "values"]
]

@precompile_all_calls begin
    for (fn, kw) in _json_examples
        read(fn; kw...)
    end
end

end # module PandasJSON
