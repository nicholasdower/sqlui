-- Selects all characters.
-- And more.
select
  *
from characters
where true
  and id > 0
  and id < 10;
