-- Selects all characters.
select
  *
from characters
where true
  and id > 0
  and id < 10;
