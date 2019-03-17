# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "generic/ubuntu1804"

  config.vm.network :forwarded_port, guest: 80, host: 1380, host_ip: "127.0.0.1"
  config.vm.network :forwarded_port, guest: 4646, host: 14646, host_ip: "127.0.0.1"

  config.vm.provision :shell, path: "vagrant-provision.sh"

  config.vm.synced_folder ".", "/vagrant"

end
