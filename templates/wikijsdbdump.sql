--
-- PostgreSQL database dump
--

-- Dumped from database version 11.16 (Debian 11.16-1.pgdg90+1)
-- Dumped by pg_dump version 11.16 (Debian 11.16-1.pgdg90+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: analytics; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.analytics (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json NOT NULL
);


ALTER TABLE public.analytics OWNER TO wikijs;

--
-- Name: apiKeys; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."apiKeys" (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    key text NOT NULL,
    expiration character varying(255) NOT NULL,
    "isRevoked" boolean DEFAULT false NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL
);


ALTER TABLE public."apiKeys" OWNER TO wikijs;

--
-- Name: apiKeys_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."apiKeys_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."apiKeys_id_seq" OWNER TO wikijs;

--
-- Name: apiKeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."apiKeys_id_seq" OWNED BY public."apiKeys".id;


--
-- Name: assetData; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."assetData" (
    id integer NOT NULL,
    data bytea NOT NULL
);


ALTER TABLE public."assetData" OWNER TO wikijs;

--
-- Name: assetFolders; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."assetFolders" (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    "parentId" integer
);


ALTER TABLE public."assetFolders" OWNER TO wikijs;

--
-- Name: assetFolders_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."assetFolders_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."assetFolders_id_seq" OWNER TO wikijs;

--
-- Name: assetFolders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."assetFolders_id_seq" OWNED BY public."assetFolders".id;


--
-- Name: assets; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.assets (
    id integer NOT NULL,
    filename character varying(255) NOT NULL,
    hash character varying(255) NOT NULL,
    ext character varying(255) NOT NULL,
    kind text DEFAULT 'binary'::text NOT NULL,
    mime character varying(255) DEFAULT 'application/octet-stream'::character varying NOT NULL,
    "fileSize" integer,
    metadata json,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL,
    "folderId" integer,
    "authorId" integer,
    CONSTRAINT assets_kind_check CHECK ((kind = ANY (ARRAY['binary'::text, 'image'::text])))
);


ALTER TABLE public.assets OWNER TO wikijs;

--
-- Name: COLUMN assets."fileSize"; Type: COMMENT; Schema: public; Owner: wikijs
--

COMMENT ON COLUMN public.assets."fileSize" IS 'In kilobytes';


--
-- Name: assets_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.assets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.assets_id_seq OWNER TO wikijs;

--
-- Name: assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.assets_id_seq OWNED BY public.assets.id;


--
-- Name: authentication; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.authentication (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json NOT NULL,
    "selfRegistration" boolean DEFAULT false NOT NULL,
    "domainWhitelist" json NOT NULL,
    "autoEnrollGroups" json NOT NULL,
    "order" integer DEFAULT 0 NOT NULL,
    "strategyKey" character varying(255) DEFAULT ''::character varying NOT NULL,
    "displayName" character varying(255) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.authentication OWNER TO wikijs;

--
-- Name: brute; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.brute (
    key character varying(255),
    "firstRequest" bigint,
    "lastRequest" bigint,
    lifetime bigint,
    count integer
);


ALTER TABLE public.brute OWNER TO wikijs;

--
-- Name: commentProviders; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."commentProviders" (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json NOT NULL
);


ALTER TABLE public."commentProviders" OWNER TO wikijs;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    content text NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL,
    "pageId" integer,
    "authorId" integer,
    render text DEFAULT ''::text NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    ip character varying(255) DEFAULT ''::character varying NOT NULL,
    "replyTo" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.comments OWNER TO wikijs;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comments_id_seq OWNER TO wikijs;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: editors; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.editors (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json NOT NULL
);


ALTER TABLE public.editors OWNER TO wikijs;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.groups (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    permissions json NOT NULL,
    "pageRules" json NOT NULL,
    "isSystem" boolean DEFAULT false NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL,
    "redirectOnLogin" character varying(255) DEFAULT '/'::character varying NOT NULL
);


ALTER TABLE public.groups OWNER TO wikijs;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.groups_id_seq OWNER TO wikijs;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: locales; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.locales (
    code character varying(5) NOT NULL,
    strings json,
    "isRTL" boolean DEFAULT false NOT NULL,
    name character varying(255) NOT NULL,
    "nativeName" character varying(255) NOT NULL,
    availability integer DEFAULT 0 NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL
);


ALTER TABLE public.locales OWNER TO wikijs;

--
-- Name: loggers; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.loggers (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    level character varying(255) DEFAULT 'warn'::character varying NOT NULL,
    config json
);


ALTER TABLE public.loggers OWNER TO wikijs;

--
-- Name: migrations; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    name character varying(255),
    batch integer,
    migration_time timestamp with time zone
);


ALTER TABLE public.migrations OWNER TO wikijs;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_id_seq OWNER TO wikijs;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: migrations_lock; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.migrations_lock (
    index integer NOT NULL,
    is_locked integer
);


ALTER TABLE public.migrations_lock OWNER TO wikijs;

--
-- Name: migrations_lock_index_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.migrations_lock_index_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_lock_index_seq OWNER TO wikijs;

--
-- Name: migrations_lock_index_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.migrations_lock_index_seq OWNED BY public.migrations_lock.index;


--
-- Name: navigation; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.navigation (
    key character varying(255) NOT NULL,
    config json
);


ALTER TABLE public.navigation OWNER TO wikijs;

--
-- Name: pageHistory; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."pageHistory" (
    id integer NOT NULL,
    path character varying(255) NOT NULL,
    hash character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    description character varying(255),
    "isPrivate" boolean DEFAULT false NOT NULL,
    "isPublished" boolean DEFAULT false NOT NULL,
    "publishStartDate" character varying(255),
    "publishEndDate" character varying(255),
    action character varying(255) DEFAULT 'updated'::character varying,
    "pageId" integer,
    content text,
    "contentType" character varying(255) NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "editorKey" character varying(255),
    "localeCode" character varying(5),
    "authorId" integer,
    "versionDate" character varying(255) DEFAULT ''::character varying NOT NULL,
    extra json DEFAULT '{}'::json NOT NULL
);


ALTER TABLE public."pageHistory" OWNER TO wikijs;

--
-- Name: pageHistoryTags; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."pageHistoryTags" (
    id integer NOT NULL,
    "pageId" integer,
    "tagId" integer
);


ALTER TABLE public."pageHistoryTags" OWNER TO wikijs;

--
-- Name: pageHistoryTags_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."pageHistoryTags_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."pageHistoryTags_id_seq" OWNER TO wikijs;

--
-- Name: pageHistoryTags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."pageHistoryTags_id_seq" OWNED BY public."pageHistoryTags".id;


--
-- Name: pageHistory_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."pageHistory_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."pageHistory_id_seq" OWNER TO wikijs;

--
-- Name: pageHistory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."pageHistory_id_seq" OWNED BY public."pageHistory".id;


--
-- Name: pageLinks; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."pageLinks" (
    id integer NOT NULL,
    path character varying(255) NOT NULL,
    "localeCode" character varying(5) NOT NULL,
    "pageId" integer
);


ALTER TABLE public."pageLinks" OWNER TO wikijs;

--
-- Name: pageLinks_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."pageLinks_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."pageLinks_id_seq" OWNER TO wikijs;

--
-- Name: pageLinks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."pageLinks_id_seq" OWNED BY public."pageLinks".id;


--
-- Name: pageTags; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."pageTags" (
    id integer NOT NULL,
    "pageId" integer,
    "tagId" integer
);


ALTER TABLE public."pageTags" OWNER TO wikijs;

--
-- Name: pageTags_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."pageTags_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."pageTags_id_seq" OWNER TO wikijs;

--
-- Name: pageTags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."pageTags_id_seq" OWNED BY public."pageTags".id;


--
-- Name: pageTree; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."pageTree" (
    id integer NOT NULL,
    path character varying(255) NOT NULL,
    depth integer NOT NULL,
    title character varying(255) NOT NULL,
    "isPrivate" boolean DEFAULT false NOT NULL,
    "isFolder" boolean DEFAULT false NOT NULL,
    "privateNS" character varying(255),
    parent integer,
    "pageId" integer,
    "localeCode" character varying(5),
    ancestors json
);


ALTER TABLE public."pageTree" OWNER TO wikijs;

--
-- Name: pages; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.pages (
    id integer NOT NULL,
    path character varying(255) NOT NULL,
    hash character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    description character varying(255),
    "isPrivate" boolean DEFAULT false NOT NULL,
    "isPublished" boolean DEFAULT false NOT NULL,
    "privateNS" character varying(255),
    "publishStartDate" character varying(255),
    "publishEndDate" character varying(255),
    content text,
    render text,
    toc json,
    "contentType" character varying(255) NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL,
    "editorKey" character varying(255),
    "localeCode" character varying(5),
    "authorId" integer,
    "creatorId" integer,
    extra json DEFAULT '{}'::json NOT NULL
);


ALTER TABLE public.pages OWNER TO wikijs;

--
-- Name: pages_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.pages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pages_id_seq OWNER TO wikijs;

--
-- Name: pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.pages_id_seq OWNED BY public.pages.id;


--
-- Name: renderers; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.renderers (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json
);


ALTER TABLE public.renderers OWNER TO wikijs;

--
-- Name: searchEngines; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."searchEngines" (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    config json
);


ALTER TABLE public."searchEngines" OWNER TO wikijs;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.sessions (
    sid character varying(255) NOT NULL,
    sess json NOT NULL,
    expired timestamp with time zone NOT NULL
);


ALTER TABLE public.sessions OWNER TO wikijs;

--
-- Name: settings; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value json,
    "updatedAt" character varying(255) NOT NULL
);


ALTER TABLE public.settings OWNER TO wikijs;

--
-- Name: storage; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.storage (
    key character varying(255) NOT NULL,
    "isEnabled" boolean DEFAULT false NOT NULL,
    mode character varying(255) DEFAULT 'push'::character varying NOT NULL,
    config json,
    "syncInterval" character varying(255),
    state json
);


ALTER TABLE public.storage OWNER TO wikijs;

--
-- Name: tags; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    tag character varying(255) NOT NULL,
    title character varying(255),
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL
);


ALTER TABLE public.tags OWNER TO wikijs;

--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tags_id_seq OWNER TO wikijs;

--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: userAvatars; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."userAvatars" (
    id integer NOT NULL,
    data bytea NOT NULL
);


ALTER TABLE public."userAvatars" OWNER TO wikijs;

--
-- Name: userGroups; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."userGroups" (
    id integer NOT NULL,
    "userId" integer,
    "groupId" integer
);


ALTER TABLE public."userGroups" OWNER TO wikijs;

--
-- Name: userGroups_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."userGroups_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."userGroups_id_seq" OWNER TO wikijs;

--
-- Name: userGroups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."userGroups_id_seq" OWNED BY public."userGroups".id;


--
-- Name: userKeys; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public."userKeys" (
    id integer NOT NULL,
    kind character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "validUntil" character varying(255) NOT NULL,
    "userId" integer
);


ALTER TABLE public."userKeys" OWNER TO wikijs;

--
-- Name: userKeys_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public."userKeys_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."userKeys_id_seq" OWNER TO wikijs;

--
-- Name: userKeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public."userKeys_id_seq" OWNED BY public."userKeys".id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: wikijs
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    "providerId" character varying(255),
    password character varying(255),
    "tfaIsActive" boolean DEFAULT false NOT NULL,
    "tfaSecret" character varying(255),
    "jobTitle" character varying(255) DEFAULT ''::character varying,
    location character varying(255) DEFAULT ''::character varying,
    "pictureUrl" character varying(255),
    timezone character varying(255) DEFAULT 'America/New_York'::character varying NOT NULL,
    "isSystem" boolean DEFAULT false NOT NULL,
    "isActive" boolean DEFAULT false NOT NULL,
    "isVerified" boolean DEFAULT false NOT NULL,
    "mustChangePwd" boolean DEFAULT false NOT NULL,
    "createdAt" character varying(255) NOT NULL,
    "updatedAt" character varying(255) NOT NULL,
    "providerKey" character varying(255) DEFAULT 'local'::character varying NOT NULL,
    "localeCode" character varying(5) DEFAULT 'en'::character varying NOT NULL,
    "defaultEditor" character varying(255) DEFAULT 'markdown'::character varying NOT NULL,
    "lastLoginAt" character varying(255),
    "dateFormat" character varying(255) DEFAULT ''::character varying NOT NULL,
    appearance character varying(255) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.users OWNER TO wikijs;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: wikijs
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO wikijs;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wikijs
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: apiKeys id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."apiKeys" ALTER COLUMN id SET DEFAULT nextval('public."apiKeys_id_seq"'::regclass);


--
-- Name: assetFolders id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."assetFolders" ALTER COLUMN id SET DEFAULT nextval('public."assetFolders_id_seq"'::regclass);


--
-- Name: assets id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.assets ALTER COLUMN id SET DEFAULT nextval('public.assets_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: migrations_lock index; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.migrations_lock ALTER COLUMN index SET DEFAULT nextval('public.migrations_lock_index_seq'::regclass);


--
-- Name: pageHistory id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistory" ALTER COLUMN id SET DEFAULT nextval('public."pageHistory_id_seq"'::regclass);


--
-- Name: pageHistoryTags id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistoryTags" ALTER COLUMN id SET DEFAULT nextval('public."pageHistoryTags_id_seq"'::regclass);


--
-- Name: pageLinks id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageLinks" ALTER COLUMN id SET DEFAULT nextval('public."pageLinks_id_seq"'::regclass);


--
-- Name: pageTags id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTags" ALTER COLUMN id SET DEFAULT nextval('public."pageTags_id_seq"'::regclass);


--
-- Name: pages id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages ALTER COLUMN id SET DEFAULT nextval('public.pages_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: userGroups id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userGroups" ALTER COLUMN id SET DEFAULT nextval('public."userGroups_id_seq"'::regclass);


--
-- Name: userKeys id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userKeys" ALTER COLUMN id SET DEFAULT nextval('public."userKeys_id_seq"'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: analytics; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'azureinsights', false, '{"instrumentationKey":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'azureinsights');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'baidutongji', false, '{"propertyTrackingId":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'baidutongji');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'countly', false, '{"appKey":"","serverUrl":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'countly');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'elasticapm', false, '{"serverUrl":"http://apm.example.com:8200","serviceName":"wiki-js","environment":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'elasticapm');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'fathom', false, '{"host":"","siteId":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'fathom');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'fullstory', false, '{"org":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'fullstory');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'google', false, '{"propertyTrackingId":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'google');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'gtm', false, '{"containerTrackingId":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'gtm');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'hotjar', false, '{"siteId":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'hotjar');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'matomo', false, '{"siteId":1,"serverHost":"https://example.matomo.cloud"}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'matomo');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'newrelic', false, '{"licenseKey":"","appId":"","beacon":"bam.nr-data.net","errorBeacon":"bam.nr-data.net"}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'newrelic');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'plausible', false, '{"domain":"","plausibleJsSrc":"https://plausible.io/js/plausible.js"}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'plausible');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'statcounter', false, '{"projectId":"","securityToken":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'statcounter');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'umami', false, '{"websiteID":"","url":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'umami');
INSERT INTO public.analytics (key, "isEnabled", config) SELECT 'yandex', false, '{"tagNumber":""}' WHERE NOT EXISTS (SELECT key FROM public.analytics WHERE key = 'yandex');


--
-- Data for Name: apiKeys; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: assetData; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: assetFolders; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: assets; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: authentication; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.authentication (key, "isEnabled", config, "selfRegistration", "domainWhitelist", "autoEnrollGroups", "order", "strategyKey", "displayName") SELECT 'liquid', true, '{"clientId":"$WIKIJS_OAUTH2_CLIENT_ID","clientSecret":"$WIKIJS_OAUTH2_CLIENT_SECRET","authorizationURL":"$WIKIJS_OAUTH2_AUTHORIZATION_URL","tokenURL":"$WIKIJS_OAUTH2_TOKEN_URL","userInfoURL":"$WIKIJS_OAUTH2_USER_PROFILE_URL","userIdClaim":"$WIKIJS_OAUTH2_USER_PROFILE_ID_ATTR","displayNameClaim":"$WIKIJS_OAUTH2_USER_PROFILE_USERNAME_ATTR","emailClaim":"$WIKIJS_OAUTH2_USER_PROFILE_EMAIL_ATTR","mapGroups":true,"groupsClaim":"$WIKIJS_OAUTH2_USER_PROFILE_GROUPS_ATTR","logoutURL":"$WIKIJS_OAUTH2_LOGOUT_URL","scope":"read","useQueryStringForAccessToken":false,"enableCSRFProtection":true}', true, '{"v":[]}', '{"v":[3]}', 0, 'oauth2', '$WIKIJS_OAUTH2_PROVIDERNAME' WHERE NOT EXISTS (SELECT key FROM public.authentication WHERE key = 'liquid');
INSERT INTO public.authentication (key, "isEnabled", config, "selfRegistration", "domainWhitelist", "autoEnrollGroups", "order", "strategyKey", "displayName") SELECT 'local', true, '{}', false, '{"v":[]}', '{"v":[]}', 1, 'local', 'Local' WHERE NOT EXISTS (SELECT key FROM public.authentication WHERE key = 'local');


--
-- Data for Name: brute; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: commentProviders; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public."commentProviders" (key, "isEnabled", config) SELECT 'artalk', false, '{"server":"","siteName":""}' WHERE NOT EXISTS (SELECT key FROM public."commentProviders" WHERE key = 'artalk');
INSERT INTO public."commentProviders" (key, "isEnabled", config) SELECT 'commento', false, '{"instanceUrl":"https://cdn.commento.io"}' WHERE NOT EXISTS (SELECT key FROM public."commentProviders" WHERE key = 'commento');
INSERT INTO public."commentProviders" (key, "isEnabled", config) SELECT 'default', true, '{"akismet":"","minDelay":30}' WHERE NOT EXISTS (SELECT key FROM public."commentProviders" WHERE key = 'default');
INSERT INTO public."commentProviders" (key, "isEnabled", config) SELECT 'disqus', false, '{"accountName":""}' WHERE NOT EXISTS (SELECT key FROM public."commentProviders" WHERE key = 'disqus');


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: editors; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.editors (key, "isEnabled", config) SELECT 'api', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'api');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'asciidoc', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'asciidoc');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'ckeditor', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'ckeditor');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'code', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'code');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'markdown', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'markdown');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'redirect', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'redirect');
INSERT INTO public.editors (key, "isEnabled", config) SELECT 'wysiwyg', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.editors WHERE key = 'wysiwyg');


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: wikijs
--

-- TODO get SQL with groups 'admin' and 'user' to map the liquid oauth groups

INSERT INTO public.groups (id, name, permissions, "pageRules", "isSystem", "createdAt", "updatedAt", "redirectOnLogin") SELECT 1, 'Administrators', '["manage:system"]', '[]', true, '2023-02-27T08:53:15.208Z', '2023-02-27T08:53:15.208Z', '/' WHERE NOT EXISTS (SELECT id FROM public.groups WHERE id = 1);
INSERT INTO public.groups (id, name, permissions, "pageRules", "isSystem", "createdAt", "updatedAt", "redirectOnLogin") SELECT 2, 'Guests', '[]', '[{"id":"guest","deny":false,"match":"START","roles":["read:pages","read:assets","read:comments"],"path":"","locales":[]}]', true, '2023-02-27T08:53:15.211Z', '2023-02-27T09:26:57.358Z', '/' WHERE NOT EXISTS (SELECT id FROM public.groups WHERE id = 2);
INSERT INTO public.groups (id, name, permissions, "pageRules", "isSystem", "createdAt", "updatedAt", "redirectOnLogin") SELECT 3, 'admin', '["read:pages","read:assets","read:comments","write:comments","write:pages","manage:pages","delete:pages","write:styles","write:scripts","read:source","read:history","write:assets","manage:assets","manage:comments","write:users","manage:users","write:groups","manage:groups","manage:api","manage:theme","manage:navigation"]', '[{"id":"default","deny":false,"match":"START","roles":["read:pages","read:assets","read:comments","write:comments"],"path":"","locales":[]}]', false, '2023-02-28T10:12:44.970Z', '2023-02-28T10:13:03.269Z', '/' WHERE NOT EXISTS (SELECT id FROM public.groups WHERE id = 3);
INSERT INTO public.groups (id, name, permissions, "pageRules", "isSystem", "createdAt", "updatedAt", "redirectOnLogin") SELECT 4, 'user', '["read:pages","read:assets","read:comments","write:comments"]', '[{"id":"default","deny":false,"match":"START","roles":["read:pages","read:assets","read:comments","write:comments"],"path":"","locales":[]}]', false, '2023-02-27T09:31:57.724Z', '2023-02-28T10:14:25.058Z', '/' WHERE NOT EXISTS (SELECT id FROM public.groups WHERE id = 4);

--
-- Data for Name: locales; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.locales (code, strings, "isRTL", name, "nativeName", availability, "createdAt", "updatedAt") SELECT 'en', '{"common":{"footer":{"poweredBy":"Powered by","copyright":"© {{year}} {{company}}. All rights reserved.","license":"Content is available under the {{license}}, by {{company}}."},"actions":{"save":"Save","cancel":"Cancel","download":"Download","upload":"Upload","discard":"Discard","clear":"Clear","create":"Create","edit":"Edit","delete":"Delete","refresh":"Refresh","saveChanges":"Save Changes","proceed":"Proceed","ok":"OK","add":"Add","apply":"Apply","browse":"Browse...","close":"Close","page":"Page","discardChanges":"Discard Changes","move":"Move","rename":"Rename","optimize":"Optimize","preview":"Preview","properties":"Properties","insert":"Insert","fetch":"Fetch","generate":"Generate","confirm":"Confirm","copy":"Copy","returnToTop":"Return to top","exit":"Exit","select":"Select","convert":"Convert"},"newpage":{"title":"This page does not exist yet.","subtitle":"Would you like to create it now?","create":"Create Page","goback":"Go back"},"unauthorized":{"title":"Unauthorized","action":{"view":"You cannot view this page.","source":"You cannot view the page source.","history":"You cannot view the page history.","edit":"You cannot edit the page.","create":"You cannot create the page.","download":"You cannot download the page content.","downloadVersion":"You cannot download the content for this page version.","sourceVersion":"You cannot view the source of this version of the page."},"goback":"Go Back","login":"Login As..."},"notfound":{"gohome":"Home","title":"Not Found","subtitle":"This page does not exist."},"welcome":{"title":"Welcome to your wiki!","subtitle":"Let''s get started and create the home page.","createhome":"Create Home Page","goadmin":"Administration"},"header":{"home":"Home","newPage":"New Page","currentPage":"Current Page","view":"View","edit":"Edit","history":"History","viewSource":"View Source","move":"Move / Rename","delete":"Delete","assets":"Assets","imagesFiles":"Images & Files","search":"Search...","admin":"Administration","account":"Account","myWiki":"My Wiki","profile":"Profile","logout":"Logout","login":"Login","searchHint":"Type at least 2 characters to start searching...","searchLoading":"Searching...","searchNoResult":"No pages matching your query.","searchResultsCount":"Found {{total}} results","searchDidYouMean":"Did you mean...","searchClose":"Close","searchCopyLink":"Copy Search Link","language":"Language","browseTags":"Browse by Tags","siteMap":"Site Map","pageActions":"Page Actions","duplicate":"Duplicate","convert":"Convert"},"page":{"lastEditedBy":"Last edited by","unpublished":"Unpublished","editPage":"Edit Page","toc":"Page Contents","bookmark":"Bookmark","share":"Share","printFormat":"Print Format","delete":"Delete Page","deleteTitle":"Are you sure you want to delete page {{title}}?","deleteSubtitle":"The page can be restored from the administration area.","viewingSource":"Viewing source of page {{path}}","returnNormalView":"Return to Normal View","id":"ID {{id}}","published":"Published","private":"Private","global":"Global","loading":"Loading Page...","viewingSourceVersion":"Viewing source as of {{date}} of page {{path}}","versionId":"Version ID {{id}}","unpublishedWarning":"This page is not published.","tags":"Tags","tagsMatching":"Pages matching tags","convert":"Convert Page","convertTitle":"Select the editor you want to use going forward for the page {{title}}:","convertSubtitle":"The page content will be converted into the format of the newly selected editor. Note that some formatting or non-rendered content may be lost as a result of the conversion. A snapshot will be added to the page history and can be restored at any time.","editExternal":"Edit on {{name}}"},"error":{"unexpected":"An unexpected error occurred."},"password":{"veryWeak":"Very Weak","weak":"Weak","average":"Average","strong":"Strong","veryStrong":"Very Strong"},"user":{"search":"Search User","searchPlaceholder":"Search Users..."},"duration":{"every":"Every","minutes":"Minute(s)","hours":"Hour(s)","days":"Day(s)","months":"Month(s)","years":"Year(s)"},"outdatedBrowserWarning":"Your browser is outdated. Upgrade to a {{modernBrowser}}.","modernBrowser":"modern browser","license":{"none":"None","ccby":" Creative Commons Attribution License","ccbysa":"Creative Commons Attribution-ShareAlike License","ccbynd":"Creative Commons Attribution-NoDerivs License","ccbync":"Creative Commons Attribution-NonCommercial License","ccbyncsa":"Creative Commons Attribution-NonCommercial-ShareAlike License","ccbyncnd":"Creative Commons Attribution-NonCommercial-NoDerivs License","cc0":"Public Domain","alr":"All Rights Reserved"},"sidebar":{"browse":"Browse","mainMenu":"Main Menu","currentDirectory":"Current Directory","root":"(root)"},"comments":{"title":"Comments","newPlaceholder":"Write a new comment...","fieldName":"Your Name","fieldEmail":"Your Email Address","markdownFormat":"Markdown Format","postComment":"Post Comment","loading":"Loading comments...","postingAs":"Posting as {{name}}","beFirst":"Be the first to comment.","none":"No comments yet.","updateComment":"Update Comment","deleteConfirmTitle":"Confirm Delete","deleteWarn":"Are you sure you want to permanently delete this comment?","deletePermanentWarn":"This action cannot be undone!","modified":"modified {{reldate}}","postSuccess":"New comment posted successfully.","contentMissingError":"Comment is empty or too short!","updateSuccess":"Comment was updated successfully.","deleteSuccess":"Comment was deleted successfully.","viewDiscussion":"View Discussion","newComment":"New Comment","fieldContent":"Comment Content","sdTitle":"Talk"},"pageSelector":{"createTitle":"Select New Page Location","moveTitle":"Move / Rename Page Location","selectTitle":"Select a Page","virtualFolders":"Virtual Folders","pages":"Pages","folderEmptyWarning":"This folder is empty."}},"auth":{"loginRequired":"Login required","fields":{"emailUser":"Email / Username","password":"Password","email":"Email Address","verifyPassword":"Verify Password","name":"Name","username":"Username"},"actions":{"login":"Log In","register":"Register"},"errors":{"invalidLogin":"Invalid Login","invalidLoginMsg":"The email or password is invalid.","invalidUserEmail":"Invalid User Email","loginError":"Login error","notYetAuthorized":"You have not been authorized to login to this site yet.","tooManyAttempts":"Too many attempts!","tooManyAttemptsMsg":"You''ve made too many failed attempts in a short period of time, please try again {{time}}.","userNotFound":"User not found"},"providers":{"local":"Local","windowslive":"Microsoft Account","azure":"Azure Active Directory","google":"Google ID","facebook":"Facebook","github":"GitHub","slack":"Slack","ldap":"LDAP / Active Directory"},"tfa":{"title":"Two Factor Authentication","subtitle":"Security code required:","placeholder":"XXXXXX","verifyToken":"Verify"},"registerTitle":"Create an account","switchToLogin":{"text":"Already have an account? {{link}}","link":"Login instead"},"loginUsingStrategy":"Login using {{strategy}}","forgotPasswordLink":"Forgot your password?","orLoginUsingStrategy":"or login using...","switchToRegister":{"text":"Don''t have an account yet? {{link}}","link":"Create an account"},"invalidEmailUsername":"Enter a valid email / username.","invalidPassword":"Enter a valid password.","loginSuccess":"Login Successful! Redirecting...","signingIn":"Signing In...","genericError":"Authentication is unavailable.","registerSubTitle":"Fill-in the form below to create your account.","pleaseWait":"Please wait","registerSuccess":"Account created successfully!","registering":"Creating account...","missingEmail":"Missing email address.","invalidEmail":"Email address is invalid.","missingPassword":"Missing password.","passwordTooShort":"Password is too short.","passwordNotMatch":"Both passwords do not match.","missingName":"Name is missing.","nameTooShort":"Name is too short.","nameTooLong":"Name is too long.","forgotPasswordCancel":"Cancel","sendResetPassword":"Reset Password","forgotPasswordSubtitle":"Enter your email address to receive the instructions to reset your password:","registerCheckEmail":"Check your emails to activate your account.","changePwd":{"subtitle":"Choose a new password","instructions":"You must choose a new password:","newPasswordPlaceholder":"New Password","newPasswordVerifyPlaceholder":"Verify New Password","proceed":"Change Password","loading":"Changing password..."},"forgotPasswordLoading":"Requesting password reset...","forgotPasswordSuccess":"Check your emails for password reset instructions!","selectAuthProvider":"Select Authentication Provider","enterCredentials":"Enter your credentials","forgotPasswordTitle":"Forgot your password","tfaFormTitle":"Enter the security code generated from your trusted device:","tfaSetupTitle":"Your administrator has required Two-Factor Authentication (2FA) to be enabled on your account.","tfaSetupInstrFirst":"1) Scan the QR code below from your mobile 2FA application:","tfaSetupInstrSecond":"2) Enter the security code generated from your trusted device:"},"admin":{"dashboard":{"title":"Dashboard","subtitle":"Wiki.js","pages":"Pages","users":"Users","groups":"Groups","versionLatest":"You are running the latest version.","versionNew":"A new version is available: {{version}}","contributeSubtitle":"Wiki.js is a free and open source project. There are several ways you can contribute to the project.","contributeHelp":"We need your help!","contributeLearnMore":"Learn More","recentPages":"Recent Pages","mostPopularPages":"Most Popular Pages","lastLogins":"Last Logins"},"general":{"title":"General","subtitle":"Main settings of your wiki","siteInfo":"Site Info","siteBranding":"Site Branding","general":"General","siteUrl":"Site URL","siteUrlHint":"Full URL to your wiki, without the trailing slash. (e.g. https://wiki.example.com)","siteTitle":"Site Title","siteTitleHint":"Displayed in the top bar and appended to all pages meta title.","logo":"Logo","uploadLogo":"Upload Logo","uploadClear":"Clear","uploadSizeHint":"An image of {{size}} pixels is recommended for best results.","uploadTypesHint":"{{typeList}} or {{lastType}} files only","footerCopyright":"Footer Copyright","companyName":"Company / Organization Name","companyNameHint":"Name to use when displaying copyright notice in the footer. Leave empty to hide.","siteDescription":"Site Description","siteDescriptionHint":"Default description when none is provided for a page.","metaRobots":"Meta Robots","metaRobotsHint":"Default: Index, Follow. Can also be set on a per-page basis.","logoUrl":"Logo URL","logoUrlHint":"Specify an image to use as the logo. SVG, PNG, JPG are supported, in a square ratio, 34x34 pixels or larger. Click the button on the right to upload a new image.","contentLicense":"Content License","contentLicenseHint":"License shown in the footer of all content pages.","siteTitleInvalidChars":"Site Title contains invalid characters.","saveSuccess":"Site configuration saved successfully.","pageExtensions":"Page Extensions","pageExtensionsHint":"A comma-separated list of URL extensions that will be treated as pages. For example, adding md will treat /foobar.md the same as /foobar.","editMenuExternalName":"Button Site Name","editMenuExternalNameHint":"The name of the external site to display on the edit button. Do not include the \"Edit on\" prefix.","editMenuExternalIcon":"Button Icon","editMenuExternalIconHint":"The icon to display on the edit button. For example, mdi-github to display the GitHub icon.","editMenuExternalUrl":"Button URL","editMenuExternalUrlHint":"Url to the page on the external repository. Use the {filename} placeholder where the filename should be included. (e.g. https://github.com/foo/bar/blob/main/{filename} )","editShortcuts":"Edit Shortcuts","editFab":"FAB Quick Edit Menu","editFabHint":"Display the edit floating action button (FAB) with a speed-dial menu in the bottom right corner of the screen.","editMenuBar":"Edit Menu Bar","displayEditMenuBar":"Display Edit Menu Bar","displayEditMenuBarHint":"Display the edit menu bar in the page header.","displayEditMenuBtn":"Display Edit Button","displayEditMenuBtnHint":"Display a button to edit the current page.","displayEditMenuExternalBtn":"Display External Edit Button","displayEditMenuExternalBtnHint":"Display a button linking to an external repository (e.g. GitHub) where users can edit or submit a PR for the current page.","footerOverride":"Footer Text Override","footerOverrideHint":"Optionally override the footer text with a custom message. Useful if none of the above licenses are appropriate."},"locale":{"title":"Locale","subtitle":"Set localization options for your wiki","settings":"Locale Settings","namespacing":"Multilingual Namespacing","downloadTitle":"Download Locale","base":{"labelWithNS":"Base Locale","hint":"All UI text elements will be displayed in selected language.","label":"Site Locale"},"autoUpdate":{"label":"Update Automatically","hintWithNS":"Automatically download updates to all namespaced locales enabled below.","hint":"Automatically download updates to this locale as they become available."},"namespaces":{"label":"Multilingual Namespaces","hint":"Enables multiple language versions of the same page."},"activeNamespaces":{"label":"Active Namespaces","hint":"List of locales enabled for multilingual namespacing. The base locale defined above will always be included regardless of this selection."},"namespacingPrefixWarning":{"title":"The locale code will be prefixed to all paths. (e.g. /{{langCode}}/page-name)","subtitle":"Paths without a locale code will be automatically redirected to the base locale defined above."},"sideload":"Sideload Locale Package","sideloadHelp":"If you are not connected to the internet or cannot download locale files using the method above, you can instead sideload packages manually by uploading them below.","code":"Code","name":"Name","nativeName":"Native Name","rtl":"RTL","availability":"Availability","download":"Download"},"stats":{"title":"Statistics"},"theme":{"title":"Theme","subtitle":"Modify the look & feel of your wiki","siteTheme":"Site Theme","siteThemeHint":"Themes affect how content pages are displayed. Other site sections (such as the editor or admin area) are not affected.","darkMode":"Dark Mode","darkModeHint":"Not recommended for accessibility. May not be supported by all themes.","codeInjection":"Code Injection","cssOverride":"CSS Override","cssOverrideHint":"CSS code to inject after system default CSS. Consider using custom themes if you have a large amount of css code. Injecting too much CSS code will result in poor page load performance! CSS will automatically be minified.","headHtmlInjection":"Head HTML Injection","headHtmlInjectionHint":"HTML code to be injected just before the closing head tag. Usually for script tags.","bodyHtmlInjection":"Body HTML Injection","bodyHtmlInjectionHint":"HTML code to be injected just before the closing body tag.","downloadThemes":"Download Themes","iconset":"Icon Set","iconsetHint":"Set of icons to use for the sidebar navigation.","downloadName":"Name","downloadAuthor":"Author","downloadDownload":"Download","cssOverrideWarning":"{{caution}} When adding styles for page content, you must scope them to the {{cssClass}} class. Omitting this could break the layout of the editor!","cssOverrideWarningCaution":"CAUTION:","options":"Theme Options","tocHeadingLevels":"Default TOC Heading Levels","tocHeadingLevelsHint":"The table of contents will show headings from and up to the selected levels by default."},"groups":{"title":"Groups"},"users":{"title":"Users","active":"Active","inactive":"Inactive","verified":"Verified","unverified":"Unverified","edit":"Edit User","id":"ID {{id}}","basicInfo":"Basic Info","email":"Email","displayName":"Display Name","authentication":"Authentication","authProvider":"Provider","password":"Password","changePassword":"Change Password","newPassword":"New Password","tfa":"Two Factor Authentication (2FA)","toggle2FA":"Toggle 2FA","authProviderId":"Provider Id","groups":"User Groups","noGroupAssigned":"This user is not assigned to any group yet. You must assign at least 1 group to a user.","selectGroup":"Select Group...","groupAssign":"Assign","extendedMetadata":"Extended Metadata","location":"Location","jobTitle":"Job Title","timezone":"Timezone","userUpdateSuccess":"User updated successfully.","userAlreadyAssignedToGroup":"User is already assigned to this group!","deleteConfirmTitle":"Delete User?","deleteConfirmText":"Are you sure you want to delete user {{username}}?","updateUser":"Update User","groupAssignNotice":"Note that you cannot assign users to the Administrators or Guests groups from this panel.","deleteConfirmForeignNotice":"Note that you cannot delete a user that already created content. You must instead either deactivate the user or delete all content that was created by that user.","userVerifySuccess":"User has been verified successfully.","userActivateSuccess":"User has been activated successfully.","userDeactivateSuccess":"User deactivated successfully.","deleteConfirmReplaceWarn":"Any content (pages, uploads, comments, etc.) that was created by this user will be reassigned to the user selected below. It is recommended to create a dummy target user (e.g. Deleted User) if you don''t want the content to be reassigned to any current active user.","userTFADisableSuccess":"2FA was disabled successfully.","userTFAEnableSuccess":"2FA was enabled successfully."},"auth":{"title":"Authentication","subtitle":"Configure the authentication settings of your wiki","strategies":"Strategies","globalAdvSettings":"Global Advanced Settings","jwtAudience":"JWT Audience","jwtAudienceHint":"Audience URN used in JWT issued upon login. Usually your domain name. (e.g. urn:your.domain.com)","tokenExpiration":"Token Expiration","tokenExpirationHint":"The expiration period of a token until it must be renewed. (default: 30m)","tokenRenewalPeriod":"Token Renewal Period","tokenRenewalPeriodHint":"The maximum period a token can be renewed when expired. (default: 14d)","strategyState":"This strategy is {{state}} {{locked}}","strategyStateActive":"active","strategyStateInactive":"not active","strategyStateLocked":"and cannot be disabled.","strategyConfiguration":"Strategy Configuration","strategyNoConfiguration":"This strategy has no configuration options you can modify.","registration":"Registration","selfRegistration":"Allow self-registration","selfRegistrationHint":"Allow any user successfully authorized by the strategy to access the wiki.","domainsWhitelist":"Limit to specific email domains","domainsWhitelistHint":"A list of domains authorized to register. The user email address domain must match one of these to gain access.","autoEnrollGroups":"Assign to group","autoEnrollGroupsHint":"Automatically assign new users to these groups.","security":"Security","force2fa":"Force all users to use Two-Factor Authentication (2FA)","force2faHint":"Users will be required to setup 2FA the first time they login and cannot be disabled by the user.","configReference":"Configuration Reference","configReferenceSubtitle":"Some strategies may require some configuration values to be set on your provider. These are provided for reference only and may not be needed by the current strategy.","siteUrlNotSetup":"You must set a valid {{siteUrl}} first! Click on {{general}} in the left sidebar.","allowedWebOrigins":"Allowed Web Origins","callbackUrl":"Callback URL / Redirect URI","loginUrl":"Login URL","logoutUrl":"Logout URL","tokenEndpointAuthMethod":"Token Endpoint Authentication Method","refreshSuccess":"List of strategies has been refreshed.","saveSuccess":"Authentication configuration saved successfully.","activeStrategies":"Active Strategies","addStrategy":"Add Strategy","strategyIsEnabled":"Active","strategyIsEnabledHint":"Are users able to login using this strategy?","displayName":"Display Name","displayNameHint":"The title shown to the end user for this authentication strategy."},"editor":{"title":"Editor"},"logging":{"title":"Logging"},"rendering":{"title":"Rendering","subtitle":"Configure the page rendering pipeline"},"search":{"title":"Search Engine","subtitle":"Configure the search capabilities of your wiki","rebuildIndex":"Rebuild Index","searchEngine":"Search Engine","engineConfig":"Engine Configuration","engineNoConfig":"This engine has no configuration options you can modify.","listRefreshSuccess":"List of search engines has been refreshed.","configSaveSuccess":"Search engine configuration saved successfully.","indexRebuildSuccess":"Index rebuilt successfully."},"storage":{"title":"Storage","subtitle":"Set backup and sync targets for your content","targets":"Targets","status":"Status","lastSync":"Last synchronization {{time}}","lastSyncAttempt":"Last attempt was {{time}}","errorMsg":"Error Message","noTarget":"You don''t have any active storage target.","targetConfig":"Target Configuration","noConfigOption":"This storage target has no configuration options you can modify.","syncDirection":"Sync Direction","syncDirectionSubtitle":"Choose how content synchronization is handled for this storage target.","syncDirBi":"Bi-directional","syncDirPush":"Push to target","syncDirPull":"Pull from target","unsupported":"Unsupported","syncDirBiHint":"In bi-directional mode, content is first pulled from the storage target. Any newer content overwrites local content. New content since last sync is then pushed to the storage target, overwriting any content on target if present.","syncDirPushHint":"Content is always pushed to the storage target, overwriting any existing content. This is safest choice for backup scenarios.","syncDirPullHint":"Content is always pulled from the storage target, overwriting any local content which already exists. This choice is usually reserved for single-use content import. Caution with this option as any local content will always be overwritten!","syncSchedule":"Sync Schedule","syncScheduleHint":"For performance reasons, this storage target synchronize changes on an interval-based schedule, instead of on every change. Define at which interval should the synchronization occur.","syncScheduleCurrent":"Currently set to every {{schedule}}.","syncScheduleDefault":"The default is every {{schedule}}.","actions":"Actions","actionRun":"Run","targetState":"This storage target is {{state}}","targetStateActive":"active","targetStateInactive":"inactive","actionsInactiveWarn":"You must enable this storage target and apply changes before you can run actions."},"api":{"title":"API Access","subtitle":"Manage keys to access the API","enabled":"API Enabled","disabled":"API Disabled","enableButton":"Enable API","disableButton":"Disable API","newKeyButton":"New API Key","headerName":"Name","headerKeyEnding":"Key Ending","headerExpiration":"Expiration","headerCreated":"Created","headerLastUpdated":"Last Updated","headerRevoke":"Revoke","noKeyInfo":"No API keys have been generated yet.","revokeConfirm":"Revoke API Key?","revokeConfirmText":"Are you sure you want to revoke key {{name}}? This action cannot be undone!","revoke":"Revoke","refreshSuccess":"List of API keys has been refreshed.","revokeSuccess":"The key has been revoked successfully.","newKeyTitle":"New API Key","newKeySuccess":"API key created successfully.","newKeyNameError":"Name is missing or invalid.","newKeyGroupError":"You must select a group.","newKeyGuestGroupError":"The guests group cannot be used for API keys.","newKeyNameHint":"Purpose of this key","newKeyName":"Name","newKeyExpiration":"Expiration","newKeyExpirationHint":"You can still revoke a key anytime regardless of the expiration.","newKeyPermissionScopes":"Permission Scopes","newKeyFullAccess":"Full Access","newKeyGroupPermissions":"or use group permissions...","newKeyGroup":"Group","newKeyGroupHint":"The API key will have the same permissions as the selected group.","expiration30d":"30 days","expiration90d":"90 days","expiration180d":"180 days","expiration1y":"1 year","expiration3y":"3 years","newKeyCopyWarn":"Copy the key shown below as {{bold}}","newKeyCopyWarnBold":"it will NOT be shown again","toggleStateEnabledSuccess":"API has been enabled successfully.","toggleStateDisabledSuccess":"API has been disabled successfully."},"system":{"title":"System Info","subtitle":"Information about your system","hostInfo":"Host Information","currentVersion":"Current Version","latestVersion":"Latest Version","published":"Published","os":"Operating System","hostname":"Hostname","cpuCores":"CPU Cores","totalRAM":"Total RAM","workingDirectory":"Working Directory","configFile":"Configuration File","ramUsage":"RAM Usage: {{used}} / {{total}}","dbPartialSupport":"Your database version is not fully supported. Some functionality may be limited or not work as expected.","refreshSuccess":"System Info has been refreshed."},"utilities":{"title":"Utilities","subtitle":"Maintenance and miscellaneous tools","tools":"Tools","authTitle":"Authentication","authSubtitle":"Various tools for authentication / users","cacheTitle":"Flush Cache","cacheSubtitle":"Flush cache of various components","graphEndpointTitle":"GraphQL Endpoint","graphEndpointSubtitle":"Change the GraphQL endpoint for Wiki.js","importv1Title":"Import from Wiki.js 1.x","importv1Subtitle":"Migrate data from a previous 1.x installation","telemetryTitle":"Telemetry","telemetrySubtitle":"Enable/Disable telemetry or reset the client ID","contentTitle":"Content","contentSubtitle":"Various tools for pages","exportTitle":"Export to Disk","exportSubtitle":"Save content to tarball for backup / migration"},"dev":{"title":"Developer Tools","flags":{"title":"Flags"},"graphiql":{"title":"GraphiQL"},"voyager":{"title":"Voyager"}},"contribute":{"title":"Contribute to Wiki.js","subtitle":"Help support Wiki.js development and operations","fundOurWork":"Fund our work","spreadTheWord":"Spread the word","talkToFriends":"Talk to your friends and colleagues about how awesome Wiki.js is!","followUsOnTwitter":"Follow us on {{0}}.","submitAnIdea":"Submit an idea or vote on a proposed one on the {{0}}.","submitAnIdeaLink":"feature requests board","foundABug":"Found a bug? Submit an issue on {{0}}.","helpTranslate":"Help translate Wiki.js in your language. Let us know on {{0}}.","makeADonation":"Make a donation","contribute":"Contribute","openCollective":"Wiki.js is also part of the Open Collective initiative, a transparent fund that goes toward community resources. You can contribute financially by making a monthly or one-time donation:","needYourHelp":"We need your help to keep improving the software and run the various associated services (e.g. hosting and networking).","openSource":"Wiki.js is a free and open-source software brought to you with {{0}} by {{1}} and {{2}}.","openSourceContributors":"contributors","tshirts":"You can also buy Wiki.js t-shirts to support the project financially:","shop":"Wiki.js Shop","becomeAPatron":"Become a Patron","patreon":"Become a backer or sponsor via Patreon (goes directly into supporting lead developer Nicolas Giard''s goal of working full-time on Wiki.js)","paypal":"Make a one-time or recurring donation via Paypal:","ethereum":"We accept donations using Ethereum:","github":"Become a sponsor via GitHub Sponsors (goes directly into supporting lead developer Nicolas Giard''s goal of working full-time on Wiki.js)","becomeASponsor":"Become a Sponsor"},"nav":{"site":"Site","users":"Users","modules":"Modules","system":"System"},"pages":{"title":"Pages"},"navigation":{"title":"Navigation","subtitle":"Manage the site navigation","link":"Link","divider":"Divider","header":"Header","label":"Label","icon":"Icon","targetType":"Target Type","target":"Target","noSelectionText":"Select a navigation item on the left.","untitled":"Untitled {{kind}}","navType":{"external":"External Link","home":"Home","page":"Page","searchQuery":"Search Query","externalblank":"External Link (New Window)"},"edit":"Edit {{kind}}","delete":"Delete {{kind}}","saveSuccess":"Navigation saved successfully.","noItemsText":"Click the Add button to add your first navigation item.","emptyList":"Navigation is empty","visibilityMode":{"all":"Visible to everyone","restricted":"Visible to select groups..."},"selectPageButton":"Select Page...","mode":"Navigation Mode","modeSiteTree":{"title":"Site Tree","description":"Classic Tree-based Navigation"},"modeCustom":{"title":"Custom Navigation","description":"Static Navigation Menu + Site Tree Button"},"modeNone":{"title":"None","description":"Disable Site Navigation"},"copyFromLocale":"Copy from locale...","sourceLocale":"Source Locale","sourceLocaleHint":"The locale from which navigation items will be copied from.","copyFromLocaleInfoText":"Select the locale from which items will be copied from. Items will be appended to the current list of items in the active locale.","modeStatic":{"title":"Static Navigation","description":"Static Navigation Menu Only"}},"mail":{"title":"Mail","subtitle":"Configure mail settings","configuration":"Configuration","dkim":"DKIM (optional)","test":"Send a test email","testRecipient":"Recipient Email Address","testSend":"Send Email","sender":"Sender","senderName":"Sender Name","senderEmail":"Sender Email","smtp":"SMTP Settings","smtpHost":"Host","smtpPort":"Port","smtpPortHint":"Usually 465 (recommended), 587 or 25.","smtpTLS":"Secure (TLS)","smtpTLSHint":"Should be enabled when using port 465, otherwise turned off (587 or 25).","smtpUser":"Username","smtpPwd":"Password","dkimHint":"DKIM (DomainKeys Identified Mail) provides a layer of security on all emails sent from Wiki.js by providing the means for recipients to validate the domain name and ensure the message authenticity.","dkimUse":"Use DKIM","dkimDomainName":"Domain Name","dkimKeySelector":"Key Selector","dkimPrivateKey":"Private Key","dkimPrivateKeyHint":"Private key for the selector in PEM format","testHint":"Send a test email to ensure your SMTP configuration is working.","saveSuccess":"Configuration saved successfully.","sendTestSuccess":"A test email was sent successfully.","smtpVerifySSL":"Verify SSL Certificate","smtpVerifySSLHint":"Some hosts requires SSL certificate checking to be disabled. Leave enabled for proper security.","smtpName":"Client Identifying Hostname","smtpNameHint":"An optional name to send to the SMTP server to identify your mailer. Leave empty to use server hostname. For Google Workspace customers, this should be your main domain name."},"webhooks":{"title":"Webhooks","subtitle":"Manage webhooks to external services"},"adminArea":"Administration Area","analytics":{"title":"Analytics","subtitle":"Add analytics and tracking tools to your wiki","providers":"Providers","providerConfiguration":"Provider Configuration","providerNoConfiguration":"This provider has no configuration options you can modify.","refreshSuccess":"List of providers refreshed successfully.","saveSuccess":"Analytics configuration saved successfully"},"comments":{"title":"Comments","provider":"Provider","subtitle":"Add discussions to your wiki pages","providerConfig":"Provider Configuration","providerNoConfig":"This provider has no configuration options you can modify.","configSaveSuccess":"Comments configuration saved successfully."},"tags":{"title":"Tags","subtitle":"Manage page tags","emptyList":"No tags to display.","edit":"Edit Tag","tag":"Tag","label":"Label","date":"Created {{created}} and last updated {{updated}}.","delete":"Delete this tag","noSelectionText":"Select a tag from the list on the left.","noItemsText":"Add a tag to a page to get started.","refreshSuccess":"Tags have been refreshed.","deleteSuccess":"Tag deleted successfully.","saveSuccess":"Tag has been saved successfully.","filter":"Filter...","viewLinkedPages":"View Linked Pages","deleteConfirm":"Delete Tag?","deleteConfirmText":"Are you sure you want to delete tag {{tag}}? The tag will also be unlinked from all pages."},"ssl":{"title":"SSL","subtitle":"Manage SSL configuration","provider":"Provider","providerHint":"Select Custom Certificate if you have your own certificate already.","domain":"Domain","domainHint":"Enter the fully qualified domain pointing to your wiki. (e.g. wiki.example.com)","providerOptions":"Provider Options","providerDisabled":"Disabled","providerLetsEncrypt":"Let''s Encrypt","providerCustomCertificate":"Custom Certificate","ports":"Ports","httpPort":"HTTP Port","httpPortHint":"Non-SSL port the server will listen to for HTTP requests. Usually 80 or 3000.","httpsPort":"HTTPS Port","httpsPortHint":"SSL port the server will listen to for HTTPS requests. Usually 443.","httpPortRedirect":"Redirect HTTP requests to HTTPS","httpPortRedirectHint":"Will automatically redirect any requests on the HTTP port to HTTPS.","writableConfigFileWarning":"Note that your config file must be writable in order to persist ports configuration.","renewCertificate":"Renew Certificate","status":"Certificate Status","expiration":"Certificate Expiration","subscriberEmail":"Subscriber Email","currentState":"Current State","httpPortRedirectTurnOn":"Turn On","httpPortRedirectTurnOff":"Turn Off","renewCertificateLoadingTitle":"Renewing Certificate...","renewCertificateLoadingSubtitle":"Do not leave this page.","renewCertificateSuccess":"Certificate renewed successfully.","httpPortRedirectSaveSuccess":"HTTP Redirection changed successfully."},"security":{"title":"Security","maxUploadSize":"Max Upload Size","maxUploadBatch":"Max Files per Upload","maxUploadBatchHint":"How many files can be uploaded in a single batch?","maxUploadSizeHint":"The maximum size for a single file.","maxUploadSizeSuffix":"bytes","maxUploadBatchSuffix":"files","uploads":"Uploads","uploadsInfo":"These settings only affect Wiki.js. If you''re using a reverse-proxy (e.g. nginx, apache, Cloudflare), you must also change its settings to match.","subtitle":"Configure security settings","login":"Login","loginScreen":"Login Screen","jwt":"JWT Configuration","bypassLogin":"Bypass Login Screen","bypassLoginHint":"Should the user be redirected automatically to the first authentication provider.","loginBgUrl":"Login Background Image URL","loginBgUrlHint":"Specify an image to use as the login background. PNG and JPG are supported, 1920x1080 recommended. Leave empty for default. Click the button on the right to upload a new image. Note that the Guests group must have read-access to the selected image!","hideLocalLogin":"Hide Local Authentication Provider","hideLocalLoginHint":"Don''t show the local authentication provider on the login screen. Add ?all to the URL to temporarily use it.","loginSecurity":"Security","enforce2fa":"Enforce 2FA","enforce2faHint":"Force all users to use Two-Factor Authentication when using an authentication provider with a user / password form."},"extensions":{"title":"Extensions","subtitle":"Install extensions for extra functionality"}},"editor":{"page":"Page","save":{"processing":"Rendering","pleaseWait":"Please wait...","createSuccess":"Page created successfully.","error":"An error occurred while creating the page","updateSuccess":"Page updated successfully.","saved":"Saved"},"props":{"pageProperties":"Page Properties","pageInfo":"Page Info","title":"Title","shortDescription":"Short Description","shortDescriptionHint":"Shown below the title","pathCategorization":"Path & Categorization","locale":"Locale","path":"Path","pathHint":"Do not include any leading or trailing slashes.","tags":"Tags","tagsHint":"Use tags to categorize your pages and make them easier to find.","publishState":"Publishing State","publishToggle":"Published","publishToggleHint":"Unpublished pages are still visible to users with write permissions on this page.","publishStart":"Publish starting on...","publishStartHint":"Leave empty for no start date","publishEnd":"Publish ending on...","publishEndHint":"Leave empty for no end date","info":"Info","scheduling":"Scheduling","social":"Social","categorization":"Categorization","socialFeatures":"Social Features","allowComments":"Allow Comments","allowCommentsHint":"Enable commenting abilities on this page.","allowRatings":"Allow Ratings","displayAuthor":"Display Author Info","displaySharingBar":"Display Sharing Toolbar","displaySharingBarHint":"Show a toolbar with buttons to share and print this page","displayAuthorHint":"Show the page author along with the last edition time.","allowRatingsHint":"Enable rating capabilities on this page.","scripts":"Scripts","css":"CSS","cssHint":"CSS will automatically be minified upon saving. Do not include surrounding style tags, only the actual CSS code.","styles":"Styles","html":"HTML","htmlHint":"You must surround your javascript code with HTML script tags.","toc":"TOC","tocTitle":"Table of Contents","tocUseDefault":"Use Site Defaults","tocHeadingLevels":"TOC Heading Levels","tocHeadingLevelsHint":"The table of contents will show headings from and up to the selected levels."},"unsaved":{"title":"Discard Unsaved Changes?","body":"You have unsaved changes. Are you sure you want to leave the editor and discard any modifications you made since the last save?"},"select":{"title":"Which editor do you want to use for this page?","cannotChange":"This cannot be changed once the page is created.","customView":"or create a custom view?"},"assets":{"title":"Assets","newFolder":"New Folder","folderName":"Folder Name","folderNameNamingRules":"Must follow the asset folder {{namingRules}}.","folderNameNamingRulesLink":"naming rules","folderEmpty":"This asset folder is empty.","fileCount":"{{count}} files","headerId":"ID","headerFilename":"Filename","headerType":"Type","headerFileSize":"File Size","headerAdded":"Added","headerActions":"Actions","uploadAssets":"Upload Assets","uploadAssetsDropZone":"Browse or Drop files here...","fetchImage":"Fetch Remote Image","imageAlign":"Image Alignment","renameAsset":"Rename Asset","renameAssetSubtitle":"Enter the new name for this asset:","deleteAsset":"Delete Asset","deleteAssetConfirm":"Are you sure you want to delete asset","deleteAssetWarn":"This action cannot be undone!","refreshSuccess":"List of assets refreshed successfully.","uploadFailed":"File upload failed.","folderCreateSuccess":"Asset folder created successfully.","renameSuccess":"Asset renamed successfully.","deleteSuccess":"Asset deleted successfully.","noUploadError":"You must choose a file to upload first!"},"backToEditor":"Back to Editor","markup":{"bold":"Bold","italic":"Italic","strikethrough":"Strikethrough","heading":"Heading {{level}}","subscript":"Subscript","superscript":"Superscript","blockquote":"Blockquote","blockquoteInfo":"Info Blockquote","blockquoteSuccess":"Success Blockquote","blockquoteWarning":"Warning Blockquote","blockquoteError":"Error Blockquote","unorderedList":"Unordered List","orderedList":"Ordered List","inlineCode":"Inline Code","keyboardKey":"Keyboard Key","horizontalBar":"Horizontal Bar","togglePreviewPane":"Hide / Show Preview Pane","insertLink":"Insert Link","insertAssets":"Insert Assets","insertBlock":"Insert Block","insertCodeBlock":"Insert Code Block","insertVideoAudio":"Insert Video / Audio","insertDiagram":"Insert Diagram","insertMathExpression":"Insert Math Expression","tableHelper":"Table Helper","distractionFreeMode":"Distraction Free Mode","markdownFormattingHelp":"Markdown Formatting Help","noSelectionError":"Text must be selected first!","toggleSpellcheck":"Toggle Spellcheck"},"ckeditor":{"stats":"{{chars}} chars, {{words}} words"},"conflict":{"title":"Resolve Save Conflict","useLocal":"Use Local","useRemote":"Use Remote","useRemoteHint":"Discard local changes and use latest version","useLocalHint":"Use content in the left panel","viewLatestVersion":"View Latest Version","infoGeneric":"A more recent version of this page was saved by {{authorName}}, {{date}}","whatToDo":"What do you want to do?","whatToDoLocal":"Use your current local version and ignore the latest changes.","whatToDoRemote":"Use the remote version (latest) and discard your changes.","overwrite":{"title":"Overwrite with Remote Version?","description":"Are you sure you want to replace your current version with the latest remote content? {{refEditsLost}}","editsLost":"Your current edits will be lost."},"localVersion":"Local Version {{refEditable}}","editable":"(editable)","readonly":"(read-only)","remoteVersion":"Remote Version {{refReadOnly}}","leftPanelInfo":"Your current edit, based on page version from {{date}}","rightPanelInfo":"Last edited by {{authorName}}, {{date}}","pageTitle":"Title:","pageDescription":"Description:","warning":"Save conflict! Another user has already modified this page."},"unsavedWarning":"You have unsaved edits. Are you sure you want to leave the editor?"},"tags":{"currentSelection":"Current Selection","clearSelection":"Clear Selection","selectOneMoreTags":"Select one or more tags","searchWithinResultsPlaceholder":"Search within results...","locale":"Locale","orderBy":"Order By","selectOneMoreTagsHint":"Select one or more tags on the left.","retrievingResultsLoading":"Retrieving page results...","noResults":"Couldn''t find any page with the selected tags.","noResultsWithFilter":"Couldn''t find any page matching the current filtering options.","pageLastUpdated":"Last Updated {{date}}","orderByField":{"creationDate":"Creation Date","ID":"ID","lastModified":"Last Modified","path":"Path","title":"Title"},"localeAny":"Any"},"history":{"restore":{"confirmTitle":"Restore page version?","confirmText":"Are you sure you want to restore this page content as it was on {{date}}? This version will be copied on top of the current history. As such, newer versions will still be preserved.","confirmButton":"Restore","success":"Page version restored succesfully!"}},"profile":{"displayName":"Display Name","location":"Location","jobTitle":"Job Title","timezone":"Timezone","title":"Profile","subtitle":"My personal info","myInfo":"My Info","viewPublicProfile":"View Public Profile","auth":{"title":"Authentication","provider":"Provider","changePassword":"Change Password","currentPassword":"Current Password","newPassword":"New Password","verifyPassword":"Confirm New Password","changePassSuccess":"Password changed successfully."},"groups":{"title":"Groups"},"activity":{"title":"Activity","joinedOn":"Joined on","lastUpdatedOn":"Profile last updated on","lastLoginOn":"Last login on","pagesCreated":"Pages created","commentsPosted":"Comments posted"},"save":{"success":"Profile saved successfully."},"pages":{"title":"Pages","subtitle":"List of pages I created or last modified","emptyList":"No pages to display.","refreshSuccess":"Page list has been refreshed.","headerTitle":"Title","headerPath":"Path","headerCreatedAt":"Created","headerUpdatedAt":"Last Updated"},"comments":{"title":"Comments"},"preferences":"Preferences","dateFormat":"Date Format","localeDefault":"Locale Default","appearance":"Appearance","appearanceDefault":"Site Default","appearanceLight":"Light","appearanceDark":"Dark"}}', false, 'English', 'English', 100, '2023-02-27T08:53:15.202Z', '2023-02-27T08:53:20.961Z' WHERE NOT EXISTS (SELECT code FROM public.locales WHERE code = 'en');


--
-- Data for Name: loggers; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'airbrake', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'airbrake');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'bugsnag', false, 'warn', '{"key":""}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'bugsnag');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'disk', false, 'info', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'disk');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'eventlog', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'eventlog');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'loggly', false, 'warn', '{"token":"","subdomain":""}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'loggly');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'logstash', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'logstash');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'newrelic', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'newrelic');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'papertrail', false, 'warn', '{"host":"","port":0}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'papertrail');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'raygun', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'raygun');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'rollbar', false, 'warn', '{"key":""}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'rollbar');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'sentry', false, 'warn', '{"key":""}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'sentry');
INSERT INTO public.loggers (key, "isEnabled", level, config) SELECT 'syslog', false, 'warn', '{}' WHERE NOT EXISTS (SELECT key FROM public.loggers WHERE key = 'syslog');


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 1, '2.0.0.js', 1, '2023-02-27 08:35:07.526+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 1);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 2, '2.1.85.js', 1, '2023-02-27 08:35:07.534+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 2);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 3, '2.2.3.js', 1, '2023-02-27 08:35:07.557+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 3);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 4, '2.2.17.js', 1, '2023-02-27 08:35:07.567+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 4);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 5, '2.3.10.js', 1, '2023-02-27 08:35:07.571+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 5);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 6, '2.3.23.js', 1, '2023-02-27 08:35:07.577+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 6);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 7, '2.4.13.js', 1, '2023-02-27 08:35:07.583+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 7);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 8, '2.4.14.js', 1, '2023-02-27 08:35:07.603+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 8);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 9, '2.4.36.js', 1, '2023-02-27 08:35:07.61+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 9);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 10, '2.4.61.js', 1, '2023-02-27 08:35:07.615+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 10);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 11, '2.5.1.js', 1, '2023-02-27 08:35:07.65+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 11);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 12, '2.5.12.js', 1, '2023-02-27 08:35:07.658+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 12);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 13, '2.5.108.js', 1, '2023-02-27 08:35:07.663+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 13);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 14, '2.5.118.js', 1, '2023-02-27 08:35:07.666+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 14);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 15, '2.5.122.js', 1, '2023-02-27 08:35:07.684+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 15);
INSERT INTO public.migrations (id, name, batch, migration_time) SELECT 16, '2.5.128.js', 1, '2023-02-27 08:35:07.69+00' WHERE NOT EXISTS (SELECT id FROM public.migrations WHERE id = 16);


--
-- Data for Name: migrations_lock; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.migrations_lock (index, is_locked) SELECT 1, 0 WHERE NOT EXISTS (SELECT index FROM public.migrations_lock WHERE index = 1);


--
-- Data for Name: navigation; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.navigation (key, config) SELECT 'site', '[{"locale":"en","items":[{"id":"a80a7847-a1c0-4f91-b2d6-32c3abddd130","icon":"mdi-home","kind":"link","label":"Home","target":"/","targetType":"home","visibilityMode":"all","visibilityGroups":null}]}]' WHERE NOT EXISTS (SELECT key FROM public.navigation WHERE key = 'site');


--
-- Data for Name: pageHistory; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: pageHistoryTags; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: pageLinks; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: pageTags; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public."pageTags" (id, "pageId", "tagId") SELECT 1, 1, 1 WHERE NOT EXISTS (SELECT id FROM public."pageTags" WHERE id = 1);


--
-- Data for Name: pageTree; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public."pageTree" (id, path, depth, title, "isPrivate", "isFolder", "privateNS", parent, "pageId", "localeCode", ancestors) SELECT 1, 'home', 1, 'Home', false, false, NULL, NULL, 1, 'en', '[]' WHERE NOT EXISTS (SELECT id FROM public."pageTree" WHERE id = 1);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: wikijs
--

-- TODO only admin user and admin secret from template

INSERT INTO public.users (id, email, name, "providerId", password, "tfaIsActive", "tfaSecret", "jobTitle", location, "pictureUrl", timezone, "isSystem", "isActive", "isVerified", "mustChangePwd", "createdAt", "updatedAt", "providerKey", "localeCode", "defaultEditor", "lastLoginAt", "dateFormat", appearance) SELECT 2, 'guest@example.com', 'Guest', NULL, '', false, NULL, '', '', NULL, 'America/New_York', true, true, true, false, '2023-02-27T08:53:15.997Z', '2023-02-27T08:53:15.997Z', 'local', 'en', 'markdown', NULL, '', '' WHERE NOT EXISTS (SELECT id FROM public.users WHERE id = 2);
INSERT INTO public.users (id, email, name, "providerId", password, "tfaIsActive", "tfaSecret", "jobTitle", location, "pictureUrl", timezone, "isSystem", "isActive", "isVerified", "mustChangePwd", "createdAt", "updatedAt", "providerKey", "localeCode", "defaultEditor", "lastLoginAt", "dateFormat", appearance) SELECT 1, 'test@1234.com', 'Administrator', NULL, '$2a$12$0/2xsgIBa/mbkN/a1vb5M.GHuE4.cxnNYu2S2CW9HCcjq1iY5yqju', false, NULL, '', '', NULL, 'America/New_York', false, true, true, false, '2023-02-27T08:53:15.422Z', '2023-02-27T08:53:15.422Z', 'local', 'en', 'markdown', '2023-02-27T09:29:07.083Z', '', '' WHERE NOT EXISTS (SELECT id FROM public.users WHERE id = 1);

--
-- Data for Name: pages; Type: TABLE DATA; Schema: public; Owner: wikijs
--

-- TODO set the homepage accordingly

INSERT INTO public.pages (id, path, hash, title, description, "isPrivate", "isPublished", "privateNS", "publishStartDate", "publishEndDate", content, render, toc, "contentType", "createdAt", "updatedAt", "editorKey", "localeCode", "authorId", "creatorId", extra) SELECT 1, 'home', 'b29b5d2ce62e55412776ab98f05631e0aa96597b', 'Home', 'This is a Home Page', false, true, NULL, '', '', '# Header
Your content here', '<h1 class="toc-header" id="header"><a href="#header" class="toc-anchor">¶</a> Header</h1>
<p>Your content here</p>
', '[{"title":"Header","anchor":"#header","children":[]}]', 'markdown', '2023-02-27T09:21:30.486Z', '2023-02-27T09:21:33.620Z', 'markdown', 'en', 1, 1, '{"js":"","css":""}' WHERE NOT EXISTS (SELECT id FROM public.pages WHERE id = 1);


--
-- Data for Name: renderers; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'asciidocCore', true, '{"safeMode":"server"}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'asciidocCore');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlAsciinema', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlAsciinema');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlBlockquotes', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlBlockquotes');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlCodehighlighter', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlCodehighlighter');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlCore', true, '{"absoluteLinks":false,"openExternalLinkNewTab":false,"relAttributeExternalLink":"noreferrer"}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlCore');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlDiagram', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlDiagram');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlImagePrefetch', false, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlImagePrefetch');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlMediaplayers', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlMediaplayers');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlMermaid', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlMermaid');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlSecurity', true, '{"safeHTML":true,"allowDrawIoUnsafe":true,"allowIFrames":false}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlSecurity');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlTabset', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlTabset');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'htmlTwemoji', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'htmlTwemoji');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownAbbr', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownAbbr');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownCore', true, '{"allowHTML":true,"linkify":true,"linebreaks":true,"underline":false,"typographer":false,"quotes":"English"}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownCore');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownEmoji', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownEmoji');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownExpandtabs', true, '{"tabWidth":4}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownExpandtabs');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownFootnotes', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownFootnotes');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownImsize', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownImsize');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownKatex', true, '{"useInline":true,"useBlocks":true}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownKatex');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownKroki', false, '{"server":"https://kroki.io","openMarker":"```kroki","closeMarker":"```"}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownKroki');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownMathjax', false, '{"useInline":true,"useBlocks":true}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownMathjax');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownMultiTable', false, '{"multilineEnabled":true,"headerlessEnabled":true,"rowspanEnabled":true}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownMultiTable');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownPlantuml', true, '{"server":"https://plantuml.requarks.io","openMarker":"```plantuml","closeMarker":"```","imageFormat":"svg"}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownPlantuml');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownSupsub', true, '{"subEnabled":true,"supEnabled":true}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownSupsub');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'markdownTasklists', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'markdownTasklists');
INSERT INTO public.renderers (key, "isEnabled", config) SELECT 'openapiCore', true, '{}' WHERE NOT EXISTS (SELECT key FROM public.renderers WHERE key = 'openapiCore');


--
-- Data for Name: searchEngines; Type: TABLE DATA; Schema: public; Owner: wikijs
--

INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'algolia', false, '{"appId":"","apiKey":"","indexName":"wiki"}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'algolia');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'aws', false, '{"domain":"","endpoint":"","region":"us-east-1","accessKeyId":"","secretAccessKey":"","AnalysisSchemeLang":"en"}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'aws');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'azure', false, '{"serviceName":"","adminKey":"","indexName":"wiki"}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'azure');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'db', true, '{}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'db');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'elasticsearch', false, '{"apiVersion":"6.x","hosts":"","verifyTLSCertificate":true,"tlsCertPath":"","indexName":"wiki","analyzer":"simple","sniffOnStart":false,"sniffInterval":0}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'elasticsearch');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'manticore', false, '{}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'manticore');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'postgres', false, '{"dictLanguage":"english"}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'postgres');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'solr', false, '{"host":"solr","port":8983,"core":"wiki","protocol":"http"}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'solr');
INSERT INTO public."searchEngines" (key, "isEnabled", config) SELECT 'sphinx', false, '{}' WHERE NOT EXISTS (SELECT key FROM public."searchEngines" WHERE key = 'sphinx');


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: wikijs
--
-- TODO use mock secrets but keep structure (shouldn't look like secrets)
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'graphEndpoint', '{"v":"https://graph.requarks.io"}', '2023-02-27T08:53:15.100Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'graphEndpoint');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'certs', '{"jwk":{"kty":"RSA","n":"sNRJ2z8Cm4-gHW20ZuE0HnUk0HDAVQwyeFCQw6JE05tpgcS4vFdCGDBHq8SKQ_XFLwTu4x9C_I4j9VVgnmTJdm2-A5rHAPClOFGKkps6ZqIH75QHTBa0WVaHsFub8jkdjBHVI-VJFYkTn9do9MVAIbshPVRvBnMckSt82owaWWlB5cl_E1qAMrSFicIZ30c3SCfGVD2fVNocDeMvyUL19YXQ5WkSpJ8XQsDHt9uEM4dS8xmRbrp3ngNiYBW6Bmep2mDbv55T4wYZBBnzcauGIR1nu8W2iIiH-2MruOq05EirijCxANEyjuOH7U8bpMhEbqXLGd2gp7py8EJHS_Zknw","e":"AQAB"},"public":"-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEAsNRJ2z8Cm4+gHW20ZuE0HnUk0HDAVQwyeFCQw6JE05tpgcS4vFdC\nGDBHq8SKQ/XFLwTu4x9C/I4j9VVgnmTJdm2+A5rHAPClOFGKkps6ZqIH75QHTBa0\nWVaHsFub8jkdjBHVI+VJFYkTn9do9MVAIbshPVRvBnMckSt82owaWWlB5cl/E1qA\nMrSFicIZ30c3SCfGVD2fVNocDeMvyUL19YXQ5WkSpJ8XQsDHt9uEM4dS8xmRbrp3\nngNiYBW6Bmep2mDbv55T4wYZBBnzcauGIR1nu8W2iIiH+2MruOq05EirijCxANEy\njuOH7U8bpMhEbqXLGd2gp7py8EJHS/ZknwIDAQAB\n-----END RSA PUBLIC KEY-----\n","private":"-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: AES-256-CBC,773DEDF497C96EC81402753CD1AF2354\n\nylRj3vD79UJ47T9HmZ9C1U3I6DEfUJLflvZA1Ss/uKZpjycH8F1pggEMobaaBr+f\ntNz/41UE6LhLzQ9IlklH8ejBmzVi5KxzHbuq0kevFP5lFvduQXI6SzZhXSDYOsAu\nOGDkRPrmoAfw1EtMv+dfgx6E8hZJlx5rac4ZMZN2wuVOEeoXsN7rNUWWQJL6ulPn\nk2h9tc/VE7pyk4qkCAuFdqrDgeDqF0LAHKXF0sCFodNpcTY1g8YmWKNVlwd7AEvi\nRAgDmAB0zsO8l0LHcuFI5/pCQDFGUmm+Shy+Aj57sb3pc/XciaLsjrB7EhlWNzXK\n5RA69rnx/789bGys2xcGtSsT7+HRJ4QQ6+VhPom29ygN8y0IMAlFcCi2vLpOUbYY\n6mdJ5WDyi6orPOihY/jd+dkzY6y8NKhVsMtUDSb68dSSNs4Hvbr5JD7TBv9XDLtd\nvNYSqeZBy6zwVvbX4n5uRGiYgYJqS5xa2slhBS5UXvclcNpyFO9Uf//VXqIdNEVf\nuwtc5y9EzNTvnncXxrOTjPdHPh/C4IinncmjzDFqeL9M1F1wQiGmjvFQYcQs75Ux\nQ9DsxzhjCcUtotQy/OY+m7KfmiXZDFemuZR7SmZ/6l6OG5HMybHS7Q96N45MJad2\n9OxTSdaykIE1TnQchS4wpA/ppPxq1qn+Eu9uiaxipJ3iEoMuf7pXc2OA1db+efnw\n0SXW2X5oEoeqLlxt8dZqIbEBoC490DLZU5KHDhif6Tk8jyekZqln3J8yTKJneZX1\nl0aMAq8WDuRXo9l6sLUQD7uQL1KtT+bgP16KObPlEI5MHhV3A28ZwoxCYsfW9+lF\nlym2QMtarS2p1QI5JyNQADbnnQ8VPVah+31wmwQtgLBjZs7jwKX/33YNobb7V4By\n5hNHMD77ETqTj4YOA9OhyuJoz3skLQz2c5DI+Vu1U+Xd5JWf4t3mfXWGoR0inLNy\n8OP7/qErHujtG/dEajZ/V4gUCkUdxfxX4pbrrjCD6xksSKWhDq2u3Eid3l5zWTfg\nUgUUDJnXs0TACKnME/hBBfXDxpeGuDmN3Wioa1xpTVYFId2h6kSlcMjWXkv6kp2b\n9Icj2tsqgFHKA8kvk5RWJa/EO4hmu7LM4jUgQ7KlrhNNssweXtSLHoA+U+WCkGos\ngzTwIdIjqkTTMN6z54/Om9JXESQ4fYypWhtnIo166TRXNkKvkpcYLyV0zMa7/kzX\nzPvwtmUJ9wSIG7/uACJPFZoof+cf7Oa8iLE8rIOJMwqqBgMf5kJYOpo93a9nIdDZ\nztU/MF1lninJBCc0luppAeL1sgn4K23UdpMJV4ycHIN4UiVWRE8DpIQxhbqoTcT9\n1jQc3GQIXwEJCKHRqi16CgAHVVPsO3sr5dCcaUiU/v7pV2GnaV0SnQ5bg4J/hweW\nbWdQIOrVLzUodqICMUozHjiVtAhmTlqTiSmAm6kw5IT7Ff6ExxRFT2Nu4C/4huZR\nqLJFa/ffYe0pMzRwwLvjeyrGYXfsrdo8ruBvm/ieDFfmkkbWTwDOWrqo0HD3T9Ef\n+LEsmUqAEzJJkYaegyJDvhXb/hY3AZUeNP+ujZPbl8VUrptlYU65HC7EZVqudPdd\n-----END RSA PRIVATE KEY-----\n"}', '2023-02-27T08:53:15.086Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'certs');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'graphEndpoint', '{"v":"https://graph.requarks.io"}', '2023-02-27T08:53:15.100Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'graphEndpoint');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'lang', '{"code":"en","autoUpdate":true,"namespacing":false,"namespaces":[]}', '2023-02-27T08:53:15.106Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'lang');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'logo', '{"hasLogo":false,"logoIsSquare":false}', '2023-02-27T08:53:15.115Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'logo');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'mail', '{"senderName":"","senderEmail":"","host":"","port":465,"name":"","secure":true,"verifySSL":true,"user":"","pass":"","useDKIM":false,"dkimDomainName":"","dkimKeySelector":"","dkimPrivateKey":""}', '2023-02-27T08:53:15.123Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'mail');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'sessionSecret', '{"v":"36de88f45b61a3f6019018b5cde5123eba83e092aa910eda2b124ac3e89900ec"}', '2023-02-27T08:53:15.132Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'sessionSecret');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'telemetry', '{"isEnabled":false,"clientId":"88c376b2-0afd-4ab5-884d-986e92862bac"}', '2023-02-27T08:53:15.135Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'telemetry');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'theming', '{"theme":"default","darkMode":false,"iconset":"mdi","injectCSS":"","injectHead":"","injectBody":""}', '2023-02-27T08:53:15.138Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'theming');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'host', '{"v":"$WIKIJS_HOST_URL"}', '2023-02-27T09:24:19.906Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'host');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'title', '{"v":"Wiki.js"}', '2023-02-27T09:24:19.962Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'title');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'company', '{"v":""}', '2023-02-27T09:24:19.964Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'company');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'contentLicense', '{"v":""}', '2023-02-27T09:24:19.966Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'contentLicense');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'footerOverride', '{"v":""}', '2023-02-27T09:24:19.967Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'footerOverride');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'seo', '{"description":"","robots":["index","follow"],"analyticsService":"","analyticsId":""}', '2023-02-27T09:24:19.969Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'seo');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'logoUrl', '{"v":"https://static.requarks.io/logo/wikijs-butterfly.svg"}', '2023-02-27T09:24:19.970Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'logoUrl');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'pageExtensions', '{"v":["md","html","txt"]}', '2023-02-27T09:24:19.972Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'pageExtensions');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'auth', '{"autoLogin":true,"enforce2FA":null,"hideLocal":null,"loginBgUrl":null,"audience":"urn:wiki.js","tokenExpiration":"30m","tokenRenewal":"14d"}', '2023-02-27T09:24:19.973Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'auth');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'editShortcuts', '{"editFab":true,"editMenuBar":false,"editMenuBtn":true,"editMenuExternalBtn":true,"editMenuExternalName":"GitHub","editMenuExternalIcon":"mdi-github","editMenuExternalUrl":"https://github.com/org/repo/blob/main/{filename}"}', '2023-02-27T09:24:19.976Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'editShortcuts');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'features', '{"featurePageRatings":true,"featurePageComments":true,"featurePersonalWikis":true}', '2023-02-27T09:24:19.981Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'features');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'security', '{"securityOpenRedirect":true,"securityIframe":true,"securityReferrerPolicy":true,"securityTrustProxy":true,"securitySRI":true,"securityHSTS":false,"securityHSTSDuration":300,"securityCSP":false,"securityCSPDirectives":""}', '2023-02-27T09:24:19.985Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'security');
INSERT INTO public.settings (key, value, "updatedAt") SELECT 'uploads', '{"maxFileSize":5242880,"maxFiles":10,"scanSVG":true,"forceDownload":true}', '2023-02-27T09:24:19.989Z' WHERE NOT EXISTS (SELECT key FROM public.settings WHERE key = 'uploads');


--
-- Data for Name: storage; Type: TABLE DATA; Schema: public; Owner: wikijs
--


-- TODO configure s3 storage?

INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'azure', false, 'push', '{"accountName":"","accountKey":"","containerName":"wiki","storageTier":"Cool"}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'azure');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'box', false, 'push', '{"clientId":"","clientSecret":"","rootFolder":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'box');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'digitalocean', false, 'push', '{"endpoint":"nyc3.digitaloceanspaces.com","bucket":"","accessKeyId":"","secretAccessKey":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'digitalocean');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'disk', false, 'push', '{"path":"","createDailyBackups":false}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'disk');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'dropbox', false, 'push', '{"appKey":"","appSecret":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'dropbox');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'gdrive', false, 'push', '{"clientId":"","clientSecret":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'gdrive');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'git', false, 'sync', '{"authType":"ssh","repoUrl":"","branch":"master","sshPrivateKeyMode":"path","sshPrivateKeyPath":"","sshPrivateKeyContent":"","verifySSL":true,"basicUsername":"","basicPassword":"","defaultEmail":"name@company.com","defaultName":"John Smith","localRepoPath":"./data/repo","gitBinaryPath":""}', 'PT5M', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'git');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'onedrive', false, 'push', '{"clientId":"","clientSecret":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'onedrive');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 's3', false, 'push', '{"region":"","bucket":"","accessKeyId":"","secretAccessKey":""}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 's3');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 's3generic', false, 'push', '{"endpoint":"https://service.region.example.com","bucket":"","accessKeyId":"","secretAccessKey":"","sslEnabled":true,"s3ForcePathStyle":false,"s3BucketEndpoint":false}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 's3generic');
INSERT INTO public.storage (key, "isEnabled", mode, config, "syncInterval", state) SELECT 'sftp', false, 'push', '{"host":"","port":22,"authMode":"privateKey","username":"","privateKey":"","passphrase":"","password":"","basePath":"/root/wiki"}', 'P0D', '{"status":"pending","message":"","lastAttempt":null}' WHERE NOT EXISTS (SELECT key FROM public.storage WHERE key = 'sftp');


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: wikijs
--

-- TODO which tag for homepage?

INSERT INTO public.tags (id, tag, title, "createdAt", "updatedAt") SELECT 1, 'home', 'home', '2023-02-27T09:21:30.582Z', '2023-02-27T09:21:30.582Z' WHERE NOT EXISTS (SELECT id FROM public.tags WHERE id = 1);


--
-- Data for Name: userAvatars; Type: TABLE DATA; Schema: public; Owner: wikijs
--



--
-- Data for Name: userGroups; Type: TABLE DATA; Schema: public; Owner: wikijs
--

-- TODO only default user

INSERT INTO public."userGroups" (id, "userId", "groupId") SELECT 1, 1, 1 WHERE NOT EXISTS (SELECT id FROM public."userGroups" WHERE id = 1);
INSERT INTO public."userGroups" (id, "userId", "groupId") SELECT 2, 2, 2 WHERE NOT EXISTS (SELECT id FROM public."userGroups" WHERE id = 2);


--
-- Data for Name: userKeys; Type: TABLE DATA; Schema: public; Owner: wikijs
--





--
-- Name: apiKeys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."apiKeys_id_seq"', 1, false);


--
-- Name: assetFolders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."assetFolders_id_seq"', 1, false);


--
-- Name: assets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.assets_id_seq', 1, false);


--
-- Name: comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.comments_id_seq', 1, false);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.groups_id_seq', 3, true);


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.migrations_id_seq', 16, true);


--
-- Name: migrations_lock_index_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.migrations_lock_index_seq', 1, true);


--
-- Name: pageHistoryTags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."pageHistoryTags_id_seq"', 1, false);


--
-- Name: pageHistory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."pageHistory_id_seq"', 1, false);


--
-- Name: pageLinks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."pageLinks_id_seq"', 1, false);


--
-- Name: pageTags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."pageTags_id_seq"', 1, true);


--
-- Name: pages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.pages_id_seq', 1, true);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.tags_id_seq', 1, true);


--
-- Name: userGroups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."userGroups_id_seq"', 5, true);


--
-- Name: userKeys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public."userKeys_id_seq"', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: wikijs
--

SELECT pg_catalog.setval('public.users_id_seq', 5, true);


--
-- Name: analytics analytics_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.analytics
    ADD CONSTRAINT analytics_pkey PRIMARY KEY (key);


--
-- Name: apiKeys apiKeys_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."apiKeys"
    ADD CONSTRAINT "apiKeys_pkey" PRIMARY KEY (id);


--
-- Name: assetData assetData_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."assetData"
    ADD CONSTRAINT "assetData_pkey" PRIMARY KEY (id);


--
-- Name: assetFolders assetFolders_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."assetFolders"
    ADD CONSTRAINT "assetFolders_pkey" PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: authentication authentication_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.authentication
    ADD CONSTRAINT authentication_pkey PRIMARY KEY (key);


--
-- Name: commentProviders commentProviders_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."commentProviders"
    ADD CONSTRAINT "commentProviders_pkey" PRIMARY KEY (key);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: editors editors_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.editors
    ADD CONSTRAINT editors_pkey PRIMARY KEY (key);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: locales locales_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.locales
    ADD CONSTRAINT locales_pkey PRIMARY KEY (code);


--
-- Name: loggers loggers_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.loggers
    ADD CONSTRAINT loggers_pkey PRIMARY KEY (key);


--
-- Name: migrations_lock migrations_lock_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.migrations_lock
    ADD CONSTRAINT migrations_lock_pkey PRIMARY KEY (index);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: navigation navigation_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.navigation
    ADD CONSTRAINT navigation_pkey PRIMARY KEY (key);


--
-- Name: pageHistoryTags pageHistoryTags_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistoryTags"
    ADD CONSTRAINT "pageHistoryTags_pkey" PRIMARY KEY (id);


--
-- Name: pageHistory pageHistory_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistory"
    ADD CONSTRAINT "pageHistory_pkey" PRIMARY KEY (id);


--
-- Name: pageLinks pageLinks_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageLinks"
    ADD CONSTRAINT "pageLinks_pkey" PRIMARY KEY (id);


--
-- Name: pageTags pageTags_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTags"
    ADD CONSTRAINT "pageTags_pkey" PRIMARY KEY (id);


--
-- Name: pageTree pageTree_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTree"
    ADD CONSTRAINT "pageTree_pkey" PRIMARY KEY (id);


--
-- Name: pages pages_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_pkey PRIMARY KEY (id);


--
-- Name: renderers renderers_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.renderers
    ADD CONSTRAINT renderers_pkey PRIMARY KEY (key);


--
-- Name: searchEngines searchEngines_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."searchEngines"
    ADD CONSTRAINT "searchEngines_pkey" PRIMARY KEY (key);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (sid);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (key);


--
-- Name: storage storage_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.storage
    ADD CONSTRAINT storage_pkey PRIMARY KEY (key);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: tags tags_tag_unique; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_tag_unique UNIQUE (tag);


--
-- Name: userAvatars userAvatars_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userAvatars"
    ADD CONSTRAINT "userAvatars_pkey" PRIMARY KEY (id);


--
-- Name: userGroups userGroups_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userGroups"
    ADD CONSTRAINT "userGroups_pkey" PRIMARY KEY (id);


--
-- Name: userKeys userKeys_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userKeys"
    ADD CONSTRAINT "userKeys_pkey" PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_providerkey_email_unique; Type: CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_providerkey_email_unique UNIQUE ("providerKey", email);


--
-- Name: pagelinks_path_localecode_index; Type: INDEX; Schema: public; Owner: wikijs
--

CREATE INDEX pagelinks_path_localecode_index ON public."pageLinks" USING btree (path, "localeCode");


--
-- Name: sessions_expired_index; Type: INDEX; Schema: public; Owner: wikijs
--

CREATE INDEX sessions_expired_index ON public.sessions USING btree (expired);


--
-- Name: assetFolders assetfolders_parentid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."assetFolders"
    ADD CONSTRAINT assetfolders_parentid_foreign FOREIGN KEY ("parentId") REFERENCES public."assetFolders"(id);


--
-- Name: assets assets_authorid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_authorid_foreign FOREIGN KEY ("authorId") REFERENCES public.users(id);


--
-- Name: assets assets_folderid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_folderid_foreign FOREIGN KEY ("folderId") REFERENCES public."assetFolders"(id);


--
-- Name: comments comments_authorid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_authorid_foreign FOREIGN KEY ("authorId") REFERENCES public.users(id);


--
-- Name: comments comments_pageid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pageid_foreign FOREIGN KEY ("pageId") REFERENCES public.pages(id);


--
-- Name: pageHistory pagehistory_authorid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistory"
    ADD CONSTRAINT pagehistory_authorid_foreign FOREIGN KEY ("authorId") REFERENCES public.users(id);


--
-- Name: pageHistory pagehistory_editorkey_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistory"
    ADD CONSTRAINT pagehistory_editorkey_foreign FOREIGN KEY ("editorKey") REFERENCES public.editors(key);


--
-- Name: pageHistory pagehistory_localecode_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistory"
    ADD CONSTRAINT pagehistory_localecode_foreign FOREIGN KEY ("localeCode") REFERENCES public.locales(code);


--
-- Name: pageHistoryTags pagehistorytags_pageid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistoryTags"
    ADD CONSTRAINT pagehistorytags_pageid_foreign FOREIGN KEY ("pageId") REFERENCES public."pageHistory"(id) ON DELETE CASCADE;


--
-- Name: pageHistoryTags pagehistorytags_tagid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageHistoryTags"
    ADD CONSTRAINT pagehistorytags_tagid_foreign FOREIGN KEY ("tagId") REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: pageLinks pagelinks_pageid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageLinks"
    ADD CONSTRAINT pagelinks_pageid_foreign FOREIGN KEY ("pageId") REFERENCES public.pages(id) ON DELETE CASCADE;


--
-- Name: pages pages_authorid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_authorid_foreign FOREIGN KEY ("authorId") REFERENCES public.users(id);


--
-- Name: pages pages_creatorid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_creatorid_foreign FOREIGN KEY ("creatorId") REFERENCES public.users(id);


--
-- Name: pages pages_editorkey_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_editorkey_foreign FOREIGN KEY ("editorKey") REFERENCES public.editors(key);


--
-- Name: pages pages_localecode_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_localecode_foreign FOREIGN KEY ("localeCode") REFERENCES public.locales(code);


--
-- Name: pageTags pagetags_pageid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTags"
    ADD CONSTRAINT pagetags_pageid_foreign FOREIGN KEY ("pageId") REFERENCES public.pages(id) ON DELETE CASCADE;


--
-- Name: pageTags pagetags_tagid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTags"
    ADD CONSTRAINT pagetags_tagid_foreign FOREIGN KEY ("tagId") REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: pageTree pagetree_localecode_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTree"
    ADD CONSTRAINT pagetree_localecode_foreign FOREIGN KEY ("localeCode") REFERENCES public.locales(code);


--
-- Name: pageTree pagetree_pageid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTree"
    ADD CONSTRAINT pagetree_pageid_foreign FOREIGN KEY ("pageId") REFERENCES public.pages(id) ON DELETE CASCADE;


--
-- Name: pageTree pagetree_parent_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."pageTree"
    ADD CONSTRAINT pagetree_parent_foreign FOREIGN KEY (parent) REFERENCES public."pageTree"(id) ON DELETE CASCADE;


--
-- Name: userGroups usergroups_groupid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userGroups"
    ADD CONSTRAINT usergroups_groupid_foreign FOREIGN KEY ("groupId") REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: userGroups usergroups_userid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userGroups"
    ADD CONSTRAINT usergroups_userid_foreign FOREIGN KEY ("userId") REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: userKeys userkeys_userid_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public."userKeys"
    ADD CONSTRAINT userkeys_userid_foreign FOREIGN KEY ("userId") REFERENCES public.users(id);


--
-- Name: users users_defaulteditor_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_defaulteditor_foreign FOREIGN KEY ("defaultEditor") REFERENCES public.editors(key);


--
-- Name: users users_localecode_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_localecode_foreign FOREIGN KEY ("localeCode") REFERENCES public.locales(code);


--
-- Name: users users_providerkey_foreign; Type: FK CONSTRAINT; Schema: public; Owner: wikijs
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_providerkey_foreign FOREIGN KEY ("providerKey") REFERENCES public.authentication(key);


--
-- PostgreSQL database dump complete
--
