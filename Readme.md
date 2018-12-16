Experiments to run liquid services in cloud environments

### docker-compose
```
docker-compose up -d
docker-compose run --rm core ./manage.py createsuperuser
docker-compose run --rm core ./manage.py createoauth2app test http://localhost:5000/__auth/callback
```

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

### nomad
Create a configuration file, `nomad-agent.hcl`, with the following content,
adapted to your machine in case `eth0` is not the main network interface:

```hcl
advertise {
  http = "{{ GetInterfaceIP `eth0` }}"
  serf = "{{ GetInterfaceIP `eth0` }}"
}

client {
  enabled = true
  network_interface = "eth0"
}
```

```shell
consul agent -dev &
nomad agent -dev -config=nomad-agent.hcl &
nomad job run core.nomad
open http://$IP # IP address of your machine
```
