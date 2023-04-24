module PandasJSON

import Dates
import JSON3
import Tables
import PrecompileTools: @compile_workload

include("read.jl")
include("write.jl")
include("guess_orient.jl")

const _json_examples = [
    (joinpath(dirname(@__DIR__), "examples", "frame-$id-$orient.json"), (; orient))
    for id in ["01", "02", "03", "04", "05"]
    for orient in ["columns", "index", "records", "split", "table", "values"]
]

@compile_workload begin
    for (fn, kw) in _json_examples
        read(fn; kw...)
    end
end

end # module PandasJSON
