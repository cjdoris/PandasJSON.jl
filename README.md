# PandasIO.jl

A
[Julia](https://julialang.org/)
package for reading and writing
[Pandas](https://pandas.pydata.org/)
dataframes.

## Install

This package is not yet registered, but can be installed like so:

```
pkg> add https://github.com/cjdoris/PandasIO.jl
```

## Tutorial

First we load relevant packages. In this tutorial we use
[DataFrames](https://dataframes.juliadata.org/stable/)
for our tabular data, but any
[Tables.jl](https://tables.juliadata.org/stable/)-compatible
data structure will do.

```julia
julia> using PandasIO, DataFrames
```

Now we create a table with two columns and some missing data.

```julia
julia> df = DataFrame(x=[1,2,3], y=[true,false,missing])
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing
```

Now let's save this to disk in JSON format and take a look at the resulting file.

```julia
julia> PandasIO.to_json("example.json", df)

julia> println(read("example.json", String))
{"index":["0","1","2"],"columns":["x","y"],"data":[[1,true],[2,false],[3,null]]}
```

Finally we read the JSON file back as a table and convert it to a DataFrame. We could do the
same thing with a JSON file written in Python by Pandas.

```julia
julia> df = PandasIO.read_json("example.json") |> DataFrame
3×2 DataFrame
 Row │ y        x
     │ Bool?    Int64
─────┼────────────────
   1 │   false      2
   2 │    true      1
   3 │ missing      3
```

Observe that the resulting table has all the same information, but the rows and columns are
not in the same order. This is a limitation of the default JSON format used by Pandas and
PandasIO.

If this is problematic, you can specify the `orient` parameter when writing and reading.
Here, we use `orient=:split` which preserves the order of rows and columns.

```julia
julia> PandasIO.to_json("example.json", df, orient=:split)

julia> df = PandasIO.read_json("example.json", orient=:split) |> DataFrame
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing
```

Note that it is important the the same `orient` parameter is used when reading a table as
when writing it. The default used by both Pandas and PandasIO is `orient=:columns`. If you
are not sure, you can use `PandasIO.guess_json_orient`.

## API

Read the docstrings for more details and keyword arguments.
- `read_json(file)`: Read a JSON file as a table.
- `to_json(file, table)`: Write a table to the file in JSON format.
- `guess_json_orient(file)`: Guess the `orient` parameter used to write the given file.
