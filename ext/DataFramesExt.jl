module DataFramesExt

import DataFrames: DataFrame
import PandasJSON: read, _json_examples
import PrecompileTools: @compile_workload

@compile_workload begin
    for (fn, kw) in _json_examples
        read(fn, DataFrame; kw...)
    end
end

end
