```
docker-compose up -d
docker-compose run --rm core ./manage.py createsuperuser
docker-compose run --rm core ./manage.py createoauth2app test http://localhost:5000/__auth/callback
```

Add the output from `createoauth2app` as env vars:

`docker-compose.override.yml`:
```
version: "3.3"

services:

  testapp-auth:
    environment:
      - LIQUID_CLIENT_ID=the-client-id-value
      - LIQUID_CLIENT_SECRET=the-client-secret-value
      - SECRET_KEY=some-random-string
```

Reload by running `docker-compose up -d` again
