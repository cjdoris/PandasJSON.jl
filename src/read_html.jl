"""
    read_html(filename_or_io; match=r".+", skiprows=0, header=1)

Read tables from an HTML file.

## Keyword Args
- `match`: Only tables matching this regular expression are returned.
- `skiprows`: The number of rows to skip from the top of each table.
- `header`: Which row contains the header. Subsequent rows are the data.
"""
function read_html(io::IO; match::Regex=r".+", kw...)
    return [
        _parse_html_table(elem; kw...)
        for elem in AbstractTrees.StatelessBFS(Gumbo.parsehtml(read(io, String)).root)
        if elem isa Gumbo.HTMLElement{:table} && occursin(match, string(elem))
    ]
end

function read_html(filename::AbstractString; kw...)
    return open(filename) do io
        read_html(io; kw...)
    end
end

function _parse_html_table(elem; header::Union{Integer,Nothing}=1, skiprows::Integer=0)
    # parse out text from the table
    rows = Vector{String}[
        String[
            Gumbo.text(cell)
            for cell in row.children
            if cell isa Union{Gumbo.HTMLElement{:th}, Gumbo.HTMLElement{:td}}
        ]
        for section in elem.children
        if section isa Union{Gumbo.HTMLElement{:thead}, Gumbo.HTMLElement{:tbody}, Gumbo.HTMLElement{:tfoot}}
        for row in section.children
        if row isa Gumbo.HTMLElement{:tr}
    ]
    # count the number of columns
    ncols = isempty(rows) ? 0 : maximum(length, rows)
    # pad rows out to the same length
    for row in rows
        while length(row) < ncols
            push!(row, "")
        end
    end
    # skip some rows
    rows = @view rows[1+skiprows:end]
    # separate header and data rows
    if header === nothing
        hrow = ["Column$i" for i in 1:ncols]
        drows = rows
    else
        hrow = rows[header]
        drows = @view rows[header+1:end]
    end
    # construct the columns
    dict = Tables.OrderedDict{Symbol,Vector}()
    for i in 1:ncols
        colname = Symbol(hrow[i])
        column = [row[i] for row in drows]
        dict[colname] = column
    end
    # construct the table
    schema = Tables.Schema([k for (k, _) in dict], [eltype(c) for (_, c) in dict])
    return Tables.DictColumnTable(schema, dict)
end
