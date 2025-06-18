create temp table perftest
(
    id serial primary key
    ,   pn  ac_policy[]
    ,   p1  ac_policy[]
    ,   p2  ac_policy[]
    ,   p4  ac_policy[]
    ,   p8  ac_policy[]
    ,   p16  ac_policy[]
    ,   p32  ac_policy[]
);

insert into perftest(pn, p1, p2, p4, p8, p16, p32) -- ~10s
SELECT
    null,
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ],
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ],
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ],
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ],
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ],
    ARRAY[
        ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        , ac_policy('me', ARRAY['select'], ARRAY['insert'])
        ]
FROM generate_series(1, 1000000) AS i;


SELECT '...' as name, 0 as result, '' as duration
UNION ALL SELECT '      no/op', (SELECT count(1) FROM perftest)                                         , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT ' 0 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], pn)) FROM perftest) , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT ' 1 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p1)) FROM perftest) , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT ' 2 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p2)) FROM perftest) , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT ' 4 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p4)) FROM perftest) , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT ' 8 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p8)) FROM perftest) , to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT '16 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p16)) FROM perftest), to_char(clock_timestamp() - now(), 'SS.MS')
UNION ALL SELECT '32 policies', (SELECT count(ac_check('select', ARRAY['r1', 'r2'], p32)) FROM perftest), to_char(clock_timestamp() - now(), 'SS.MS')
;

-- Selecting 1mio rows with 32 policies takes about 33 seconds
-- on a MacBook Pro 2019 (2,4 GHz 8-Core Intel Core i9).

--     name     | result  | duration
-- -------------+---------+----------
--  ...         |       0 |
--        no/op | 1000000 | 00.605
--   0 policies |       0 | 00.977
--   1 policies |       0 | 02.680
--   2 policies |       0 | 04.796
--   4 policies |       0 | 07.503
--   8 policies |       0 | 11.647
--  16 policies |       0 | 19.132
--  32 policies |       0 | 33.008
