# systemd timers — scheduled dumps

On the **dump node** (not the CDN box):

```bash
sudo mkdir -p /opt/gpe-deploy
sudo cp -a /path/to/deploy/*.sh /opt/gpe-deploy/
sudo cp deploy/systemd/dogecoin-snapshot.service /etc/systemd/system/
sudo cp deploy/systemd/dogecoin-snapshot.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dogecoin-snapshot.timer
systemctl list-timers | grep dogecoin-snapshot
```

Optional publish after dump: create `/etc/dogecoin/snapshot-publish.env` (mode 600):

```bash
CDN_TARGET=deploy@cdn-host:/var/www/doge-sync/
```

Uncomment `EnvironmentFile` / `ExecStartPost` in the service unit, or prefer
**pull on the CDN host** via its own cron (often safer).

Do not put RPC passwords in the timer unit.
