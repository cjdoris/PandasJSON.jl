"""
    write(file, table;
        orient="columns",
        index=true,
        date_format=nothing,
        date_unit="ms",
    )

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

- `date_format`: One of `"epoch"` or `"iso"`. The default for `orient="table"` is `"iso"`,
  otherwise it is `"epoch"`.

- `date_unit`: The precision of any encoded timestamps. One of `"s"`, `"ms"`, `"us"` or
  `"ns"`.
"""
function write(io::IO, table;
    orient::AbstractString="columns",
    index::Union{Bool,AbstractVector}=true,
    date_format::Union{Nothing,AbstractString}=nothing,
    date_unit::AbstractString="ms",
)
    if index isa Bool && !index && orient != "split" && orient != "table"
        error("index=false only supported for orient=\"split\" or orient=\"table\"")
    end
    if date_format === nothing
        date_format = orient == "table" ? "iso" : "epoch"
    end
    fmt = Format(date_format, date_unit)
    if orient == "columns"
        _write_columns(io, table; fmt, index)
    elseif orient == "index"
        _write_index(io, table; fmt, index)
    elseif orient == "records"
        _write_records(io, table; fmt)
    elseif orient == "split"
        _write_split(io, table; fmt, index)
    elseif orient == "table"
        _write_table(io, table; fmt, index)
    elseif orient == "values"
        _write_values(io, table; fmt)
    else
        error("invalid orient=$(repr(orient))")
    end
    return
end

write(filename::AbstractString, table; kw...) = open(io->write(io, table; kw...), filename, "w")

struct Format{DF,DU}
    function Format(df, du)
        df = Symbol(df)
        du = Symbol(du)
        df in (:epoch, :iso) || error("invalid date_format: $df")
        du in (:s, :ms, :us, :ns) || error("invalid date_unit: $du")
        return new{df,du}()
    end
end

_to_json(x::Union{Nothing,Bool,Real,AbstractString}, fmt) = x
_to_json(x::Missing, fmt) = nothing
_to_json(x::Real, fmt) = isfinite(x) ? x : nothing
_to_json(x::Union{AbstractVector,AbstractSet,Tuple}, fmt) = [_to_json(x, fmt) for x in x]
_to_json(x::AbstractDict, fmt) = Dict(string(k) => _to_json(v, fmt) for (k, v) in x)
_to_json(x::Dates.DateTime, ::Format{:epoch,:s}) = ((x - Dates.DateTime(1970))::Dates.Millisecond).value ÷ 1000
_to_json(x::Dates.DateTime, ::Format{:epoch,:ms}) = ((x - Dates.DateTime(1970))::Dates.Millisecond).value
_to_json(x::Dates.DateTime, ::Format{:epoch,:us}) = ((x - Dates.DateTime(1970))::Dates.Millisecond).value * 1000
_to_json(x::Dates.DateTime, ::Format{:epoch,:ns}) = ((x - Dates.DateTime(1970))::Dates.Millisecond).value * 1000000
_to_json(x::Dates.DateTime, ::Format{:iso,:s}) = Dates.format(x, Dates.dateformat"yyyy-mm-ddTHH:MM:SS")
_to_json(x::Dates.DateTime, ::Format{:iso,:ms}) = Dates.format(x, Dates.dateformat"yyyy-mm-ddTHH:MM:SS.sss")
_to_json(x::Dates.DateTime, ::Format{:iso,:us}) = Dates.format(x, Dates.dateformat"yyyy-mm-ddTHH:MM:SS.sss000")
_to_json(x::Dates.DateTime, ::Format{:iso,:ns}) = Dates.format(x, Dates.dateformat"yyyy-mm-ddTHH:MM:SS.sss000000")

function _write_columns(io, table; cols=Tables.columns(table), index, fmt)
    data = Dict{Symbol,Dict{String,Any}}()
    for colname in Tables.columnnames(cols)
        data[colname] = Dict{String,Any}(
            string(index isa Bool ? i-1 : index[begin+i-1]) => _to_json(x, fmt)
            for (i, x) in enumerate(Tables.getcolumn(cols, colname))
        )
    end
    JSON3.write(io, data)
end

function _write_index(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index, fmt)
    data = Dict{String,Dict{Symbol,Any}}()
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json(x, fmt)
        end
        data[string(index isa Bool ? i-1 : index[begin+i-1])] = newrow
    end
    JSON3.write(io, data)
end

function _write_records(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), fmt)
    data = Vector{Dict{Symbol,Any}}()
    for row in rows
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json(x, fmt)
        end
        push!(data, newrow)
    end
    JSON3.write(io, data)
end

function _write_split(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index, fmt)
    data = Vector{Any}[]
    columns = collect(Tables.columnnames(rows))
    for row in rows
        newrow = []
        Tables.eachcolumn(sch, row) do x, _, _
            push!(newrow, _to_json(x, fmt))
        end
        push!(data, newrow)
    end
    if index isa Bool
        include_index = index
        index = Int[i-1 for i in 1:length(data)]
    else
        include_index = true
        length(index) == length(data) || error("index must be the same length as the table")
        index = [_to_json(x, fmt) for x in index]
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

function _write_table(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index, fmt)
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
            newrow[colname] = _to_json(x, fmt)
        end
        if include_index
            newrow[idxname] = _to_json(index isa Bool ? i-1 : index[begin+i-1], fmt)
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

function _write_values(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), fmt)
    data = Vector{Vector{Any}}()
    for row in rows
        newrow = []
        Tables.eachcolumn(sch, row) do x, _, _
            push!(newrow, _to_json(x, fmt))
        end
        push!(data, newrow)
    end
    JSON3.write(io, data)
end
