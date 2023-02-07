_read_json_item(::Type{T}, x) where {T} = x === nothing ? missing : convert(T, x)::T
_read_json_item(::Type{Any}, x) = _read_json_item(x)

_read_json_item(x) =
    x === nothing ? missing :
    x isa AbstractVector ? [_read_json_item(x) for x in x] :
    x isa AbstractDict ? [_read_json_item(x) for x in x] :
    x isa Symbol ? String(x) :
    x isa AbstractString ? convert(String, x) : x

function _read_json_table_column(::Type{T}, k, rows) where {T}
    return [_read_json_item(T, get(row, k, nothing)) for row in rows]
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

function _read_json_columns!(io, data, index)
    o = JSON3.read(io, Dict{Symbol, Dict{String,Any}})
    idx = _sort_index!(unique!([k for col in values(o) for k in keys(col)]))
    index !== nothing && push!(data, index => idx)
    cols = _sort_columns!(collect(keys(o)))
    for k in cols
        col = o[k]
        push!(data, k => [_read_json_item(get(col, i, nothing)) for i in idx])
    end
end

function _read_json_index!(io, data, index)
    o = JSON3.read(io, Dict{String,Dict{Symbol,Any}})
    idx = _sort_index!(collect(keys(o)))
    index !== nothing && push!(data, idx)
    cols = _sort_columns!(unique!([k for row in values(o) for k in keys(row)]))
    for k in cols
        push!(data, k => [_read_json_item(get(o[i], k, nothing)) for i in idx])
    end
end

function _read_json_records!(io, data, index)
    o = JSON3.read(io, Vector{Dict{Symbol,Any}})
    index !== nothing && push!(data, index => 1:length(o))
    cols = _sort_cols!(unique!([k for row in o for k in keys(row)]))
    for k in cols
        push!(data, k => [_read_json_item(get(row, k, nothing)) for row in o])
    end
end

function _read_json_split!(io, data, index)
    o = JSON3.read(io, @NamedTuple{columns::Vector{Symbol}, index::Vector, data::Vector{Vector{Any}}})
    index !== nothing && push!(data, index => map(identity, o.index))
    cols = o.columns
    for (i, k) in pairs(cols)
        push!(data, k => [_read_json_item(row[i]) for row in o.data])
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
        end
    end
    error("unknown field type: $(repr(t))")
end

function _read_json_table!(io, data, index)
    o = JSON3.read(io, @NamedTuple{schema::@NamedTuple{fields::Vector{@NamedTuple{name::Symbol,type::Any}}, primaryKey::Vector{Symbol}}, data::Vector{Dict{Symbol,Any}}})
    for fld in o.schema.fields
        k = fld.name
        index === nothing && k in o.schema.primaryKey && continue
        T = _field_type(fld.type)
        push!(data, k => _read_json_table_column(T, k, o.data))
    end
end

function _read_json_values!(io, data, index)
    o = JSON3.read(io, Vector{Vector{Any}})
    index !== nothing && push!(data, index => 1:length(o))
    ncols = length(first(o))
    for k in 1:ncols
        push!(data, Symbol("Column$k") => [_read_json_item(row[k]) for row in o])
    end
end

"""
    guess_orient(filename_or_io)

Guess possible values for the `orient` parameter used when the given file was created.

A list of symbols is returned, the values being one of `:columns`, `:index`, `:records`,
`:split`, `:table` or `:values`.

Normally one possibility is returned. Since `:columns` and `:index` are similar formats,
these two cases cannot be distinguished and are always returned together - in which case
`:columns` is the likely format since this is the default in Pandas.
"""
function guess_orient(io::IO)
    # read a character (skip space)
    function readc(io)
        while true
            c = Base.read(io, Char)
            isspace(c) || return c
        end
    end
    # read a string (skip space)
    function reads(io)
        c = readc(io)
        c == '"' || error("invalid JSON")
        cs = Char[]
        while true
            c = Base.read(io, Char)
            if c == '"'
                return String(cs)
            else
                push!(cs, c)
            end
        end
    end
    pos = position(io)
    c = readc(io)
    if c == '{'
        k = reads(io)
        if k in ["schema", "data", "index", "columns"]
            # need to parse the whole file to get the full set of keys
            # TODO: make a special dict type which only stores the keys
            seek(io, pos)
            o = JSON3.read(io, Dict{Symbol,Any})
            if issubset([:columns, :data], keys(o)) && o[:data] isa AbstractVector
                return [:split]
            elseif issubset([:schema, :data], keys(o)) && o[:data] isa AbstractVector
                return [:table]
            else
                return [:columns, :index]
            end
        else
            return [:columns, :index]
        end
    elseif c == '['
        c = readc(io)
        if c == '{' || c == ']'
            return [:records]
        elseif c == '['
            return [:values]
        end
    end
    return Symbol[]
end

guess_orient(filename::AbstractString) = open(guess_orient, filename)

"""
    read(file, [type]; orient=:columns, index=false)

Read a Pandas dataframe in JSON format from the given file or IO stream.

## Args
- `file`: Either a file name or an open IO stream.
- `type`: The type of the returned table.

## Keyword Args

- `orient`: the format of the data in the JSON file, one of `:columns`, `:index`,
  `:records`, `:split`, `:table` or `:values`. The default `:columns` matches the default
  used by Pandas. See [`guess_orient`](@ref) if you are not sure.

- `index`: if true, include the index as extra column(s) of the table. By default the column
  name is `index` but can be specified by setting `index` to a `Symbol`.
"""
function read(io::IO; orient::Symbol=:columns, index::Union{Nothing,Symbol,Bool}=nothing)
    # boolean index is interpreted as :index or nothing
    if index isa Bool
        index = index ? :index : nothing
    end
    # parse into columnname => columndata pairs
    data = Vector{Pair{Symbol,Vector}}()
    if orient === :columns
        _read_json_columns!(io, data, index)
    elseif orient === :index
        _read_json_index!(io, data, index)
    elseif orient === :records
        _read_json_records!(io, data, index)
    elseif orient === :split
        _read_json_split!(io, data, index)
    elseif orient === :table
        _read_json_table!(io, data, index)
    elseif orient === :values
        _read_json_values!(io, data, index)
    else
        error("invalid orient=$(repr(orient))")
    end
    # construct the returned table
    schema = Tables.Schema([k for (k, _) in data], [eltype(c) for (_, c) in data])
    dict = Tables.OrderedDict(data)
    return Tables.DictColumnTable(schema, dict)
end

read(fn::AbstractString; kw...) = open(io -> read(io; kw...), fn)
read(file, sink; kw...) = sink(read(file; kw...))
