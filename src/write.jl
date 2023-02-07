"""
    write(filename_or_io, table; orient="columns", index=nothing)

Write the given table to the given file in JSON format.

## Keyword Args

- `orient`: the format of the data in the JSON file, one of `"columns"`, `"index"`,
  `"records"`, `"split"`, `"table"` or `"values"`. The default `"columns"` matches the
  default used by Pandas.
  
- `index`: an optional vector of index values to use, instead of the default 0, 1, 2...
"""
function write(io::IO, table; orient::AbstractString="columns", index::Union{Nothing,AbstractVector}=nothing)
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
            string(index === nothing ? i-1 : index[begin+i-1]) => _to_json_item(x)
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
        data[string(index === nothing ? i-1 : index[begin+i-1])] = newrow
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
    if index === nothing
        index = Int[i-1 for i in 1:length(data)]
    else
        length(index) == length(data) || error("index must be the same length as the table")
        index = [_to_json_item(x) for x in index]
    end
    JSON3.write(io, (; index, columns, data))
end

_to_json_field_type(::Type{<:Union{Missing,Bool}}) = "boolean"
_to_json_field_type(::Type{<:Union{Missing,Integer}}) = "integer"
_to_json_field_type(::Type{<:Union{Missing,Real}}) = "number"
_to_json_field_type(::Type{<:Union{Missing,AbstractString}}) = "string"
_to_json_field_type(::Type{T}) where {T} = "string"

function _to_json_table(io, table; rows=Tables.rows(table), sch=Tables.schema(rows), index)
    idxname = :index
    while idxname in sch.names
        idxname = Symbol("_", idxname)
    end
    data = Dict{Symbol,Any}[]
    fields = [
        (
            name = colname,
            type = _to_json_field_type(coltype),
        )
        for (colname, coltype) in zip(sch.names, sch.types)
    ]
    pushfirst!(fields, (name = idxname, type = index === nothing ? "integer" : _to_json_field_type(eltype(index))))
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        newrow[idxname] = index === nothing ? i-1 : index[begin+i-1]
        push!(data, newrow)
    end
    schema = (;
        fields,
        primaryKey = [idxname],
    )
    JSON3.write(io, (; schema, data))
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
