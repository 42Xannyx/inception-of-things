# Sources

- [machine_settings](https://developer.hashicorp.com/vagrant/docs/vagrantfile/machine_settings)
- [Network options](https://docs.k3s.io/networking/basic-network-options)
- [VirtualBox Configuration](https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/configuration)

You can use both `INSTALL_K3S_EXEC=` or `-s -` to pass flags to k3s on installation. See example:

```
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --flannel-backend none --token 12345
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --flannel-backend none" K3S_TOKEN=12345 sh -s -
curl -sfL https://get.k3s.io | K3S_TOKEN=12345 sh -s - server --flannel-backend none
# server is assumed below because there is no K3S_URL
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend none --token 12345" sh -s - 
curl -sfL https://get.k3s.io | sh -s - --flannel-backend none --token 12345
```

To pass envirnments to the script on launch of a VM on Vagrant you can do the following:

`server_config.vm.provision "shell", path: "script.sh", env: {"KEY" => "VALUE"}`

This is similair to `export KEY=VALUE` in `bash`.
