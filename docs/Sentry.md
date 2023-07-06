# Installing sentry, self-hosted, for monitoring Liquid Investigations

Sentry, in its default configuration, requires:

- 38 docker containers
- around **15 GB** of Docker images to download
- around **60 GB** of Disk Space just after installation
- **12-20 GB RAM**

These resources can either run on a dedicated box, or on the same computer as Liquid Investigations
(not recommended without manually reserving the RAM in Cluster/Nomad configs).

In the first case (dedicated box), one must connect the servers using a VPN, and access Sentry on the VPN IP. In the second case (single box), one can access Sentry on the liquid-bridge IP configured for Nomad
(by default, 10.66.60.1). Do not use `localhost` or `0.0.0.0` to bind/access the Sentry instance.

Monitoring browser-side JavaScript errors requires a public endpoint for
Sentry. To allow for this, one can proxy Sentry to a subdomain of the liquid
domain.
This can be achieved by setting the `[sentry] proxy-to-subdomain` setting to
the URL where the backends can reach Sentry. Alternatively, one can use their
own HTTPS termination to export Sentry, or omit the `hoover-ui-client` variable
and not track browser errors using Sentry.


## Prerequisite packages

- docker: https://get.docker.com
- docker-compose: https://docs.docker.com/compose/install/linux/#install-the-plugin-manually
- OS package manager: bash, git, curl

Use this snippet to check installed versions:

```
docker --version          # tested on v24.0.2
docker-compose --version  # tested on v2.18.1
# OR:
docker compose --version
```


## 1. Installing Containers

First, clone the repository.

```
sudo mkdir /opt/sentry && sudo chown "$(id -u):$(id -g)" /opt/sentry
git clone https://github.com/getsentry/self-hosted /opt/sentry
cd /opt/sentry && git fetch -ap && git checkout 23.6.1
```

Next, edit the environment file `.env.custom` with following changes:

- `cp .env .env.custom`
- edit `.env.custom` with whatever editor you have available
- replace `SENTRY_EVENT_RETENTION_DAYS` from `90` into `14`
- replace `SENTRY_BIND` from `9000` into `10.66.60.1:9000` or different VPN IP/port
- append `SENTRY_BEACON=False`

Finally, run the install scripts:

```
export SENTRY_BEACON=False
./install.sh --no-user-prompt --no-report-self-hosted-issues

docker compose --env-file .env.custom up -d
```

## 2. Create User Account & First Login

- Create initial user:
  - `cd /opt/sentry`
  - `docker compose run --rm web createuser`
  - write: email (e.g. admin@admin.admin), password (twice), superuser (Yes)
- Visit `http://10.66.60.1:9000` or whatever Bind Address you set previously, and login.
- Confirm the anonymous option at the bottom and hit Continue.
- Create new User Auth Token and paste it in liquid.ini
  - Visit Sentry (top-left drop-down) > User Auth Tokens > New Token
  - Create with the scopes `project:releases` and `org:read`
  - Paste the resulting token into `liquid.ini` section `[sentry] auth-token`


## 3. Create Projects

- Visit "Project > New Project": http://10.66.60.1:9000/organizations/sentry/projects/new/
- Create these projects with following info. For each project, disable alerts (the "create later" option).

| Platform     | Project Name  |
| ------------ | ------------- |
| Django       | hoover-snoop  |
| Django       | hoover-search |
| Django       | liquid-core   |
| Next.JS      | hoover-ui     |


After creating each project, save the DSN from  ["[Project] > Settings > Client Keys (DSN)"](http://10.66.60.1:9000/settings/sentry/projects/hoover-snoop/keys/) string in liquid.ini.
This results in a liquid.ini section that resembles the following:

```
[sentry]
hoover-snoop = http://b19327daef424246ac39e60d192ad556@10.66.60.1:9000/2
hoover-search = http://683d544f08b34e5eb845cd7d031f4ad5@10.66.60.1:9000/3
liquid-core = http://a96b372629fb45349a66bcd00eb1c922@10.66.60.1:9000/4
hoover-ui-server = http://6938c63f8037454383134ba0af114f67@10.66.60.1:9000/5
hoover-ui-client = http://6938c63f8037454383134ba0af114f67@sentry.liquid.example.org/5
proxy-to-subdomain = http://10.66.60.1:9000
```

Finally, in `/opt/node` re-run `./liquid deploy` to use the new Sentry configuration.

Your events should appear shortly in the UI.
