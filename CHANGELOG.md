# Nhật ký thay đổi / Changelog

Tiếng Việt trước, English below.

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
