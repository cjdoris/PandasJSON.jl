module DataFramesExt

import DataFrames: DataFrame
import PandasIO: read_json, _json_examples
import SnoopPrecompile: @precompile_all_calls

@precompile_all_calls begin
    for (fn, kw) in _json_examples
        read_json(fn, DataFrame; kw...)
    end
end

end
