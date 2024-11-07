# dell-fan-control-nvidia
Manually control a dell server's fan speed based on the nvidia gpu temperature

# Why did you make this?
I have an Nvidia P4 in my dell R430 and the server does not adjust its fan speed based on the gpu temperature. This means that after a few minutes of use the card will overheat and my system will reboot :(

This little script fixes that problem by periodically checking the gpu temperature and setting the fan speed accordingly via IPMI :)

# Will this work with my system?

**Tested and improved to work on the following systems:**

PE R430 with single tesla P4

PE R720 with dual tesla P100 (idrac version 2.65.65.65)

**The basic requirementes are:**

- You have a Dell server and an Nvidia GPU (duh)
- You need to be able to run the `nvidia-smi` command (aka have the nvidia drivers installed)
- You need to have enabled IPMI over LAN in you IDRAC settings. On a 13th gen server this can be found under `Overview > IDRAC Settings > Network > IPMI Settings > Enable IPMI over LAN`

You can find a list of IPMI commands to test it [here](https://www.dell.com/support/manuals/en-ca/open-server-manager/open_server_manager_2.0/ipmi-commands?guid=guid-0a26239a-fdd7-4d06-b4f1-be8e59d6ca7b)

# How to use

**Cloning:**
```bash
git clone https://github.com/Olaren15/dell-fan-control-nvidia.git
cd dell-fan-control-nvidia
sudo chmod +x *.sh
nano *.sh
```

Edit the `dell-fan-control-nvidia.sh` file to use the proper IP adress, username and password. You may use a text editor like nano or vim.

`username` is the username you use to access idrac

`password` is the password you use to access idrac

`ip address` is the ip address of the idrac interface

**Setting Up:**

```bash
sudo mv dell-fan-control-nvidia.sh /usr/local/bin/dell-fan-control-nvidia.sh
sudo mv dell-fan-control-nvidia.service /lib/systemd/system/dell-fan-control-nvidia.service
```

**Installing Dependency:**

```bash
sudo apt install ipmitool
```

**Configuring systemctl:**

```bash
sudo systemctl daemon-reload
sudo systemctl start dell-fan-control-nvidia.service
sudo systemctl enable dell-fan-control-nvidia.service
```

And make sure the service is running without errors:

```bash
sudo systemctl status dell-fan-control-nvidia.service
```
enjoy!

# Credits
This script was (in part) inspired by [This repository](https://github.com/tigerblue77/Dell_iDRAC_fan_controller_Docker/tree/master) by [@tigetblue77](https://github.com/tigerblue77)

---
Made with ❤️ by a friend of Blåhaj
