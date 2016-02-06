
 

-- http://www.piazza.com/class_profile/get_resource/ijcejswq97f42q/ijzd7g7gnrx3no


DROP TABLE IF EXISTS cats."user" CASCADE ;


CREATE TABLE cats."user"
(
  user_id serial primary key NOT NULL,
  user_name character varying(50) NOT NULL,
  facebook_id character varying(50) NOT NULL
);


DROP TABLE IF EXISTS  cats."video" CASCADE;

CREATE TABLE cats."video"
(
  video_id serial primary key NOT NULL,
  video_name character varying(50) NOT NULL
);

DROP TABLE IF EXISTS  cats.watch CASCADE;

CREATE TABLE cats.watch
(
  watch_id serial primary key NOT NULL,
  video_id integer references cats.video (video_id) NOT NULL,
  user_id integer references cats."user" (user_id) NOT NULL,
  "time" timestamp without time zone NOT NULL
);
  

DROP TABLE  IF EXISTS cats.likes CASCADE;

CREATE TABLE cats."likes"
(
  like_id serial primary key NOT NULL,
  user_id integer references cats."user" (user_id) NOT NULL,
  video_id integer references cats.video (video_id) NOT NULL,
  "time" timestamp without time zone NOT NULL
);

DROP TABLE IF EXISTS  cats.login CASCADE;


CREATE TABLE cats.login
(
  login_id serial primary key NOT NULL,
  user_id integer references cats."user" (user_id) NOT NULL,
  "time" timestamp without time zone NOT NULL
);


DROP TABLE IF EXISTS cats.suggestion CASCADE;

CREATE TABLE cats.suggestion
(
  suggestion_id serial primary key NOT NULL,
  login_id integer references cats.login(login_id) NOT NULL,
  video_id integer references cats.video (video_id) NOT NULL
);

DROP TABLE IF EXISTS  cats.friend CASCADE;
CREATE TABLE cats.friend
(
  user_id integer references cats."user" (user_id) NOT NULL,
  friend_id integer references cats."user" (user_id) NOT NULL
);



