# PandasIO.jl

A Julia package for reading and writing Pandas dataframes.

## Install

This package is not yet registered, but can be installed like so:

```
pkg> add https://github.com/cjdoris/PandasIO.jl
```

## Example

The `examples` directory in this repository contains many example Pandas dataframes.

In the following example, we use `read_json` to read a JSON-formatted dataframe as a table,
which is then converted to a `DataFrame` for easier processing.

```julia
julia> using PandasIO, DataFrames

julia> df = DataFrame(PandasIO.read_json("examples/frame-01-table.json"))
3×4 DataFrame
 Row │ int    num      str     bool
     │ Int64  Float64  String  Bool
─────┼───────────────────────────────
   1 │     1      1.1  foo      true
   2 │     2      2.2  bar     false
   3 │     3      3.3  baz      true
```
