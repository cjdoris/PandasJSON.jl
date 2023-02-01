module PandasIO

import AbstractTrees
import Gumbo
import JSON3
import Tables
import SnoopPrecompile: @precompile_all_calls

include("read_json.jl")
include("to_json.jl")
include("read_html.jl")

const _json_examples = [
    (joinpath(dirname(@__DIR__), "examples", "frame-$id-$orient.json"), (; orient))
    for id in ["01", "02", "03", "04"]
    for orient in [:columns, :index, :records, :split, :table, :values]
]

@precompile_all_calls begin
    for (fn, kw) in _json_examples
        read_json(fn; kw...)
    end
end

end # module PandasIO
