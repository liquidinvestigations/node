# Vagrant configuration

### Running in Travis
Travis needs two secrets: the DO token and the SSH private key.

```shell
ssh-keygen -f id_rsa
travis encrypt-file id_rsa
travis encrypt DO_TOKEN="$DO_TOKEN"
```

Upload `id_rsa.pub` to DigitalOcean and name it `vagrant`.
