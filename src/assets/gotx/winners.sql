-- The winners of every GotX pick, one tab-separated line each, oldest first: type, date, theme,
-- titles (USA, EU, Japan, world, other), system, year, ScreenScraper id, genre, hours to beat.
-- Run against the GotX Randomizer's database (github.com/blakekl/gotx-randomizer, MIT); its
-- nominations and members aren't kept. Tabs and line breaks in values become spaces.
SELECT
  n.nomination_type,
  t.creation_date,
  replace(replace(replace(coalesce(t.title, ''), char(9), ' '), char(10), ' '), char(13), ' '),
  replace(replace(coalesce(g.title_usa, ''), char(9), ' '), char(10), ' '),
  replace(replace(coalesce(g.title_eu, ''), char(9), ' '), char(10), ' '),
  replace(replace(coalesce(g.title_jap, ''), char(9), ' '), char(10), ' '),
  replace(replace(coalesce(g.title_world, ''), char(9), ' '), char(10), ' '),
  replace(replace(coalesce(g.title_other, ''), char(9), ' '), char(10), ' '),
  replace(replace(coalesce(g.system, ''), char(9), ' '), char(10), ' '),
  coalesce(g.year, ''),
  coalesce(g.screenscraper_id, ''),
  replace(replace(coalesce(g.genre, ''), char(9), ' '), char(10), ' '),
  coalesce(g.time_to_beat, '')
FROM [public.nominations] n
JOIN [public.games] g ON g.id = n.game_id
JOIN [public.themes] t ON t.id = n.theme_id
WHERE n.winner = 1
ORDER BY t.creation_date, n.id;
