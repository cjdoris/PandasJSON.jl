@testitem "guess_orient" begin
    for (fn, kw) in PandasJSON._json_examples
        ans = PandasJSON.guess_orient(fn)
        @test ans isa Vector{String}
        tgt = kw.orient in ["columns", "index"] ? ["columns", "index"] : [kw.orient]
        @test ans == tgt
    end
end

@testitem "read" begin
    include("common.jl")
    for (fn, kw) in PandasJSON._json_examples
        m = match(r"frame-([0-9]+)-([a-z]+).json$", fn)
        @assert m isa RegexMatch
        id = m.captures[1]
        orient = m.captures[2]
        @assert orient == kw.orient
        ans = PandasJSON.read(fn, DataFrame; kw...)
        @test ans isa DataFrame
        tgt = get(examples, id, nothing)
        @assert tgt !== nothing
        # example 02 uses a non-standard index
        index = id == "02" ? ["a", "b", "c"] : true
        if tgt !== nothing
            # check the size
            @test size(ans) == size(tgt)
            # check the column names
            if orient == "values"
                # no column names
                @test Set(names(ans)) == Set(["Column$i" for i in 1:size(tgt,2)])
            elseif orient in ["split", "table"]
                # these preserve column order
                @test names(ans) == names(tgt)
            else
                # column order not preserved
                @test sort(names(ans)) == sort(names(tgt))
            end
            # check the data
            tnames = names(tgt)
            if orient == "values"
                anames = ["Column$i" for i in 1:length(tnames)]
            else
                anames = tnames
            end
            trows = [Any[tgt[i,nm] for nm in tnames] for i in axes(tgt,1)]
            arows = [Any[ans[i,nm] for nm in anames] for i in axes(ans,1)]
            if orient in ["values", "split", "table", "records"] || index === true
                # these preserve row order
                @test isequal(trows, arows)
            else
                # row order not preserved
                @test isequal(sort(trows), sort(arows))
            end
        end
    end
end

@testitem "write" begin
    include("common.jl")
    for (fn, kw) in PandasJSON._json_examples
        m = match(r"frame-([0-9]+)-([a-z]+).json$", fn)
        @assert m isa RegexMatch
        id = m.captures[1]
        @assert id in ["01", "02", "03", "04"]
        orient = m.captures[2]
        @assert orient == kw.orient
        df = get(examples, id, nothing)
        @assert df !== nothing
        # example 02 uses a non-standard index
        index = id == "02" ? ["a", "b", "c"] : true
        if df !== nothing
            # write the table to a buffer
            io = IOBuffer()
            PandasJSON.write(io, df; index, kw...)
            seekstart(io)
            # parse the JSON in the buffer
            if orient == "columns"
                T = Dict{String,Dict{String,Any}}
            elseif orient == "index"
                T = Dict{String,Dict{String,Any}}
            elseif orient == "records"
                T = Vector{Dict{String,Any}}
            elseif orient == "split"
                T = @NamedTuple{
                    columns::Vector{String},
                    index::Vector{Any},
                    data::Vector{Vector{Any}},
                }
            elseif orient == "table"
                T = @NamedTuple{
                    schema::@NamedTuple{
                        fields::Vector{@NamedTuple{name::String,type::String,extDtype::Union{String,Nothing}}},
                        primaryKey::Vector{String},
                    },
                    data::Vector{Dict{String,Any}},
                }
            elseif orient == "values"
                T = Vector{Vector{Any}}
            else
                @assert false
            end
            ans = JSON3.read(io, T)
            # check the JSON matches that in the original file
            tgt = open(io->JSON3.read(io, T), fn)
            @test isequal(ans, tgt)
        end
    end
end
