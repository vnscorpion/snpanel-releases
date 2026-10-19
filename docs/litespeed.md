# Upgrading from nginx to LiteSpeed Enterprise

**English** | [Tiếng Việt](litespeed.vi.md)

A fresh SNPanel serves its websites with nginx and PHP-FPM. You can move a
server to LiteSpeed Enterprise with one build job, in the style of
DirectAdmin's CustomBuild:

- Apache stays installed as a hot standby.
- A watchdog moves the sites to Apache within seconds if LiteSpeed stops
  answering or its licence stops being valid.
- The watchdog moves the sites back once LiteSpeed is healthy again.

Everything below runs as root over SSH. The panel's
**Server › Web server & PHP** page does the same things with buttons.

## Before you start

- **AlmaLinux 10 or Debian 13.**
  - Rocky Linux and RHEL 10 take AlmaLinux's path. Debian 12 takes Debian
    13's but has not been tested on a real server.
  - On Ubuntu, `snpanel build` refuses LiteSpeed for now, and those servers
    stay on nginx.
  - CloudLinux is not supported by this path.
- **Disk and memory.** At least 5 GB free on `/`. With less than 4 GB of RAM,
  add a 2 GB swap file first.
- **Network.** The server must reach `license.litespeedtech.com`.
- **Free ports.** Nothing else may listen on 8080/8443 (Apache) or 9080/9443
  (LiteSpeed).
- **Where lsphp comes from.**
  - AlmaLinux: Remi's PHP repository must be configured (the installer does
    that).
  - Debian: the update step adds LiteSpeed's own apt repository
    (`rpms.litespeedtech.com/debian`), its signing key shipped with the panel
    and pinned; lsphp is the `lsphpXY` packages.
  - Every PHP version a site uses must be installed.
- **No running jobs.** No restore, import or backup job may be running. The
  build waits for nothing; it refuses and tells you which job is running.
- **A licence.** Either a trial or a serial:
  - **Trial:** 14 days. LiteSpeed gives each IP address two trials, ever.
  - **Serial:** a purchased LiteSpeed Enterprise licence.
- **A snapshot of the VPS** is a good idea, as before any change to the web
  server.

## 1. Look at what runs now

```bash
snpanel build show       # build.conf and what the server runs
snpanel doctor           # everything should be ok before you change the web server
```

## 2. Declare LiteSpeed in build.conf

```bash
snpanel build set webserver litespeed     # php_mode becomes lsphp by itself
snpanel build set lsws_license trial      # or: serial (see below)
snpanel build set php_versions 8.4,8.3    # optional: the PHP versions to build; the first is the default
snpanel build set lsws_auto_return yes    # the default: return to LiteSpeed by itself after a failover
snpanel build show
```

`set` only writes `/etc/snpanel/build.conf`, after checking the value. It
installs nothing.

### With a serial instead of a trial

The serial is read from standard input, so it never appears on a command
line or in the shell history:

```bash
snpanel build license                     # paste the serial, then Enter
snpanel build set lsws_license serial
```

### About the trial

- The webserver step asks LiteSpeed for a trial key **only when the server has
  no LiteSpeed key at all**.
- If a key is there - even an expired one - the build never asks for another
  trial by itself.

## 3. Preview (optional)

```bash
snpanel build preview --wait
```

`preview` runs the preflight and the update step as a dry run. It shows the
plan and changes nothing.

On Debian, certbot's nginx plugin (`python3-certbot-nginx`) depends on
nginx and goes with it: expected, the cutover moves every certificate's
renewal off it first, and the way back to nginx installs it again.

On a fresh AlmaLinux server the preview may say that the package manager
would also remove phpMyAdmin with nginx. That is because Apache is not
installed yet. The cutover asks the package manager again, after Apache is
installed, and then phpMyAdmin stays. If the cutover still lists packages
that would go with nginx, the job stops and asks. Cancel it unless you mean
to remove them.

## 4. Build and cut over

```bash
snpanel build all --wait
```

`all` runs one background job with these steps. On a 4-CPU VPS the whole
job took about four minutes.

| Step | What it does |
|---|---|
| `preflight` | Checks everything above. |
| `update` | Package metadata, LiteSpeed's newest release, and the pinned OWASP CRS. |
| `webserver` | Installs Apache as the standby on 8080/8443 and LiteSpeed Enterprise on 9080/9443, and installs the licence. |
| `php` | lsphp for every PHP version, and LiteSpeed's handlers. |
| `waf` | ModSecurity and the rule set for Apache and LiteSpeed. |
| `rewrite_confs` | Writes every website's vhost again. |
| `cutover` | Compares every site on the new stack with what nginx serves, moves 80/443 to LiteSpeed with no gap, and removes nginx last. |

- The job runs in a systemd unit of its own (`snpanel-build-<job>`). Closing
  the SSH session, restarting the panel, or a panel update does not stop it.
  A panel update waits for the job.
- `--wait` follows the job and prints each step's log lines as they come.
  Without `--wait`, the command prints the job id and returns.
- If the job stops in a step, fix the cause and run it again from that step
  with `snpanel build retry <job>`.
- **One step at a time.** You can also run `snpanel build update`,
  `webserver`, `php`, `waf` and `rewrite_confs` one by one (each with
  `--wait`). Only `all` moves 80/443. Every step skips the work that is
  already done, so `all` after the separate steps only finishes the rest.

### Watching a job

```bash
snpanel build status                 # the last jobs: id, kind, state, start time
snpanel build status bj-xxxxxxxxxxxx # one job: each step, its state and message
journalctl -u snpanel-build-bj-xxxxxxxxxxxx -f    # everything the job's unit logs
snpanel build cancel bj-xxxxxxxxxxxx # stop at the next safe point (during the cutover: back to nginx)
snpanel build retry bj-xxxxxxxxxxxx  # run again from the step that stopped
```

- The cutover compares every site through the new stack with what nginx
  serves. The job stops if a site would answer differently (`needs_accept`).
  Look at the differences it lists.
- If the differences are expected, go on with
  `snpanel build retry <job> --accept-diffs`. This never goes past a site
  that would serve PHP source.

## 5. Check

```bash
snpanel build live        # who answers 80/443, both servers, the licence, the watchdog, WebAdmin
snpanel doctor            # web-stack, web-live, webwatch, lsws-licence and web-table should all be ok
curl -sI http://<a site>/ | grep -i '^server'    # Server: LiteSpeed
```

After the cutover:

- LiteSpeed serves 80/443.
- Apache is running on 8080/8443 as the standby.
- nginx is removed.
- Every customer's home is 0750, and the web servers are in each customer's
  group. `snpanel doctor --isolation` checks that no customer can reach into
  another's home.
- phpMyAdmin and the panel's tools vhost are served by Apache/LiteSpeed.

## 6. The watchdog and the return to LiteSpeed

`snpanel-webwatch.service` watches LiteSpeed:

- **It probes LiteSpeed every second.** After three failed probes it moves
  80/443 to Apache, within seconds. If Apache does not answer either, it
  restarts Apache once.
- **It checks the licence every 5 minutes.** If the licence is not valid, it
  moves the sites to Apache and never restarts or reloads LiteSpeed. A reload
  with a bad key would stop LiteSpeed.
- **Auto-return** (`lsws_auto_return = yes`). After a failover, the sites go
  back to LiteSpeed once all of these hold:
  - its licence checks valid;
  - it has answered for 5 minutes;
  - 10 minutes have passed since the switch.

You can take over by hand at any time:

```bash
snpanel build switch apache               # 80/443 to Apache now
snpanel build switch litespeed            # back: only if LiteSpeed answers and its licence is valid
snpanel build set lsws_auto_return no     # stay on Apache until you switch back yourself
```

The panel's Notifications send a message for:

- each failover;
- each return;
- a licence that will expire in 7, 3 or 1 days;
- a licence that has expired.

## 7. The licence

```bash
snpanel build live            # the licence: trial or serial, status, days left, expiry date
snpanel build license-check   # check it now (a serial's key is fetched again)
```

The Web server page shows the same licence card.

**When a trial or a licence expires:**

1. The watchdog sees an invalid licence within 5 minutes and moves 80/443 to
   Apache. The websites keep working on Apache: same vhosts, same PHP.
2. LiteSpeed is not reloaded, because a reload with an expired key would stop
   it.
3. To come back to LiteSpeed, install a serial:

   ```bash
   snpanel build license                    # paste the serial
   snpanel build set lsws_license serial
   snpanel build license-check              # registers the serial and checks it
   ```

   Auto-return then brings the sites back. Without auto-return, run
   `snpanel build switch litespeed`.
4. Or leave LiteSpeed and go back to nginx (section 9).

There is no new trial for the same IP after two. The build never asks for one
while any key is on the server.

## 8. LiteSpeed WebAdmin (port 7080)

WebAdmin listens on the loopback only (`lsws_admin = local`). Reach it through
an SSH tunnel:

```bash
ssh -L 7080:127.0.0.1:7080 root@<server>
# then open https://127.0.0.1:7080 in your browser; user: admin
cat /var/lib/snpanel-build/lsws-webadmin-password   # root only; never printed by the panel
```

The Web server page can also set a new WebAdmin password and shows it once.

To open WebAdmin on the network, for chosen addresses only:

```bash
snpanel build set lsws_admin_allow 203.0.113.5,198.51.100.0/24
snpanel build set lsws_admin public       # applied at once, and kept by every build and update
snpanel build set lsws_admin local        # back to the loopback
```

The panel manages LiteSpeed's configuration. Changes made in WebAdmin to
what the panel writes are overwritten by the next build or update.

## 9. Going back to nginx, or to Apache only

```bash
snpanel build set webserver nginx
snpanel build all --wait                      # nginx serves again; LiteSpeed and Apache are kept, stopped, for a quick return
snpanel build all --remove-litespeed --wait   # the same, and LiteSpeed and Apache are removed
```

- After `--remove-litespeed`, the licence key is kept aside, so a later return
  to LiteSpeed reuses it and does not ask for a new trial.
- `snpanel build set webserver apache` followed by `snpanel build all --wait`
  moves the server to Apache alone, with PHP-FPM.

## Debian 13: what differs

The commands are the same. Under the hood:

| | AlmaLinux 10 | Debian 13 |
|---|---|---|
| Apache | `httpd`, `/etc/httpd` | `apache2`, `/etc/apache2`; modules with `a2enmod`; the panel's `ports.conf` (8080/8443 only); the stock `000-default` site and snippets (`phpmyadmin.conf`, `serve-cgi-bin.conf` ...) become comment-only files |
| Web server account | `apache` | `www-data` |
| Sites' logs | `/var/log/httpd/<domain>.access.log` | `/var/log/apache2/<domain>.access.log` |
| lsphp | Remi's `phpXY-php-litespeed`, one `php.d` with PHP-FPM | LiteSpeed's `lsphpXY` packages in `/usr/local/lsws/lsphpXY`; the panel's ini files are linked into `/usr/local/lsws/lsphpXY/etc/php/X.Y/mods-available` |
| ModSecurity | `mod_security` | `libapache2-mod-security2`; the engine file is `/etc/apache2/modsec/engine.conf` |
| nginx removal | `dnf remove` (keeps `nginx-filesystem`) | `apt-get remove` (not purge: `/etc/nginx` stays for the way back) |

- PHP-FPM extensions LiteSpeed does not package for lsphp (FFI, shmop, and
  mcrypt on 8.4) are listed in the job's log and plan (`lsphp_gaps`); the
  sites run without them under LiteSpeed.
- **A trial key from before a reinstall.** LiteSpeed gives each IP two
  trials. On a reinstalled server whose IP already has a valid trial, put the
  saved key at `/usr/local/lsws/conf/trial.key` (root, 0600) before the
  first build: the webserver step installs LiteSpeed with it and asks for no
  new trial. A key that is not valid stops the install; no other trial is
  asked for.

## build.conf keys

| Key | Values |
|---|---|
| `webserver` | `nginx`, `apache` or `litespeed` (litespeed keeps Apache as the standby) |
| `php_mode` | `php-fpm` or `lsphp`; follows `webserver` (litespeed needs lsphp, nginx needs php-fpm) |
| `php_versions` | e.g. `8.4,8.3`; the first is the default |
| `waf` | `modsecurity` or `off` |
| `lsws_license` | `trial` or `serial` |
| `lsws_auto_return` | `yes` or `no` |
| `lsws_admin` | `local` or `public` |
| `lsws_admin_allow` | addresses or CIDR networks, comma-separated; empty allows every address |

`build.conf` also holds `harden_userns`, root's choice about user namespaces,
which `snpanel build set` does not change. Every `snpanel build` command and
option, and the host hardening, are in
[commands.md](commands.md#6-web-stack-snpanel-build).
