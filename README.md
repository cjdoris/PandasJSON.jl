# PandasJSON.jl

A
[Julia](https://julialang.org/)
package for reading and writing
[Pandas](https://pandas.pydata.org/)
dataframes.

Currently supports JSON.

## Install

This package is not yet registered, but can be installed like so:

```
pkg> add https://github.com/cjdoris/PandasJSON.jl
```

## Tutorial

First we load relevant packages. In this tutorial we use
[DataFrames](https://dataframes.juliadata.org/stable/)
for our tabular data, but any
[Tables.jl](https://tables.juliadata.org/stable/)-compatible
data structure will do.

```julia
julia> using PandasJSON, DataFrames
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
julia> PandasJSON.write("example.json", df)

julia> println(read("example.json", String))
{"y":{"1":false,"0":true,"2":null},"x":{"1":2,"0":1,"2":3}}
```

Finally we read the JSON file back as a table and convert it to a DataFrame. We could do the
same thing with a JSON file written in Python by Pandas.

```julia
julia> df = PandasJSON.read("example.json", DataFrame)
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing
```

**Note:** These functions have an optional `orient` keyword argument, which controls
how the tabular data is represented as a JSON structure. The default in both Pandas and
PandasJSON is `orient=:split`, so with default parameters everything should be compatible.

You should use this argument if either:
- You are reading data which set the `orient` to something non-default.
- You would like to guarantee row and column ordering is correct (`split`, `table` or
  `values`) or require more column type information to be stored (`table`).

If you are not sure, you can use `guess_orient`:

```julia
julia> PandasJSON.write("example.json", df, orient=:table)

julia> PandasJSON.guess_orient("example.json")
1-element Vector{Symbol}:
 "table"

julia> df = PandasJSON.read("example.json", DataFrame, orient=:table)
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing
```

## API

Read the docstrings for more details and keyword arguments.
- `PandasJSON.read(file, [type])`: Read a JSON file as a table.
- `PandasJSON.write(file, table)`: Write a table to the file in JSON format.
- `PandasJSON.guess_orient(file)`: Guess the `orient` parameter used to write the given file.

## Supported formats

Currently only JSON is supported.

Other more standard tabular formats are supported by other Julia packages - we recommend
using one of these instead if you have the choice:

| Format | Packages |
| ------ | -------- |
| Feather | [Feather](https://feather.juliadata.org/stable/) |
| Parquet | [Parquet](https://github.com/JuliaIO/Parquet.jl), [Parquet2](https://expandingman.gitlab.io/Parquet2.jl/) |
| ORC | ??? |
| Stata DTA, SAS, SPSS | [ReadStat](https://github.com/queryverse/ReadStat.jl) |
| Excel | [XLSX](https://felipenoris.github.io/XLSX.jl/stable/), [ExcelReaders](https://github.com/queryverse/ExcelReaders.jl) |
| HDF | ??? |
| CSV | [CSV](https://csv.juliadata.org/stable/), [DelimitedFiles](https://docs.julialang.org/en/v1/stdlib/DelimitedFiles/) |
| FWF | [CSV](https://csv.juliadata.org/stable/examples.html#ignorerepeated_example) |
| JSON | [**PandasJSON**](https://github.com/cjdoris/PandasJSON.jl) |
| Pickle | ??? |
| HTML | [PrettyTables](https://ronisbr.github.io/PrettyTables.jl/stable/man/html_backend/) (write only) |
| XML | ??? |
| LaTeX | [PrettyTables](https://ronisbr.github.io/PrettyTables.jl/stable/man/latex_backend/) (write only) |

The following packages can read/write the given formats, but require some extra manual
parsing to get to/from a tabular data structure:

| Format | Packages |
| ------ | -------- |
| JSON | [JSON](https://github.com/JuliaIO/JSON.jl), [JSON3](https://quinnj.github.io/JSON3.jl/stable/) |
| HTML | [Gumbo](https://github.com/JuliaWeb/Gumbo.jl), [EzXML](https://juliaio.github.io/EzXML.jl/stable/) |
| XML | [EzXML](https://juliaio.github.io/EzXML.jl/stable/), [LightXML](https://github.com/JuliaIO/LightXML.jl), [XML](https://github.com/JuliaComputing/XML.jl) |
| HDF | [HDF5](https://juliaio.github.io/HDF5.jl/stable/) |
