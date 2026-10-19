# SNPanel releases

[Tiếng Việt](#tiếng-việt) | [English](#english)

SNPanel là bảng điều khiển hosting gọn nhẹ: website WordPress và PHP, tài
khoản và gói, sao lưu, SSL, tường lửa, WAF, email, DNS, và LiteSpeed
Enterprise với Apache dự phòng.

SNPanel is a lightweight hosting control panel: WordPress and PHP websites,
accounts and packages, backups, SSL, a firewall, a WAF, email, DNS, and
LiteSpeed Enterprise with Apache as a standby.

Kho này là **kênh phát hành** của SNPanel. Nó chứa trình cài khởi động
(`install.sh`), nhật ký thay đổi, tài liệu, và các gói phát hành đính kèm mỗi
[GitHub release](https://github.com/vnscorpion/snpanel-releases/releases).
Mã nguồn không nằm ở đây.

This repository is SNPanel's **release channel**. It holds the bootstrap
installer (`install.sh`), the changelog, the documentation, and the release
bundles attached to each
[GitHub release](https://github.com/vnscorpion/snpanel-releases/releases).
The source code is not here.

**Tra cứu lệnh đầy đủ / Full command reference:**
[docs/commands.vi.md](docs/commands.vi.md) (Tiếng Việt) |
[docs/commands.md](docs/commands.md) (English)

## Tiếng Việt

### Yêu cầu

Máy chủ x86_64 mới cài, có quyền root, chạy một trong các hệ sau:

| Hệ điều hành | Trạng thái |
|---|---|
| **AlmaLinux 10** | **Nền chính.** Hỗ trợ đầy đủ, kể cả LiteSpeed Enterprise với Apache dự phòng. |
| Debian 13 | Đang hoàn thiện: cài và chạy được với nginx; `snpanel build` (LiteSpeed, Apache) chưa mở trên hệ này. |
| Ubuntu 24.04 LTS | Cài và chạy được với nginx; `snpanel build` chưa mở trên hệ này. |
| Rocky Linux 10, RHEL 10, Debian 12 | Trình cài chấp nhận, kiểm thử ít hơn. |

- Tối thiểu 1 vCPU, 1 GB RAM; khuyến nghị 2 vCPU, 2 GB RAM. LiteSpeed
  Enterprise cần 2 GB.
- cgroup v2 (có `cpu`, `memory`, `pids`) để giới hạn tài nguyên. Không có thì
  cài với `SNPANEL_RESOURCE_LIMITS=off`.
- Cổng cần mở: SSH, `2222` (panel), 80, 443, 465, 587; addon Email thêm 25,
  110, 143, 993, 995 và 2096 (webmail); addon DNS Manager thêm 53.

Chi tiết: [docs/commands.vi.md](docs/commands.vi.md#muc-1).

### Cài đặt

Chạy bằng root:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

Lệnh làm các bước sau:

1. Tìm bản phát hành chính thức mới nhất.
2. Tải `snpanel-<tag>-x86_64-linux.tar.gz` và `SHA256SUMS`.
3. Kiểm SHA-256. Chỉ khi khớp mới giải nén và chạy trình cài bên trong.

Gói đã có sẵn giao diện và các file chạy tĩnh, nên máy chủ không biên dịch gì.

Muốn cài một bản cụ thể (kể cả bản thử nghiệm) thì ghi rõ bản đó:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_VERSION=v2.0.0 bash
```

Muốn cài không hỏi gì thì đặt sẵn địa chỉ panel:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://203.0.113.10:2222 bash
# dùng tên miền, có Let's Encrypt:
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://panel.example.com:2222 ENABLE_SSL=yes SSL_EMAIL=admin@example.com bash
```

Mọi biến môi trường của trình cài (`PANEL_PORT`, `PHP_VERSIONS`,
`PANEL_TIMEZONE`, `SNPANEL_HARDEN_USERNS`...):
[docs/commands.vi.md](docs/commands.vi.md#muc-2).

### Đăng nhập lần đầu

- **Địa chỉ:** `https://<tên miền hoặc IP>:2222`. Không có tên miền thì
  panel dùng chứng chỉ tự ký, và trình duyệt cảnh báo một lần.
- **Tên đăng nhập:** `admin`.
- **Mật khẩu:** chỉ hiện trên terminal lúc cài, và được lưu trong
  `/root/login.txt` (chỉ root đọc được).
- `snpanel login` in lại địa chỉ, tên đăng nhập và mật khẩu.
- `snpanel doctor` kiểm tra bản cài.

### Cập nhật

- Dùng trang **Máy chủ > Cập nhật** của panel, hoặc chạy:

  ```bash
  snpanel update                              # bản chính thức mới nhất
  snpanel update --tag v2.0.0                 # một bản cụ thể
  SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # kể cả bản thử nghiệm
  ```

- **Máy cài trước v2.0.0** vẫn tìm bản mới trong kho mã nguồn riêng tư, nên
  không thấy được bản mới. Hãy chạy lệnh cài ở trên một lần. Lệnh tự nhận ra
  máy đã cài và cập nhật nó.

### Các lệnh hay dùng

```bash
snpanel                              # menu cứu hộ, dùng khi không vào được panel web
snpanel status                       # dịch vụ, cổng, chứng chỉ, tường lửa
snpanel logs -f                      # log của panel
snpanel doctor                       # chẩn đoán; mã thoát 0 ổn, 1 có cảnh báo, 2 có lỗi
snpanel build show                   # web stack: đã khai báo và đang chạy
snpanel build live                   # LiteSpeed: ai trả 80/443, giấy phép, watchdog
snpanel change-admin-password
snpanel reset-admin-2fa              # mất ứng dụng xác thực hoặc passkey
snpanel repair-firewall              # mở lại cổng panel và SSH
```

Mọi lệnh, tuỳ chọn và cách xử lý sự cố: [docs/commands.vi.md](docs/commands.vi.md).

### Chuyển từ nginx lên LiteSpeed Enterprise

Xem [docs/litespeed.vi.md](docs/litespeed.vi.md), và
[docs/commands.vi.md](docs/commands.vi.md#muc-6) cho mọi lệnh `snpanel build`.

### Tự kiểm tra một gói

```bash
tag=v2.0.0
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/snpanel-$tag-x86_64-linux.tar.gz
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/SHA256SUMS
sha256sum -c SHA256SUMS
```

### Thay đổi

Xem [CHANGELOG.md](CHANGELOG.md).

## English

### Requirements

A clean x86_64 server with root access, running one of these:

| System | Status |
|---|---|
| **AlmaLinux 10** | **The primary target.** Everything, LiteSpeed Enterprise with Apache as the standby included. |
| Debian 13 | In progress: installs and runs with nginx; `snpanel build` (LiteSpeed, Apache) is not open there yet. |
| Ubuntu 24.04 LTS | Installs and runs with nginx; `snpanel build` is not open there yet. |
| Rocky Linux 10, RHEL 10, Debian 12 | Accepted by the installer, tested less. |

- At least 1 vCPU and 1 GB RAM; 2 vCPU and 2 GB RAM recommended. LiteSpeed
  Enterprise needs 2 GB.
- cgroup v2 (with `cpu`, `memory` and `pids`) for resource limits. Without
  it, install with `SNPANEL_RESOURCE_LIMITS=off`.
- Open ports: SSH, `2222` (the panel), 80, 443, 465, 587; the Email addon
  adds 25, 110, 143, 993, 995 and 2096 (webmail); the DNS Manager addon, 53.

Details: [docs/commands.md](docs/commands.md#1-requirements).

### Install

Run as root:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

The command:

1. Finds the newest stable release.
2. Downloads `snpanel-<tag>-x86_64-linux.tar.gz` and `SHA256SUMS`.
3. Checks the SHA-256. Only when it matches does it unpack the bundle and run
   the installer inside.

The bundle carries the interface already built and static binaries, so
nothing is compiled on the server.

To install one particular release (a release candidate too), name it:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_VERSION=v2.0.0 bash
```

To install without questions, set the panel's address beforehand:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://203.0.113.10:2222 bash
# on a domain, with Let's Encrypt:
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://panel.example.com:2222 ENABLE_SSL=yes SSL_EMAIL=admin@example.com bash
```

Every installer variable (`PANEL_PORT`, `PHP_VERSIONS`, `PANEL_TIMEZONE`,
`SNPANEL_HARDEN_USERNS`, ...): [docs/commands.md](docs/commands.md#2-install).

### First login

- **Address:** `https://<domain or IP>:2222`. Without a domain, the panel uses
  a self-signed certificate, and the browser warns once.
- **User:** `admin`.
- **Password:** shown on the terminal only, during the install, and saved in
  `/root/login.txt` (readable by root only).
- `snpanel login` prints the address, the user and the password again.
- `snpanel doctor` checks the installation.

### Update

- Use the panel's **Server > Updates** page, or run:

  ```bash
  snpanel update                              # the newest stable release
  snpanel update --tag v2.0.0                 # a particular release
  SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # release candidates too
  ```

- **Servers installed before v2.0.0** still look for releases in the private
  source repository, so they cannot see new releases. Run the install command
  above once: it sees the existing installation and updates it.

### Commands used most

```bash
snpanel                              # the rescue menu, for when the web panel cannot be reached
snpanel status                       # services, ports, certificate, firewall
snpanel logs -f                      # the panel's log
snpanel doctor                       # diagnose; exit code 0 ok, 1 warnings, 2 failures
snpanel build show                   # the web stack: declared and running
snpanel build live                   # LiteSpeed: who serves 80/443, the licence, the watchdog
snpanel change-admin-password
snpanel reset-admin-2fa              # the authenticator or passkey is lost
snpanel repair-firewall              # reopen the panel and SSH ports
```

Every command, option and common problem: [docs/commands.md](docs/commands.md).

### From nginx to LiteSpeed Enterprise

See [docs/litespeed.md](docs/litespeed.md), and
[docs/commands.md](docs/commands.md#6-web-stack-snpanel-build) for every
`snpanel build` command.

### Checking a bundle yourself

```bash
tag=v2.0.0
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/snpanel-$tag-x86_64-linux.tar.gz
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/SHA256SUMS
sha256sum -c SHA256SUMS
```

### Changes

See [CHANGELOG.md](CHANGELOG.md).
