# Vagrant configuration

The Vagrantfile supports VirtualBox and VMCK providers.

## VirtualBox

With Virtualbox we're using 8GB RAM and 8GB of swap.

First, run `./vbox-create-swap.sh` to create the swap file on your host.

Then just `vagrant up` and you should be good to go.


## VMCK

VMCK is used to provision VMs with 16GB of RAM.

```shell
export VMCK_URL=http://127.0.0.1:12345
vagrant up
```
