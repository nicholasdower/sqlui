-- Selects all characters. yo
select
  *
from characters
where true
  and id > 0
  and id < 10;
