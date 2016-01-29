DROP TABLE IF EXISTS users CASCADE ;


CREATE TABLE users (
  
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    fb_uid TEXT
);

DROP TABLE IF EXISTS  videos CASCADE;

CREATE TABLE videos (
    id SERIAL PRIMARY KEY
);

DROP TABLE IF EXISTS  watches CASCADE;

CREATE TABLE watches (
    user_id INTEGER REFERENCES users (id) NOT NULL,
    video_id INTEGER REFERENCES videos (id) NOT NULL
);
  

DROP TABLE  IF EXISTS likes CASCADE;

CREATE TABLE likes (
    user_id INTEGER REFERENCES users (id) NOT NULL,
    video_id INTEGER REFERENCES videos (id) NOT NULL,
    created_at time with time zone
);

DROP TABLE IF EXISTS  logins CASCADE;


CREATE TABLE logins (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users (id) NOT NULL,
    created_at time with time zone
);


DROP TABLE IF EXISTS  suggestions CASCADE;

CREATE TABLE suggestions(
  id SERIAL PRIMARY KEY,
  login_id INTEGER REFERENCES logins (id) NOT NULL,
  video_id INTEGER REFERENCES videos (id) NOT NULL
);



