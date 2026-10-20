# Nhật ký thay đổi / Changelog

Tiếng Việt trước, English below.

## v2.1.0

Chưa phát hành (bản thử nghiệm `v2.1.0-rc.N`) / Unreleased (release candidates `v2.1.0-rc.N`).

### Tiếng Việt

**Debian 13: LiteSpeed Enterprise và Apache qua `snpanel build`**

- `snpanel build` chạy trên Debian 13 như trên AlmaLinux 10:
  - nginx → LiteSpeed Enterprise, Apache dự phòng nóng, watchdog tự chuyển và tự quay về;
  - nginx → chỉ Apache (PHP-FPM);
  - quay về nginx từ cả hai.
  - Debian 12 dùng cùng đường code nhưng chưa được thử trên máy thật. Ubuntu vẫn bị từ chối.
- Apache là gói `apache2`:
  - module bật bằng `a2enmod` (ssl, http2, proxy, proxy_fcgi, rewrite, headers, security2, expires, setenvif ...);
  - `ports.conf` của panel chỉ có 8080/8443;
  - site và conf mặc định của Debian (000-default, phpmyadmin.conf ...) thành file chỉ có chú thích;
  - `www-data` nằm trong nhóm của từng khách hàng khi home được cách ly (0750).
- lsphp từ kho apt của LiteSpeed, khoá ký kèm theo panel và ghim SHA-256; mỗi phiên bản PHP là gói `lsphpXY`.
  - Phần mở rộng của PHP-FPM được ánh xạ sang `lsphpXY-*`. LiteSpeed không đóng gói FFI, shmop và mcrypt: job ghi lại các chỗ thiếu này, và panel build được chúng (xem dưới).
  - `php.ini` của lsphp nhận các thiết lập của panel; các file ini của panel (OPcache ...) được liên kết vào thư mục quét của lsphp, cả khi trang PHP ghi file đó sau khi build.
  - Mỗi tên miền một phiên bản PHP, chạy bằng user của khách hàng (suEXEC), đã kiểm trên máy thật.
- WAF: `libapache2-mod-security2` với OWASP CRS 4.29 ghim; LiteSpeed đọc cùng bộ luật.
- nginx được gỡ (remove, không purge: giữ `/etc/nginx` để quay về). Gói certbot cho nginx đi cùng nginx mà không hỏi lại.
- Một trial key đặt sẵn ở `/usr/local/lsws/conf/trial.key` trước lần cài LiteSpeed đầu tiên được dùng lại, không xin trial mới (máy cài lại mà IP đã có trial).

**Extension lsphp mà LiteSpeed không đóng gói (Debian)**

- Trang PHP của máy chạy LiteSpeed có thẻ *lsphp X.Y: extension LiteSpeed không đóng gói*: FFI, shmop và mcrypt được build cho lsphp với nút **Build và bật**, theo dõi tiến trình và nhật ký build, và **Gỡ**. IMAP: gói `lsphpXY-imap` của LiteSpeed trên Debian 12; trên Debian 13 không có (thư viện c-client đã bị bỏ và không ai bảo trì).
- Mã nguồn được kiểm tra trước khi dùng: tarball PHP đúng phiên bản của lsphp từ php.net, SHA-256 lấy từ danh sách phát hành của php.net qua HTTPS; mcrypt là PECL 1.0.9 với SHA-256 ghim trong panel.
- Không biên dịch bằng root: giải nén, `phpize`, `configure`, `make` và lần nạp thử chạy bằng tài khoản `snpanel-extbuild` trong sandbox systemd (không mạng, không capability, hệ thống chỉ đọc, ưu tiên thấp, `-j1` trên máy RAM nhỏ). Root chỉ cài tệp `.so` sau khi kiểm tra đó là ELF shared object.
- FFI mặc định `ffi.enable=preload`: script của website không gọi được hàm C.
- Giữ qua các lần nâng cấp lsphp: bản ghi PHP API của từng lần build; kiểm tra mỗi ngày, sau khi cập nhật panel, trong bước php của `snpanel build` và sau cập nhật hệ điều hành; build lại khi PHP API đổi. Lỗi hiện ở chuông thông báo, gửi qua addon Thông báo và `snpanel doctor` (`lsphp-extensions`).
- Lệnh mới: `snpanel-helper lsphp-ext-status|build|remove|log|check`. AlmaLinux không đổi: lsphp của Remi đã có các gói này.

**Sửa lỗi tìm thấy trên Debian 13**

- Bộ lọc thư (Sieve): kiểm tra bằng `sievec` không chạy được với Dovecot 2.4, nên mọi bộ lọc bị từ chối.
- Chuyển hộp thư qua IMAP (`doveadm imapc`): cấu hình cho Dovecot 2.4 sai thứ tự và dùng tên tính năng của 2.3.
- ModSecurity cho Apache: file `unicode.mapping` được ghi đường dẫn tuyệt đối (trước đó `apache2ctl -t` từ chối).
- Thư của `exim4-base` (dọn dẹp hằng ngày của Debian) không còn bị dừng giữa chừng khi dịch vụ kết thúc ("Failed writing transport results to pipe" trong paniclog, cảnh báo paniclog lặp lại mỗi ngày).
- File include tuỳ chỉnh của nginx và luật WAF riêng của site mới được ghi 0640; thư mục `/etc/nginx/snpanel/custom` giữ 2770 sau mỗi lần cập nhật (`snpanel doctor` không còn cảnh báo web-file-modes).
- Trên stack Apache/LiteSpeed, các file luật WAF riêng của site mới (`rules.conf` ...) cũng được ghi 0640, nhóm của panel, ngay khi tạo site (trước đây 0644 cho đến lần cập nhật sau).

**Lệnh**

- `snpanel restart` khởi động lại web server của stack đang chạy: nginx, hoặc reload an toàn Apache và LiteSpeed. Trước đây lệnh luôn gọi nginx và báo lỗi trên stack LiteSpeed/Apache.
- `snpanel firewall migrate-nft` (không kèm `--dry-run`) nạp bộ luật qua helper thay vì từ chối.
- `snpanel doctor` chỉ báo về iptables khi chain cũ `SNPANEL-INPUT` còn được nạp.
- Thông báo về CloudLinux chỉ đúng script `installer/hosting/upgrade-cloudlinux.sh`.

**Giới hạn đã biết**

- Ubuntu 24.04: `snpanel build` vẫn chưa mở.
- Debian 12: cùng đường code với Debian 13 nhưng chưa thử trên máy thật.
- Trên Debian, Valkey của panel là gói `redis-server` (Redis 8.0) của Debian.

### English

**Debian 13: LiteSpeed Enterprise and Apache through `snpanel build`**

- `snpanel build` runs on Debian 13 as it does on AlmaLinux 10:
  - nginx → LiteSpeed Enterprise, with Apache as the hot standby and the watchdog's failover and automatic return;
  - nginx → Apache alone (PHP-FPM);
  - back to nginx from either.
  - Debian 12 takes the same code path but has not been tested on a real server. Ubuntu is still refused.
- Apache is the `apache2` package:
  - modules switched on with `a2enmod` (ssl, http2, proxy, proxy_fcgi, rewrite, headers, security2, expires, setenvif ...);
  - the panel's `ports.conf` listens on 8080/8443 only;
  - Debian's stock sites and snippets (000-default, phpmyadmin.conf ...) become comment-only files;
  - `www-data` is in each customer's group once the homes are isolated (0750).
- lsphp comes from LiteSpeed's apt repository, its signing key shipped with the panel and pinned by SHA-256; each PHP version is an `lsphpXY` package.
  - PHP-FPM's extensions are mapped onto `lsphpXY-*` packages. LiteSpeed packages no FFI, shmop or mcrypt: the job records these gaps, and the panel can build them (below).
  - lsphp's `php.ini` gets the panel's settings, and the panel's ini files (OPcache ...) are linked into lsphp's scan directory, also when the PHP pages write one after the build.
  - A PHP version per domain, run as the customer (suEXEC), checked on a real server.
- WAF: `libapache2-mod-security2` with the pinned OWASP CRS 4.29; LiteSpeed reads the same rules.
- nginx is removed (not purged: `/etc/nginx` stays for the way back). certbot's nginx plugin goes with it without a question.
- A trial key put in `/usr/local/lsws/conf/trial.key` before LiteSpeed's first install is used instead of asking for a new trial (a reinstalled server whose IP already has one).

**lsphp extensions LiteSpeed does not package (Debian)**

- The PHP page of a LiteSpeed server has a card, *lsphp X.Y: extensions LiteSpeed does not package*: FFI, shmop and mcrypt are built for lsphp with **Build and enable**, followed with their progress and build log, and **Remove**. IMAP: LiteSpeed's `lsphpXY-imap` package on Debian 12; not offered on Debian 13 (its c-client library was dropped and nobody maintains it).
- The source is verified before use: the PHP tarball of exactly lsphp's release from php.net, its SHA-256 from php.net's release list over HTTPS; mcrypt is PECL 1.0.9 with its SHA-256 pinned in the panel.
- Never compiled as root: unpacking, `phpize`, `configure`, `make` and a test load run as the `snpanel-extbuild` account in a systemd sandbox (no network, no capabilities, a read-only system, low priority, `-j1` on a small server). Root only installs the `.so` after checking it is an ELF shared object.
- FFI defaults to `ffi.enable=preload`: a website's own scripts cannot call C functions.
- Kept across lsphp's upgrades: each build's PHP API is recorded; a check daily, after a panel update, in `snpanel build`'s php step and after an OS update builds again when the API changed. Failures show in the bell, through the Notifications addon and in `snpanel doctor` (`lsphp-extensions`).
- New commands: `snpanel-helper lsphp-ext-status|build|remove|log|check`. AlmaLinux is unchanged: Remi's lsphp has these packages.

**Fixes found on Debian 13**

- Mail filters (Sieve): the `sievec` check could not start on Dovecot 2.4, so every filter was refused.
- IMAP mailbox migration (`doveadm imapc`): the configuration for Dovecot 2.4 had its version setting in the wrong place and used 2.3's feature names.
- ModSecurity for Apache: `unicode.mapping` is named by its absolute path (`apache2ctl -t` refused the relative one).
- The mail Debian's daily `exim4-base` housekeeping sends is no longer cut off when the service ends ("Failed writing transport results to pipe" in the paniclog, and a paniclog alert that came back every day).
- A new site's nginx custom include and WAF rules are written 0640, and `/etc/nginx/snpanel/custom` stays 2770 across updates (`snpanel doctor` no longer warns about web-file-modes).
- On the Apache and LiteSpeed stack a new site's WAF rule files (`rules.conf` ...) are written 0640 to the panel's group too, when the site is made (they were 0644 until the next update).

**Commands**

- `snpanel restart` restarts the running stack's web server: nginx, or a safe reload of Apache and LiteSpeed. It used to always ask for nginx and fail on the LiteSpeed and Apache stacks.
- `snpanel firewall migrate-nft` (without `--dry-run`) loads the ruleset through the helper instead of refusing.
- `snpanel doctor` mentions iptables only when the old `SNPANEL-INPUT` chain is still loaded.
- The CloudLinux messages name the real script, `installer/hosting/upgrade-cloudlinux.sh`.

**Known limits**

- Ubuntu 24.04: `snpanel build` is not open yet.
- Debian 12: the same code path as Debian 13, not tested on a real server.
- On Debian the panel's Valkey is Debian's `redis-server` package (Redis 8.0).

## v2.0.0

Phát hành 19/10/2026 / Released 2026-10-19.

SNPanel 2.0.0 là bản lớn đầu tiên sau 1.1.0 (27/09/2026). Bản này gom hơn
năm mươi pull request (#22–#77).

Từ bản này, SNPanel phát hành qua kho công khai
[vnscorpion/snpanel-releases](https://github.com/vnscorpion/snpanel-releases).
Mỗi bản phát hành là một gói dựng sẵn, có kèm `SHA256SUMS`.

### Tiếng Việt

**Cài đặt và cập nhật**

- Lệnh cài mới:
  `curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash`
  - Lệnh tải gói `snpanel-<tag>-x86_64-linux.tar.gz`, kiểm SHA-256 rồi mới giải nén và chạy trình cài.
  - Muốn cài đúng một bản thì đặt `SNPANEL_VERSION=v2.0.0`.
- Gói đã có sẵn giao diện và năm file chạy Rust tĩnh (musl):
  - máy chủ không phải dựng frontend;
  - không cần npm.
- Trang Cập nhật, `snpanel update` và `snpanel-update` cùng dùng kênh phát hành này.
  - Kiểm tra phiên bản dùng `releases/latest` của GitHub. Không gọi được thì dùng `git ls-remote`.
  - Panel hiểu các bản thử nghiệm (`2.0.0-rc.1` < `2.0.0`).

**Web server: LiteSpeed Enterprise trên bản Standard**

- `snpanel build` làm việc theo kiểu CustomBuild của DirectAdmin:
  - khai báo trong `/etc/snpanel/build.conf`;
  - chạy các bước `update`, `webserver`, `php`, `waf`, `rewrite_confs` hoặc `all` thành một job nền;
  - xem tiến độ bằng `snpanel build status`.
- Chuyển nginx → LiteSpeed Enterprise:
  - Apache chạy dự phòng nóng (8080/8443), LiteSpeed nằm ở 9080/9443;
  - 80/443 được chuyển sang LiteSpeed;
  - nginx được gỡ sau khi chuyển.
- Watchdog bằng Rust:
  - LiteSpeed ngừng trả lời hoặc hết giấy phép thì chuyển sang Apache trong vài giây;
  - giấy phép hợp lệ lại thì tự quay về LiteSpeed;
  - có nút quay về bằng tay;
  - có thông báo.
- Giấy phép trial hoặc serial: có thẻ giấy phép trên trang Web server.
- Truy cập WebAdmin:
  - mặc định chỉ ở 127.0.0.1:7080;
  - có chế độ công khai với danh sách IP được phép.
- Quay lại nginx hoặc Apache bằng cùng lệnh `snpanel build all`.
- Qua SSH: `snpanel build live` (ai đang trả 80/443, giấy phép, watchdog,
  WebAdmin), `snpanel build switch apache|litespeed` và
  `snpanel build license-check`.
- PHP: lsphp từ Remi; mỗi tên miền chọn một phiên bản PHP riêng (suEXEC).
- Thêm LSCache, throttling, chỉ thị Apache tuỳ chỉnh và giới hạn lsphp.
- Hướng dẫn: [docs/litespeed.vi.md](docs/litespeed.vi.md).

**Giao diện mới**

- Bảng điều khiển gom theo nhóm, kiểu DirectAdmin, với bộ biểu tượng riêng.
- Thanh bên gọn hơn; addon nằm trên Dashboard.
- Header mới:
  - tài khoản, ngôn ngữ, giao diện sáng/tối;
  - chuông cảnh báo.
- Hộp thoại, tab và biểu mẫu dùng chung, theo phong cách OPanel.
- Tiếng Việt đầy đủ, có bảng thuật ngữ.
- Nút bấm cỡ 40 px cho điện thoại.
- Chuyển trang thì mở từ đầu trang.

**Bảo mật và cách ly**

- Terminal là bash thật, chạy trong lồng riêng của từng tài khoản (systemd, slice của người dùng):
  - tối đa 2 phiên;
  - nghỉ 30 phút thì đóng; tối đa 8 giờ;
  - không có shell cho staff hay root.
- Thư mục home 0750 trên Apache/LiteSpeed: khách hàng không đọc được thư mục của nhau. `snpanel doctor --isolation` kiểm việc này.
- phpMyAdmin chạy bằng tài khoản riêng `snpanel-pma`, có CA bundle và không tự kiểm tra bản mới.
- Valkey:
  - không còn người dùng ẩn danh; panel và Rspamd có người dùng ACL riêng;
  - object cache của mỗi tài khoản chạy trên unix socket riêng.
- Siết máy chủ:
  - tắt user namespace (`harden_userns = no` để giữ nguyên);
  - tắt TIOCSTI;
  - MariaDB chỉ nghe ở loopback.
- Chỉ tin `X-Forwarded-For` từ `TRUSTED_PROXIES`.
- File vhost và log có quyền 0640.
- Tường lửa khoá các cổng hệ thống. fail2ban theo dõi đúng web stack đang chạy.

**Email (addon Email)**

- Bộ lọc thư (Sieve) và trả lời tự động.
- Nhật ký gửi nhận, xuất ra Excel/CSV.
- Danh sách thư (mailing list) và thư nhóm.
- Chuyển hàng loạt hộp thư từ máy khác qua IMAP (`doveadm imapc`).
- Catch-all theo tên miền.
- SMTP relay (smarthost):
  - dùng cổng do quản trị chọn;
  - SPF của relay được thêm vào SPF của mọi tên miền.
- Danh sách cho phép/chặn người gửi theo tên miền.
- DKIM: khoá cũ được thu hồi.
- Hỗ trợ Dovecot 2.3 và 2.4.
- Mật khẩu hash yếu (từ dữ liệu nhập) được nâng cấp ở lần đổi mật khẩu sau.
- Webmail (BNIX Webmail) nằm sẵn trong panel; người dùng đổi được mật khẩu hộp thư.

**WordPress Manager (addon)**

- Bộ công cụ WP-CLI:
  - đăng nhập một chạm (SSO);
  - staging và đẩy staging lên site thật;
  - điểm khôi phục;
  - chuyển sang HTTPS.
- Tải lên plugin và theme.
- Bật/tắt object cache cho từng site.
- Hàng đợi tác vụ; thanh công cụ gọn.

**Object cache**

- Mỗi tài khoản có một Valkey riêng trên unix socket `~/.valkey/valkey.sock`: 64 MB, db0 cho ứng dụng, db1–63 cho WordPress.
- Bật ở Tài khoản › Object cache, hoặc cho từng site trong WordPress Manager.

**Chuyển dữ liệu từ panel khác**

- Nhập từ cPanel: tải file backup lên, hoặc kéo qua SSH (pkgacct; tiếp tục được khi đứt; kiểm SHA-256).
- Nhập từ DirectAdmin (addon): kéo qua SSH theo task.queue hoặc Admin Backup. Đã thử trên DA 1.62 và 1.671.
- Nhập từ FastPanel (addon): kéo qua SSH. Đã thử trên một máy FASTPANEL 2 thật.

**Addon**

- Danh sách addon: Application, cPanel Import, DirectAdmin Import, FastPanel Import, DNS, Email, Fail2ban, Incremental Backup, Malware, MCP, Notifications, WordPress.
- Trang của addon chưa cài chỉ hiện thông báo trống, kèm nút dẫn tới trang Addons.
- Gỡ addon không xoá dữ liệu.
- Incremental Backup:
  - dùng restic, lưu ra local, SFTP hoặc S3;
  - khách hàng tự khôi phục được;
  - quản trị khôi phục được cả tài khoản.
- DNS Manager (PowerDNS), có nhóm đại lý (reseller).

**Tài nguyên và vận hành**

- Giới hạn CPU, bộ nhớ, số tiến trình và IO cho từng người dùng (cgroup v2).
- Thẻ Tài nguyên tài khoản.
- MySQL governor theo người dùng.
- AutoSSL. Khôi phục chạy nền.
- OPcache: mặc định 768/64/100000; chỉnh được trong giới hạn php.ini.
- Node.js 22.
- `snpanel doctor` kiểm tra nhiều thứ hơn.

**Thay đổi phá vỡ và lưu ý khi nâng cấp**

- **Kênh cập nhật mới.** Máy cài trước v2.0.0 có trình cập nhật vẫn tìm bản mới trong kho mã nguồn. Kho này là riêng tư, nên máy không đọc được và trang Cập nhật báo lỗi. Hãy nâng cấp một lần bằng lệnh bootstrap. Lệnh này tự nhận ra máy đã cài và chuyển sang chế độ cập nhật:
  `curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash`
  - Từ đó trở đi, trang Cập nhật và `snpanel update` dùng kênh mới.
  - `.env` được ghi `SNPANEL_RELEASE_REPO`. `SNPANEL_REPO_URL` cũ trỏ tới kho riêng tư thì bị xoá.
- Cập nhật không dựng frontend nữa. `node_modules` cũ trong `/opt/snpanel/frontend` được xoá.
- Khách hàng mới mặc định tắt Terminal, trừ khi gói (package) bật.
- Sau khi chuyển sang LiteSpeed/Apache, nginx bị gỡ. Thư mục home thành 0750, và web server được thêm vào nhóm của từng khách hàng.
- WordPress đang dùng Valkey chung được chuyển sang Valkey riêng của tài khoản.
- User namespace bị tắt. Phần mềm nào cần nó (vd. rootless container) thì đặt `harden_userns = no` trong `/etc/snpanel/build.conf` (của root).

**Giới hạn đã biết**

- LiteSpeed trên Debian/Ubuntu còn hoãn: `snpanel build` từ chối, các máy đó dùng nginx. AlmaLinux 10 là nền chính.
- Nhập thư và DNS từ FastPanel/DirectAdmin chưa được thử trên dữ liệu mẫu thật: máy FastPanel mẫu không có hộp thư hay vùng DNS.
- Hết hạn trial LiteSpeed thật mới được mô phỏng. Lần thử thật dự kiến ngày 26/10/2026.
- Trình cài không cấu hình SELinux.
- Chưa có đường CloudLinux trên máy thật.

### English

**Install and update**

- New install command:
  `curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash`
  - It downloads the bundle `snpanel-<tag>-x86_64-linux.tar.gz`, checks its SHA-256, and only then unpacks it and runs the installer.
  - `SNPANEL_VERSION=v2.0.0` pins a release.
- The bundle carries the interface already built and the five static (musl) Rust binaries:
  - nothing is built on the server;
  - npm is not needed.
- The Updates page, `snpanel update` and `snpanel-update` all use this channel.
  - The version check uses GitHub's `releases/latest`, falling back to `git ls-remote`.
  - Prereleases are understood (`2.0.0-rc.1` < `2.0.0`).

**Web stack: LiteSpeed Enterprise on Standard**

- `snpanel build` works in DirectAdmin's CustomBuild style:
  - declare the stack in `/etc/snpanel/build.conf`;
  - run `update`, `webserver`, `php`, `waf`, `rewrite_confs` or `all` as one background job;
  - follow it with `snpanel build status`.
- nginx → LiteSpeed Enterprise:
  - Apache is a hot standby (8080/8443) and LiteSpeed sits on 9080/9443;
  - 80/443 move to LiteSpeed;
  - nginx is removed after the cutover.
- A Rust watchdog:
  - fails over to Apache within seconds when LiteSpeed stops answering or its licence fails;
  - returns to LiteSpeed automatically once its licence is valid again;
  - has a manual return button;
  - sends notifications.
- Trial or serial licences, with a licence card on the Web server page.
- WebAdmin access:
  - loopback-only by default (127.0.0.1:7080);
  - an optional public mode with an allow list.
- Return to nginx or Apache with the same `snpanel build all`.
- Over SSH: `snpanel build live` (who answers 80/443, the licence, the
  watchdog, WebAdmin), `snpanel build switch apache|litespeed` and
  `snpanel build license-check`.
- PHP: Remi lsphp, and a PHP version per domain (suEXEC).
- LSCache, throttling, custom Apache directives and lsphp limits.
- Guide: [docs/litespeed.md](docs/litespeed.md).

**The new interface**

- A grouped, DirectAdmin-style dashboard with an original icon set.
- A smaller sidebar, with addons on the Dashboard.
- A new header:
  - account, language and light/dark theme;
  - an alert bell.
- Shared dialogs, tabs and forms, in the OPanel style.
- A full Vietnamese translation with a glossary.
- 40 px touch targets for phones.
- Pages open at the top after in-panel navigation.

**Security and isolation**

- The Terminal is a real bash in a per-account jail (systemd, the user's slice):
  - 2 sessions per account;
  - a 30-minute idle limit and an 8-hour maximum;
  - no staff or root shell.
- Homes are 0750 on Apache/LiteSpeed, so customers cannot read each other's files. `snpanel doctor --isolation` checks it.
- phpMyAdmin runs as its own `snpanel-pma` account, with a CA bundle and no version check of its own.
- Valkey:
  - no anonymous user; ACL users for the panel and Rspamd;
  - each account's object cache on its own unix socket.
- Host hardening:
  - user namespaces off (opt out with `harden_userns = no`);
  - TIOCSTI off;
  - MariaDB on loopback only.
- `X-Forwarded-For` is trusted only from `TRUSTED_PROXIES`.
- Vhost and log files are 0640.
- The firewall locks the system ports. fail2ban watches the web stack in use.

**Email (Email addon)**

- Filters (Sieve) and an autoresponder.
- A delivery log with Excel/CSV export.
- Mailing lists and group mail.
- Bulk IMAP migration of mailboxes from another server (`doveadm imapc`).
- Catch-all per domain.
- SMTP relay (smarthost):
  - on the port the administrator chooses;
  - the relay's SPF merged into every domain's SPF.
- Per-domain sender allow/block lists.
- DKIM key retirement.
- Dovecot 2.3 and 2.4.
- Weak imported hashes are upgraded at the next password change.
- The webmail (BNIX Webmail) ships with the panel, and users can change their mailbox password there.

**WordPress Manager (addon)**

- A WP-CLI toolkit:
  - single sign-on;
  - staging, and pushing staging to the live site;
  - restore points;
  - switch to HTTPS.
- Plugin and theme upload.
- A per-site object cache switch.
- A task queue and a compact toolbar.

**Object cache**

- Each account gets its own Valkey on the unix socket `~/.valkey/valkey.sock`: 64 MB, db0 for applications, db1–63 for WordPress sites.
- Turn it on under Account › Object cache, or per site in WordPress Manager.

**Migrations**

- cPanel import: upload a backup, or pull over SSH (pkgacct, resumable transfer, SHA-256 checked).
- DirectAdmin Import addon: pull over SSH via task.queue or Admin Backup. Tested on DA 1.62 and 1.671.
- FastPanel Import addon: pull over SSH. Tested on a real FASTPANEL 2 server.

**Addons**

- Application, cPanel Import, DirectAdmin Import, FastPanel Import, DNS, Email, Fail2ban, Incremental Backup, Malware, MCP, Notifications and WordPress.
- The page of an addon that is not installed shows an empty state with a link to the Addons page.
- Uninstalling an addon never deletes data.
- Incremental Backup:
  - restic, to local, SFTP or S3 storage;
  - customers can restore on their own;
  - administrators can restore a whole account.
- DNS Manager (PowerDNS), with resellers.

**Resources and operations**

- Per-user CPU, memory, process and IO limits (cgroup v2).
- An Account resources tab.
- A per-user MySQL governor.
- AutoSSL. Restores run in the background.
- OPcache defaults of 768/64/100000, adjustable within the php.ini limits.
- Node.js 22.
- `snpanel doctor` checks much more.

**Breaking changes and upgrade notes**

- **A new update channel.** On a server installed before v2.0.0, the updater still looks for releases in the source repository. That repository is private, so the server cannot read it and the Updates page reports an error. Upgrade once with the bootstrap, which sees the existing install and updates it:
  `curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash`
  - From then on, the Updates page and `snpanel update` use the new channel.
  - `.env` gets `SNPANEL_RELEASE_REPO`. An old `SNPANEL_REPO_URL` that points at the private repository is removed.
- Updates no longer build the frontend. The old `node_modules` in `/opt/snpanel/frontend` is removed.
- New customers get Terminal off unless their package enables it.
- After a cutover to LiteSpeed or Apache, nginx is removed. Homes become 0750, and the web servers join each customer's group.
- WordPress sites using the shared Valkey move to their account's own Valkey.
- User namespaces are turned off. If software needs them (rootless containers, for example), set `harden_userns = no` in root's `/etc/snpanel/build.conf`.

**Known limits**

- LiteSpeed on Debian/Ubuntu is deferred: `snpanel build` refuses it there, and those servers stay on nginx. AlmaLinux 10 is the primary target.
- Mail and DNS import from FastPanel/DirectAdmin have not been tested on real sample data: the FastPanel sample server had no mailboxes or zones.
- A real LiteSpeed trial expiry has only been simulated. The real test is planned for 2026-10-26.
- The installer does not configure SELinux.
- The CloudLinux path has not been run on a real host.

## v1.1.0

27/09/2026: the panel as one Rust binary, with a Rust privileged helper.
