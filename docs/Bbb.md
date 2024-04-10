## Deploy liquid with Bigbluebutton frontend

You can deploy the liquid-node instance with a Bigbluebutton (BBB) videoconference frontend.
BBB (https://bigbluebutton.org) is a videoconference server, that provides an API to either start, end or join meetings.
Liquid uses Greenlight as a WEBUI for the BBB server.
But Liquid **DOES NOT** provide a BBB server. You have to deploy your own one, on a different server than the one hosting Liquid.
The following documentation will guide you through the deployment of a BBB server, and how to connect your Liquid instance to it.

### Deploy the BBB server

To deploy a BBB server, please first deploy a server with the following minimal hardware and system requirements:

- Ubuntu 20.04 64-bit
- 16 GB of memory
- 8 CPU cores
- 50GB disk storage
- prepare a hostname to point to it (it can be up to you to set up yourself the SSL certificates, this procedure assumes you don't, if you do, please refer to the official BBB documentation whose link is at the end of this file). Later in this documentation, the hostname used will be : **YOUR_SERVER_HOSTNAME**

Regarding networking, the server has to have:
- 80/443 TCP
- 16384-32768 UDP traffic enabled.

**This documentation will assume your BBB server has a unique public IP**, but you SHOULD protect your BBB server the same way your Liquid instance is, so if all traffic to Liquid is tunneled via a VPN, your traffic to BBB should do the same ; also, BBB software will try and detect itself its own public IP, so the server is better with only one IP.
If you move away from that assumption (server with a unique public IP) in any way, please refer to the official BBB documentation, otherwise a functional BBB server is not guaranteed.

Install the latest Docker on your server using `curl https://get.docker.com/ | sudo bash`
As per the Docker Doc recommandations, you can try and assure Docker is well installed by running:
`docker run hello-world`

Then, to install the latest BBB software (version 2.7), also as per the official documentation recommends (read and change two variables before running):
Options used:
`-e` is the email you will provide for being contacted regarding Letsencrypt SSL certificates, you can drop that option if you generated your own certificates yourselves
`-s` is the name your BBB server will be configured with
`-v` is the BBB software version you're querying
Preamble: all commands in this documentation are assumed to be run as root.
```
wget -q https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh
bash ./bbb-install.sh -v focal-270 -s YOUR_SERVER_HOSTNAME -e email_for_letsencrypt_certbot@your_domain.org
echo 'disableRecordingDefault=true' >>  /etc/bigbluebutton/bbb-web.properties
echo 'breakoutRoomsRecord=false' >> /etc/bigbluebutton/bbb-web.properties
/usr/bin/bbb-conf --restart
/usr/bin/bbb-conf --check
```
The two 'echo' commands are for disabling recording.

The last line of the code block is a checker, to ensure your BBB server is up and running.
The last line you should see in the output is: `# Potential problems described below`
If this is not the case, please refer to the official BBB documentation (link at the end of this file).


### Deploy liquid with the BBB frontend (Greenlight)

Now, to deploy liquid with the BBB frontend, you should get the credentials from your BBB server. To do so, connect to the BBB server and use the bbb-conf tool like this:
`/usr/bin/bbb-conf --secret`
that will give you the BBB URL and SECRET to fill in the liquid.ini file. Copy-paste them as follows:
```
bbb_endpoint = YOUR_BBB_API_URL
bbb_secret = YOUR_BBB_API_TOKEN
```
You can then add this data to your liquid.ini file like the following:
```
[bbb]
bbb_endpoint = https://YOUR_BBB_FQDN/bigbluebutton/
bbb_secret = YOUR_BBB_API_TOKEN
```
You can see an example liqui.ini file [there](../examples/liquid.ini#L238-L241)
Don't forget to enable bbb in apps : [example there](../examples/liquid.ini#L211)

### Troubleshooting the deployment

To narrow down what to troubleshoot, be sure what's blocking you, it can be either on the Liquid-node side, or on the BBB Server's.
If you can connect to your Liquid platform, a link for Bbb should appear, if clicked, it should redirect you to https://bbb.YOUR_SERVER_HOSTNAME, which shows a webUI called Greenlight. Then you can go and click to "start a meeting".
If you can go all thoses steps, your trouble lies within BBB-Server, otherwise, your trouble lies within Liquid-node BBB-Frontend

#### Troubleshooting the deployment of BBB-Server
In any case or trouble, you can report to the official BBB installation documentation there : https://docs.bigbluebutton.org/administration/install/
#### Troubleshooting the deployment of Liquid-node BBB-Frontend
Double-check and re-read this present file
Double-check and re-read the liquid.ini config file, see example available [there](../examples/liquid.ini)
