# SNPanel command reference

**English** | [Tiếng Việt](commands.vi.md)

This is every command, flag and setting an administrator uses to install,
update and run SNPanel **v2.0.0**. Each one was checked against the v2.0.0
release: the `--help` of its binaries, and its install and update scripts.

Run everything as **root** over SSH, unless a line says otherwise. The panel
itself does most of this with buttons; the menu path is given where there is
one.

## Contents

1. [Requirements](#1-requirements)
2. [Install](#2-install)
3. [First login](#3-first-login)
4. [Update](#4-update)
5. [The `snpanel` command](#5-the-snpanel-command)
6. [Web stack: `snpanel build`](#6-web-stack-snpanel-build)
7. [Diagnostics and logs](#7-diagnostics-and-logs)
8. [Rescue and day-to-day administration](#8-rescue-and-day-to-day-administration)
9. [`snpanel-helper` operations for administrators](#9-snpanel-helper-operations-for-administrators)
10. [Addons and where they are in the panel](#10-addons-and-where-they-are-in-the-panel)
11. [Uninstall](#11-uninstall)
12. [Security notes](#12-security-notes)

---

## 1. Requirements

### Operating systems

| System | Status | Web stack |
|---|---|---|
| **AlmaLinux 10** | **Primary.** Tested the most; everything is supported. | nginx after the install; `snpanel build` moves it to LiteSpeed Enterprise (Apache as the standby) or to Apache alone, and back |
| Rocky Linux 10, RHEL 10 | Accepted by the installer and by `snpanel build`, but not tested like AlmaLinux. | as AlmaLinux |
| Oracle Linux 10, CentOS Stream 10 | Accepted by the installer, untested. `snpanel build` refuses them. | nginx |
| **Debian 13** | **Supported** (from v2.1.0), tested on real servers: the install, and `snpanel build` to LiteSpeed Enterprise (Apache as the standby) or Apache alone, and back. In v2.0.0 `snpanel build` refused it. | as AlmaLinux |
| **Ubuntu 24.04 LTS** | **Supported** (from v2.2.0), tested on real servers: a fresh install, an upgrade from 1.1.0, and `snpanel build` to LiteSpeed Enterprise (Apache as the standby) or Apache alone, and back. Until v2.1.0 `snpanel build` refused it. | as AlmaLinux |
| Debian 12 | Accepted by the installer and by `snpanel build` (Debian 13's code path), not tested on a real server. PHP 8.3 and 8.2 by default. | as Debian 13 |
| Ubuntu 26.04 and anything else | Refused by the installer. | - |
| CloudLinux | Not by these commands: `snpanel build` refuses it. | - |

Notes:

- On AlmaLinux the installer enables EPEL, CRB and Remi; PHP comes from Remi.
  SELinux is not configured by the installer.
- On AlmaLinux with nginx, the WAF page offers HTTP flood limits and bot
  blocking only (the nginx ModSecurity engine is not packaged there). The
  Apache and LiteSpeed stacks bring ModSecurity.
- Debian 13 gets PHP 7.4 to 8.5 from packages.sury.org; Ubuntu gets PHP from
  Ondřej Surý's PPA.

### Hardware

- **x86_64 only.** The bootstrap refuses other architectures.
- **CPU and RAM:** at least 1 vCPU and 1 GB RAM; 2 vCPU and 2 GB RAM
  recommended. Each account runs its own PHP-FPM master for each PHP version
  it uses, about 20-30 MB each.
- **LiteSpeed Enterprise** (with Apache as the standby): at least 2 GB RAM.
  The build accepts 1.9 GB, or 1.7 GB with 1 GB of swap. Below 4 GB of RAM
  without swap it advises a 2 GB swap file. Apache alone needs 1 GB.
- **Disk:** the installer does not check it. A `snpanel build` job needs 5 GB
  free on `/` for LiteSpeed, 2 GB for Apache or nginx. Leave room for the
  websites, their databases and local backups (`/var/backups/snpanel`).
- **cgroup v2** with the `cpu`, `memory` and `pids` controllers, for the
  per-account limits. Every supported distribution has it on a KVM or VMware
  VPS or real hardware. OpenVZ and some LXC containers do not: there the
  installer stops, unless you install with `SNPANEL_RESOURCE_LIMITS=off`
  (no per-account limits).

### A clean server

- A freshly installed operating system and root access.
- No other control panel, and nothing else on ports 80, 443, the panel port
  (2222) or, for the Email addon, the mail ports.
- The installer takes over the server: it installs nginx, MariaDB, Redis
  (Valkey on AlmaLinux), PHP, Node.js 22, certbot, phpMyAdmin, WP-CLI and
  nftables; it writes its own firewall, an SFTP block in `sshd_config` and
  kernel settings (`/etc/sysctl.d/90-snpanel-hardening.conf`). Do not install
  it on a server that already does other work.
- Optional: a domain that points at the server, for the panel's own Let's
  Encrypt certificate.

### Network

The server must reach, over HTTPS:

- `raw.githubusercontent.com`, `github.com` and `api.github.com`, and the
  hosts GitHub sends release downloads to (the release channel);
- the distribution's mirrors, and the repositories the installer adds: EPEL
  and Remi on AlmaLinux; NodeSource on Debian and Ubuntu; packages.sury.org
  on Debian; Ondřej Surý's PPA on Ubuntu;
- `license.litespeedtech.com`, for LiteSpeed Enterprise.

### Ports

| Port | What | Open |
|---|---|---|
| your SSH port (22) | SSH and SFTP | always; the panel's firewall cannot close it |
| 2222 (`PANEL_PORT`) | the panel, over HTTPS | always |
| 80, 443 | websites, Let's Encrypt, phpMyAdmin | always |
| 465, 587 | mail submission | always |
| 25, 110, 143, 993, 995 | SMTP, POP3, IMAP | when the Email addon is installed |
| 2096 | webmail | when the Email addon is installed |
| 53 TCP and UDP | DNS | when the DNS Manager addon is installed |
| 7080 | LiteSpeed WebAdmin | only with `lsws_admin public`; on 127.0.0.1 otherwise |
| 8080/8443, 9080/9443 | Apache (standby) and LiteSpeed, behind the 80/443 redirect | local only; never open them outside |
| 7081/7443 | nginx, while a build compares it before a return to nginx | local only |

MariaDB, Valkey/Redis and the PowerDNS API (8081) listen on the loopback
only. If your provider has a firewall in front of the server (a security
group), open the same ports there.

---

## 2. Install

### The bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

What it does:

1. Checks that it runs as root on x86_64, and installs `curl`, `tar`,
   `gzip`, `sha256sum`, `awk` or `sed` if one is missing.
2. Finds the newest stable release in
   [vnscorpion/snpanel-releases](https://github.com/vnscorpion/snpanel-releases)
   (GitHub's `releases/latest`; else the newest `vX.Y.Z` tag over git).
3. Downloads `snpanel-<tag>-x86_64-linux.tar.gz` and `SHA256SUMS` into
   `/var/tmp/snpanel-release.XXXXXX`, and checks the bundle's SHA-256.
   Nothing in the bundle is unpacked, let alone run, before that check.
4. Runs the installer inside the bundle. **If SNPanel is already installed**
   (`/opt/snpanel/backend/.env` exists), it runs the bundle's updater
   instead: see [4.4](#44-servers-installed-before-v200).
5. Removes the bundle, unless `SNPANEL_KEEP_BUNDLE=yes`.

The bundle carries the interface already built and the panel's static
binaries, so nothing is compiled on the server.

### The installer's questions

- **Panel hostname** - optional. Left blank, the panel uses the server's IP
  address.
- **Panel port** - `2222` by default. The firewall opens only that port for
  the panel.
- **Let's Encrypt** for the hostname (only asked for a domain), and an e-mail
  address for it.

Without a domain, or without Let's Encrypt, the panel gets a self-signed
certificate (10 years) and still answers over HTTPS.

### Environment variables

Put them between the pipe and `bash`:
`curl ... | NAME=value NAME2=value bash`.

| Variable | Default | What it does |
|---|---|---|
| `SNPANEL_VERSION` | the newest stable release | Install this release: `vX.Y.Z`, or a prerelease such as `v2.0.0-rc.1`. |
| `PANEL_URL` | asked | `https://<host or IP>:<port>`. Answers the hostname and port questions; needed when there is no terminal. |
| `PANEL_HOSTNAME` | asked | The hostname only; the port is still asked. |
| `PANEL_PORT` | `2222` | The panel's port. A port in `PANEL_URL` wins. |
| `ENABLE_SSL` | `auto` (asks, for a domain) | `yes`: a Let's Encrypt certificate for the hostname (needs `SSL_EMAIL`). `no`: self-signed. An IP address is always self-signed. |
| `SSL_EMAIL` | asked when needed | The Let's Encrypt account e-mail; also kept in the panel's `.env`. |
| `PANEL_TIMEZONE` | unchanged | Sets the server's time zone, e.g. `Asia/Ho_Chi_Minh`. Left empty, the installer never touches it. |
| `PHP_VERSIONS` | `8.3 8.4` (Debian 12: `8.2 8.3`) | The PHP versions to install, separated by spaces. More can be added from the panel later. |
| `PHP_DEFAULT` | `8.4` (Debian 12: `8.3`) | The default PHP version; it must be one of `PHP_VERSIONS`. |
| `SNPANEL_RESOURCE_LIMITS` | `on` | `off` installs without per-account CPU and memory limits (no cgroup v2). |
| `SNPANEL_HARDEN_USERNS` | `yes` | `no` keeps user namespaces as the distribution has them (see [6.8](#68-host-hardening-and-the-opt-out)). |
| `SNPANEL_ADMIN_PASSWORD` | random | The `admin` password to set, instead of a random one. Typed on a command line it lands in the shell history: prefer the random one. |
| `BACKUP_ROOT` | `/var/backups/snpanel` | Where backups are kept. |
| `APP_DIR` | `/opt/snpanel` | Where the panel is installed. Leave it: the `snpanel` command then needs the same `APP_DIR` in its environment every time. |
| `SNPANEL_RELEASE_REPO` | `https://github.com/vnscorpion/snpanel-releases` | Another GitHub repository with the same layout (development only). |
| `SNPANEL_KEEP_BUNDLE` | `no` | `yes` keeps the unpacked bundle and prints where it is. |

Examples:

```bash
# A particular release
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_VERSION=v2.0.0 bash

# No questions, on the server's IP (self-signed certificate)
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://203.0.113.10:2222 bash

# No questions, on a domain with Let's Encrypt: ENABLE_SSL and SSL_EMAIL are
# needed too, or the installer stops at the Let's Encrypt question
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh \
  | PANEL_URL=https://panel.example.com:2222 ENABLE_SSL=yes SSL_EMAIL=admin@example.com bash

# Time zone, PHP versions, and user namespaces kept
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh \
  | PANEL_TIMEZONE=Asia/Ho_Chi_Minh PHP_VERSIONS="8.2 8.3 8.4" PHP_DEFAULT=8.4 SNPANEL_HARDEN_USERNS=no bash

# A container without cgroup v2 controllers
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_RESOURCE_LIMITS=off bash
```

Variables not listed here are the scripts' own and are not meant to be set.

### What gets installed where

| | |
|---|---|
| `snpanel` (and the links `snpanelctl`, `snpanel-cli`) | `/usr/local/sbin/` |
| `snpanel-helper`, `snpanel-install`, `snpanel-update`, `snpanel-rescue-firewall`, `snpanel-extract` | `/usr/local/sbin/` |
| The panel's server binary | `/usr/local/bin/snpanel-api-rust`, run by `snpanel-api.service` |
| Program, interface | `/opt/snpanel` |
| Configuration | `/opt/snpanel/backend/.env`, `/etc/snpanel/` |
| State | `/var/lib/snpanel/`, `/var/lib/snpanel-build/` (web-stack builds) |
| Backups | `/var/backups/snpanel/` |
| Websites | `/home/<user>/<domain>/public_html` |
| Services | `snpanel-api`, `snpanel-helper` (socket `/run/snpanel/helper.sock`), `snpanel-firewall` |

### Install log, and running it again

- The installer prints to the terminal and keeps no log file. To keep one:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash 2>&1 | tee /root/snpanel-install.log
  ```

  The admin password is written to the terminal itself, never to the output,
  so it is not in that log.
- When a step fails, fix what it says and **run the same command again**.
  Before the panel's `.env` exists (late in the install) it installs again;
  after that, the bootstrap runs the updater, which writes the panel's files
  again.
- After the install: `snpanel doctor`, and `journalctl -u snpanel-api` for the
  panel's own log.

---

## 3. First login

At the end the installer prints the panel's address and the user, `admin`.

- **Address:** `https://<your domain or the server's IP>:2222`. With a
  self-signed certificate the browser warns once.
- **User:** `admin`.
- **Password:** shown on the terminal only, and saved in `/root/login.txt`
  (mode 0600, root only).
- `snpanel login` prints the address, the user and the password again. It
  prints the password in clear: mind who can see your screen or your session
  log.
- **Two-step sign-in:** the account menu at the top right > **Account
  security** (passkey, authenticator app, or both).
- The panel answers on every domain hosted on the server, each with its own
  certificate: `https://<any hosted domain>:2222` opens it without a warning.
- With the Email addon, the webmail is at `https://<host>:2096`.

Then check the installation:

```bash
snpanel doctor
```

---

## 4. Update

### 4.1 From the panel

**Server > Updates** shows the installed and the newest release, and updates
with one button. The update runs on the server as the unit
`snpanel-panel-update.service`, so closing the browser does not stop it:

```bash
journalctl -u snpanel-panel-update.service -f
```

### 4.2 `snpanel update`

```bash
snpanel update                              # the newest stable release
snpanel update --release                    # the same, said explicitly
snpanel update --tag v2.0.0                 # one release
snpanel update --tag v2.0.1-rc.1            # a prerelease
SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # the same as --tag
```

| Option | Meaning |
|---|---|
| `--release` | The newest stable release (the default). |
| `--tag <TAG>` | One release: `vX.Y.Z`, or a prerelease such as `v2.0.0-rc.1`. |
| `--branch <BRANCH>` | The head of a branch of the source. Development only: the source repository is private. |

- The three options exclude each other. With none of them,
  `SNPANEL_VERSION` names the release, else the newest stable one.
- `snpanel update` asks `Update SNPanel to ... now? [y/N]` first. In a
  script, call `snpanel-update` instead, which does not ask.

### 4.3 `snpanel-update` (the updater itself)

```bash
snpanel-update                       # the newest stable release
snpanel-update --tag v2.0.0
SNPANEL_VERSION=v2.0.0 snpanel-update
snpanel-update --help
```

| Option | Meaning |
|---|---|
| `--release` | The newest stable release (the default). |
| `--tag TAG` | One release, or a prerelease. |
| `--branch NAME` | A branch of a git checkout of the source (needs access to the private repository). |
| `--channel MODE` | `release`, `tag` or `branch`. |
| `--remote NAME` | The git remote for `--branch` (default `origin`). |
| `--skip-pull` | Use `SOURCE_DIR` (an unpacked bundle or a checkout) as it is; fetch nothing. |
| `--app-dir DIR` | The installation (default `/opt/snpanel`). |
| `-h`, `--help` | The help. |

| Environment | Default | Meaning |
|---|---|---|
| `SNPANEL_VERSION` | - | Pins a release, as `--tag`, unless `--release`, `--tag` or `--branch` is given. |
| `SNPANEL_RELEASE_REPO` | `https://github.com/vnscorpion/snpanel-releases` | Where releases come from. Read from the environment only, never from the panel's `.env`. |
| `SNPANEL_UPDATE_JOB_WAIT` | `21600` (6 hours) | Seconds to wait for running jobs before the panel is restarted; `0` does not wait. |
| `SNPANEL_UPDATE_BUILD_WAIT` | `7200` (2 hours) | Seconds to wait for a running web-stack build job. |
| `SNPANEL_FORCE_FULL_UPDATE` | - | `1` runs every step again, even those whose inputs did not change. |
| `SNPANEL_HARDEN_USERNS` | - | `no` or `yes`: records the user-namespace choice ([6.8](#68-host-hardening-and-the-opt-out)). |
| `APP_DIR`, `SOURCE_DIR`, `REPO_URL`, `GIT_REMOTE`, `UPDATE_CHANNEL`, `BRANCH`, `RELEASE_TAG`, `SKIP_PULL` | | The same as the options above. |

### 4.4 Servers installed before v2.0.0

Their updater looks for releases in the panel's private source repository, so
their Updates page cannot see v2.0.0. Run the bootstrap once; it sees the
installation and updates it:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

From then on the Updates page, `snpanel update` and `snpanel-update` use the
release channel.

### 4.5 What an update does

1. Downloads the release bundle and checks its SHA-256, as the installer does.
2. Takes a snapshot of the panel's database:
   `/var/backups/snpanel/db-snapshots/snpanel-<UTC time>.db` (the newest ten
   are kept).
3. Waits for running jobs (below).
4. Puts the new program, interface and binaries in place, writes the panel's
   units and configuration again, applies the host hardening, restarts the
   panel, reloads the web server (LiteSpeed only with a valid licence) and
   checks that the panel answers.

If the browser still shows the old interface afterwards, reload with
Ctrl + Shift + R.

### 4.6 Running jobs

- **Web-stack build** (`snpanel build`): the update waits for it, up to
  `SNPANEL_UPDATE_BUILD_WAIT`, and stops with an error if it is still
  running. No build job can start while an update runs.
- **Restores, imports and transfers**: backup restores, cPanel and DirectAdmin
  imports, cPanel, DirectAdmin and FastPanel pulls, Incremental Backup
  restores, mailbox migrations, and WordPress Manager tasks that change a
  site (clone, push, roll-back). The update waits for them before it restarts
  the panel, up to `SNPANEL_UPDATE_JOB_WAIT`, showing it on the Updates page.
  After that time it goes ahead; a job it cut off is marked interrupted, and
  **Retry** runs it again.

### 4.7 Rollback

There is no rollback command.

- `snpanel update --tag <tag>` installs any release published in the release
  channel; v2.0.0 is the first one there.
- Each update leaves the database snapshot above.
- Take a VPS snapshot before an update you are unsure of.
- For the web server, see [6.7](#67-back-to-nginx-or-apache-only): it has its
  own way back.

---

## 5. The `snpanel` command

`snpanel` with no argument opens the rescue menu. Every command also answers
with a leading `--` (`snpanel --status`), as the old `snpanelctl` did, and
`snpanelctl` and `snpanel-cli` are links to `snpanel`.

| Command | What it does |
|---|---|
| `snpanel` / `snpanel menu` | The rescue menu ([8.1](#81-the-rescue-menu)). |
| `snpanel login` | The panel address, the user and the password from `/root/login.txt`. Alias: `show-login`. |
| `snpanel status` | The OS, panel port and URL, panel SSL, services and firewall. |
| `snpanel logs [-f] [-n N]` | The panel's journal: `-f` follows it, `-n` lines of history (default 200). |
| `snpanel restart` | Restarts the panel, then the stack's web server: nginx, or a safe reload of Apache and LiteSpeed ([8.2](#82-status-logs-and-restart)). |
| `snpanel repair-firewall` | Reopens the panel and SSH ports. |
| `snpanel update [--release \| --tag T \| --branch B]` | Updates the panel ([4.2](#42-snpanel-update)). |
| `snpanel change-ip [OLD_IP NEW_IP]` | The server's IP address changed. |
| `snpanel set-panel-url` | Sets the panel's domain and port again (asks). |
| `snpanel install-panel-ssl` | Issues or repairs the panel's own Let's Encrypt certificate (asks). |
| `snpanel fix-permissions` | Puts ownership and modes back across the panel and the sites. |
| `snpanel change-admin-password` | A new `admin` password (asks twice). |
| `snpanel sync-admin-root-password` | Makes the `admin` password root's. Aliases: `admin-use-root-password`. |
| `snpanel reset-admin-2fa` | Turns off the admin's two-step sign-in after a lost device. |
| `snpanel firewall status \| reopen \| rescue \| migrate-nft [--dry-run]` | Firewall maintenance ([8.4](#84-firewall)). |
| `snpanel build ...` | The web stack ([section 6](#6-web-stack-snpanel-build)). |
| `snpanel limits show <USER> \| resync` | Per-account CPU, memory and process limits ([8.7](#87-resource-limits-and-autossl)). |
| `snpanel autossl` | AutoSSL for every website now, and what it did. |
| `snpanel doctor [--json] [--isolation] [--enterprise-readiness]` | Diagnoses the server ([7.1](#71-snpanel-doctor)). |
| `snpanel --version`, `snpanel --help` | The version (`snpanel 2.0.0`) and the help. Every command takes `--help`. |

---

## 6. Web stack: `snpanel build`

A fresh SNPanel serves its websites with nginx and PHP-FPM. On AlmaLinux 10
(and Rocky Linux or RHEL 10) and Debian 13 (and 12) `snpanel build` moves a server to **LiteSpeed
Enterprise** with **Apache as a hot standby**, or to **Apache alone**, and
back to nginx - the way DirectAdmin's CustomBuild does it:

1. `snpanel build set ...` declares what the server should run, in
   `/etc/snpanel/build.conf`. It checks the value and installs nothing.
2. A build job (`all`, or one step) makes the server match the declaration.

The build refuses CloudLinux; those servers stay on nginx. (v2.0.0 refused
Debian, and v2.1.0 Ubuntu.) What Debian and Ubuntu do their own way under the
same commands is in [litespeed.md](litespeed.md#debian-13-what-differs) and
[litespeed.md](litespeed.md#ubuntu-2404-what-differs). The panel's
**Server > Web server & PHP** page does the same with buttons. A walkthrough
with more background is in [litespeed.md](litespeed.md).

### 6.1 How a build job runs

- It runs in a systemd unit of its own, `snpanel-build-<job>`, with the job's
  files in `/var/lib/snpanel-build/jobs/<job>/` (root only). Closing the SSH
  session, restarting the panel or a panel update does not stop it.
- One job at a time. A job refuses to start while a restore, import or backup
  job, or a panel update, is running, and says which.
- Job ids look like `bj-` and 12 letters or digits.
- Job states: `queued`, `running`, `completed`, `failed`, `cancelled`,
  `interrupted`. Step states: `pending`, `running`, `done`, `skipped`,
  `failed`.
- Every step is idempotent: it skips what is already done. A stopped job is
  run again from the step that stopped with `retry`.

### 6.2 Commands

| Command | Options | What it does |
|---|---|---|
| `snpanel build show` | | `build.conf`, and what the server runs: `Running: <webserver> with <php_mode>; <server> answers 80/443`. |
| `snpanel build set <KEY> <VALUE>` | | Changes one key of `build.conf` ([6.3](#63-buildconf-keys)). Installs nothing; WebAdmin's two keys are applied at once. |
| `snpanel build preview` | `--wait` | The preflight and the update step as a dry run: the plan, nothing changed. |
| `snpanel build update` | `--wait` | Package metadata, LiteSpeed's newest release, the pinned OWASP CRS. |
| `snpanel build webserver` | `--wait`, `--lsws-latest` | Apache (standby, 8080/8443) and LiteSpeed Enterprise (9080/9443), and the licence. |
| `snpanel build php` | `--wait` | lsphp for every PHP version, LiteSpeed's handlers, the pools. |
| `snpanel build waf` | `--wait` | ModSecurity and the rule set for Apache and LiteSpeed. |
| `snpanel build rewrite_confs` | `--wait` | Every website's vhost written again. Also `rewrite-confs`. |
| `snpanel build all` | `--wait`, `--accept-diffs`, `--lsws-latest`, `--remove-litespeed` | Every step, then the cutover: 80/443 to LiteSpeed (or Apache) and nginx removed; or, with `webserver = nginx`, back to nginx. |
| `snpanel build status [JOB]` | | The last jobs (id, kind, state, start time), or one job's steps, states and messages. |
| `snpanel build cancel <JOB>` | | Stops a job at its next safe point. During the cutover it goes back to nginx. |
| `snpanel build retry <JOB>` | `--wait`, `--accept-diffs` | Runs a stopped job again from the step that failed. |
| `snpanel build license` | | Stores LiteSpeed's serial number, read from standard input (one line). Never on the command line. |
| `snpanel build live` | | LiteSpeed stack only: who answers 80/443, both servers, the licence, the watchdog, auto-return, WebAdmin, the last switch. |
| `snpanel build switch <litespeed\|apache>` | | Moves 80/443 by hand. Back to LiteSpeed only when it answers and its licence is valid. |
| `snpanel build license-check` | | Checks LiteSpeed's licence now (a serial's key is fetched again). A licence that is not valid moves the sites to Apache. Also `licence-check`. |

Options:

- `--wait` follows the job and prints each step's log lines as they come,
  then its result; the exit code is 0 only for `completed`. Without it, the
  command prints the job id and returns.
- `--accept-diffs` goes on past differences the cutover's comparison does not
  know. It never goes past a site that would serve PHP source.
- `--lsws-latest` installs LiteSpeed's newest release even when the panel has
  no SHA-256 pinned for it; only LiteSpeed's own checksum is checked then. It
  prints a warning.
- `--remove-litespeed`, with `webserver = nginx`: removes LiteSpeed and Apache
  once nginx serves. Without it they are kept, stopped, for a quick return.

There is no `snpanel build log`: use `--wait`, `snpanel build status <job>`
or `journalctl -u snpanel-build-<job>`.

### 6.3 `build.conf` keys

`snpanel build set` takes these keys:

| Key | Values | Notes |
|---|---|---|
| `webserver` | `nginx`, `apache`, `litespeed` | `litespeed` keeps Apache as the standby. Setting it also sets `php_mode`. |
| `php_mode` | `php-fpm`, `lsphp` | `litespeed` needs `lsphp`; `nginx` and `apache` need `php-fpm`. |
| `php_versions` | e.g. `8.4,8.3` | Comma-separated; the first is the default. |
| `waf` | `modsecurity`, `off` | |
| `lsws_license` | `trial`, `serial` | |
| `lsws_auto_return` | `yes`, `no` | Read by the watchdog at once. |
| `lsws_admin` | `local`, `public` | Applied at once ([6.6](#66-litespeed-webadmin-port-7080)). |
| `lsws_admin_allow` | addresses or CIDR networks, comma-separated | Applied at once; empty allows every address. |

`build.conf` has one more key, **`harden_userns`** (`yes` or `no`). It is
root's choice and `snpanel build set` does not take it: see
[6.8](#68-host-hardening-and-the-opt-out).

What `set` answers:

```text
webserver = litespeed (nothing installed yet: run `snpanel build all` to build it)
lsws_license = trial (used by the webserver step and by `snpanel build license-check`)
lsws_auto_return = yes (applied: the watchdog reads it on its next look)
```

### 6.4 nginx to LiteSpeed Enterprise, step by step

**Before you start:**

- AlmaLinux 10 (or Rocky Linux or RHEL 10), Debian 13 (or 12) or Ubuntu
  24.04, not CloudLinux.
- 2 GB of RAM (see [Hardware](#hardware)); add a 2 GB swap file below 4 GB.
- 5 GB free on `/`.
- The server reaches `license.litespeedtech.com`.
- Nothing else listens on 8080/8443, 9080/9443 or 7080.
- Every PHP version a site uses is installed.
- No restore, import or backup job is running.
- A VPS snapshot.

**The licence: trial or serial.**

- **Trial:** about 14 days. LiteSpeed gives each IP address only two trials,
  ever. The webserver step asks for a trial key **only when the server has no
  LiteSpeed key at all**; with any key on the server - an expired one too -
  it never asks for another.
- **Serial:** a purchased LiteSpeed Enterprise licence, stored with
  `snpanel build license` before the build.

**1. Look at what runs now.**

```bash
snpanel build show
snpanel doctor
```

`show` ends with, on a fresh server:

```text
Running: nginx with php-fpm; nginx answers 80/443
```

**2. Declare LiteSpeed.**

```bash
snpanel build set webserver litespeed     # php_mode becomes lsphp by itself
snpanel build set lsws_license trial      # or serial, below
snpanel build set php_versions 8.4,8.3    # optional; the first is the default
snpanel build set lsws_auto_return yes    # the default
snpanel build show
```

With a serial instead of a trial:

```bash
snpanel build license                     # paste the serial, then Enter
snpanel build set lsws_license serial
```

`snpanel build license` asks for the serial and answers:

```text
LiteSpeed serial number:
Serial stored (root only). Set `lsws_license = serial` and run the webserver step to use it.
```

A serial is 8 to 64 letters, digits or `+ / = -`. It is kept in
`/var/lib/snpanel-build/` (root only).

**3. Preview (optional).**

```bash
snpanel build preview --wait
```

On a fresh AlmaLinux server the preview may say that phpMyAdmin would be
removed with nginx: Apache is not installed yet at that point. The cutover
asks the package manager again after Apache is installed, and phpMyAdmin
stays. If the cutover still lists packages that would go with nginx, the job
stops and asks; cancel it unless you mean to remove them.

**4. Build and cut over.**

```bash
snpanel build all --wait
```

Expected output (shortened):

```text
Build job bj-xxxxxxxxxxxx started (all).
[preflight] almalinux 10: supported
[preflight] RAM <n> MB, swap <n> MB, <n> MB free on /
...
[cutover] ...

Build job bj-xxxxxxxxxxxx: completed
  preflight      done       ...
  update         done       ...
  webserver      done       ...
  php            done       ...
  waf            done       ...
  rewrite_confs  done       ...
  cutover        done       ...
```

| Step | What it does |
|---|---|
| `preflight` | Checks everything in "Before you start". |
| `update` | Package metadata, LiteSpeed's newest release, the pinned OWASP CRS. |
| `webserver` | Apache as the standby on 8080/8443, LiteSpeed Enterprise on 9080/9443, the licence. |
| `php` | lsphp for every PHP version, LiteSpeed's handlers. |
| `waf` | ModSecurity and the rule set for Apache and LiteSpeed. |
| `rewrite_confs` | Every website's vhost written again. |
| `cutover` | Compares every site through the new stack with what nginx serves, moves 80/443 to LiteSpeed with no gap, and removes nginx last. |

On a 4-CPU VPS the whole job took about four minutes.

**If the job stops:**

```bash
snpanel build status bj-xxxxxxxxxxxx              # each step, its state and message
journalctl -u snpanel-build-bj-xxxxxxxxxxxx -f    # everything the job logs
snpanel build retry bj-xxxxxxxxxxxx --wait        # again from the step that stopped
snpanel build cancel bj-xxxxxxxxxxxx              # stop it (during the cutover: back to nginx)
```

When a site would answer differently on the new stack, the job stops with
`needs_accept` and prints the differences and
`To go on anyway: snpanel build retry bj-xxxxxxxxxxxx --accept-diffs`.
Run that only when the differences are expected.

You can also run the steps one by one (`update`, `webserver`, `php`, `waf`,
`rewrite_confs`, each with `--wait`). Only `all` moves 80/443; after the
separate steps, `all` finishes the rest.

**5. Check.**

```bash
snpanel build live
snpanel doctor                                     # web-stack, web-live, webwatch, lsws-licence, web-table: ok
curl -sI http://<a site>/ | grep -i '^server'      # Server: LiteSpeed
snpanel doctor --isolation                         # no customer reaches another's home
```

`snpanel build live` prints, for example:

```text
80/443:      LiteSpeed
LiteSpeed:   running, answering (6.3.7)
Apache:      running, answering
Licence:     trial ok, 8 day(s) left (ends 2026-10-27) - [OK] Your trial license key will expire in 8 days!
  checked    2026-10-19T00:10:43Z
Watchdog:    running (snpanel-webwatch)
Auto-return: yes (back to LiteSpeed once its licence is valid again)
WebAdmin:    local (listening on 127.0.0.1:7080)
Last switch: apache -> lsws at 2026-10-15T03:49:04Z (back to LiteSpeed)
```

After the cutover: LiteSpeed serves 80/443; Apache runs on 8080/8443 as the
standby; nginx is removed; every customer's home is 0750 with the web
servers in the customer's group; phpMyAdmin and the panel's tools vhost are
served by Apache/LiteSpeed.

### 6.5 The watchdog, auto-return and the licence

`snpanel-webwatch.service` watches LiteSpeed:

- It probes LiteSpeed every second. After three failed probes it moves
  80/443 to Apache, within seconds. If Apache does not answer either, it
  restarts Apache once.
- It checks the licence every 5 minutes. A licence that is not valid moves
  the sites to Apache, and LiteSpeed is never restarted or reloaded with it
  (a reload with a bad key stops LiteSpeed).
- **Auto-return** (`lsws_auto_return = yes`): after a failover the sites go
  back to LiteSpeed once its licence checks valid, it has answered for
  5 minutes, and 10 minutes have passed since the last switch.
- Notifications (addon) tell administrators of each failover and return, a
  licence that ends in 7, 3 or 1 days, and an expired one.

By hand:

```bash
snpanel build switch apache              # 80/443 to Apache now
snpanel build switch litespeed           # back; only if LiteSpeed answers and its licence is valid
snpanel build set lsws_auto_return no    # stay on Apache until you switch back
snpanel build license-check              # check the licence now
```

**When the trial or licence expires:**

1. Within 5 minutes the watchdog moves 80/443 to Apache. The sites keep
   working on Apache with the same vhosts and PHP.
2. LiteSpeed is not reloaded.
3. To come back to LiteSpeed, install a serial:

   ```bash
   snpanel build license                    # paste the serial
   snpanel build set lsws_license serial
   snpanel build license-check              # registers the serial and checks it
   ```

   Auto-return brings the sites back; without it, run
   `snpanel build switch litespeed`.
4. Or go back to nginx ([6.7](#67-back-to-nginx-or-apache-only)).

No new trial is asked for while any key is on the server.

### 6.6 LiteSpeed WebAdmin (port 7080)

**Local (the default).** WebAdmin listens on 127.0.0.1 only. Reach it with an
SSH tunnel:

```bash
ssh -L 7080:127.0.0.1:7080 root@<server>
# then open https://127.0.0.1:7080 in your browser; user: admin
cat /var/lib/snpanel-build/lsws-webadmin-password    # root only
```

**Password reset.** The **Web server & PHP** page sets a new WebAdmin password
and shows it once. Over SSH:

```bash
snpanel-helper lsws-admin-password    # prints the user (admin) and the new password once, as JSON
```

The new password is also written to `/var/lib/snpanel-build/lsws-webadmin-password`.
It is printed on your terminal: clear the screen afterwards.

**Public, with an allowlist.**

```bash
snpanel build set lsws_admin_allow 203.0.113.5,198.51.100.0/24
snpanel build set lsws_admin public      # applied at once, kept by every build and update
snpanel build set lsws_admin local       # back to the loopback
```

Each answers what really happened, for example
`lsws_admin = public (applied: WebAdmin listens on *:7080)`, or that the
change waits for LiteSpeed's next start. Public mode opens 7080 in the
panel's firewall and serves WebAdmin over TLS; an empty `lsws_admin_allow`
allows every address. Going back to `local` removes the firewall rule the
panel added.

The panel manages LiteSpeed's configuration: changes made in WebAdmin to what
the panel writes are overwritten by the next build or update.

### 6.7 Back to nginx, or Apache only

```bash
snpanel build set webserver nginx
snpanel build all --wait                      # nginx serves again; LiteSpeed and Apache are kept, stopped
snpanel build all --remove-litespeed --wait   # the same, and LiteSpeed and Apache are removed
```

- After `--remove-litespeed` the licence key is kept aside, so a later return
  to LiteSpeed reuses it and does not ask for a new trial.
- **Apache only**, with PHP-FPM:

  ```bash
  snpanel build set webserver apache          # php_mode becomes php-fpm
  snpanel build all --wait
  ```

### 6.8 Host hardening and the opt-out

Every install and update writes `/etc/sysctl.d/90-snpanel-hardening.conf` and
applies it at once (no reboot):

- No user namespaces. On AlmaLinux `user.max_user_namespaces = 0`, after the
  services that need one get a drop-in or keep the setting off (`snpanel
  doctor` names them). Debian uses `kernel.unprivileged_userns_clone = 0`;
  Ubuntu keeps `kernel.apparmor_restrict_unprivileged_userns = 1`.
- `dev.tty.legacy_tiocsti = 0` (kernel 6.2 and later).

To keep user namespaces as the distribution has them (rootless containers, a
Chrome sandbox):

```bash
SNPANEL_HARDEN_USERNS=no snpanel-helper host-harden    # records harden_userns = no in build.conf, and applies it
SNPANEL_HARDEN_USERNS=yes snpanel-helper host-harden   # back to the hardening
```

`no`, `off`, `false` and `0` opt out. You can also put `harden_userns = no` in
`/etc/snpanel/build.conf` and run `snpanel-helper host-harden`, or set the
variable for `install.sh` or `snpanel-update`. Every later update keeps the
choice. The panel's `.env` is not read for this.

---

## 7. Diagnostics and logs

### 7.1 `snpanel doctor`

```bash
snpanel doctor                          # every check
snpanel doctor --json                   # the same, as JSON
snpanel doctor --isolation              # only: customers cannot reach into each other's homes
snpanel doctor --enterprise-readiness   # only: could this machine move to CloudLinux (read-only, no licence needed)
```

- Every check is read-only; `doctor` repairs nothing.
- It covers the OS and CPU, the panel's configuration and secret key, the
  firewall, SELinux, phpMyAdmin, the web stack (`web-stack`, `web-live`,
  `web-table`, `webwatch`, `lsws-licence`), the isolation between accounts,
  the panel's paths and file modes, resource limits, the Terminal's jail,
  Valkey, the host hardening and the lsphp extensions the panel built
  (`lsphp-extensions`: one that does not load, one built for another PHP
  API, FFI not preload-only).
- Each finding is `ok`, `note`, `warn` or `FAIL`, with what to do next.
- **Exit code:** 0 when nothing is wrong, 1 with warnings, 2 with failures, so
  it fits a monitoring check.
- `--isolation` checks, as each customer, that `stat /home/<other>/.` fails.
- `--enterprise-readiness` checks AlmaLinux 10, an x86-64-v3 CPU, no
  container, RAM and disk: what the Hosting Edition's
  `installer/hosting/upgrade-cloudlinux.sh` needs to convert the server to
  CloudLinux (see `installer/hosting/README.md`).

### 7.2 Other quick checks

```bash
snpanel status                 # OS, panel port/URL/SSL, services, firewall
snpanel logs -n 100            # the panel's journal
snpanel firewall status        # the firewall's state and rules
snpanel build live             # LiteSpeed stack: who serves 80/443, the licence
```

### 7.3 Where the logs are

| What | Where |
|---|---|
| The panel | `journalctl -u snpanel-api` (or `snpanel logs`) |
| The root helper | `journalctl -u snpanel-helper`; audit trail: `journalctl -t snpanel-helper` (e.g. `journalctl -t snpanel-helper F_OP=firewall-deny-ip`) |
| Panel updates | `journalctl -u snpanel-panel-update.service`; the Updates page |
| Web-stack builds | `snpanel build status <job>`, `journalctl -u snpanel-build-<job>` |
| LiteSpeed watchdog | `journalctl -u snpanel-webwatch`; the switches: `/var/log/snpanel-webswitch.log` |
| nginx | `/var/log/nginx/`; a site: `/var/log/nginx/<domain>.access.log`, `<domain>.error.log` |
| Apache and LiteSpeed sites | AlmaLinux: `/var/log/httpd/<domain>.access.log`, `<domain>.error.log`; Debian/Ubuntu: `/var/log/apache2/` |
| LiteSpeed itself | `/usr/local/lsws/logs/` |
| Exim (Email addon) | AlmaLinux: `/var/log/exim/`; Debian/Ubuntu: `/var/log/exim4/`; the Email page's Delivery log |
| Dovecot (Email addon) | `journalctl -u dovecot` |
| Rspamd, webmail | `journalctl -u rspamd`, `journalctl -u snpanel-webmail` |
| Mail for root and system accounts | `/var/log/snpanel-mail/system-mail.log` |
| Fail2ban (addon) | `/var/log/fail2ban.log` |
| MariaDB | `journalctl -u mariadb` |
| An account's PHP-FPM | `journalctl -u snpanel-php-fpm-<user>-<version>` |
| The firewall | `nft list table inet snpanel`; rules: `/var/lib/snpanel-firewall/rules.tsv` |

### 7.4 Common problems

| Problem | What to do |
|---|---|
| The panel does not load | `snpanel status`, `snpanel logs -n 100`, `snpanel restart`. |
| Locked out by the firewall (from the console) | `snpanel repair-firewall`; still locked out: `snpanel-rescue-firewall` ([8.4](#84-firewall)). |
| Admin password forgotten | `snpanel login`, or `snpanel change-admin-password`. |
| Authenticator app or passkey lost | `snpanel reset-admin-2fa`. |
| The server's IP address changed | `snpanel change-ip OLD_IP NEW_IP`, then `snpanel doctor`. |
| The panel's certificate expired or is wrong | `snpanel install-panel-ssl`. |
| Files owned by root after a manual copy | `snpanel fix-permissions`. |
| The old interface after an update | Reload with Ctrl + Shift + R. |
| The Updates page cannot see v2.0.0 | Installed before v2.0.0: run the bootstrap once ([4.4](#44-servers-installed-before-v200)). |
| A build job stopped | `snpanel build status <job>`, fix the cause, `snpanel build retry <job> --wait`. |
| LiteSpeed licence expired | The sites are already on Apache; see [6.5](#65-the-watchdog-auto-return-and-the-licence). |
| Dovecot or Exim stopped after a distribution upgrade (Email addon) | `snpanel-helper mail-reconfigure`, or the next panel update. |
| A service needs a user namespace and will not start | `snpanel doctor` names it; see [6.8](#68-host-hardening-and-the-opt-out). |

---

## 8. Rescue and day-to-day administration

### 8.1 The rescue menu

`snpanel` (or `snpanel menu`) opens it in a terminal:

```text
SNPanel SSH Rescue Menu
1) Show login info
2) Show rescue status
3) View recent logs
4) Restart panel services
5) Repair firewall ports
6) Set/reset panel URL / port
7) Install/repair panel SSL
8) Fix permissions/runtime
9) Change admin password
10) Update panel from release
11) Change server IP
12) Sync admin password from root
0) Exit
```

Each entry is the command of the same name in [section 5](#5-the-snpanel-command).
Without a terminal it prints the menu and stops.

### 8.2 Status, logs and restart

```bash
snpanel status
snpanel logs                 # the last 200 lines
snpanel logs -n 50 -f        # 50 lines, then follow
snpanel restart              # the panel, then the stack's web server
```

`snpanel restart` restarts the panel, then the web server the record says
(`snpanel build show`):

- **nginx stack:** `systemctl restart nginx`.
- **LiteSpeed and Apache stacks:** the helper's `web-reload` - the
  configuration tested, Apache reloaded (a stopped standby stays stopped),
  LiteSpeed reloaded only when its licence checks valid, so a bad licence
  never takes it down. Which server answers 80/443 is the watchdog's:
  `snpanel build live`, `snpanel build switch`.
- A unit that is not installed is skipped and said so.

Before v2.1, `snpanel restart` always restarted nginx and stopped with
`restarting nginx failed` on these stacks (the panel was restarted all the
same).

### 8.3 Admin password and two-step sign-in

```bash
snpanel login                       # address, user, password (/root/login.txt)
snpanel change-admin-password       # asks twice; updates /root/login.txt; signs every session out
snpanel sync-admin-root-password    # admin (panel and Linux) takes root's password hash
snpanel reset-admin-2fa             # authenticator app and every passkey off
```

- No password ever goes on a command line: they are typed at a prompt.
- `sync-admin-root-password` cannot read root's password back from its hash;
  it asks you to type it if you want it written to `/root/login.txt` (blank
  skips).

### 8.4 Firewall

The panel's firewall is the nftables table `inet snpanel`, with its rules in
`/var/lib/snpanel-firewall/rules.tsv`. The SSH port, the panel port and 80,
443, 465 and 587 are always open.

```bash
snpanel firewall status             # state and rules
snpanel repair-firewall             # reopen the panel and SSH ports (also: snpanel firewall reopen)
snpanel firewall rescue             # drop the panel's nftables table: no panel filtering until it is applied again
snpanel firewall migrate-nft --dry-run   # print the nftables ruleset the panel loads, from rules.tsv
snpanel firewall migrate-nft             # load it (through the helper) and remove the old iptables chain
snpanel-rescue-firewall             # last resort, see below
```

- `repair-firewall` / `firewall reopen` rebuild the table, adding a rule for
  an SSH port other than 22.
- `firewall rescue` deletes the panel's table only; other tables (Docker,
  fail2ban) stay. The firewall comes back at the next change, at boot, or
  with `snpanel repair-firewall`.
- `firewall migrate-nft` is for a server that still filters with the old
  iptables/ipset backend (`snpanel doctor` says so when the old
  `SNPANEL-INPUT` chain is still loaded). It rebuilds the rules from
  `rules.tsv` in nftables through the helper, and removes the old chain only
  once the new ruleset is live. Every update already moves such a server to
  nftables by itself, and `snpanel repair-firewall` loads the same ruleset.
  (In v2.0.0, `migrate-nft` without `--dry-run` refused.) The iptables and
  ipset tools themselves stay installed on Debian: the update uses them to
  read an old UFW setup, and Docker needs them.
- **`snpanel-rescue-firewall`** saves the current state to
  `/root/snpanel-firewall-rescue-<time>/` (with a copy of `rules.tsv`),
  removes UFW, the old iptables chain and ipsets and the panel's table,
  **empties the panel's allow and deny rules** and the downloaded blocklist
  addresses, and rebuilds the firewall with the protected ports only (SSH,
  the panel port, 80, 443, 465, 587). The blocklist URLs stay and are fetched
  again by their daily timer. Add your rules back from the Firewall page
  afterwards.

### 8.5 Panel address, certificate and IP address

```bash
snpanel set-panel-url              # asks the domain (blank: the server's IP) and the port
snpanel install-panel-ssl          # asks the domain and the Let's Encrypt e-mail
snpanel change-ip                  # asks the old and new address
snpanel change-ip 203.0.113.10 203.0.113.20
```

- `install-panel-ssl` issues through the web server's webroot: no website
  goes down while it runs.
- `change-ip` rewrites the address in the panel's `.env`, nginx's
  configuration, phpMyAdmin, the panel's systemd units and `/etc/hosts`,
  copying every file to a backup first. Run `snpanel doctor` afterwards.

### 8.6 Permissions

```bash
snpanel fix-permissions
```

Puts the panel's and the sites' ownership and modes back the way the
installer left them, and the SFTP block in `sshd_config` (checked with
`sshd -t`, put back if it does not pass). Safe to run when nothing is wrong.

### 8.7 Resource limits and AutoSSL

```bash
snpanel limits show alice    # the account's slice, what the panel applied, its PHP-FPM masters
snpanel limits resync        # apply every account's limits again from the database
snpanel autossl              # every website now: issue where the domain points here, renew what is due
```

Paused websites stay paused in AutoSSL.

### 8.8 What has no command

Users, packages, websites, databases, backups and restores, cron jobs,
addons, mail, DNS, WordPress and the WAF are managed **in the panel**. The
`snpanel` command has no subcommands for them. For automation there are:

- the provisioning API used by the WHMCS module (an API token from
  **Settings > Panel settings > API tokens**);
- the MCP server addon, for AI assistants.

---

## 9. `snpanel-helper` operations for administrators

`snpanel-helper` is the panel's root helper. The panel calls it over
`/run/snpanel/helper.sock`; root can run one operation directly with
`snpanel-helper <operation>`. `snpanel-helper --help` lists all of them
(298 in v2.1.0). Most are the panel's own work: run only these by hand.

| Command | What it does |
|---|---|
| `snpanel-helper host-harden` | Applies the host hardening again ([6.8](#68-host-hardening-and-the-opt-out)). |
| `snpanel-helper php-fpm-retune` | Sizes every PHP-FPM pool again from RAM, CPU and the `SNPANEL_PHP_FPM_*` settings in `.env`. |
| `snpanel-helper mariadb-retune` | Writes MariaDB's tuning file again from RAM and CPU and the `SNPANEL_MARIADB_*` settings; **restarts MariaDB**. |
| `snpanel-helper lsws-admin-password` | A new LiteSpeed WebAdmin password, printed once ([6.6](#66-litespeed-webadmin-port-7080)). |
| `snpanel-helper mail-reconfigure` | Writes Dovecot's and Exim's files and the webmail again for this release (Email addon). |
| `snpanel-helper clamav-db-status` | The malware signature database in use, as JSON (Malware Scanner addon). |
| `snpanel-helper malware-sigs-update` | Updates ClamAV's and LMD's signatures now (Malware Scanner addon). |
| `snpanel-helper lsphp-ext-status [<version>]` | The lsphp extensions the panel builds on Debian's LiteSpeed lsphp (ffi, shmop, mcrypt; imap where LiteSpeed packages it), as JSON: with a version, each one's source, whether lsphp loads it and its build's record; without, the records ([litespeed.md](litespeed.md#lsphp-extensions-litespeed-does-not-package)). |
| `snpanel-helper lsphp-ext-build <version> <ext>` | Builds one from verified, signed source in a sandbox (or installs LiteSpeed's package) and enables it, in a unit of its own (`snpanel-lsext-<job>`). Refused on AlmaLinux (Remi's packages) and for imap on Debian 13 (not offered). |
| `snpanel-helper lsphp-ext-log <version> <ext>` | The last build's log. |
| `snpanel-helper lsphp-ext-remove <version> <ext>` | Takes the module and its ini away (or LiteSpeed's package); it is not built again. lsphp restarts gracefully. |
| `snpanel-helper lsphp-ext-check` | Each built extension against lsphp as it is now: FFI and shmop built again when lsphp moves to another PHP release (a patch release too), every extension when the PHP API changed. The panel runs it daily and after an update. |
| `snpanel-helper lsphp-ext-tools-remove` | Removes the build tools the panel installed (never a library a built module loads); a later build installs them again. |

Every call is recorded: `journalctl -t snpanel-helper`.

`snpanel-install` is the installer's phase runner, called by the install and
update scripts; it is not meant to be run by hand.

---

## 10. Addons and where they are in the panel

Addons are installed and uninstalled from **Settings > Addons** (also
**Dashboard > Extensions > Manage addons**). Uninstalling an addon never
deletes its data. None of them has a command of its own; the menus below are
the administrator's.

| Addon | What it does | Where in the panel |
|---|---|---|
| Email | Mailboxes and forwarders with Exim, Dovecot and Rspamd; webmail | Dashboard > Email (Mailboxes, Forwarders, Delivery log, SMTP relay, Mail app settings); Webmail at `https://<host>:2096` |
| DNS Manager | PowerDNS for the websites' domains | Dashboard > Websites and domains > DNS |
| WordPress Manager | WP-CLI toolkit: updates, security, sign-in, staging, restore points | Sidebar > WordPress Manager |
| Incremental Backup | restic backups to a disk, SFTP or S3; customers restore their own | Dashboard > Files and backups > Incremental Backup; customers: Backup & Restore > Incremental Backup |
| cPanel Import | Accounts from cPanel backups, or pulled from a cPanel server | Dashboard > Migration > cPanel Import |
| DirectAdmin Import | Users from DirectAdmin backups, or pulled from a DirectAdmin server | Dashboard > Migration > DirectAdmin Import |
| FastPanel Import | Users pulled from a FASTPANEL server | Dashboard > Migration > FastPanel Import |
| Fail2ban | Bans addresses that keep failing to sign in | Security > Fail2ban |
| Malware Scanner | ClamAV and Linux Malware Detect, quarantine | Security > Malware Scanner |
| MCP server | AI assistants (Claude Code, Cursor, VS Code) through `/api/mcp` | Dashboard > Advanced > AI assistants |
| Notifications | E-mail and Telegram alerts for administrators | Settings > Notifications |
| Application | Node.js apps, Docker containers and Compose projects | Dashboard > Websites and domains > Applications |

**CloudLinux** is not an addon. The **CloudLinux Manager** page (and the
customers' Resource usage and PHP version pages) appear only on a CloudLinux
server, which these commands do not set up.

---

## 11. Uninstall

There is no uninstall command in v2.0.0. SNPanel changes the firewall, sshd,
kernel settings, PHP, MariaDB and the web server, so the clean way back is a
fresh operating system (or the VPS snapshot taken before the install).
Addons can be removed from **Settings > Addons**; their data is kept.

---

## 12. Security notes

**Where the secrets are** (none of them is ever shown again by the panel):

| File | Holds | Readable by |
|---|---|---|
| `/root/login.txt` | the `admin` password | root (0600) |
| `/opt/snpanel/backend/.env` | `SECRET_KEY` and the panel's settings | root and the panel's account (0640) |
| `/opt/snpanel/.my.cnf` | the panel's MariaDB credentials | the panel's account (0600) |
| `/etc/snpanel/` | the panel's certificates, `build.conf` | root and the panel's group |
| `/var/lib/snpanel-build/` | LiteSpeed's serial, WebAdmin's password, build jobs | root only (0700) |

- Database passwords are encrypted at rest with the `SECRET_KEY`.
- The panel runs as the `snpanel` user, not root; privileged work goes through
  `snpanel-helper`, which checks its caller and every argument, and logs every
  call.
- Commands that take a secret read it from a prompt or standard input
  (`snpanel build license`, `change-admin-password`), never from the command
  line, where any local user could read it.
- **The Terminal** (a real bash in a per-account jail) is **off** for new
  customers unless their package enables it.
- **The release channel.** Releases come only from
  [vnscorpion/snpanel-releases](https://github.com/vnscorpion/snpanel-releases).
  The bootstrap and every update check the bundle against the `SHA256SUMS`
  published with it before unpacking it, and refuse a bundle without one.
  `SNPANEL_RELEASE_REPO` is read from the environment only, never from the
  panel's `.env`.

To check a bundle yourself:

```bash
tag=v2.0.0
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/snpanel-$tag-x86_64-linux.tar.gz
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/SHA256SUMS
sha256sum -c SHA256SUMS
```
