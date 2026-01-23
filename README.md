# README

## Kill MineCraft on Ram

Script will get the ram usage and check it against a specified percent. If the RAM usage is greater
than the specified percent it will kill all instanaces of MineCraft. 

To install run the following

```
sudo install -m 0755 /path/to/script /usr/local/bin/kill-minecraft-on-ram.sh
```

Copy the service file to ```/etc/systemd/system/kill-minecraft-on-ram.service```

Then run

```
sudo systemctl daemon-reload
sudo systemctl enable --now kill-minecraft-on-ram.service
```
