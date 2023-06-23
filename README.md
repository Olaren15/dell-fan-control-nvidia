# dell-fan-control-nvidia
Manually control a dell server's fan speed based on the nvidia gpu temperature

# Why did you make this?
I have an Nvidia P4 in my dell R430 and the server does not adjust its fan speed based on the gpu temperature. This means that after a few minutes of use the card will overheat and my system will reboot :(

This little script fixes that problem by periodically checking the gpu temperature and setting the fan speed accordingly via IPMI :)

# Will this work with my system?
Maybe 🤷‍♀️ I only tested this script on my dell R430 and an Nvidia Tesla P4.
The basic requirementes are: 
- You have a Dell server and an Nvidia GPU (duh)
- You need to be able to run the `nvidia-smi` command (aka have the nvidia drivers installed)
- You need to have enabled IPMI over LAN in you IDRAC settings. On a 13th gen server this can be found under `Overview > IDRAC Settings > Network > IPMI Settings > Enable IPMI over LAN`

# How to use
1. Edit the `dell-fan-control-nvidia.sh` file to use the proper IP adress, username and password
2. Place the `dell-fan-control-nvidia.sh` file in /usr/local/bin/
3. Place the `dell-fan-control-nvidia.service` file in /lib/systemd/system/
4. run `sudo systemctl daemon-reload` so that systemd is aware of our new service
5. run `sudo systemctl start dell-fan-control-nvidia.service` to start the service
6. run `sudo systemctl enable dell-fan-control-nvidia.service` to start the service on every boot
7. enjoy!

---
Made with ❤️ by a friend of Blåhaj
