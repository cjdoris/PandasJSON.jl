"""
    guess_orient(file)

Guess possible values for the `orient` parameter used when the given file was created.

A list of symbols is returned, the values being one of `"columns"`, `"index"`, `"records"`,
`"split"`, `"table"` or `"values"`.

Normally one possibility is returned. Since `"columns"` and `"index"` are similar formats,
these two cases cannot be distinguished and are always returned together - in which case
`"columns"` is the likely format since this is the default in Pandas.
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
                return ["split"]
            elseif issubset([:schema, :data], keys(o)) && o[:data] isa AbstractVector
                return ["table"]
            else
                return ["columns", "index"]
            end
        else
            return ["columns", "index"]
        end
    elseif c == '['
        c = readc(io)
        if c == '{' || c == ']'
            return ["records"]
        elseif c == '['
            return ["values"]
        end
    end
    return String[]
end

guess_orient(filename::AbstractString) = open(guess_orient, filename)
