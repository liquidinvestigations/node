## Deploy liquid with Bigbluebutton frontend

Preamble : all commands in this documentation are assumed to be run as root.

To benefit from latest features, you can now deploy the liquid-node instance with a Bigbluebutton (BBB) videoconference frontend.

### Deploy the BBB server

In any case or trouble, you can report to the official BBB installation documentation there : https://docs.bigbluebutton.org/administration/install/

To deploy a BBB server, please deploy first a server with following minimal hardware and system requirements :

 - Ubuntu 20.04 64-bit
 - 16 GB of memory
 - 8 CPU cores
 - 50GB disk storage
 - prepare a hostname to point to it ( it can be up to you to set up yourself the SSL certificates, this procedure assume you don't, if you do, please refer to official BBB documentation ), later in the docs, the hostname used will be : **YOUR_SERVER_HOSTNAME**

Regarding networking, the server has to have :
- 80/443 TCP
- 16384-32768 UDP traffic enabled.

**This documentation will assume your BBB server has a unique public IP**, but you SHOULD protect your BBB server the same way your Liquid instance is, so if all traffic to Liquid is tunneled via a VPN, your traffic to BBB should do the same ; also, BBB software will try and detect itself its public IP, so the server is better with only one IP.
If you move apart from that assumption (server with unique public IP) in any way, please refer to official BBB documentation, otherwise functional BBB server is not guaranteed.

Install latest docker on your server :
```bash
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
as per the docker doc recommands, you can try and assure Docker is well installed by running :
`docker run hello-world`

Then to install latest BBB software (version 2.7), also as per the official doc recommands (read and change two variables before running) :
Options used :
`-e` is the email your will provide for being contacted regarding Letsencrypt SSL certificates, you can drop that option if generated your own certificates yourselves
`-s` is the name your BBB server will be configured with
`-v` is the BBB software version you're querying
```
wget -qO- https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh | bash -s -- -v focal-270 -s YOUR_SERVER_HOSTNAME -e email_for_letsencrypt_certbot@your_domain.org
echo 'disableRecordingDefault=true' >>  /etc/bigbluebutton/bbb-web.properties
echo 'breakoutRoomsRecord=false' >> /etc/bigbluebutton/bbb-web.properties
/usr/bin/bbb-conf --restart
```
The two 'echo' commands are for disabling recording.

Then, to ensure your BBB server is up and running, you can run :
`/usr/bin/bbb-conf --check`, last line you should see in the output is : `# Potential problems described below`
If this is not the case, please refer to official BBB documentation.


### Deploy liquid with the BBB frontend (Greenlight)

As of now, we have to rely on a specific branch from liquid-core to deploy liquid-node with BBB enabled.
To do that, after having followed the liquid-node installation instructions, please create a versions.ini file at the root of liquid-node, with following content :
```
[versions]    
liquid-core = liquidinvestigations/core:tmp-admin-show-oauth2
```
Then run `liquid deploy` again.
That version will match criteria for the BBB frontend OIDC + it will allow to have a new section "oauth2 provider" with manual access to add new oauth2 app.

Now, to deploy liquid with the BBB frontend, you should get the credentials from your BBB server, to do so, connect to the BBB server and use the bbb-conf tool like this :
`/usr/bin/bbb-conf --secret`
that will give you the BBB URL and SECRET to fill in the liquid.ini file, copy-paste them as follows :
```
bbb_endpoint = YOUR_BBB_API_URL
bbb_secret = YOUR_BBB_API_TOKEN
```

Then, you have to create a connect agent on the liquid admin interface, it's located at :
`https://YOUR_LIQUID_FQDN/admin/oauth2_provider/application/`
The info to fill in is as follows :
```
client type : 'confidential'
authorization grant type : 'anthorization code'
redirect URIs : https://bbb.LIQUID_DOMAIN/auth/openid_connect/callback
algo HMAC with sha2-256
```

Creation of that agent will give you the two last info to fill in the liquid.ini, that's :
```
bbb_oidc_id = COPY_PASTE_FROM_LIQUID_ADMIN_INTERFACE
bbb_oidc_secret = COPY_PASTE_FROM_LIQUID_ADMIN_INTERFACE
```

**IMPORTANT**
You can now connect to the 'greenlight' (the BBB frontend) interface with your liquid users ! But the users HAVE to have a first name and surname with at least 2 characters. Otherwise, you will get an error.
