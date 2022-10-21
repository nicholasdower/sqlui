drop table if exists development.names;

create table development.names(name varchar(255), description varchar(255));

insert
into development.names
    (name, description)
values
  ('Nick', 'A dev on the project.');
