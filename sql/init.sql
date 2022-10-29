create database seinfeld;

create table seinfeld.characters(
  id int auto_increment primary key,
  name varchar(255),
  description varchar(255)
);

insert into seinfeld.characters
  (name, description)
values
  ('Jerry',  'A funny guy.'),
  ('George', 'A short, stocky, slow-witted, bald man.'),
  ('Elaine', 'A wonderful girl, a great pal, and more.'),
  ('Kramer', 'A hipster doofus.');

create user if not exists 'root'@'%' identified by 'root';
grant usage on *.* to 'root'@'%';
grant all privileges on *.* to 'root'@'%';

create user if not exists 'newman'@'%' identified by 'drakescoffeecake';
grant usage on *.* to 'newman'@'%';
grant all privileges on *.* to 'newman'@'%';

flush privileges;
