# Tra cứu lệnh SNPanel

[English](commands.md) | **Tiếng Việt**

Đây là toàn bộ lệnh, tuỳ chọn và thiết lập mà quản trị viên dùng để cài, cập
nhật và vận hành SNPanel **v2.0.0**. Từng lệnh đã được đối chiếu với bản phát
hành v2.0.0: phần `--help` của các file chạy, và script cài đặt, cập nhật đi
kèm.

Mọi lệnh chạy bằng **root** qua SSH, trừ khi có ghi chú khác. Phần lớn việc ở
đây panel cũng làm được bằng nút bấm; chỗ nào có menu thì có ghi đường dẫn.

## Mục lục

1. [Yêu cầu](#muc-1)
2. [Cài đặt](#muc-2)
3. [Đăng nhập lần đầu](#muc-3)
4. [Cập nhật](#muc-4)
5. [Lệnh `snpanel`](#muc-5)
6. [Web stack: `snpanel build`](#muc-6)
7. [Chẩn đoán và log](#muc-7)
8. [Cứu hộ và quản trị hằng ngày](#muc-8)
9. [Các thao tác `snpanel-helper` dành cho quản trị viên](#muc-9)
10. [Addon và vị trí trong panel](#muc-10)
11. [Gỡ cài đặt](#muc-11)
12. [Ghi chú bảo mật](#muc-12)

---

<a id="muc-1"></a>
## 1. Yêu cầu

### Hệ điều hành

| Hệ điều hành | Trạng thái ở v2.0.0 | Web stack |
|---|---|---|
| **AlmaLinux 10** | **Nền chính.** Được kiểm thử nhiều nhất, hỗ trợ đầy đủ. | Sau khi cài là nginx; `snpanel build` chuyển sang LiteSpeed Enterprise (Apache dự phòng) hoặc chỉ Apache, và chuyển ngược lại |
| Rocky Linux 10, RHEL 10 | Trình cài và `snpanel build` chấp nhận, nhưng chưa kiểm thử như AlmaLinux. | như AlmaLinux |
| Oracle Linux 10, CentOS Stream 10 | Trình cài chấp nhận, chưa kiểm thử. `snpanel build` từ chối. | nginx |
| **Debian 13** | **Đang hoàn thiện.** Cài và chạy được với nginx. Ở v2.0.0, `snpanel build` từ chối Debian và Ubuntu ("Debian and Ubuntu come later"). | nginx |
| Ubuntu 24.04 LTS | Cài và chạy được với nginx; kiểm thử ít hơn AlmaLinux. `snpanel build` từ chối. | nginx |
| Debian 12 | Trình cài chấp nhận, chưa kiểm thử kỹ. Mặc định PHP 8.3 và 8.2. | nginx |
| Ubuntu 26.04 và các hệ khác | Trình cài từ chối. | - |
| CloudLinux | Không dùng các lệnh này: `snpanel build` từ chối. | - |

Ghi chú:

- Trên AlmaLinux, trình cài bật EPEL, CRB và Remi; PHP lấy từ Remi. Trình cài
  không cấu hình SELinux.
- Trên AlmaLinux dùng nginx, trang WAF chỉ có giới hạn HTTP flood và chặn bot
  (ở đó không có gói ModSecurity cho nginx). Stack Apache và LiteSpeed có
  ModSecurity.
- Debian 13 có PHP từ 7.4 đến 8.5, lấy từ packages.sury.org; Ubuntu lấy PHP
  từ PPA của Ondřej Surý.

<a id="phan-cung"></a>
### Phần cứng

- **Chỉ x86_64.** Trình cài khởi động từ chối kiến trúc khác.
- **CPU và RAM:** tối thiểu 1 vCPU và 1 GB RAM; khuyến nghị 2 vCPU và 2 GB
  RAM. Mỗi tài khoản chạy một master PHP-FPM riêng cho mỗi phiên bản PHP nó
  dùng, khoảng 20-30 MB mỗi master.
- **LiteSpeed Enterprise** (có Apache dự phòng): tối thiểu 2 GB RAM. Build
  chấp nhận 1,9 GB, hoặc 1,7 GB nếu có 1 GB swap. RAM dưới 4 GB mà không có
  swap thì build khuyên thêm file swap 2 GB. Chỉ Apache thì cần 1 GB.
- **Đĩa:** trình cài không kiểm tra. Một job `snpanel build` cần trống 5 GB
  trên `/` cho LiteSpeed, 2 GB cho Apache hoặc nginx. Hãy chừa chỗ cho
  website, cơ sở dữ liệu và bản sao lưu cục bộ (`/var/backups/snpanel`).
- **cgroup v2** có các controller `cpu`, `memory` và `pids`, để giới hạn tài
  nguyên theo tài khoản. Mọi bản phân phối được hỗ trợ đều có, trên VPS KVM,
  VMware hay máy thật. OpenVZ và một số container LXC thì không: ở đó trình
  cài dừng lại, trừ khi bạn cài với `SNPANEL_RESOURCE_LIMITS=off` (không có
  giới hạn theo tài khoản).

### Máy chủ sạch

- Hệ điều hành mới cài, có quyền root.
- Không có control panel nào khác, và không có gì khác chiếm cổng 80, 443,
  cổng panel (2222), hay các cổng mail nếu dùng addon Email.
- Trình cài tiếp quản máy chủ: cài nginx, MariaDB, Redis (Valkey trên
  AlmaLinux), PHP, Node.js 22, certbot, phpMyAdmin, WP-CLI và nftables; ghi
  tường lửa riêng, một khối SFTP trong `sshd_config` và thiết lập kernel
  (`/etc/sysctl.d/90-snpanel-hardening.conf`). Đừng cài lên máy chủ đang dùng
  cho việc khác.
- Không bắt buộc: một tên miền trỏ về máy chủ, để panel có chứng chỉ Let's
  Encrypt riêng.

### Mạng

Máy chủ phải kết nối được qua HTTPS tới:

- `raw.githubusercontent.com`, `github.com`, `api.github.com`, và các máy chủ
  GitHub chuyển tải file phát hành sang (kênh phát hành);
- mirror của bản phân phối, và các kho trình cài thêm vào: EPEL và Remi trên
  AlmaLinux; NodeSource trên Debian và Ubuntu; packages.sury.org trên Debian;
  PPA của Ondřej Surý trên Ubuntu;
- `license.litespeedtech.com`, cho LiteSpeed Enterprise.

### Cổng

| Cổng | Dùng cho | Mở khi nào |
|---|---|---|
| cổng SSH của bạn (22) | SSH và SFTP | luôn mở; tường lửa của panel không đóng được |
| 2222 (`PANEL_PORT`) | panel, qua HTTPS | luôn mở |
| 80, 443 | website, Let's Encrypt, phpMyAdmin | luôn mở |
| 465, 587 | gửi thư (submission) | luôn mở |
| 25, 110, 143, 993, 995 | SMTP, POP3, IMAP | khi đã cài addon Email |
| 2096 | webmail | khi đã cài addon Email |
| 53 TCP và UDP | DNS | khi đã cài addon DNS Manager |
| 7080 | LiteSpeed WebAdmin | chỉ khi `lsws_admin public`; bình thường chỉ nghe ở 127.0.0.1 |
| 8080/8443, 9080/9443 | Apache (dự phòng) và LiteSpeed, phía sau chuyển hướng 80/443 | chỉ nội bộ; đừng mở ra ngoài |
| 7081/7443 | nginx, khi build so sánh trước lúc quay về nginx | chỉ nội bộ |

MariaDB, Valkey/Redis và API của PowerDNS (8081) chỉ nghe ở loopback. Nếu nhà
cung cấp có tường lửa phía trước máy chủ (security group), hãy mở các cổng
tương ứng ở đó.

---

<a id="muc-2"></a>
## 2. Cài đặt

### Lệnh cài khởi động (bootstrap)

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

Lệnh này làm các bước:

1. Kiểm tra đang chạy bằng root trên x86_64, và cài `curl`, `tar`, `gzip`,
   `sha256sum`, `awk` hoặc `sed` nếu thiếu.
2. Tìm bản phát hành chính thức mới nhất ở
   [vnscorpion/snpanel-releases](https://github.com/vnscorpion/snpanel-releases)
   (`releases/latest` của GitHub; không được thì tag `vX.Y.Z` mới nhất qua git).
3. Tải `snpanel-<tag>-x86_64-linux.tar.gz` và `SHA256SUMS` về
   `/var/tmp/snpanel-release.XXXXXX`, rồi kiểm SHA-256 của gói. Trước khi
   kiểm xong, không có gì trong gói được giải nén, càng không được chạy.
4. Chạy trình cài nằm trong gói. **Nếu máy đã cài SNPanel**
   (`/opt/snpanel/backend/.env` đã có), lệnh chạy trình cập nhật của gói thay
   vào đó: xem [4.4](#muc-4-4).
5. Xoá gói đã giải nén, trừ khi đặt `SNPANEL_KEEP_BUNDLE=yes`.

Gói đã có sẵn giao diện và các file chạy tĩnh của panel, nên máy chủ không
phải biên dịch gì.

### Các câu hỏi của trình cài

- **Tên miền panel** - không bắt buộc. Bỏ trống thì panel dùng IP của máy
  chủ.
- **Cổng panel** - mặc định `2222`. Tường lửa chỉ mở cổng này cho panel.
- **Let's Encrypt** cho tên miền (chỉ hỏi khi là tên miền), và e-mail đăng ký.

Không có tên miền, hoặc không dùng Let's Encrypt, thì panel dùng chứng chỉ tự
ký (10 năm) và vẫn chạy HTTPS.

### Biến môi trường

Đặt các biến giữa dấu `|` và `bash`:
`curl ... | TEN_BIEN=giatri TEN_BIEN2=giatri bash`.

| Biến | Mặc định | Tác dụng |
|---|---|---|
| `SNPANEL_VERSION` | bản chính thức mới nhất | Cài đúng bản này: `vX.Y.Z`, hoặc bản thử nghiệm như `v2.0.0-rc.1`. |
| `PANEL_URL` | hỏi | `https://<tên miền hoặc IP>:<cổng>`. Trả lời sẵn câu hỏi tên miền và cổng; bắt buộc khi không có terminal. |
| `PANEL_HOSTNAME` | hỏi | Chỉ tên miền; cổng vẫn được hỏi. |
| `PANEL_PORT` | `2222` | Cổng của panel. Cổng ghi trong `PANEL_URL` được ưu tiên. |
| `ENABLE_SSL` | `auto` (hỏi, khi là tên miền) | `yes`: chứng chỉ Let's Encrypt cho tên miền (cần `SSL_EMAIL`). `no`: tự ký. Địa chỉ IP thì luôn tự ký. |
| `SSL_EMAIL` | hỏi khi cần | E-mail tài khoản Let's Encrypt; cũng được lưu trong `.env` của panel. |
| `PANEL_TIMEZONE` | không đổi | Đặt múi giờ máy chủ, ví dụ `Asia/Ho_Chi_Minh`. Để trống thì trình cài không động tới. |
| `PHP_VERSIONS` | `8.3 8.4` (Debian 12: `8.2 8.3`) | Các phiên bản PHP cần cài, cách nhau bằng dấu cách. Cài thêm sau trong panel được. |
| `PHP_DEFAULT` | `8.4` (Debian 12: `8.3`) | Phiên bản PHP mặc định; phải nằm trong `PHP_VERSIONS`. |
| `SNPANEL_RESOURCE_LIMITS` | `on` | `off`: cài không có giới hạn CPU và bộ nhớ theo tài khoản (máy không có cgroup v2). |
| `SNPANEL_HARDEN_USERNS` | `yes` | `no`: giữ user namespace như bản phân phối (xem [6.8](#muc-6-8)). |
| `SNPANEL_ADMIN_PASSWORD` | ngẫu nhiên | Mật khẩu `admin` muốn đặt, thay cho mật khẩu ngẫu nhiên. Gõ trên dòng lệnh thì nó nằm lại trong lịch sử shell: nên dùng mật khẩu ngẫu nhiên. |
| `BACKUP_ROOT` | `/var/backups/snpanel` | Nơi giữ bản sao lưu. |
| `APP_DIR` | `/opt/snpanel` | Thư mục cài panel. Nên để mặc định: nếu đổi, lần nào chạy lệnh `snpanel` cũng phải có cùng `APP_DIR` trong môi trường. |
| `SNPANEL_RELEASE_REPO` | `https://github.com/vnscorpion/snpanel-releases` | Một kho GitHub khác có cùng cấu trúc (chỉ dùng khi phát triển). |
| `SNPANEL_KEEP_BUNDLE` | `no` | `yes`: giữ lại gói đã giải nén và in ra đường dẫn. |

Ví dụ:

```bash
# Cài đúng một bản
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_VERSION=v2.0.0 bash

# Không hỏi gì, dùng IP của máy chủ (chứng chỉ tự ký)
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | PANEL_URL=https://203.0.113.10:2222 bash

# Không hỏi gì, dùng tên miền và Let's Encrypt: cần thêm ENABLE_SSL và
# SSL_EMAIL, nếu không trình cài dừng ở câu hỏi Let's Encrypt
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh \
  | PANEL_URL=https://panel.example.com:2222 ENABLE_SSL=yes SSL_EMAIL=admin@example.com bash

# Múi giờ, các bản PHP, và giữ user namespace
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh \
  | PANEL_TIMEZONE=Asia/Ho_Chi_Minh PHP_VERSIONS="8.2 8.3 8.4" PHP_DEFAULT=8.4 SNPANEL_HARDEN_USERNS=no bash

# Container không có controller cgroup v2
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | SNPANEL_RESOURCE_LIMITS=off bash
```

Các biến không có trong bảng là biến nội bộ của script, không dùng để đặt
tay.

### Cài những gì, ở đâu

| | |
|---|---|
| `snpanel` (và hai liên kết `snpanelctl`, `snpanel-cli`) | `/usr/local/sbin/` |
| `snpanel-helper`, `snpanel-install`, `snpanel-update`, `snpanel-rescue-firewall`, `snpanel-extract` | `/usr/local/sbin/` |
| File chạy máy chủ của panel | `/usr/local/bin/snpanel-api-rust`, do `snpanel-api.service` chạy |
| Chương trình, giao diện | `/opt/snpanel` |
| Cấu hình | `/opt/snpanel/backend/.env`, `/etc/snpanel/` |
| Trạng thái | `/var/lib/snpanel/`, `/var/lib/snpanel-build/` (build web stack) |
| Sao lưu | `/var/backups/snpanel/` |
| Website | `/home/<user>/<tên miền>/public_html` |
| Dịch vụ | `snpanel-api`, `snpanel-helper` (socket `/run/snpanel/helper.sock`), `snpanel-firewall` |

### Log cài đặt, và chạy lại

- Trình cài in ra terminal và không giữ file log. Muốn giữ log:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash 2>&1 | tee /root/snpanel-install.log
  ```

  Mật khẩu admin được ghi thẳng ra terminal, không ra đầu ra chuẩn, nên không
  nằm trong log đó.
- Một bước bị lỗi thì sửa theo thông báo rồi **chạy lại đúng lệnh cũ**. Khi
  `.env` của panel chưa có (gần cuối quá trình cài), lệnh cài lại từ đầu; khi
  đã có, lệnh chạy trình cập nhật, ghi lại các file của panel.
- Cài xong: chạy `snpanel doctor`, và xem log của panel bằng
  `journalctl -u snpanel-api`.

---

<a id="muc-3"></a>
## 3. Đăng nhập lần đầu

Cuối cùng, trình cài in ra địa chỉ panel và tên đăng nhập `admin`.

- **Địa chỉ:** `https://<tên miền hoặc IP của máy>:2222`. Với chứng chỉ tự
  ký, trình duyệt cảnh báo một lần.
- **Tên đăng nhập:** `admin`.
- **Mật khẩu:** chỉ hiện trên terminal, và được lưu trong `/root/login.txt`
  (quyền 0600, chỉ root đọc được).
- `snpanel login` in lại địa chỉ, tên đăng nhập và mật khẩu. Mật khẩu được in
  rõ: để ý ai đang nhìn màn hình hay ghi log phiên SSH của bạn.
- **Đăng nhập hai bước:** menu tài khoản ở góc trên bên phải > **Bảo mật tài
  khoản** (passkey, ứng dụng xác thực, hoặc cả hai).
- Panel mở được trên mọi tên miền đang host trên máy, mỗi tên miền với chứng
  chỉ của nó: `https://<tên miền bất kỳ trên máy>:2222` mở không cảnh báo.
- Có addon Email thì webmail ở `https://<tên máy>:2096`.

Sau đó kiểm tra bản cài:

```bash
snpanel doctor
```

---

<a id="muc-4"></a>
## 4. Cập nhật

### 4.1 Từ panel

**Máy chủ > Cập nhật** cho xem bản đang cài và bản mới nhất, và cập nhật bằng
một nút. Việc cập nhật chạy trên máy chủ trong unit
`snpanel-panel-update.service`, nên đóng trình duyệt cũng không làm nó dừng:

```bash
journalctl -u snpanel-panel-update.service -f
```

<a id="muc-4-2"></a>
### 4.2 `snpanel update`

```bash
snpanel update                              # bản chính thức mới nhất
snpanel update --release                    # như trên, ghi rõ
snpanel update --tag v2.0.0                 # một bản cụ thể
snpanel update --tag v2.0.1-rc.1            # một bản thử nghiệm
SNPANEL_VERSION=v2.0.1-rc.1 snpanel update  # giống --tag
```

| Tuỳ chọn | Ý nghĩa |
|---|---|
| `--release` | Bản chính thức mới nhất (mặc định). |
| `--tag <TAG>` | Một bản: `vX.Y.Z`, hoặc bản thử nghiệm như `v2.0.0-rc.1`. |
| `--branch <BRANCH>` | Đầu một nhánh của mã nguồn. Chỉ để phát triển: kho mã nguồn là riêng tư. |

- Ba tuỳ chọn không dùng chung với nhau. Không có tuỳ chọn nào thì
  `SNPANEL_VERSION` quyết định bản, nếu không có thì là bản chính thức mới
  nhất.
- `snpanel update` hỏi `Update SNPanel to ... now? [y/N]` trước. Trong script,
  hãy gọi `snpanel-update`, lệnh này không hỏi.

### 4.3 `snpanel-update` (chính trình cập nhật)

```bash
snpanel-update                       # bản chính thức mới nhất
snpanel-update --tag v2.0.0
SNPANEL_VERSION=v2.0.0 snpanel-update
snpanel-update --help
```

| Tuỳ chọn | Ý nghĩa |
|---|---|
| `--release` | Bản chính thức mới nhất (mặc định). |
| `--tag TAG` | Một bản, hoặc bản thử nghiệm. |
| `--branch NAME` | Một nhánh của bản checkout git mã nguồn (cần quyền vào kho riêng tư). |
| `--channel MODE` | `release`, `tag` hoặc `branch`. |
| `--remote NAME` | Remote git cho `--branch` (mặc định `origin`). |
| `--skip-pull` | Dùng `SOURCE_DIR` (gói đã giải nén hoặc bản checkout) như đang có; không tải gì. |
| `--app-dir DIR` | Thư mục cài (mặc định `/opt/snpanel`). |
| `-h`, `--help` | Trợ giúp. |

| Biến môi trường | Mặc định | Ý nghĩa |
|---|---|---|
| `SNPANEL_VERSION` | - | Ghim một bản, như `--tag`, trừ khi có `--release`, `--tag` hoặc `--branch`. |
| `SNPANEL_RELEASE_REPO` | `https://github.com/vnscorpion/snpanel-releases` | Nơi lấy bản phát hành. Chỉ đọc từ môi trường, không bao giờ đọc từ `.env` của panel. |
| `SNPANEL_UPDATE_JOB_WAIT` | `21600` (6 giờ) | Số giây chờ các job đang chạy trước khi khởi động lại panel; `0` là không chờ. |
| `SNPANEL_UPDATE_BUILD_WAIT` | `7200` (2 giờ) | Số giây chờ job build web stack đang chạy. |
| `SNPANEL_FORCE_FULL_UPDATE` | - | `1`: chạy lại mọi bước, kể cả bước có đầu vào không đổi. |
| `SNPANEL_HARDEN_USERNS` | - | `no` hoặc `yes`: ghi lại lựa chọn về user namespace ([6.8](#muc-6-8)). |
| `APP_DIR`, `SOURCE_DIR`, `REPO_URL`, `GIT_REMOTE`, `UPDATE_CHANNEL`, `BRANCH`, `RELEASE_TAG`, `SKIP_PULL` | | Giống các tuỳ chọn ở trên. |

<a id="muc-4-4"></a>
### 4.4 Máy cài trước v2.0.0

Trình cập nhật của các máy này tìm bản mới trong kho mã nguồn riêng tư, nên
trang Cập nhật không thấy được v2.0.0. Hãy chạy lệnh cài khởi động một lần;
lệnh tự nhận ra máy đã cài và cập nhật nó:

```bash
curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
```

Từ đó trở đi, trang Cập nhật, `snpanel update` và `snpanel-update` dùng kênh
phát hành.

### 4.5 Một lần cập nhật làm gì

1. Tải gói phát hành và kiểm SHA-256, như trình cài.
2. Chụp lại cơ sở dữ liệu của panel:
   `/var/backups/snpanel/db-snapshots/snpanel-<giờ UTC>.db` (giữ mười bản mới
   nhất).
3. Chờ các job đang chạy (xem dưới).
4. Đặt chương trình, giao diện và file chạy mới vào chỗ, ghi lại unit và cấu
   hình của panel, áp lại phần siết máy chủ, khởi động lại panel, nạp lại web
   server (LiteSpeed chỉ khi giấy phép hợp lệ) và kiểm tra panel trả lời.

Nếu sau đó trình duyệt vẫn hiện giao diện cũ, tải lại bằng Ctrl + Shift + R.

### 4.6 Các job đang chạy

- **Build web stack** (`snpanel build`): lần cập nhật chờ job xong, tối đa
  `SNPANEL_UPDATE_BUILD_WAIT`, rồi dừng với lỗi nếu job vẫn chạy. Trong lúc
  cập nhật, không job build nào bắt đầu được.
- **Khôi phục, nhập và chuyển dữ liệu**: khôi phục bản sao lưu, nhập từ cPanel
  và DirectAdmin, kéo dữ liệu từ cPanel, DirectAdmin và FastPanel, khôi phục
  của Sao lưu tăng dần, chuyển hộp thư, và các tác vụ của WordPress Manager có
  sửa site (nhân bản, đẩy staging, quay lại điểm khôi phục). Lần cập nhật chờ
  chúng xong rồi mới khởi động lại panel, tối đa `SNPANEL_UPDATE_JOB_WAIT`, và
  hiện việc chờ trên trang Cập nhật. Quá thời gian đó thì cập nhật tiếp; job
  bị cắt ngang được đánh dấu là bị gián đoạn, và nút **Chạy lại** chạy lại nó.

### 4.7 Quay lại bản cũ

Không có lệnh quay lại bản cũ.

- `snpanel update --tag <tag>` cài bất kỳ bản nào đã phát hành trong kênh phát
  hành; v2.0.0 là bản đầu tiên ở đó.
- Mỗi lần cập nhật để lại bản chụp cơ sở dữ liệu ở trên.
- Chụp snapshot VPS trước một lần cập nhật bạn chưa chắc chắn.
- Với web server, xem [6.7](#muc-6-7): nó có đường lui riêng.

---

<a id="muc-5"></a>
## 5. Lệnh `snpanel`

`snpanel` không kèm tham số thì mở menu cứu hộ. Mọi lệnh cũng nhận dạng có
`--` phía trước (`snpanel --status`), như `snpanelctl` cũ, và `snpanelctl`,
`snpanel-cli` là liên kết tới `snpanel`.

| Lệnh | Việc làm |
|---|---|
| `snpanel` / `snpanel menu` | Menu cứu hộ ([8.1](#muc-8-1)). |
| `snpanel login` | Địa chỉ panel, tên đăng nhập và mật khẩu trong `/root/login.txt`. Tên khác: `show-login`. |
| `snpanel status` | Hệ điều hành, cổng và địa chỉ panel, SSL của panel, các dịch vụ và tường lửa. |
| `snpanel logs [-f] [-n N]` | Journal của panel: `-f` theo dõi liên tục, `-n` số dòng (mặc định 200). |
| `snpanel restart` | Khởi động lại panel và nginx (trên LiteSpeed và Apache xem [8.2](#muc-8-2)). |
| `snpanel repair-firewall` | Mở lại cổng panel và cổng SSH. |
| `snpanel update [--release \| --tag T \| --branch B]` | Cập nhật panel ([4.2](#muc-4-2)). |
| `snpanel change-ip [OLD_IP NEW_IP]` | Máy chủ đổi địa chỉ IP. |
| `snpanel set-panel-url` | Đặt lại tên miền và cổng của panel (có hỏi). |
| `snpanel install-panel-ssl` | Cấp hoặc sửa chứng chỉ Let's Encrypt của panel (có hỏi). |
| `snpanel fix-permissions` | Đặt lại chủ sở hữu và quyền tệp cho panel và các website. |
| `snpanel change-admin-password` | Mật khẩu `admin` mới (hỏi hai lần). |
| `snpanel sync-admin-root-password` | Cho mật khẩu `admin` trùng mật khẩu root. Tên khác: `admin-use-root-password`. |
| `snpanel reset-admin-2fa` | Tắt đăng nhập hai bước của admin khi mất thiết bị. |
| `snpanel firewall status \| reopen \| rescue \| migrate-nft --dry-run` | Bảo trì tường lửa ([8.4](#muc-8-4)). |
| `snpanel build ...` | Web stack ([mục 6](#muc-6)). |
| `snpanel limits show <USER> \| resync` | Giới hạn CPU, bộ nhớ và số tiến trình theo tài khoản ([8.7](#muc-8-7)). |
| `snpanel autossl` | Chạy AutoSSL cho mọi website ngay, và in kết quả. |
| `snpanel doctor [--json] [--isolation] [--enterprise-readiness]` | Chẩn đoán máy chủ ([7.1](#muc-7-1)). |
| `snpanel --version`, `snpanel --help` | Phiên bản (`snpanel 2.0.0`) và trợ giúp. Lệnh nào cũng nhận `--help`. |

---

<a id="muc-6"></a>
## 6. Web stack: `snpanel build`

SNPanel mới cài chạy website bằng nginx và PHP-FPM. Trên AlmaLinux 10 (và
Rocky Linux, RHEL 10), `snpanel build` chuyển máy sang **LiteSpeed
Enterprise** với **Apache dự phòng nóng**, hoặc sang **chỉ Apache**, và quay
về nginx - theo kiểu CustomBuild của DirectAdmin:

1. `snpanel build set ...` khai báo máy cần chạy gì, trong
   `/etc/snpanel/build.conf`. Lệnh kiểm tra giá trị và không cài gì.
2. Một job build (`all`, hoặc một bước) đưa máy về đúng khai báo.

Ở v2.0.0, build từ chối Debian, Ubuntu ("Debian and Ubuntu come later") và
CloudLinux; các máy đó giữ nginx. Trang **Máy chủ > Máy chủ web & PHP** của
panel làm được những việc này bằng nút bấm. Hướng dẫn chi tiết hơn ở
[litespeed.vi.md](litespeed.vi.md).

### 6.1 Một job build chạy thế nào

- Job chạy trong unit systemd riêng, `snpanel-build-<job>`, với các file của
  job trong `/var/lib/snpanel-build/jobs/<job>/` (chỉ root). Đóng SSH, khởi
  động lại panel hay cập nhật panel đều không làm job dừng.
- Mỗi lúc một job. Job từ chối bắt đầu khi đang có job khôi phục, nhập hay sao
  lưu, hoặc đang cập nhật panel, và nói rõ job nào.
- Mã job có dạng `bj-` và 12 chữ cái hoặc chữ số.
- Trạng thái job: `queued`, `running`, `completed`, `failed`, `cancelled`,
  `interrupted`. Trạng thái bước: `pending`, `running`, `done`, `skipped`,
  `failed`.
- Bước nào cũng chạy lại được: phần đã xong thì bỏ qua. Job dừng giữa chừng
  được chạy lại từ bước bị dừng bằng `retry`.

### 6.2 Các lệnh

| Lệnh | Tuỳ chọn | Việc làm |
|---|---|---|
| `snpanel build show` | | `build.conf`, và máy đang chạy gì: `Running: <webserver> with <php_mode>; <server> answers 80/443`. |
| `snpanel build set <KEY> <VALUE>` | | Đổi một khoá của `build.conf` ([6.3](#muc-6-3)). Không cài gì; hai khoá của WebAdmin được áp ngay. |
| `snpanel build preview` | `--wait` | Chạy thử preflight và bước update: cho xem kế hoạch, không đổi gì. |
| `snpanel build update` | `--wait` | Thông tin gói, bản LiteSpeed mới nhất, bộ OWASP CRS đã ghim. |
| `snpanel build webserver` | `--wait`, `--lsws-latest` | Apache (dự phòng, 8080/8443) và LiteSpeed Enterprise (9080/9443), và giấy phép. |
| `snpanel build php` | `--wait` | lsphp cho mọi phiên bản PHP, handler của LiteSpeed, các pool. |
| `snpanel build waf` | `--wait` | ModSecurity và bộ luật cho Apache và LiteSpeed. |
| `snpanel build rewrite_confs` | `--wait` | Ghi lại vhost của mọi website. Viết `rewrite-confs` cũng được. |
| `snpanel build all` | `--wait`, `--accept-diffs`, `--lsws-latest`, `--remove-litespeed` | Mọi bước, rồi cutover: 80/443 sang LiteSpeed (hoặc Apache) và gỡ nginx; hoặc, với `webserver = nginx`, quay về nginx. |
| `snpanel build status [JOB]` | | Các job gần đây (mã, loại, trạng thái, giờ bắt đầu), hoặc từng bước của một job, trạng thái và thông báo. |
| `snpanel build cancel <JOB>` | | Dừng job ở điểm an toàn kế tiếp. Đang cutover thì quay về nginx. |
| `snpanel build retry <JOB>` | `--wait`, `--accept-diffs` | Chạy lại job đã dừng, từ bước bị lỗi. |
| `snpanel build license` | | Lưu serial của LiteSpeed, đọc từ đầu vào chuẩn (một dòng). Không bao giờ nằm trên dòng lệnh. |
| `snpanel build live` | | Chỉ stack LiteSpeed: ai đang trả 80/443, cả hai server, giấy phép, watchdog, tự quay về, WebAdmin, lần chuyển gần nhất. |
| `snpanel build switch <litespeed\|apache>` | | Chuyển 80/443 bằng tay. Về LiteSpeed chỉ khi nó trả lời và giấy phép hợp lệ. |
| `snpanel build license-check` | | Kiểm giấy phép LiteSpeed ngay (key của serial được tải lại). Giấy phép không hợp lệ thì các site chuyển sang Apache. Viết `licence-check` cũng được. |

Tuỳ chọn:

- `--wait` theo dõi job, in log của từng bước khi có, rồi in kết quả; mã thoát
  là 0 chỉ khi `completed`. Không có `--wait` thì lệnh in mã job rồi thoát.
- `--accept-diffs` cho đi tiếp qua những khác biệt mà phần so sánh của
  cutover chưa biết. Không bao giờ đi tiếp qua một site sẽ lộ mã nguồn PHP.
- `--lsws-latest` cài bản LiteSpeed mới nhất kể cả khi panel chưa ghim
  SHA-256 cho nó; khi đó chỉ checksum của LiteSpeed được kiểm. Lệnh in cảnh
  báo.
- `--remove-litespeed`, với `webserver = nginx`: gỡ LiteSpeed và Apache sau
  khi nginx đã phục vụ. Không có tuỳ chọn này thì chúng được giữ lại, dừng,
  để quay lại nhanh.

Không có lệnh `snpanel build log`: hãy dùng `--wait`,
`snpanel build status <job>` hoặc `journalctl -u snpanel-build-<job>`.

<a id="muc-6-3"></a>
### 6.3 Các khoá của `build.conf`

`snpanel build set` nhận các khoá sau:

| Khoá | Giá trị | Ghi chú |
|---|---|---|
| `webserver` | `nginx`, `apache`, `litespeed` | `litespeed` giữ Apache làm dự phòng. Đặt khoá này thì `php_mode` cũng đổi theo. |
| `php_mode` | `php-fpm`, `lsphp` | `litespeed` cần `lsphp`; `nginx` và `apache` cần `php-fpm`. |
| `php_versions` | ví dụ `8.4,8.3` | Cách nhau bằng dấu phẩy; bản đầu là mặc định. |
| `waf` | `modsecurity`, `off` | |
| `lsws_license` | `trial`, `serial` | |
| `lsws_auto_return` | `yes`, `no` | Watchdog đọc ngay. |
| `lsws_admin` | `local`, `public` | Áp ngay ([6.6](#muc-6-6)). |
| `lsws_admin_allow` | địa chỉ hoặc mạng CIDR, cách nhau bằng dấu phẩy | Áp ngay; để trống là cho mọi địa chỉ. |

`build.conf` còn một khoá nữa, **`harden_userns`** (`yes` hoặc `no`). Đây là
lựa chọn của root và `snpanel build set` không nhận khoá này: xem
[6.8](#muc-6-8).

`set` trả lời như sau:

```text
webserver = litespeed (nothing installed yet: run `snpanel build all` to build it)
lsws_license = trial (used by the webserver step and by `snpanel build license-check`)
lsws_auto_return = yes (applied: the watchdog reads it on its next look)
```

### 6.4 Từ nginx lên LiteSpeed Enterprise, từng bước

**Trước khi bắt đầu:**

- AlmaLinux 10 (hoặc Rocky Linux, RHEL 10), không phải CloudLinux.
- 2 GB RAM (xem [Phần cứng](#phan-cung)); dưới 4 GB thì thêm file swap 2 GB.
- Trống 5 GB trên `/`.
- Máy kết nối được tới `license.litespeedtech.com`.
- Không có gì khác nghe ở 8080/8443, 9080/9443 hay 7080.
- Mọi phiên bản PHP mà các site dùng đều đã cài.
- Không có job khôi phục, nhập hay sao lưu nào đang chạy.
- Đã chụp snapshot VPS.

**Giấy phép: trial hay serial.**

- **Trial:** khoảng 14 ngày. Mỗi địa chỉ IP chỉ được LiteSpeed cấp hai lần
  trial, mãi mãi. Bước webserver chỉ xin key trial **khi máy chưa có key
  LiteSpeed nào**; đã có key - kể cả key hết hạn - thì không bao giờ xin thêm.
- **Serial:** giấy phép LiteSpeed Enterprise đã mua, lưu bằng
  `snpanel build license` trước khi build.

**1. Xem máy đang chạy gì.**

```bash
snpanel build show
snpanel doctor
```

Trên máy mới cài, `show` kết thúc bằng:

```text
Running: nginx with php-fpm; nginx answers 80/443
```

**2. Khai báo LiteSpeed.**

```bash
snpanel build set webserver litespeed     # php_mode tự thành lsphp
snpanel build set lsws_license trial      # hoặc serial, xem dưới
snpanel build set php_versions 8.4,8.3    # tuỳ chọn; bản đầu là mặc định
snpanel build set lsws_auto_return yes    # mặc định
snpanel build show
```

Dùng serial thay cho trial:

```bash
snpanel build license                     # dán serial rồi Enter
snpanel build set lsws_license serial
```

`snpanel build license` hỏi serial và trả lời:

```text
LiteSpeed serial number:
Serial stored (root only). Set `lsws_license = serial` and run the webserver step to use it.
```

Serial dài 8 đến 64 ký tự, gồm chữ, số hoặc `+ / = -`. Serial được giữ trong
`/var/lib/snpanel-build/` (chỉ root).

**3. Chạy thử (tuỳ chọn).**

```bash
snpanel build preview --wait
```

Trên máy AlmaLinux mới cài, preview có thể báo phpMyAdmin sẽ bị gỡ cùng nginx:
lúc đó Apache chưa được cài. Đến cutover, Apache đã có, trình quản lý gói
được hỏi lại và phpMyAdmin được giữ. Nếu cutover vẫn liệt kê gói sẽ bị gỡ
cùng nginx thì job dừng lại và hỏi; hãy huỷ job, trừ khi bạn thật sự muốn gỡ
các gói đó.

**4. Build và chuyển.**

```bash
snpanel build all --wait
```

Kết quả mong đợi (rút gọn):

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

| Bước | Việc làm |
|---|---|
| `preflight` | Kiểm tra mọi điều ở "Trước khi bắt đầu". |
| `update` | Thông tin gói, bản LiteSpeed mới nhất, bộ OWASP CRS đã ghim. |
| `webserver` | Apache dự phòng ở 8080/8443, LiteSpeed Enterprise ở 9080/9443, giấy phép. |
| `php` | lsphp cho mọi phiên bản PHP, handler của LiteSpeed. |
| `waf` | ModSecurity và bộ luật cho Apache và LiteSpeed. |
| `rewrite_confs` | Ghi lại vhost của mọi website. |
| `cutover` | So từng site trên stack mới với những gì nginx đang trả, chuyển 80/443 sang LiteSpeed không gián đoạn, gỡ nginx sau cùng. |

Trên VPS 4 CPU, cả job mất khoảng bốn phút.

**Nếu job dừng:**

```bash
snpanel build status bj-xxxxxxxxxxxx              # từng bước, trạng thái và thông báo
journalctl -u snpanel-build-bj-xxxxxxxxxxxx -f    # mọi thứ job ghi ra
snpanel build retry bj-xxxxxxxxxxxx --wait        # chạy lại từ bước bị dừng
snpanel build cancel bj-xxxxxxxxxxxx              # dừng job (đang cutover thì quay về nginx)
```

Khi một site sẽ trả lời khác đi trên stack mới, job dừng với `needs_accept`,
in ra các khác biệt và dòng
`To go on anyway: snpanel build retry bj-xxxxxxxxxxxx --accept-diffs`. Chỉ
chạy lệnh đó khi các khác biệt là đúng như bạn mong đợi.

Bạn cũng có thể chạy từng bước một (`update`, `webserver`, `php`, `waf`,
`rewrite_confs`, mỗi lệnh kèm `--wait`). Chỉ `all` mới chuyển 80/443; chạy
`all` sau các bước riêng chỉ làm nốt phần còn lại.

**5. Kiểm tra.**

```bash
snpanel build live
snpanel doctor                                     # web-stack, web-live, webwatch, lsws-licence, web-table: ok
curl -sI http://<một site>/ | grep -i '^server'    # Server: LiteSpeed
snpanel doctor --isolation                         # không khách hàng nào vào được home của người khác
```

Ví dụ `snpanel build live` in ra:

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

Sau cutover: LiteSpeed trả 80/443; Apache chạy dự phòng ở 8080/8443; nginx đã
gỡ; home của mọi khách hàng là 0750, web server nằm trong group của từng
khách hàng; phpMyAdmin và vhost công cụ của panel do Apache/LiteSpeed phục
vụ.

<a id="muc-6-5"></a>
### 6.5 Watchdog, tự quay về và giấy phép

`snpanel-webwatch.service` canh LiteSpeed:

- Mỗi giây thăm dò LiteSpeed một lần. Ba lần liên tiếp không trả lời thì
  chuyển 80/443 sang Apache, trong vài giây. Apache cũng không trả lời thì
  khởi động lại Apache một lần.
- Năm phút kiểm giấy phép một lần. Giấy phép không hợp lệ thì chuyển các site
  sang Apache, và không bao giờ khởi động lại hay nạp lại LiteSpeed với giấy
  phép đó (nạp lại với key hỏng sẽ làm LiteSpeed dừng).
- **Tự quay về** (`lsws_auto_return = yes`): sau failover, các site về lại
  LiteSpeed khi giấy phép kiểm lại hợp lệ, LiteSpeed đã trả lời đủ 5 phút, và
  đã qua 10 phút kể từ lần chuyển gần nhất.
- Addon Thông báo báo cho quản trị viên mỗi lần failover và quay về, giấy phép
  còn 7, 3 hoặc 1 ngày, và giấy phép đã hết hạn.

Làm bằng tay:

```bash
snpanel build switch apache              # 80/443 sang Apache ngay
snpanel build switch litespeed           # quay về; chỉ khi LiteSpeed trả lời và giấy phép hợp lệ
snpanel build set lsws_auto_return no    # ở lại Apache cho tới khi bạn tự chuyển về
snpanel build license-check              # kiểm giấy phép ngay
```

**Khi trial hoặc giấy phép hết hạn:**

1. Trong vòng 5 phút, watchdog chuyển 80/443 sang Apache. Các site vẫn chạy
   trên Apache, cùng vhost, cùng PHP.
2. LiteSpeed không bị nạp lại.
3. Muốn quay lại LiteSpeed thì cài serial:

   ```bash
   snpanel build license                    # dán serial
   snpanel build set lsws_license serial
   snpanel build license-check              # đăng ký serial và kiểm tra
   ```

   Tự quay về sẽ đưa các site về; nếu tắt tự quay về thì chạy
   `snpanel build switch litespeed`.
4. Hoặc quay về nginx ([6.7](#muc-6-7)).

Khi máy còn bất kỳ key nào, build không xin trial mới.

<a id="muc-6-6"></a>
### 6.6 LiteSpeed WebAdmin (cổng 7080)

**Nội bộ (mặc định).** WebAdmin chỉ nghe ở 127.0.0.1. Vào bằng SSH tunnel:

```bash
ssh -L 7080:127.0.0.1:7080 root@<máy chủ>
# rồi mở https://127.0.0.1:7080 trong trình duyệt; tên đăng nhập: admin
cat /var/lib/snpanel-build/lsws-webadmin-password    # chỉ root đọc được
```

**Đặt lại mật khẩu.** Trang **Máy chủ web & PHP** đặt mật khẩu WebAdmin mới và
hiện một lần. Qua SSH:

```bash
snpanel-helper lsws-admin-password    # in tên đăng nhập (admin) và mật khẩu mới một lần, dạng JSON
```

Mật khẩu mới cũng được ghi vào `/var/lib/snpanel-build/lsws-webadmin-password`.
Nó hiện trên terminal của bạn: hãy xoá màn hình sau đó.

**Công khai, kèm danh sách cho phép.**

```bash
snpanel build set lsws_admin_allow 203.0.113.5,198.51.100.0/24
snpanel build set lsws_admin public      # áp ngay, mọi lần build và cập nhật đều giữ
snpanel build set lsws_admin local       # về lại loopback
```

Mỗi lệnh báo đúng điều đã xảy ra, ví dụ
`lsws_admin = public (applied: WebAdmin listens on *:7080)`, hoặc báo thay đổi
phải chờ LiteSpeed khởi động lần tới. Chế độ công khai mở cổng 7080 trên tường
lửa của panel và phục vụ WebAdmin qua TLS; `lsws_admin_allow` để trống là cho
mọi địa chỉ. Về lại `local` thì luật tường lửa do panel thêm được gỡ.

Panel quản lý cấu hình của LiteSpeed: những gì sửa trong WebAdmin đè lên phần
panel ghi sẽ bị ghi đè ở lần build hoặc cập nhật sau.

<a id="muc-6-7"></a>
### 6.7 Quay về nginx, hoặc chỉ dùng Apache

```bash
snpanel build set webserver nginx
snpanel build all --wait                      # nginx phục vụ lại; LiteSpeed và Apache được giữ, đã dừng
snpanel build all --remove-litespeed --wait   # như trên, và gỡ LiteSpeed và Apache
```

- Sau `--remove-litespeed`, key giấy phép được cất riêng, nên lần sau quay lại
  LiteSpeed sẽ dùng lại key đó, không xin trial mới.
- **Chỉ Apache**, với PHP-FPM:

  ```bash
  snpanel build set webserver apache          # php_mode thành php-fpm
  snpanel build all --wait
  ```

<a id="muc-6-8"></a>
### 6.8 Siết máy chủ và cách tắt

Mỗi lần cài và cập nhật đều ghi `/etc/sysctl.d/90-snpanel-hardening.conf` và
áp ngay (không cần khởi động lại):

- Tắt user namespace. Trên AlmaLinux là `user.max_user_namespaces = 0`, sau khi
  các dịch vụ cần namespace đã có drop-in hoặc giữ thiết lập tắt (`snpanel
  doctor` nêu tên chúng). Debian dùng `kernel.unprivileged_userns_clone = 0`;
  Ubuntu giữ `kernel.apparmor_restrict_unprivileged_userns = 1`.
- `dev.tty.legacy_tiocsti = 0` (kernel 6.2 trở lên).

Muốn giữ user namespace như bản phân phối (container rootless, sandbox của
Chrome):

```bash
SNPANEL_HARDEN_USERNS=no snpanel-helper host-harden    # ghi harden_userns = no vào build.conf và áp ngay
SNPANEL_HARDEN_USERNS=yes snpanel-helper host-harden   # bật lại phần siết
```

`no`, `off`, `false` và `0` đều là tắt. Bạn cũng có thể ghi `harden_userns = no`
vào `/etc/snpanel/build.conf` rồi chạy `snpanel-helper host-harden`, hoặc đặt
biến này khi chạy `install.sh` hay `snpanel-update`. Các lần cập nhật sau đều
giữ lựa chọn. `.env` của panel không được đọc cho việc này.

---

<a id="muc-7"></a>
## 7. Chẩn đoán và log

<a id="muc-7-1"></a>
### 7.1 `snpanel doctor`

```bash
snpanel doctor                          # mọi mục kiểm tra
snpanel doctor --json                   # như trên, dạng JSON
snpanel doctor --isolation              # chỉ kiểm: khách hàng không vào được home của nhau
snpanel doctor --enterprise-readiness   # chỉ kiểm: máy có chuyển lên CloudLinux được không (chỉ đọc, không cần giấy phép)
```

- Mọi mục kiểm tra chỉ đọc; `doctor` không sửa gì.
- Các mục gồm hệ điều hành và CPU, cấu hình và khoá bí mật của panel, tường
  lửa, SELinux, phpMyAdmin, web stack (`web-stack`, `web-live`, `web-table`,
  `webwatch`, `lsws-licence`), sự cách ly giữa các tài khoản, đường dẫn và
  quyền tệp của panel, giới hạn tài nguyên, lồng của Terminal, Valkey và phần
  siết máy chủ.
- Mỗi kết quả là `ok`, `note`, `warn` hoặc `FAIL`, kèm việc cần làm.
- **Mã thoát:** 0 khi không có vấn đề, 1 khi có cảnh báo, 2 khi có lỗi - dùng
  được cho hệ thống giám sát.
- `--isolation` kiểm, dưới danh nghĩa từng khách hàng, rằng
  `stat /home/<người khác>/.` thất bại.
- `--enterprise-readiness` kiểm AlmaLinux 10, CPU x86-64-v3, không phải
  container, RAM và đĩa.

### 7.2 Kiểm tra nhanh khác

```bash
snpanel status                 # hệ điều hành, cổng/địa chỉ/SSL của panel, dịch vụ, tường lửa
snpanel logs -n 100            # journal của panel
snpanel firewall status        # trạng thái và luật tường lửa
snpanel build live             # stack LiteSpeed: ai trả 80/443, giấy phép
```

### 7.3 Log nằm ở đâu

| Thành phần | Vị trí |
|---|---|
| Panel | `journalctl -u snpanel-api` (hoặc `snpanel logs`) |
| Helper root | `journalctl -u snpanel-helper`; nhật ký kiểm toán: `journalctl -t snpanel-helper` (ví dụ `journalctl -t snpanel-helper F_OP=firewall-deny-ip`) |
| Cập nhật panel | `journalctl -u snpanel-panel-update.service`; trang Cập nhật |
| Build web stack | `snpanel build status <job>`, `journalctl -u snpanel-build-<job>` |
| Watchdog LiteSpeed | `journalctl -u snpanel-webwatch`; các lần chuyển: `/var/log/snpanel-webswitch.log` |
| nginx | `/var/log/nginx/`; một site: `/var/log/nginx/<tên miền>.access.log`, `<tên miền>.error.log` |
| Site trên Apache và LiteSpeed | AlmaLinux: `/var/log/httpd/<tên miền>.access.log`, `<tên miền>.error.log`; Debian/Ubuntu: `/var/log/apache2/` |
| Bản thân LiteSpeed | `/usr/local/lsws/logs/` |
| Exim (addon Email) | AlmaLinux: `/var/log/exim/`; Debian/Ubuntu: `/var/log/exim4/`; mục Nhật ký gửi thư của trang Email |
| Dovecot (addon Email) | `journalctl -u dovecot` |
| Rspamd, webmail | `journalctl -u rspamd`, `journalctl -u snpanel-webmail` |
| Thư gửi cho root và tài khoản hệ thống | `/var/log/snpanel-mail/system-mail.log` |
| Fail2ban (addon) | `/var/log/fail2ban.log` |
| MariaDB | `journalctl -u mariadb` |
| PHP-FPM của một tài khoản | `journalctl -u snpanel-php-fpm-<user>-<phiên bản>` |
| Tường lửa | `nft list table inet snpanel`; luật: `/var/lib/snpanel/firewall/rules.tsv` |

### 7.4 Sự cố thường gặp

| Sự cố | Cách xử lý |
|---|---|
| Panel không tải được | `snpanel status`, `snpanel logs -n 100`, `snpanel restart`. |
| Bị tường lửa khoá ngoài (vào bằng console) | `snpanel repair-firewall`; vẫn bị khoá: `snpanel-rescue-firewall` ([8.4](#muc-8-4)). |
| Quên mật khẩu admin | `snpanel login`, hoặc `snpanel change-admin-password`. |
| Mất ứng dụng xác thực hoặc passkey | `snpanel reset-admin-2fa`. |
| Máy chủ đổi địa chỉ IP | `snpanel change-ip OLD_IP NEW_IP`, rồi `snpanel doctor`. |
| Chứng chỉ của panel hết hạn hoặc sai | `snpanel install-panel-ssl`. |
| Tệp thuộc root sau khi chép tay | `snpanel fix-permissions`. |
| Giao diện cũ sau khi cập nhật | Tải lại bằng Ctrl + Shift + R. |
| Trang Cập nhật không thấy v2.0.0 | Máy cài trước v2.0.0: chạy lệnh cài khởi động một lần ([4.4](#muc-4-4)). |
| Job build dừng | `snpanel build status <job>`, sửa nguyên nhân, `snpanel build retry <job> --wait`. |
| Giấy phép LiteSpeed hết hạn | Các site đã ở trên Apache; xem [6.5](#muc-6-5). |
| Dovecot hoặc Exim dừng sau khi nâng cấp bản phân phối (addon Email) | `snpanel-helper mail-reconfigure`, hoặc lần cập nhật panel kế tiếp. |
| Một dịch vụ cần user namespace và không khởi động được | `snpanel doctor` nêu tên nó; xem [6.8](#muc-6-8). |

---

<a id="muc-8"></a>
## 8. Cứu hộ và quản trị hằng ngày

<a id="muc-8-1"></a>
### 8.1 Menu cứu hộ

`snpanel` (hoặc `snpanel menu`) mở menu trong terminal:

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

Mỗi mục là lệnh cùng tên ở [mục 5](#muc-5). Không có terminal thì lệnh chỉ
in menu rồi dừng.

<a id="muc-8-2"></a>
### 8.2 Trạng thái, log và khởi động lại

```bash
snpanel status
snpanel logs                 # 200 dòng gần nhất
snpanel logs -n 50 -f        # 50 dòng, rồi theo dõi tiếp
snpanel restart              # panel, rồi nginx
```

Trên stack LiteSpeed và Apache, nginx không còn được cài: ở v2.0.0,
`snpanel restart` khởi động lại panel rồi dừng với `restarting nginx failed`.
Panel vẫn đã được khởi động lại. Web server ở đó do watchdog lo:
`snpanel build live`, `snpanel build switch`.

### 8.3 Mật khẩu admin và đăng nhập hai bước

```bash
snpanel login                       # địa chỉ, tên đăng nhập, mật khẩu (/root/login.txt)
snpanel change-admin-password       # hỏi hai lần; cập nhật /root/login.txt; đăng xuất mọi phiên
snpanel sync-admin-root-password    # admin (panel và Linux) dùng hash mật khẩu của root
snpanel reset-admin-2fa             # tắt ứng dụng xác thực và mọi passkey
```

- Mật khẩu không bao giờ nằm trên dòng lệnh: bạn gõ ở dấu nhắc.
- `sync-admin-root-password` không đọc lại được mật khẩu root từ hash; lệnh
  hỏi bạn gõ nếu muốn ghi vào `/root/login.txt` (để trống là bỏ qua).

<a id="muc-8-4"></a>
### 8.4 Tường lửa

Tường lửa của panel là bảng nftables `inet snpanel`, luật nằm trong
`/var/lib/snpanel/firewall/rules.tsv`. Cổng SSH, cổng panel và 80, 443, 465,
587 luôn mở.

```bash
snpanel firewall status             # trạng thái và luật
snpanel repair-firewall             # mở lại cổng panel và SSH (hoặc: snpanel firewall reopen)
snpanel firewall rescue             # xoá bảng nftables của panel: panel không lọc gì cho tới khi áp lại
snpanel firewall migrate-nft --dry-run   # in bộ luật nftables panel sẽ nạp, dựng từ rules.tsv
snpanel-rescue-firewall             # cách cuối cùng, xem dưới
```

- `repair-firewall` / `firewall reopen` dựng lại bảng, thêm luật cho cổng SSH
  nếu khác 22.
- `firewall rescue` chỉ xoá bảng của panel; các bảng khác (Docker, fail2ban)
  giữ nguyên. Tường lửa có lại ở lần thay đổi kế tiếp, khi khởi động máy, hoặc
  khi chạy `snpanel repair-firewall`.
- `firewall migrate-nft` dành cho máy còn lọc bằng iptables/ipset kiểu cũ. Mỗi
  lần cập nhật đã tự chuyển máy như vậy sang nftables, và
  `snpanel repair-firewall` nạp đúng bộ luật đó. Ở v2.0.0, `migrate-nft` không
  kèm `--dry-run` sẽ từ chối và nói rõ.
- **`snpanel-rescue-firewall`** lưu trạng thái hiện tại vào
  `/root/snpanel-firewall-rescue-<thời điểm>/` (kèm bản sao `rules.tsv`), gỡ
  UFW, chain iptables và ipset cũ cùng bảng của panel, **xoá trắng các luật
  cho phép và chặn của panel** cùng các địa chỉ blocklist đã tải, rồi dựng lại
  tường lửa chỉ với các cổng được bảo vệ (SSH, cổng panel, 80, 443, 465, 587).
  Các URL blocklist vẫn giữ và được bộ hẹn giờ hằng ngày tải lại. Sau đó hãy
  thêm lại luật của bạn ở trang Tường lửa.

### 8.5 Địa chỉ panel, chứng chỉ và địa chỉ IP

```bash
snpanel set-panel-url              # hỏi tên miền (để trống: IP của máy) và cổng
snpanel install-panel-ssl          # hỏi tên miền và e-mail Let's Encrypt
snpanel change-ip                  # hỏi địa chỉ cũ và mới
snpanel change-ip 203.0.113.10 203.0.113.20
```

- `install-panel-ssl` cấp chứng chỉ qua webroot của web server: không website
  nào bị ngắt trong lúc chạy.
- `change-ip` thay địa chỉ trong `.env` của panel, cấu hình nginx, phpMyAdmin,
  các unit systemd của panel và `/etc/hosts`, chép từng file ra bản sao lưu
  trước. Chạy `snpanel doctor` sau đó.

### 8.6 Quyền tệp

```bash
snpanel fix-permissions
```

Đặt lại chủ sở hữu và quyền tệp của panel và các website như lúc trình cài để
lại, cùng khối SFTP trong `sshd_config` (kiểm bằng `sshd -t`, không qua thì
khôi phục bản cũ). Chạy khi không có lỗi gì cũng an toàn.

<a id="muc-8-7"></a>
### 8.7 Giới hạn tài nguyên và AutoSSL

```bash
snpanel limits show alice    # slice của tài khoản, những gì panel đã áp, các master PHP-FPM
snpanel limits resync        # áp lại giới hạn của mọi tài khoản từ cơ sở dữ liệu
snpanel autossl              # mọi website ngay: cấp khi tên miền trỏ về đây, gia hạn khi tới hạn
```

Website đang tạm dừng AutoSSL thì vẫn giữ trạng thái tạm dừng.

### 8.8 Những gì không có lệnh

Người dùng, gói, website, cơ sở dữ liệu, sao lưu và khôi phục, cron, addon,
email, DNS, WordPress và WAF được quản lý **trong panel**. Lệnh `snpanel`
không có lệnh con cho chúng. Muốn tự động hoá thì có:

- API cấp tài khoản mà module WHMCS dùng (token API tạo ở
  **Cài đặt > Cài đặt panel > API token**);
- addon MCP server, cho trợ lý AI.

---

<a id="muc-9"></a>
## 9. Các thao tác `snpanel-helper` dành cho quản trị viên

`snpanel-helper` là helper chạy quyền root của panel. Panel gọi nó qua
`/run/snpanel/helper.sock`; root chạy trực tiếp một thao tác bằng
`snpanel-helper <thao tác>`. `snpanel-helper --help` liệt kê tất cả (292 thao
tác ở v2.0.0). Phần lớn là việc riêng của panel: chỉ nên tự chạy các thao tác
sau.

| Lệnh | Việc làm |
|---|---|
| `snpanel-helper host-harden` | Áp lại phần siết máy chủ ([6.8](#muc-6-8)). |
| `snpanel-helper php-fpm-retune` | Tính lại kích thước mọi pool PHP-FPM theo RAM, CPU và các thiết lập `SNPANEL_PHP_FPM_*` trong `.env`. |
| `snpanel-helper mariadb-retune` | Ghi lại file tinh chỉnh MariaDB theo RAM, CPU và các thiết lập `SNPANEL_MARIADB_*`; **khởi động lại MariaDB**. |
| `snpanel-helper lsws-admin-password` | Mật khẩu LiteSpeed WebAdmin mới, in ra một lần ([6.6](#muc-6-6)). |
| `snpanel-helper mail-reconfigure` | Ghi lại file của Dovecot, Exim và webmail cho bản này (addon Email). |
| `snpanel-helper clamav-db-status` | Bộ dữ liệu nhận diện mã độc đang dùng, dạng JSON (addon Quét mã độc). |
| `snpanel-helper malware-sigs-update` | Cập nhật dữ liệu nhận diện của ClamAV và LMD ngay (addon Quét mã độc). |

Mọi lần gọi đều được ghi lại: `journalctl -t snpanel-helper`.

`snpanel-install` là công cụ chạy từng phần của trình cài, do script cài và
cập nhật gọi; không dùng để chạy tay.

---

<a id="muc-10"></a>
## 10. Addon và vị trí trong panel

Addon được cài và gỡ ở **Cài đặt > Addon** (hoặc **Tổng quan > Tiện ích mở
rộng > Quản lý addon**). Gỡ addon không bao giờ xoá dữ liệu của nó. Không addon
nào có lệnh riêng; đường dẫn menu dưới đây là của quản trị viên.

| Addon | Việc làm | Vị trí trong panel |
|---|---|---|
| Email | Hộp thư và chuyển tiếp với Exim, Dovecot và Rspamd; webmail | Tổng quan > Email (Hộp thư, Chuyển tiếp thư, Nhật ký gửi thư, SMTP relay, Cài đặt ứng dụng mail); Webmail ở `https://<tên máy>:2096` |
| DNS Manager | PowerDNS cho tên miền của các website | Tổng quan > Website & tên miền > DNS |
| WordPress Manager | Bộ công cụ WP-CLI: cập nhật, bảo mật, đăng nhập một chạm, staging, điểm khôi phục | Thanh bên > WordPress Manager |
| Sao lưu tăng dần | Sao lưu bằng restic ra đĩa, SFTP hoặc S3; khách hàng tự khôi phục | Tổng quan > Tệp & sao lưu > Sao lưu tăng dần; khách hàng: Sao lưu & Khôi phục > Sao lưu tăng dần |
| Nhập từ cPanel | Tài khoản từ bản sao lưu cPanel, hoặc kéo từ máy chủ cPanel | Tổng quan > Chuyển dữ liệu > Nhập từ cPanel |
| Nhập từ DirectAdmin | Người dùng từ bản sao lưu DirectAdmin, hoặc kéo từ máy chủ DirectAdmin | Tổng quan > Chuyển dữ liệu > Nhập từ DirectAdmin |
| Nhập từ FastPanel | Người dùng kéo từ máy chủ FASTPANEL | Tổng quan > Chuyển dữ liệu > Nhập từ FastPanel |
| Fail2ban | Chặn địa chỉ đăng nhập sai nhiều lần | Bảo mật > Fail2ban |
| Quét mã độc | ClamAV và Linux Malware Detect, cách ly | Bảo mật > Quét mã độc |
| MCP server | Trợ lý AI (Claude Code, Cursor, VS Code) qua `/api/mcp` | Tổng quan > Nâng cao > Trợ lý AI |
| Thông báo | Cảnh báo qua e-mail và Telegram cho quản trị viên | Cài đặt > Thông báo |
| Application | Ứng dụng Node.js, container Docker và dự án Compose | Tổng quan > Website & tên miền > Ứng dụng |

**CloudLinux** không phải addon. Trang **CloudLinux Manager** (cùng các trang
Mức dùng tài nguyên và Phiên bản PHP của khách hàng) chỉ hiện trên máy chủ
CloudLinux, mà các lệnh ở đây không cài.

---

<a id="muc-11"></a>
## 11. Gỡ cài đặt

v2.0.0 không có lệnh gỡ cài đặt. SNPanel thay đổi tường lửa, sshd, thiết lập
kernel, PHP, MariaDB và web server, nên cách sạch sẽ để quay lại là cài lại hệ
điều hành (hoặc dùng snapshot VPS chụp trước khi cài). Addon thì gỡ được ở
**Cài đặt > Addon**; dữ liệu của addon được giữ lại.

---

<a id="muc-12"></a>
## 12. Ghi chú bảo mật

**Các bí mật nằm ở đâu** (panel không bao giờ hiện lại chúng):

| File | Chứa | Ai đọc được |
|---|---|---|
| `/root/login.txt` | mật khẩu `admin` | root (0600) |
| `/opt/snpanel/backend/.env` | `SECRET_KEY` và các thiết lập của panel | root và tài khoản của panel (0640) |
| `/opt/snpanel/.my.cnf` | thông tin đăng nhập MariaDB của panel | tài khoản của panel (0600) |
| `/etc/snpanel/` | chứng chỉ của panel, `build.conf` | root và group của panel |
| `/var/lib/snpanel-build/` | serial LiteSpeed, mật khẩu WebAdmin, các job build | chỉ root (0700) |

- Mật khẩu cơ sở dữ liệu được mã hoá khi lưu, bằng `SECRET_KEY`.
- Panel chạy bằng user `snpanel`, không phải root; việc cần đặc quyền đi qua
  `snpanel-helper`, helper này kiểm tra người gọi và từng tham số, và ghi lại
  mọi lần gọi.
- Lệnh nào nhận bí mật thì đọc từ dấu nhắc hoặc đầu vào chuẩn
  (`snpanel build license`, `change-admin-password`), không bao giờ từ dòng
  lệnh, nơi mọi user trên máy đều đọc được.
- **Terminal** (bash thật trong lồng riêng của từng tài khoản) **tắt** với
  khách hàng mới, trừ khi gói của họ bật.
- **Kênh phát hành.** Bản phát hành chỉ đến từ
  [vnscorpion/snpanel-releases](https://github.com/vnscorpion/snpanel-releases).
  Lệnh cài khởi động và mọi lần cập nhật kiểm gói với `SHA256SUMS` đi kèm trước
  khi giải nén, và từ chối gói không có file này. `SNPANEL_RELEASE_REPO` chỉ
  đọc từ môi trường, không bao giờ từ `.env` của panel.

Tự kiểm tra một gói:

```bash
tag=v2.0.0
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/snpanel-$tag-x86_64-linux.tar.gz
curl -fsSLO https://github.com/vnscorpion/snpanel-releases/releases/download/$tag/SHA256SUMS
sha256sum -c SHA256SUMS
```
