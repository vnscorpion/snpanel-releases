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

## Tiếng Việt

### Yêu cầu

- Máy chủ x86_64 mới cài, có quyền root.
- **AlmaLinux 10** là nền chính, hỗ trợ đầy đủ, kể cả LiteSpeed Enterprise.
- Ubuntu 24.04 LTS và Debian 13 (Debian 12 cài được) chạy với nginx.
  LiteSpeed trên các hệ này đang hoãn.
- Tối thiểu 1 vCPU, 1 GB RAM; khuyến nghị 2 vCPU, 2 GB RAM.
- cgroup v2 (có `cpu`, `memory`, `pids`) để giới hạn tài nguyên. Không có thì
  cài với `SNPANEL_RESOURCE_LIMITS=off`.

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
```

### Đăng nhập lần đầu

- **Địa chỉ:** `https://<tên miền hoặc IP>:2222`. Không có tên miền thì
  panel dùng chứng chỉ tự ký, và trình duyệt cảnh báo một lần.
- **Tên đăng nhập:** `admin`.
- **Mật khẩu:** chỉ hiện trên terminal lúc cài, và được lưu trong
  `/root/login.txt` (chỉ root đọc được).
- `snpanel login` in lại địa chỉ, tên đăng nhập và mật khẩu.

### Cập nhật

- Dùng trang **Cập nhật** của panel, hoặc chạy:

  ```bash
  snpanel update                              # bản chính thức mới nhất
  snpanel update --tag v2.0.0                 # một bản cụ thể
  SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # kể cả bản thử nghiệm
  ```

- **Máy cài trước v2.0.0** vẫn tìm bản mới trong kho mã nguồn riêng tư, nên
  không thấy được bản mới. Hãy chạy lệnh cài ở trên một lần. Lệnh tự nhận ra
  máy đã cài và cập nhật nó.

### Chuyển từ nginx lên LiteSpeed Enterprise

Xem [docs/litespeed.vi.md](docs/litespeed.vi.md).

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

- A clean x86_64 server with root access.
- **AlmaLinux 10** is the primary target, fully supported, LiteSpeed
  Enterprise included.
- Ubuntu 24.04 LTS and Debian 13 (Debian 12 installs) run with nginx.
  LiteSpeed is deferred on them.
- At least 1 vCPU and 1 GB RAM; 2 vCPU and 2 GB RAM recommended.
- cgroup v2 (with `cpu`, `memory` and `pids`) for resource limits. Without
  it, install with `SNPANEL_RESOURCE_LIMITS=off`.

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
```

### First login

- **Address:** `https://<domain or IP>:2222`. Without a domain, the panel uses
  a self-signed certificate, and the browser warns once.
- **User:** `admin`.
- **Password:** shown on the terminal only, during the install, and saved in
  `/root/login.txt` (readable by root only).
- `snpanel login` prints the address, the user and the password again.

### Update

- Use the panel's **Updates** page, or run:

  ```bash
  snpanel update                              # the newest stable release
  snpanel update --tag v2.0.0                 # a particular release
  SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # release candidates too
  ```

- **Servers installed before v2.0.0** still look for releases in the private
  source repository, so they cannot see new releases. Run the install command
  above once: it sees the existing installation and updates it.

### From nginx to LiteSpeed Enterprise

See [docs/litespeed.md](docs/litespeed.md).

### Checking a bundle yourself

```bash
tag=v2.0.0
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/snpanel-$tag-x86_64-linux.tar.gz
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/SHA256SUMS
sha256sum -c SHA256SUMS
```

### Changes

See [CHANGELOG.md](CHANGELOG.md).
