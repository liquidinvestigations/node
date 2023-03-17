UPDATE public.authentication
SET
    "isEnabled" = true,
    config = '{
        "clientId":"$WIKIJS_OAUTH2_CLIENT_ID",
        "clientSecret":"$WIKIJS_OAUTH2_CLIENT_SECRET",
        "authorizationURL":"$WIKIJS_OAUTH2_AUTHORIZATION_URL",
        "tokenURL":"$WIKIJS_OAUTH2_TOKEN_URL",
        "userInfoURL":"$WIKIJS_OAUTH2_USER_PROFILE_URL",
        "userIdClaim":"$WIKIJS_OAUTH2_USER_PROFILE_ID_ATTR",
        "displayNameClaim":"$WIKIJS_OAUTH2_USER_PROFILE_USERNAME_ATTR",
        "emailClaim":"$WIKIJS_OAUTH2_USER_PROFILE_EMAIL_ATTR",
        "mapGroups":true,
        "groupsClaim":"$WIKIJS_OAUTH2_USER_PROFILE_GROUPS_ATTR",
        "logoutURL":"$WIKIJS_OAUTH2_LOGOUT_URL",
        "scope":"read",
        "useQueryStringForAccessToken":false,
        "enableCSRFProtection":true
    }',
    "selfRegistration" = true,
    "domainWhitelist" = '{"v":[]}',
    "autoEnrollGroups" = '{"v":[2]}',
    "order" = 0,
    "strategyKey" = 'oauth2',
    "displayName" = '$WIKIJS_OAUTH2_PROVIDERNAME'
WHERE  key = 'liquid' ;

UPDATE public.authentication
SET
    "isEnabled" = false,
    "selfRegistration" = false
WHERE  key != 'liquid' ;

UPDATE public.settings
SET
    value = '{"v":"$WIKIJS_HOST_URL"}',
    "updatedAt" = '2023-02-27T09:24:19.906Z'
WHERE key = 'host';

UPDATE public.settings
SET
    value = '{"v":"Wiki.js | $LIQUID_TITLE"}',
    "updatedAt" = '2023-02-27T09:24:19.906Z'
WHERE key IN ('title', 'company', 'footerOverride');


UPDATE public.settings
SET
    value = '{"autoLogin":true,"enforce2FA":false,"hideLocal":true,"loginBgUrl":"","audience":"urn:wiki.js","tokenExpiration":"30m","tokenRenewal":"1d"}',
    "updatedAt" = '2023-02-27T09:24:19.906Z'
WHERE key = 'auth';

-- UPDATE public.settings
-- SET
--     value = '{"v":"$WIKIJS_SESSION_SECRET"}',
--     "updatedAt" = '2023-02-27T09:24:19.906Z'
-- WHERE key ='sessionSecret';

--INSERT INTO public.settings (key, value, "updatedAt") VALUES ('api', '{"isEnabled":true}', '2023-03-15T09:51:04.841Z');
--INSERT INTO public."apiKeys" (id, name, key, expiration, "isRevoked", "createdAt", "updatedAt") VALUES (1, 'liquid_admin', 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGkiOjEsImdycCI6MSwiaWF0IjoxNjc4ODczODk5LCJleHAiOjE3NzM1NDY2OTksImF1ZCI6InVybjp3aWtpLmpzIiwiaXNzIjoidXJuOndpa2kuanMifQ.LmYugO9eN4EaeXJ-6fMBHVOowRBjhjetuRnhydujMUS10C9ZqlzuBOP6Bpnj0CyGMGFVq26LzI_ka1RYl_0tXenU_My21IUVivI3abv4JuQFjpl2GapiAtB6V1MgjvPtcNMkQaNIqDpty6x-psfRAB3cRp7Qkw3YU5UQopPuZ-aAhzupS4HIwkSNMFqB8XeyDHTz9gycfwJQTgTLXZZ0VjMwREGq6znyNHGtoQhuDLseA2mlJ2xdyjNY5qjNY32Xi6LDmSw1X-Ytug3vadFpTsaEwfPfRSBOQZsY2EpY2ozR-GNvUOBsKYTwQ8gkP5Zzcyo1HV7RzOon8CjE77m7Vw', '2026-03-15T03:51:39.605Z', false, '2023-03-15T09:51:39.608Z', '2023-03-15T09:51:39.691Z');
