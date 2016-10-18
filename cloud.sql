--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: dom_username; Type: DOMAIN; Schema: public; Owner: beetle
--

CREATE DOMAIN dom_username AS text
	CONSTRAINT dom_username_check CHECK (((length(VALUE) > 3) AND (length(VALUE) < 200)));


ALTER DOMAIN dom_username OWNER TO beetle;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: beetle; Tablespace: 
--

CREATE TABLE comments (
    projectname text,
    projectowner dom_username,
    author dom_username,
    contents text,
    id integer NOT NULL,
    date timestamp with time zone
);


ALTER TABLE comments OWNER TO beetle;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: beetle
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comments_id_seq OWNER TO beetle;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: beetle
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: likes; Type: TABLE; Schema: public; Owner: beetle; Tablespace: 
--

CREATE TABLE likes (
    id integer NOT NULL,
    liker dom_username,
    projectname text,
    projectowner dom_username
);


ALTER TABLE likes OWNER TO beetle;

--
-- Name: likes_id_seq; Type: SEQUENCE; Schema: public; Owner: beetle
--

CREATE SEQUENCE likes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE likes_id_seq OWNER TO beetle;

--
-- Name: likes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: beetle
--

ALTER SEQUENCE likes_id_seq OWNED BY likes.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: beetle; Tablespace: 
--

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
    imageisfeatured boolean
);


ALTER TABLE projects OWNER TO beetle;

--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: beetle
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE projects_id_seq OWNER TO beetle;

--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: beetle
--

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: beetle; Tablespace: 
--

CREATE TABLE users (
    username dom_username NOT NULL,
    email text,
    password text,
    id integer NOT NULL,
    joined timestamp with time zone,
    about text,
    location text
);


ALTER TABLE users OWNER TO beetle;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: beetle
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO beetle;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: beetle
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY likes ALTER COLUMN id SET DEFAULT nextval('likes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: beetle; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: likes_pkey; Type: CONSTRAINT; Schema: public; Owner: beetle; Tablespace: 
--

ALTER TABLE ONLY likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: beetle; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (username, projectname);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: beetle; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: comments_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_author_fkey FOREIGN KEY (author) REFERENCES users(username);


--
-- Name: comments_projectname_fkey; Type: FK CONSTRAINT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_projectname_fkey FOREIGN KEY (projectname, projectowner) REFERENCES projects(projectname, username);


--
-- Name: likes_liker_fkey; Type: FK CONSTRAINT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY likes
    ADD CONSTRAINT likes_liker_fkey FOREIGN KEY (liker) REFERENCES users(username);


--
-- Name: likes_projectname_fkey; Type: FK CONSTRAINT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY likes
    ADD CONSTRAINT likes_projectname_fkey FOREIGN KEY (projectname, projectowner) REFERENCES projects(projectname, username);


--
-- Name: projects_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: beetle
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_username_fkey FOREIGN KEY (username) REFERENCES users(username);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

