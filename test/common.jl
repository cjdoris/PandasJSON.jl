using DataFrames, Dates, JSON3

examples = Dict(
    "01" => DataFrame(
        int = [1, 2, 3],
        num = [1.1, 2.2, 3.3],
        str = ["foo", "bar", "baz"],
        bool = [true, false, true]
    ),
    "02" => DataFrame(
        num = [1.1, 2.2, 3.3]
    ),
    "03" => DataFrame(
        num = [1.1, missing, missing, missing],
        int = [1, missing, missing, 4],
        bool = [true, missing, missing, false],
    ),
    "04" => DataFrame(
        list = [[1,2],[3,4],[5,6]],
        set = [[1,2],[3,4],[5,6]],
        tuple = [[1,2],[3,4],[5,6]],
        list2 = [[1,2],missing,[5,6]],
    ),
    "05" => DataFrame(
        datetime = [DateTime(2001,2,3), missing, DateTime(2004,5,6), DateTime(2007,8,9)],
    ),
)
