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

create user if not exists 'newman'@'%' identified by 'drakescoffeecake';
grant usage on seinfeld.* to 'newman'@'%';
grant all privileges on seinfeld.* to 'newman'@'%';

-- Friends
drop database if exists friends;
create database friends;

create table friends.characters(
  id int auto_increment primary key,
  name varchar(255),
  description varchar(255)
);

insert into friends.characters
  (name, description)
values
  ('Monica',   'A neat freak.'),
  ('Chandler', 'A clown.'),
  ('Rachel',   'A spoiled brat.'),
  ('Ross',     'A know-it-all.'),
  ('Phoebe',   'A ditz.'),
  ('Joey',     'A moron.');

create user if not exists 'heckles'@'%' identified by 'keepitdown';
grant usage on friends.* to 'heckles'@'%';
grant all privileges on friends.* to 'heckles'@'%';

-- Root permissions
create user if not exists 'root'@'%' identified by 'root';
grant usage on *.* to 'root'@'%';
grant all privileges on *.* to 'root'@'%';

flush privileges;
