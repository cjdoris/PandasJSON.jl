"""
    write(file, table; orient="columns", index=true)

Write the given table to the given file in JSON format.

## Args
- `file`: Either a file name or an open IO stream.
- `table`: A Tables.jl-compatible table.

## Keyword Args

- `orient`: The format of the data in the JSON file, one of `"columns"`, `"index"`,
  `"records"`, `"split"`, `"table"` or `"values"`. The default `"columns"` matches the
  default used by Pandas.
  
- `index`: Whether or not to include the index. Not including the index (`index=false`) is
  only supported for `orient="split"` and `orient="table"`. By default the index is
  `[0,1,2,...]` but you may pass a vector of index values instead.
"""
function write(io::IO, table; orient::AbstractString="columns", index::Union{Bool,AbstractVector}=true)
    if index isa Bool && !index && orient != "split" && orient != "table"
        error("index=false only supported for orient=\"split\" or orient=\"table\"")
    end
    if orient == "columns"
        _to_json_columns(io, table; index)
    elseif orient == "index"
        _to_json_index(io, table; index)
    elseif orient == "records"
        _to_json_records(io, table)
    elseif orient == "split"
        _to_json_split(io, table; index)
    elseif orient == "table"
        _to_json_table(io, table; index)
    elseif orient == "values"
        _to_json_values(io, table)
    else
        error("invalid orient=$(repr(orient))")
    end
    return
end

write(filename::AbstractString, table; kw...) = open(io->write(io, table; kw...), filename, "w")

_to_json_item(x::Union{Nothing,Bool,Real,AbstractString}) = x
_to_json_item(x::Missing) = nothing
_to_json_item(x::Real) = isfinite(x) ? x : nothing
_to_json_item(x::Union{AbstractVector,AbstractSet,Tuple}) = [_to_json_item(x) for x in x]
_to_json_item(x::AbstractDict) = Dict(string(k) => _to_json_item(v) for (k, v) in x)

function _to_json_columns(io, table; cols=Tables.columns(table), index)
    data = Dict{Symbol,Dict{String,Any}}()
    for colname in Tables.columnnames(cols)
        data[colname] = Dict{String,Any}(
            string(index isa Bool ? i-1 : index[begin+i-1]) => _to_json_item(x)
            for (i, x) in enumerate(Tables.getcolumn(cols, colname))
        )
    end
    JSON3.write(io, data)
end

function _to_json_index(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index)
    data = Dict{String,Dict{Symbol,Any}}()
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        data[string(index isa Bool ? i-1 : index[begin+i-1])] = newrow
    end
    JSON3.write(io, data)
end

function _to_json_records(io, table; rows=Tables.rows(table), sch=Tables.schema(rows))
    data = Vector{Dict{Symbol,Any}}()
    for row in rows
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        push!(data, newrow)
    end
    JSON3.write(io, data)
end

function _to_json_split(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index)
    data = Vector{Any}[]
    columns = collect(Tables.columnnames(rows))
    for row in rows
        newrow = []
        Tables.eachcolumn(sch, row) do x, _, _
            push!(newrow, _to_json_item(x))
        end
        push!(data, newrow)
    end
    if index isa Bool
        include_index = index
        index = Int[i-1 for i in 1:length(data)]
    else
        include_index = true
        length(index) == length(data) || error("index must be the same length as the table")
        index = [_to_json_item(x) for x in index]
    end
    if include_index
        JSON3.write(io, (; index, columns, data))
    else
        JSON3.write(io, (; columns, data))
    end
end

function _table_schema_field(name, T)
    n = Symbol(name)
    e = nothing
    if T <: Missing
        t = "string"
    elseif T <: Union{Bool,Missing}
        t = "boolean"
        if Missing <: T
            e = "boolean"
        end
    elseif T <: Union{Missing,Integer}
        t = "integer"
        if Missing <: T
            e = "Int64"
        end
    elseif T <: Union{Missing,Real}
        t = "number"
    else
        t = "string"
    end
    return NamedTuple{(:name,:type,:extDtype),Tuple{Symbol,String,Union{String,Nothing}}}((n,t,e))
end

function _to_json_table(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index)
    include_index = !isa(index, Bool) || index
    idxname = :index
    while idxname in sch.names
        idxname = Symbol("_", idxname)
    end
    data = Dict{Symbol,Any}[]
    fields = [
        _table_schema_field(colname, coltype)
        for (colname, coltype) in zip(sch.names, sch.types)
    ]
    if include_index
        pushfirst!(fields, _table_schema_field(idxname, index isa Bool ? Int : eltype(index)))
    end
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        if include_index
            newrow[idxname] = index isa Bool ? i-1 : index[begin+i-1]
        end
        push!(data, newrow)
    end
    if include_index
        schema = (; fields, primaryKey = [idxname])
        JSON3.write(io, (; schema, data))
    else
        schema = (; fields)
        JSON3.write(io, (; schema, data))
    end
end

function _to_json_values(io, table; rows=Tables.rows(table), sch=Tables.schema(rows))
    data = Vector{Vector{Any}}()
    for row in rows
        newrow = []
        Tables.eachcolumn(sch, row) do x, _, _
            push!(newrow, _to_json_item(x))
        end
        push!(data, newrow)
    end
    JSON3.write(io, data)
end
