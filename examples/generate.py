import pandas as pd

series_orients = ['split', 'records', 'index']
frame_orients = ['split', 'records', 'index', 'columns', 'values', 'table']

def save_json(x, name, orients=None):
    if orients is None:
        if isinstance(x, pd.DataFrame):
            orients = frame_orients
        elif isinstance(x, pd.Series):
            orients = series_orients
        else:
            assert False
    for orient in orients:
        x.to_json(f'examples/{name}-{orient}.json', orient=orient)

# basic data types
save_json(
    pd.DataFrame(
        {
            'int': [1, 2, 3],
            'num': [1.1, 2.2, 3.3],
            'str': ['foo', 'bar', 'baz'],
            'bool': [True, False, True],
        },
    ),
    'frame-01',
)

# index
save_json(
    pd.DataFrame(
        {
            'num': [1.1, 2.2, 3.3],
        },
        index = ['a', 'b', 'c'],
    ),
    'frame-02',
)

# missing/invalid values
save_json(
    pd.DataFrame(
        {
            'num': pd.array([1.1, float('NaN'), float('Inf'), None], dtype='float64'),
            'int': pd.array([1, None, pd.NA, 4], dtype='Int64'),
            'bool': pd.array([True, None, pd.NA, False], dtype='boolean'),
        }
    ),
    'frame-03',
)

# compound values
save_json(
    pd.DataFrame(
        {
            'list': [[1,2],[3,4],[5,6]],
            'set': [{1,2},{3,4},{5,6}],
            'tuple': [(1,2),(3,4),(5,6)],
            'list2': [[1,2],None,[5,6]],
        }
    ),
    'frame-04',
)

# series
save_json(
    pd.Series([1,2,3,4,5]),
    'series-01',
)
