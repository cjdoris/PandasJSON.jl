_from_json(::Type{T}, x) where {T} = x === nothing ? missing : convert(T, x)::T
_from_json(::Type{Any}, x) = _from_json(x)

_from_json(x) =
    x === nothing ? missing :
    x isa AbstractVector ? [_from_json(x) for x in x] :
    x isa AbstractDict ? [_from_json(x) for x in x] :
    x isa Symbol ? String(x) :
    x isa AbstractString ? convert(String, x) : x

function _read_table_column(::Type{T}, k, rows) where {T}
    return [_from_json(T, get(row, k, nothing)) for row in rows]
end

function _sort_index!(idx)
    # int sort
    intidx = Union{Int,Nothing}[tryparse(Int, x) for x in idx]
    if !any(isnothing, intidx)
        return permute!(idx, sortperm(intidx))
    end
    # string sort
    return sort!(idx)
end

function _sort_columns!(cols)
    return sort!(cols)
end

function _read_columns!(io, data, index)
    o = JSON3.read(io, Dict{Symbol, Dict{String,Any}})
    idx = _sort_index!(unique!([k for col in values(o) for k in keys(col)]))
    index !== nothing && push!(data, index => idx)
    cols = _sort_columns!(collect(keys(o)))
    for k in cols
        col = o[k]
        push!(data, k => [_from_json(get(col, i, nothing)) for i in idx])
    end
end

function _read_index!(io, data, index)
    o = JSON3.read(io, Dict{String,Dict{Symbol,Any}})
    idx = _sort_index!(collect(keys(o)))
    index !== nothing && push!(data, idx)
    cols = _sort_columns!(unique!([k for row in values(o) for k in keys(row)]))
    for k in cols
        push!(data, k => [_from_json(get(o[i], k, nothing)) for i in idx])
    end
end

function _read_records!(io, data, index)
    o = JSON3.read(io, Vector{Dict{Symbol,Any}})
    index !== nothing && push!(data, index => 1:length(o))
    cols = _sort_columns!(unique!([k for row in o for k in keys(row)]))
    for k in cols
        push!(data, k => [_from_json(get(row, k, nothing)) for row in o])
    end
end

function _read_split!(io, data, index)
    o = JSON3.read(io, @NamedTuple{columns::Vector{Symbol}, index::Vector, data::Vector{Vector{Any}}})
    index !== nothing && push!(data, index => map(identity, o.index))
    cols = o.columns
    for (i, k) in pairs(cols)
        push!(data, k => [_from_json(row[i]) for row in o.data])
    end
end

function _field_type(t)
    if t isa AbstractString
        if t == "boolean"
            return Bool
        elseif t == "string"
            return Any
        elseif t == "number"
            return Real
        elseif t == "integer"
            return Integer
        elseif t == "datetime"
            return Union{Integer,String}
        end
    end
    error("unknown field type: $(repr(t))")
end

function _read_table!(io, data, index, coltypes)
    o = JSON3.read(io, @NamedTuple{schema::@NamedTuple{fields::Vector{@NamedTuple{name::Symbol,type::Any}}, primaryKey::Vector{Symbol}}, data::Vector{Dict{Symbol,Any}}})
    datetime_cols = Int[]
    unparsed_cols = Int[]
    for fld in o.schema.fields
        k = fld.name
        index === nothing && k in o.schema.primaryKey && continue
        T = _field_type(fld.type)
        push!(data, k => _read_table_column(T, k, o.data))
        fld.type == "string" || push!(coltypes, k => Symbol(fld.type))
    end
end

function _read_values!(io, data, index)
    o = JSON3.read(io, Vector{Vector{Any}})
    index !== nothing && push!(data, index => 1:length(o))
    ncols = length(first(o))
    for k in 1:ncols
        push!(data, Symbol("Column$k") => [_from_json(row[k]) for row in o])
    end
end

"""
    read(file, [type];
      orient="columns",
      index=false,
      convert_dates=true,
      keep_default_dates=true,
      date_unit=nothing,
    )

Read a Pandas dataframe in JSON format from the given file.

## Args
- `file`: Either a file name or an open IO stream.
- `type`: The type of the returned table.

## Keyword Args

- `orient`: The format of the data in the JSON file, one of `"columns"`, `"index"`,
  `"records"`, `"split"`, `"table"` or `"values"`. The default `"columns"` matches the
  default used by Pandas. See [`guess_orient`](@ref) if you are not sure.

- `index`: If true, include the index as extra column(s) of the table. By default the column
  name is `index` but can be specified by setting `index` to a `Symbol`.

- `convert_dates`: If true, convert datetimes (encoded as strings or timestamps) to
  `Dates.DateTime`. Note that these are truncated to millisecond precision. By default only
  the columns specified by `keep_default_dates` are converted. You may instead pass a vector
  of column names to convert these to dates.

- `keep_default_dates`: If true, try to convert any columns with the following names to
  `Dates.DateTime`: `modified`, `date`, `datetime`, `timestamp*`, `*_at`, `*_time`.

- `date_unit`: The unit of any timestamps. By default, the unit is guessed from the data but
  can be specified as one of: `"s"`, `"ms"`, `"us"` or `"ns"`.
"""
function read(io::IO;
    orient::AbstractString="columns",
    index::Union{Nothing,Symbol,Bool}=nothing,
    convert_dates::Union{Bool,AbstractVector}=true,
    keep_default_dates::Bool=true,
    date_unit::Union{Nothing,AbstractString}=nothing,
)
    # boolean index is interpreted as :index or nothing
    if index isa Bool
        index = index ? :index : nothing
    end
    # parse into columnname => columndata pairs
    data = Vector{Pair{Symbol,Vector}}()
    coltypes = Dict{Symbol,Symbol}()
    if orient == "columns"
        _read_columns!(io, data, index)
    elseif orient == "index"
        _read_index!(io, data, index)
    elseif orient == "records"
        _read_records!(io, data, index)
    elseif orient == "split"
        _read_split!(io, data, index)
    elseif orient == "table"
        _read_table!(io, data, index, coltypes)
    elseif orient == "values"
        _read_values!(io, data, index)
    else
        error("invalid orient=$(repr(orient))")
    end
    # indices of columns of datetimes
    if convert_dates isa AbstractVector
        for k in convert_dates
            coltypes[Symbol(k)] = :datetime
        end
        convert_dates = true
        keep_default_dates = false
    end
    # try to convert datetimes
    if convert_dates
        for (i, (k, oldcol)) in pairs(data)
            t = get(coltypes, k, :unknown)
            t === :datetime || (keep_default_dates && t === :unknown && _colname_might_be_datetime(k)) || continue
            col = _try_convert_col_to_datetime(oldcol, date_unit)
            if col === nothing
                if t === :datetime
                    error("cannot parse column $(repr(colname)) as a datetime")
                else
                    continue
                end
            end
            data[i] = k => col
            coltypes[k] = :datetime
        end
    end
    # construct the returned table
    schema = Tables.Schema([k for (k, _) in data], [eltype(c) for (_, c) in data])
    dict = Tables.OrderedDict(data)
    return Tables.DictColumnTable(schema, dict)
end

read(fn::AbstractString; kw...) = open(io -> read(io; kw...), fn)
read(file, sink; kw...) = sink(read(file; kw...))

function _col_map(f, col)
    ans = Base.Iterators.map(x -> x === missing ? missing : f(x), col)
    ans = Base.Iterators.takewhile(!isnothing, ans)
    ans = collect(ans)
    if length(ans) != length(col)
        ans = nothing
    end
    return ans
end

function _try_convert_col_to_datetime(col, unit)
    if Missing <: eltype(col) && all(ismissing, col)
        return nothing
    elseif all(x->isa(x,Union{Missing,Integer}), col)
        # integers are assumed to be timestamps between 1971 and 2970
        if unit === nothing || unit == "ns"
            ans = _col_map(x -> x < 31536000000000000 ? nothing : Dates.DateTime(1970) + Dates.Nanosecond(x), col)
            ans === nothing || return ans
        end
        if unit === nothing || unit == "us"
            ans = _col_map(x -> x < 31536000000000 ? nothing : Dates.DateTime(1970) + Dates.Microsecond(x), col)
            ans === nothing || return ans
        end
        if unit === nothing || unit == "ms"
            ans = _col_map(x -> x < 31536000000 ? nothing : Dates.DateTime(1970) + Dates.Millisecond(x), col)
            ans === nothing || return ans
        end
        if unit === nothing || unit == "s"
            ans = _col_map(x -> x < 31536000 ? nothing : Dates.DateTime(1970) + Dates.Second(x), col)
            ans === nothing || return ans
        end
    elseif all(x->isa(x,Union{Missing,AbstractString}), col)
        ans = _col_map(x -> tryparse(Dates.DateTime, x), col)
        ans === nothing || return ans
    end
    return nothing
end

function _colname_might_be_datetime(k)
    k = lowercase(string(k))
    # see https://github.com/pandas-dev/pandas/blob/main/pandas/io/json/_json.py#L1370
    return k == "modified" || k == "date" || k == "datetime" || startswith(k, "timestamp") || endswith(k, "_at") || endswith(k, "_time")
end
