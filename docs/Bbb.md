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

Install latest docker on your server using `curl https://get.docker.com/ | sudo bash`
as per the docker doc recommands, you can try and assure Docker is well installed by running :
`docker run hello-world`

Then to install latest BBB software (version 2.7), also as per the official doc recommands (read and change two variables before running) :
Options used :
`-e` is the email your will provide for being contacted regarding Letsencrypt SSL certificates, you can drop that option if generated your own certificates yourselves
`-s` is the name your BBB server will be configured with
`-v` is the BBB software version you're querying
```
wget -q https://raw.githubusercontent.com/bigbluebutton/bbb-install/v2.7.x-release/bbb-install.sh
bash ./bbb-install.sh -v focal-270 -s YOUR_SERVER_HOSTNAME -e email_for_letsencrypt_certbot@your_domain.org
echo 'disableRecordingDefault=true' >>  /etc/bigbluebutton/bbb-web.properties
echo 'breakoutRoomsRecord=false' >> /etc/bigbluebutton/bbb-web.properties
/usr/bin/bbb-conf --restart
```
The two 'echo' commands are for disabling recording.

Then, to ensure your BBB server is up and running, you can run :
`/usr/bin/bbb-conf --check`, last line you should see in the output is : `# Potential problems described below`
If this is not the case, please refer to official BBB documentation.


### Deploy liquid with the BBB frontend (Greenlight)

Now, to deploy liquid with the BBB frontend, you should get the credentials from your BBB server, to do so, connect to the BBB server and use the bbb-conf tool like this :
`/usr/bin/bbb-conf --secret`
that will give you the BBB URL and SECRET to fill in the liquid.ini file, copy-paste them as follows :
```
bbb_endpoint = YOUR_BBB_API_URL
bbb_secret = YOUR_BBB_API_TOKEN
```
