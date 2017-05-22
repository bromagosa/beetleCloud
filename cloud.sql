--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;


CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
SET search_path = public, pg_catalog;

CREATE DOMAIN dom_username AS text
	CONSTRAINT dom_username_check CHECK (((length(VALUE) >= 3) AND (length(VALUE) < 200)));

SET default_tablespace = '';
SET default_with_oids = false;

--- COMMENTS ---

CREATE TABLE comments (
    projectname text,
    projectowner dom_username,
    author dom_username,
    contents text,
    id integer NOT NULL,
    date timestamp with time zone
);

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--- LIKES ---

CREATE TABLE likes (
    id integer NOT NULL,
    liker dom_username,
    projectname text,
    projectowner dom_username
);

CREATE SEQUENCE likes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE likes_id_seq OWNED BY likes.id;

--- PROJECTS ---

CREATE TABLE projects (
    projectname text NOT NULL,
    ispublic boolean,
    contents text,
    thumbnail text,
    notes text,
    updated timestamp with time zone,
    username dom_username NOT NULL,
    id integer NOT NULL,
    shared timestamp with time zone,
    views integer,
    imageisfeatured boolean,
	admin_tags text
);

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--- USERS ---

CREATE TABLE users (
    username dom_username NOT NULL,
    email text,
    password text,
    id integer NOT NULL,
    joined timestamp with time zone,
    about text,
    location text,
	isadmin boolean,
	reset_code text
);

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE users_id_seq OWNED BY users.id;

--- keys and contraints --

ALTER TABLE ONLY comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);
ALTER TABLE ONLY likes ALTER COLUMN id SET DEFAULT nextval('likes_id_seq'::regclass);
ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);
ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);

ALTER TABLE ONLY comments ADD CONSTRAINT comments_pkey PRIMARY KEY (id);
ALTER TABLE ONLY likes ADD CONSTRAINT likes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY projects ADD CONSTRAINT projects_pkey PRIMARY KEY (username, projectname);
ALTER TABLE ONLY users ADD CONSTRAINT users_pkey PRIMARY KEY (username);
ALTER TABLE ONLY comments ADD CONSTRAINT comments_author_fkey FOREIGN KEY (author) REFERENCES users(username);
ALTER TABLE ONLY comments ADD CONSTRAINT comments_projectname_fkey FOREIGN KEY (projectname, projectowner) REFERENCES projects(projectname, username);
ALTER TABLE ONLY likes ADD CONSTRAINT likes_liker_fkey FOREIGN KEY (liker) REFERENCES users(username);
ALTER TABLE ONLY likes ADD CONSTRAINT likes_projectname_fkey FOREIGN KEY (projectname, projectowner) REFERENCES projects(projectname, username);
ALTER TABLE ONLY projects ADD CONSTRAINT projects_username_fkey FOREIGN KEY (username) REFERENCES users(username);

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;
