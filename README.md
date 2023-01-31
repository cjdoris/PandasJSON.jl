# PandasIO.jl

A Julia package for reading and writing Pandas dataframes.

## Install

This package is not yet registered, but can be installed like so:

```
pkg> add https://github.com/cjdoris/PandasIO.jl
```

## Tutorial

In the following example, we:
- construct a simple dataframe;
- save it in JSON format with `to_json`;
- print out the resulting JSON file; and
- read the file back in as a dataframe with `read_json`.

```
julia> using PandasIO, DataFrames

julia> df = DataFrame(x=[1,2,3], y=[true,false,missing])
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing

julia> PandasIO.to_json("example.json", df, orient=:split)

julia> println(read("example.json", String))
{"index":["0","1","2"],"columns":["x","y"],"data":[[1,true],[2,false],[3,null]]}

julia> df = PandasIO.read_json("example.json", orient=:split) |> DataFrame
3×2 DataFrame
 Row │ x      y
     │ Int64  Bool?
─────┼────────────────
   1 │     1     true
   2 │     2    false
   3 │     3  missing
```

Notes:
- We used `DataFrame`s for convenience, but PandasIO works with any Tables.jl-compatible
  tabular data structure.
- The `orient=:split` argument is optional. We used `:split` because it preserves the order
  of rows and columns, whereas the default `orient=:columns` does not.
- When reading a table, you must ensure the `orient` argument is the same as when it was
  written. The default used by both Pandas and PandasIO is `orient=:columns`. The function
  `PandasIO.guess_json_orient` can be used if you're not sure what this should be.
