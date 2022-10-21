drop table if exists development.names;

create table development.names(
  id int auto_increment primary key,
  name varchar(255),
  description varchar(255)
);

insert
into development.names
    (name, description)
values
  ('Nick', 'A dev on the project.');
