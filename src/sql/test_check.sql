CREATE EXTENSION IF NOT EXISTS ac VERSION '0.0.1';

WITH cases AS (
    SELECT 'news',     'select', 'admin',   TRUE,  '001 Admin can always select from news'
    UNION ALL SELECT 'news',     'select', 'visitor', TRUE,  '002 Visitor can always select from news'
    UNION ALL SELECT 'news',     'select', 'writer',  TRUE,  '003 Writer can always select from news'
    UNION ALL SELECT 'news',     'select', 'editor',  TRUE,  '004 Editor can always select from news'
    UNION ALL SELECT 'news',     'select', 'editor',  TRUE,  '005 Editor can always select from news'
    UNION ALL SELECT 'news',     'delete', 'editor',  NULL,  '006 Editor can not delete the news'
    UNION ALL SELECT 'news',     'delete', 'admin',   TRUE,  '007 Admin can always delete the news'
    UNION ALL SELECT 'news',     'delete', 'visitor', NULL,  '008 Visitor can not delete the news'
    UNION ALL SELECT 'news',     'delete', 'writer',  NULL,  '009 Writer can not delete the news'
    UNION ALL SELECT 'news',     'delete', 'owner',   FALSE, '010 Owner can not delete the news'
    UNION ALL SELECT 'news',     'insert', 'admin',   TRUE,  '011 Admin can always insert into news'
    UNION ALL SELECT 'news',     'insert', 'visitor', NULL,  '012 Visitor can not insert into news'
    UNION ALL SELECT 'comments', 'select', 'admin',   TRUE,  '013 Admin can always select from comments'
    UNION ALL SELECT 'comments', 'select', 'writer',  TRUE,  '014 Writer can always select from comments'
    UNION ALL SELECT 'comments', 'select', 'editor',  TRUE,  '015 Editor can always select from comments'
),
     data AS (
         SELECT 'news' as obj, ARRAY[
             ac_policy('admin'::ac_subject, ARRAY['select', 'update', 'insert', 'delete'])
             ,   ac_policy('visitor', 'select')
             ,   ac_policy('writer', ARRAY['select', 'insert'])
             ,   ac_policy('editor', ARRAY['select', 'update'])
             ,   ac_policy('owner', ARRAY['select', 'update'], ARRAY['delete'])
             ] as list
         UNION ALL SELECT  'comments', ARRAY[
             ac_policy('admin', ARRAY['select', 'update', 'insert', 'delete'])
             ,   ac_policy('writer', ARRAY['select'])
             ,   ac_policy('editor', ARRAY['select'])
             ,   ac_policy('visitor', ARRAY['select', 'create'])
             ,   ac_policy('owner', ARRAY['select', 'update'])
             ]
     ),
     results AS (
         SELECT ac_check(c.op, c.sub, d.list) AS result, c.*, d.list
         FROM data AS d, cases AS c(obj, op, sub, expected, label)
         WHERE d.obj = c.obj
     )
SELECT label
     , CASE WHEN expected IS NULL
                THEN expected IS NULL
            ELSE result = expected
    END AS pass
     , op
     , sub
     , list
FROM results
ORDER BY label
