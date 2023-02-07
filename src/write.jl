"""
    write(filename_or_io, table; orient="columns")

Write the given table to the given file in JSON format.

## Keyword Args

- `orient`: the format of the data in the JSON file, one of `"columns"`, `"index"`,
  `"records"`, `"split"`, `"table"` or `"values"`. The default `"columns"` matches the
  default used by Pandas.
"""
function write(io::IO, table; orient::AbstractString="columns")
    if orient == "columns"
        _to_json_columns(io, table)
    elseif orient == "index"
        _to_json_index(io, table)
    elseif orient == "records"
        _to_json_records(io, table)
    elseif orient == "split"
        _to_json_split(io, table)
    elseif orient == "table"
        _to_json_table(io, table)
    elseif orient == "values"
        _to_json_values(io, table)
    else
        error("invalid orient=$(repr(orient))")
    end
    return
end

write(filename::AbstractString, table; kw...) = open(io->write(io, table; kw...), filename, "w")

_to_json_item(x::Union{Nothing,Bool,Real}) = x
_to_json_item(x::Missing) = nothing
_to_json_item(x::Real) = isfinite(x) ? x : nothing
_to_json_item(x::Union{AbstractVector,AbstractSet,Tuple}) = [_to_json_item(x) for x in x]
_to_json_item(x::AbstractDict) = Dict(string(k) => _to_json_item(v) for (k, v) in x)

function _to_json_columns(io, table; cols=Tables.columns(table))
    data = Dict{Symbol,Dict{String,Any}}()
    for colname in Tables.columnnames(cols)
        data[colname] = Dict{String,Any}(
            string(i-1) => _to_json_item(x)
            for (i, x) in enumerate(Tables.getcolumn(cols, colname))
        )
    end
    JSON3.write(io, data)
end

function _to_json_index(io, table; rows=Tables.rows(table), sch=Tables.schema(rows))
    data = Dict{String,Dict{Symbol,Any}}()
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        data[string(i-1)] = newrow
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

function _to_json_split(io, table; rows=Tables.rows(table), sch=Tables.schema(rows))
    data = Vector{Any}[]
    index = String[]
    columns = collect(Tables.columnnames(rows))
    for (i, row) in enumerate(rows)
        push!(index, string(i-1))
        newrow = []
        Tables.eachcolumn(sch, row) do x, _, _
            push!(newrow, _to_json_item(x))
        end
        push!(data, newrow)
    end
    JSON3.write(io, (; index, columns, data))
end

_to_json_field_type(::Type{<:Union{Nothing,Bool}}) = "boolean"
_to_json_field_type(::Type{<:Union{Nothing,Integer}}) = "integer"
_to_json_field_type(::Type{<:Union{Nothing,Real}}) = "number"
_to_json_field_type(::Type{<:Union{Nothing,AbstractString}}) = "string"
_to_json_field_type(::Type{T}) where {T} = "string"

function _to_json_table(io, table; rows=Tables.rows(table), sch=Tables.schema(rows))
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
    push!(fields, (name = idxname, type = "integer"))
    for (i, row) in enumerate(rows)
        newrow = Dict{Symbol,Any}()
        Tables.eachcolumn(sch, row) do x, _, colname
            newrow[colname] = _to_json_item(x)
        end
        newrow[idxname] = i-1
        push!(data, newrow)
    end
    schema = (;
        fields,
        primaryKey = [idxname]
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
