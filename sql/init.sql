-- Seinfeld
drop database if exists seinfeld;
create database seinfeld;

create table seinfeld.characters(
  id int auto_increment primary key,
  name varchar(255),
  description varchar(255)
);

insert into seinfeld.characters
  (name, description)
values
  ('Jerry',  'A joke maker.'),
  ('George', 'A short, stocky, slow-witted, bald man.'),
  ('Elaine', 'A wonderful girl, a great pal, and more.'),
  ('Kramer', 'A hipster doofus.');

create table seinfeld.random_data(
  id int auto_increment primary key,
  data varchar(8)
);

create user if not exists 'newman'@'%' identified by 'drakescoffeecake';
grant usage on seinfeld.* to 'newman'@'%';
grant all privileges on seinfeld.* to 'newman'@'%';

-- Friends
drop database if exists friends;
create database friends;

create table friends.actors(
  id int auto_increment primary key,
  name varchar(255)
);

insert into friends.actors
  (id, name)
values
  (1, 'Courteney Cox'),
  (2, 'Matthew Perry'),
  (3, 'Jennifer Aniston'),
  (4, 'David Schwimmer'),
  (5, 'Lisa Kudrow'),
  (6, 'Matt LeBlanc');

create table friends.characters(
  id int auto_increment primary key,
  name varchar(255),
  description varchar(255),
  actor_id int,
  foreign key (actor_id)
    references friends.actors(id)
    on delete cascade
);

insert into friends.characters
  (name, description, actor_id)
values
  ('Monica',   'A neat freak.',   1),
  ('Chandler', 'A clown.',        2),
  ('Rachel',   'A spoiled brat.', 3),
  ('Ross',     'A know-it-all.',  4),
  ('Phoebe',   'A ditz.',         5),
  ('Joey',     'A moron.',        6);

create user if not exists 'heckles'@'%' identified by 'keepitdown';
grant usage on friends.* to 'heckles'@'%';
grant all privileges on friends.* to 'heckles'@'%';

-- Root permissions
create user if not exists 'root'@'%' identified by 'root';
grant usage on *.* to 'root'@'%';
grant all privileges on *.* to 'root'@'%';

flush privileges;

-- Random data, useful for testing pagination and max rows.
use seinfeld;

drop procedure if exists seed_random_data;

delimiter //  
create procedure seed_random_data()   
begin
  set @i = 0; 
  -- Max rows is currently set at 100,000.
  -- Insert 100,001 random rows (200 rows per insert * 500 inserts).

  insert into seinfeld.random_data (data) values (left(uuid(), 8));

  while (@i < 500) do
    insert into seinfeld.random_data
      (data)
    values
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)),
      (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8)), (left(uuid(), 8));
    set @i = @i + 1;
  end while;
end;
//  

delimiter ;

call seed_random_data(); 
