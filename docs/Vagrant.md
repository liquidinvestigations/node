# Vagrant

You can run a full Liquid cluster in a virtual machine using [Vagrant][]. The
configuration has been tested with the [libvirt driver][] but should work with
the default VirtualBox driver as well.

1. [Install vagrant][]
2. `cd` to the `vagrant` subfolder, everything Vagrant-related happens in here:
    ```shell
    cd vagrant/
    ```
3. Start the VM:
    ```shell
    vagrant up
    ```

You can log into the vm using `vagrant ssh`. Optionally, install
[vagrant-env][], and set environment variables in an `.env` local file that
will be ignored by git.

Vagrant will forward the following http ports:
  * `guest: 80, host: 1380` - public web server
  * `guest: 8765, host: 18765` - internal web server
  * `guest: 8500, host: 18500` - consul
  * `guest: 8200, host: 18200` - vault
  * `guest: 4646, host: 14646` - nomad


### Vagrant on MacOS

On MacOS the following extra steps need to be taken:

1. Run the following command in a terminal:
```shell
sudo socat -vvv  tcp-listen:80,fork tcp:localhost:1380
```

2. Edit `/etc/hosts` and add the following line:
```text
10.66.60.1       [liquid_domain] hoover.[liquid_domain]
```
where `[liquid_domain]` is the value of `liquid.domain` from the `liquid.ini` file.

[Vagrant]: https://www.vagrantup.com
[libvirt driver]: https://github.com/vagrant-libvirt/vagrant-libvirt
[Install vagrant]: https://www.vagrantup.com/docs/installation/
[vagrant-env]: https://github.com/gosuri/vagrant-env
