# Nâng cấp từ nginx lên LiteSpeed Enterprise

[English](litespeed.md) | **Tiếng Việt**

SNPanel mới cài chạy website bằng nginx và PHP-FPM. Bạn có thể chuyển máy
sang LiteSpeed Enterprise bằng một job build, theo kiểu CustomBuild của
DirectAdmin:

- Apache vẫn được cài và chạy dự phòng nóng.
- LiteSpeed ngừng trả lời hoặc giấy phép hết hợp lệ thì watchdog chuyển các
  site sang Apache trong vài giây.
- LiteSpeed ổn trở lại thì watchdog đưa các site về LiteSpeed.

Mọi lệnh dưới đây chạy bằng root qua SSH. Trang **Máy chủ › Máy chủ web & PHP**
của panel làm được những việc này bằng nút bấm.

## Trước khi bắt đầu

- **AlmaLinux 10, Debian 13 hoặc Ubuntu 24.04.**
  - Rocky Linux và RHEL 10 đi đường của AlmaLinux. Debian 12 đi đường của
    Debian 13 nhưng chưa được thử trên máy thật. Ubuntu 24.04 đi đường của
    Debian, với những khác biệt ở
    [Ubuntu 24.04: những gì khác](#ubuntu-2404-nhung-gi-khac).
  - Đường này không hỗ trợ CloudLinux.
- **Đĩa và RAM.** Trống ít nhất 5 GB trên `/`. RAM dưới 4 GB thì nên thêm
  swap 2 GB trước.
- **Mạng.** Máy phải kết nối được tới `license.litespeedtech.com`.
- **Cổng trống.** Không có gì khác đang nghe ở 8080/8443 (Apache) hay
  9080/9443 (LiteSpeed).
- **lsphp lấy từ đâu.**
  - AlmaLinux: kho PHP Remi phải đã cấu hình (trình cài làm việc này).
  - Debian và Ubuntu: bước update thêm kho apt của chính LiteSpeed
    (`rpms.litespeedtech.com/debian`), khoá ký kèm theo panel và được ghim;
    lsphp là các gói `lsphpXY`.
  - Mọi phiên bản PHP mà site đang dùng phải đã cài.
- **Không có job đang chạy.** Không có job khôi phục, nhập hay sao lưu nào.
  Build không chờ: nó từ chối và nói job nào đang chạy.
- **Giấy phép.** Trial hoặc serial:
  - **Trial:** 14 ngày. Mỗi địa chỉ IP chỉ được LiteSpeed cấp hai lần trial,
    mãi mãi.
  - **Serial:** giấy phép LiteSpeed Enterprise đã mua.
- **Snapshot VPS** trước khi đổi web server là nên làm.

## 1. Xem máy đang chạy gì

```bash
snpanel build show       # build.conf và stack đang chạy
snpanel doctor           # mọi mục nên ok trước khi đổi web server
```

## 2. Khai báo LiteSpeed trong build.conf

```bash
snpanel build set webserver litespeed     # php_mode tự thành lsphp
snpanel build set lsws_license trial      # hoặc: serial (xem dưới)
snpanel build set php_versions 8.4,8.3    # tuỳ chọn: các bản PHP cần dựng; bản đầu là mặc định
snpanel build set lsws_auto_return yes    # mặc định: tự quay về LiteSpeed sau khi failover
snpanel build show
```

`set` chỉ ghi `/etc/snpanel/build.conf`, sau khi kiểm tra giá trị. Lệnh này
không cài gì.

### Dùng serial thay cho trial

Serial được đọc từ đầu vào chuẩn (stdin), nên không bao giờ nằm trên dòng
lệnh hay trong lịch sử shell:

```bash
snpanel build license                     # dán serial rồi Enter
snpanel build set lsws_license serial
```

### Về trial

- Bước webserver chỉ xin LiteSpeed một key trial **khi máy chưa có key
  LiteSpeed nào**.
- Đã có key - kể cả key hết hạn - thì build không tự xin trial khác.

## 3. Chạy thử (tuỳ chọn)

```bash
snpanel build preview --wait
```

`preview` chạy preflight và bước update ở chế độ chạy thử. Lệnh cho xem kế
hoạch và không đổi gì.

Trên Debian, plugin nginx của certbot (`python3-certbot-nginx`) phụ thuộc
nginx nên bị gỡ cùng nginx: điều này đã được tính, cutover chuyển việc gia hạn
mọi chứng chỉ ra khỏi plugin đó trước, và khi quay về nginx thì gói được cài
lại.

Trên máy AlmaLinux mới cài, preview có thể báo rằng trình quản lý gói sẽ gỡ
luôn phpMyAdmin cùng nginx. Lý do là lúc đó Apache chưa được cài. Đến bước
cutover, Apache đã có, trình quản lý gói được hỏi lại và phpMyAdmin được giữ.
Nếu cutover vẫn liệt kê gói sẽ bị gỡ cùng nginx thì job dừng lại và hỏi. Hãy
huỷ job, trừ khi bạn thật sự muốn gỡ các gói đó.

## 4. Build và chuyển

```bash
snpanel build all --wait
```

`all` chạy một job nền gồm các bước sau. Trên VPS 4 CPU, cả job mất khoảng
bốn phút.

| Bước | Việc làm |
|---|---|
| `preflight` | Kiểm tra mọi điều ở trên. |
| `update` | Thông tin gói, bản LiteSpeed mới nhất, bộ OWASP CRS đã ghim. |
| `webserver` | Cài Apache dự phòng ở 8080/8443 và LiteSpeed Enterprise ở 9080/9443, cài giấy phép. |
| `php` | lsphp cho mọi phiên bản PHP, handler của LiteSpeed. |
| `waf` | ModSecurity và bộ luật cho Apache và LiteSpeed. |
| `rewrite_confs` | Ghi lại vhost của mọi website. |
| `cutover` | So từng site trên stack mới với những gì nginx đang trả, chuyển 80/443 sang LiteSpeed không gián đoạn, gỡ nginx sau cùng. |

- Job chạy trong unit systemd riêng (`snpanel-build-<job>`). Đóng SSH, khởi
  động lại panel hay cập nhật panel đều không làm job dừng. Cập nhật panel
  chờ job xong.
- `--wait` theo dõi job và in log của từng bước. Không có `--wait` thì lệnh
  in mã job rồi thoát.
- Job dừng ở bước nào thì sửa nguyên nhân rồi chạy lại từ bước đó bằng
  `snpanel build retry <job>`.
- **Từng bước một.** Bạn cũng có thể chạy riêng `snpanel build update`,
  `webserver`, `php`, `waf` và `rewrite_confs` (mỗi lệnh kèm `--wait`). Chỉ
  `all` mới chuyển 80/443. Bước nào xong rồi thì tự bỏ qua, nên chạy `all`
  sau các bước riêng chỉ làm nốt phần còn lại.

### Theo dõi job

```bash
snpanel build status                 # các job gần đây: mã, loại, trạng thái, lúc bắt đầu
snpanel build status bj-xxxxxxxxxxxx # một job: từng bước, trạng thái và thông báo
journalctl -u snpanel-build-bj-xxxxxxxxxxxx -f    # toàn bộ log của unit
snpanel build cancel bj-xxxxxxxxxxxx # dừng ở điểm an toàn kế tiếp (trong cutover: quay về nginx)
snpanel build retry bj-xxxxxxxxxxxx  # chạy lại từ bước bị dừng
```

- Cutover so mọi site qua stack mới với nginx. Có site trả khác thì job dừng
  (`needs_accept`). Xem các khác biệt được liệt kê.
- Khác biệt đó là bình thường thì chạy tiếp bằng
  `snpanel build retry <job> --accept-diffs`. Lệnh này không bao giờ cho qua
  một site sẽ lộ mã nguồn PHP.
- Phần so sánh đọc `.htaccess` của từng thư mục để tìm thư mục mà server hiện
  tại đóng (mật khẩu hoặc deny) còn nginx — vốn không đọc `.htaccess` — sẽ để
  mở. Nhưng nó **không** đọc các `.htaccess` nằm trong cây mã nguồn của
  WordPress (`wp-content/plugins`, `wp-content/themes`, `wp-content/mu-plugins`).
  `.htaccess` của một plugin hay theme (Akismet có sẵn một cái) đóng thư mục đó
  trên Apache và LiteSpeed nhưng chưa bao giờ đóng trên nginx, nên đó không
  phải khác biệt do việc chuyển gây ra. Mọi thư mục khác, kể cả
  `wp-content/uploads`, đều được đọc.

## 5. Kiểm tra

```bash
snpanel build live        # ai trả 80/443, hai web server, giấy phép, watchdog, WebAdmin
snpanel doctor            # web-stack, web-live, webwatch, lsws-licence, web-table đều phải ok
curl -sI http://<một site>/ | grep -i '^server'    # Server: LiteSpeed
```

Sau khi chuyển:

- LiteSpeed trả 80/443.
- Apache chạy ở 8080/8443 làm dự phòng.
- nginx đã được gỡ.
- Thư mục home của mọi khách hàng là 0750, và web server nằm trong nhóm của
  từng khách hàng. `snpanel doctor --isolation` kiểm rằng không khách hàng
  nào vào được home của người khác.
- phpMyAdmin và vhost công cụ của panel do Apache/LiteSpeed phục vụ.

## 6. Watchdog và quay về LiteSpeed

`snpanel-webwatch.service` canh LiteSpeed:

- **Thử LiteSpeed mỗi giây.** Hỏng ba lần liên tiếp thì chuyển 80/443 sang
  Apache, trong vài giây. Apache cũng không trả lời thì khởi động lại Apache
  một lần.
- **Kiểm giấy phép mỗi 5 phút.** Giấy phép không hợp lệ thì chuyển site sang
  Apache, và không bao giờ khởi động lại hay reload LiteSpeed. Reload với key
  hỏng sẽ làm LiteSpeed dừng.
- **Tự quay về** (`lsws_auto_return = yes`). Sau failover, site về lại
  LiteSpeed khi đủ cả ba điều:
  - giấy phép kiểm lại là hợp lệ;
  - LiteSpeed đã trả lời ổn 5 phút;
  - đã qua 10 phút kể từ lần chuyển.

Bạn có thể tự tay điều khiển bất kỳ lúc nào:

```bash
snpanel build switch apache               # chuyển 80/443 sang Apache ngay
snpanel build switch litespeed            # về lại: chỉ khi LiteSpeed trả lời và giấy phép hợp lệ
snpanel build set lsws_auto_return no     # ở lại Apache cho tới khi bạn tự chuyển về
```

Thông báo (Notifications) của panel gửi tin khi:

- có failover;
- quay về LiteSpeed;
- giấy phép còn 7, 3 hoặc 1 ngày;
- giấy phép đã hết hạn.

## 7. Giấy phép

```bash
snpanel build live            # giấy phép: trial hay serial, trạng thái, số ngày còn, ngày hết hạn
snpanel build license-check   # kiểm ngay (serial thì tải lại key)
```

Trang Web server có thẻ giấy phép với cùng thông tin.

**Khi trial hoặc giấy phép hết hạn:**

1. Trong vòng 5 phút, watchdog thấy giấy phép không hợp lệ và chuyển 80/443
   sang Apache. Website vẫn chạy bình thường trên Apache: cùng vhost, cùng
   PHP.
2. LiteSpeed không bị reload, vì reload với key hết hạn sẽ làm nó dừng.
3. Muốn quay về LiteSpeed thì cài serial:

   ```bash
   snpanel build license                    # dán serial
   snpanel build set lsws_license serial
   snpanel build license-check              # đăng ký serial và kiểm tra
   ```

   Sau đó tự quay về sẽ đưa site về LiteSpeed. Đã tắt tự quay về thì chạy
   `snpanel build switch litespeed`.
4. Hoặc bỏ LiteSpeed và quay về nginx (mục 9).

Một IP đã dùng hai lần trial thì không xin thêm được. Build không bao giờ tự
xin trial khi máy còn bất kỳ key nào.

## 8. LiteSpeed WebAdmin (cổng 7080)

WebAdmin chỉ nghe ở loopback (`lsws_admin = local`). Vào qua đường hầm SSH:

```bash
ssh -L 7080:127.0.0.1:7080 root@<máy chủ>
# rồi mở https://127.0.0.1:7080 trên trình duyệt; người dùng: admin
cat /var/lib/snpanel-build/lsws-webadmin-password   # chỉ root đọc được; panel không bao giờ in ra
```

Trang Web server cũng đặt được mật khẩu WebAdmin mới và hiện nó một lần.

Muốn mở WebAdmin ra mạng, chỉ cho một số địa chỉ:

```bash
snpanel build set lsws_admin_allow 203.0.113.5,198.51.100.0/24
snpanel build set lsws_admin public       # áp dụng ngay; mọi lần build và cập nhật đều giữ
snpanel build set lsws_admin local        # về lại loopback
```

Panel quản lý cấu hình của LiteSpeed. Những gì sửa trong WebAdmin đè lên
phần panel ghi sẽ bị lần build hoặc cập nhật sau ghi lại.

## 9. Quay về nginx, hoặc chỉ dùng Apache

```bash
snpanel build set webserver nginx
snpanel build all --wait                      # nginx phục vụ lại; LiteSpeed và Apache được giữ, đã dừng, để quay lại nhanh
snpanel build all --remove-litespeed --wait   # như trên, và gỡ luôn LiteSpeed và Apache
```

- Sau `--remove-litespeed`, key giấy phép được cất riêng. Lần sau quay lại
  LiteSpeed sẽ dùng lại key đó, không xin trial mới.
- `snpanel build set webserver apache` rồi `snpanel build all --wait` chuyển
  máy sang chỉ dùng Apache, với PHP-FPM.

<a id="debian-13-nhung-gi-khac"></a>

## Debian 13: những gì khác

Các lệnh giống hệt. Bên dưới thì khác:

| | AlmaLinux 10 | Debian 13 |
|---|---|---|
| Apache | `httpd`, `/etc/httpd` | `apache2`, `/etc/apache2`; module bật bằng `a2enmod`; `ports.conf` của panel (chỉ 8080/8443); site `000-default` và các snippet mặc định (`phpmyadmin.conf`, `serve-cgi-bin.conf` ...) thành file chỉ có chú thích |
| Tài khoản web server | `apache` | `www-data` |
| Log của site | `/var/log/httpd/<tên miền>.access.log` | `/var/log/apache2/<tên miền>.access.log` |
| lsphp | `phpXY-php-litespeed` của Remi, dùng chung `php.d` với PHP-FPM | các gói `lsphpXY` của LiteSpeed trong `/usr/local/lsws/lsphpXY`; file ini của panel được liên kết vào `/usr/local/lsws/lsphpXY/etc/php/X.Y/mods-available` |
| ModSecurity | `mod_security` | `libapache2-mod-security2`; file engine là `/etc/apache2/modsec/engine.conf` |
| Gỡ nginx | `dnf remove` (giữ `nginx-filesystem`) | `apt-get remove` (không purge: giữ `/etc/nginx` để quay về) |

- Các extension PHP-FPM mà LiteSpeed không đóng gói cho lsphp (FFI, shmop,
  mcrypt) được ghi trong log và kế hoạch của job (`lsphp_gaps`). Panel có
  thể build chúng cho lsphp: xem phần dưới.
- **Trial key từ trước khi cài lại máy.** LiteSpeed cấp mỗi IP hai lần trial.
  Máy cài lại mà IP đã có trial còn hạn: đặt key đã lưu ở
  `/usr/local/lsws/conf/trial.key` (root, 0600) trước lần build đầu tiên; bước
  webserver cài LiteSpeed bằng key đó và không xin trial mới. Key không hợp lệ
  thì bước cài dừng lại; không có trial nào khác được xin.

<a id="ubuntu-2404-nhung-gi-khac"></a>

## Ubuntu 24.04: những gì khác

Các lệnh giống hệt, và bố cục là của Debian (bảng trên: `apache2` với
`a2enmod`, `www-data`, `/var/log/apache2`, các gói `lsphpXY` của LiteSpeed -
từ suite `noble` -, `libapache2-mod-security2`, nginx được gỡ nhưng không
purge). Những gì Ubuntu làm theo cách riêng:

- **PHP-FPM** lấy từ PPA của Ondřej Surý. `php-defaults` của chính Ubuntu là
  PHP 8.3, nên phpMyAdmin và Composer kéo các gói PHP 8.3 vào trước, như gói
  phụ thuộc: panel đánh dấu các gói nó dùng là cài tay, để `apt autoremove`
  không bao giờ gỡ chúng, và ghim loại mọi phiên bản PHP bạn không cài (các
  gói `php-*` của PPA muốn 8.5).
- **Redis, không phải Valkey.** Ubuntu 24.04 có Redis 7.0, không có lệnh
  `CLIENT SETINFO`; tệp ACL của panel bỏ lệnh đó ra trên hệ này.
- **phpMyAdmin** là gói 5.2.1 của Ubuntu, tìm thư viện qua include path của
  PHP (`/usr/share/php`); dưới LiteSpeed, panel đặt đường dẫn đó cho
  phpMyAdmin.
- **AppArmor** vẫn bật, với `kernel.apparmor_restrict_unprivileged_userns = 1`
  (công tắc user namespace của Ubuntu). LiteSpeed, lsphp với suEXEC, terminal
  bị cô lập và container Docker (profile `docker-default`) chạy bình thường;
  LiteSpeed Containers vẫn tắt.
- **apt.** needrestart chỉ liệt kê trong lúc panel cài, build và cập nhật;
  panel chờ unattended-upgrades và lần làm mới hằng ngày của apt thay vì thất
  bại; sau mỗi lần nâng cấp gói, hook của apt
  (`/etc/apt/apt.conf.d/80snpanel-php-fpm-reload`) chuyển các master PHP-FPM
  của từng tài khoản sang `php-fpm` mới. Các gói Ubuntu hoãn theo "phased
  updates" được liệt kê riêng ở trang Cập nhật.
- **ClamAV 1.5** (gói `clamav-daemon` của Ubuntu bật `FIPSCryptoHashLimits`):
  cơ sở dữ liệu đã lọc của Malware Scanner giữ các chữ ký `.cvd.sign` mà
  clamd khi đó cần.
- **Extension lsphp.** Suite `noble` của LiteSpeed không có `lsphpXY-ffi`,
  `-shmop` hay `-mcrypt`: panel build chúng như trên Debian (xem dưới).
  `lsphpXY-imap` có gói cho noble, nên IMAP lấy từ LiteSpeed.
- WordPress có LiteSpeed Cache hay object cache ghi một chú thích có giờ sau
  `</html>`; việc chuyển giữa các stack không còn tính nó là khác biệt.

<a id="extension-lsphp-ma-litespeed-khong-dong-goi"></a>
### Extension lsphp mà LiteSpeed không đóng gói

Kho Debian của LiteSpeed (bookworm, trixie và noble của Ubuntu) không có
`lsphpXY-ffi`, `lsphpXY-shmop` hay `lsphpXY-mcrypt`, và trixie cũng không có
`lsphpXY-imap`.
Ở **Máy chủ web & PHP > PHP**, máy chạy LiteSpeed có thêm thẻ cho phiên bản
đang chọn, *lsphp X.Y: extension LiteSpeed không đóng gói*, với trạng thái của
từng extension (chưa build, đang build và đang ở bước nào, đã build và đang
nạp, build lỗi kèm nhật ký, không có và lý do), nút **Build và bật**, **Gỡ** và
**Nhật ký build**. Chỉ quản trị viên; mọi lần build và gỡ đều vào nhật ký kiểm
tra.

| | AlmaLinux 10 (Remi) | Debian 12 | Debian 13 | Ubuntu 24.04 |
|---|---|---|---|---|
| ffi | gói `phpXY-php-ffi` của Remi | build | build | build |
| shmop | gói `phpXY-php-process` của Remi | build | build | build |
| mcrypt | gói `phpXY-php-pecl-mcrypt` của Remi | build (PECL 1.0.9, PHP 7.2 đến 8.5) | build (PECL 1.0.9, PHP 7.2 đến 8.5) | build (PECL 1.0.9, PHP 7.2 đến 8.5) |
| imap | gói `phpXY-php-imap` của Remi (8.4: `pecl-imap`) | gói `lsphpXY-imap` của LiteSpeed | **không có** | gói `lsphpXY-imap` của LiteSpeed |

Trên AlmaLinux không build gì: lsphp là của Remi và dùng chung `php.d` với
PHP-FPM, nên trang chỉ nêu tên gói Remi của extension mà lsphp chưa nạp. IMAP
không bao giờ được build: từ PHP 8.4 nó nằm ở PECL và dựa trên thư viện UW
c-client, thứ Debian 13 đã bỏ và không ai bảo trì.

**Một lần build chạy thế nào.** Một job trong unit riêng
(`snpanel-lsext-<job>`), mỗi lúc một job, không bao giờ trong lúc cập nhật
panel hay build máy chủ web (job giữ chung khoá của cả hai, và build máy chủ
web không bắt đầu khi đang build extension):

1. Hỏi lsphp phiên bản và PHP API của nó - trong sandbox bên dưới, bằng
   `nobody` (xem *Không bao giờ bằng root*).
2. Cài công cụ build nếu thiếu và giữ lại cho lần sau: `build-essential
   autoconf pkg-config xz-utils lsphpXY-dev`, thêm `libffi-dev` (FFI) hoặc
   `libmcrypt-dev` (mcrypt). Mọi gói apt cài kèm đều được ghi lại và liệt kê
   trên trang; nút **Gỡ công cụ build** gỡ chúng khi không cần build nữa
   (không bao giờ gỡ thư viện mà module đã build cần, như `libmcrypt4`, và chỉ
   khi apt không gỡ thêm gì khác), lần build hoặc build lại sau sẽ tự cài lại.
   Panel không tự gỡ.
3. **Mã nguồn được kiểm tra trước khi bất cứ thứ gì đọc nó.** FFI và shmop:
   `php-<phiên bản>.tar.xz` đúng phiên bản của lsphp từ
   `https://www.php.net/distributions/`, chỉ qua HTTPS, kiểm tra hai lần:
   - SHA-256 so với danh sách phát hành của php.net
     (`https://www.php.net/releases/index.php?json&version=<phiên bản>`);
   - chữ ký tách rời (`php-<phiên bản>.tar.xz.asc`) bằng `gpgv`, chỉ với khoá
     của những người phát hành nhánh đó. Dấu vân tay được ghim trong panel và
     khoá đi kèm panel, mỗi nhánh một bộ khoá, xuất từ bộ khoá của php.net và
     ghim bằng SHA-256:

     | Nhánh | Khoá của người phát hành |
     |---|---|
     | 8.2 | `39B641343D8C104B2B146DC3F9C39DC0B9698544`, `E60913E4DF209907D8E30D96659A97C9CF2A795A`, `1198C0117593497A5EC5C199286AF1F9897469DC` |
     | 8.3 | `1198C0117593497A5EC5C199286AF1F9897469DC`, `C28D937575603EB4ABB725861C0779DC5C0A9DE4`, `AFD8691FDAEDF03BDF6E460563F15A9B715376CA` |
     | 8.4 | `AFD8691FDAEDF03BDF6E460563F15A9B715376CA`, `9D7F99A0CB8F05C8A6958D6256A97AF7600A39A6`, `0616E93D95AF471243E26761770426E17EBBB3DD` |
     | 8.5 | `1198C0117593497A5EC5C199286AF1F9897469DC`, `49D9AF6BC72A80D6691719C8AA23F5BE9C7097D4`, `D95C03BC702BE9515344AE3374E44BC9067701A5` |

     Bản vá mới của các nhánh này kiểm tra được mà không cần bản panel mới;
     tarball không do họ ký bị từ chối, chữ ký bị xoá khỏi bộ nhớ đệm và không
     build gì. Nhánh chưa ghim khoá (7.4, 8.0, 8.1) không được build.

   mcrypt: `https://pecl.php.net/get/mcrypt-1.0.9.tgz`, SHA-256
   `2a9ef0817d3bf677f6d7baf8e325629a2758974735d8abad6566384788d424a5` và kích
   thước được ghim trong panel. Tarball và chữ ký đã kiểm tra được giữ ở
   `/var/lib/snpanel-lsext/cache` (root, 0600) và kiểm tra lại mỗi lần dùng.
4. **Biên dịch không phải bằng root.** Kiểm tra chữ ký, giải nén, `phpize`,
   `./configure`, `make` và lần nạp thử đầu tiên (`php -n -d extension=... -m`)
   chạy bằng tài khoản hệ thống `snpanel-extbuild` (không đăng nhập, không
   home) trong một unit systemd tạm:
   - không mạng và không socket nào (`PrivateNetwork`,
     `RestrictAddressFamilies=AF_INET` in an empty network namespace, `PrivateIPC`): không ra internet, không
     chạm được socket Unix của máy (MariaDB, D-Bus, Dovecot);
   - không capability, `NoNewPrivileges`, `SystemCallFilter=@system-service`;
   - cả hệ thống chỉ đọc trừ thư mục riêng dưới `/var/lib/snpanel-lsext-work` -
     thư mục do root tạo, là đường dẫn ghi được duy nhất và thư mục làm việc
     của unit; mỗi bước vào thư mục mã nguồn từ bên trong sandbox
     (`env --chdir`), sau khi root kiểm tra mọi thư mục trên đường đi là thư
     mục thật, không phải liên kết;
   - `/tmp` riêng, tệp của panel và home của khách hàng bị ẩn;
   - giới hạn bộ nhớ (768 MB, hoặc nửa RAM trên máy nhỏ), ưu tiên CPU và I/O
     thấp nhất, `make -j1` khi RAM dưới 3 GB;
   - unit còn sót lại từ lần build bị ngắt được dừng trước khi tài khoản này
     build tiếp.
5. Root đọc lại module mà không đi theo bất kỳ liên kết nào, kiểm tra đó là
   tệp thường và là ELF shared object cho máy này, rồi cài vào `extension_dir`
   của lsphp (0644); `30-snpanel-<ext>.ini` trong
   `/usr/local/lsws/lsphpXY/etc/php/X.Y/mods-available` (thư mục quét của
   lsphp) bật nó lên. Nếu lsphp không nạp được với các tệp ini của nó, cả hai
   bị gỡ ra lại. lsphp khởi động lại nhẹ nhàng (`.lsphp_restart.txt` của
   LiteSpeed).

**Không bao giờ bằng root.** Mỗi khi panel hỏi lsphp đang nạp gì - trang, các
lần kiểm tra, `snpanel doctor` - CLI của lsphp chạy cùng các module của nó
trong cùng loại sandbox, bằng `nobody`: mã của module không bao giờ chạy trong
một tiến trình root.

Khi LiteSpeed có gói cho extension đó (`lsphpXY-imap` trên Debian 12), nút
**Cài và bật** cài gói đó thay vì build.

**FFI chỉ cho preload.** `30-snpanel-ffi.ini` đặt `ffi.enable=preload`: FFI
chạy được cho mã do `opcache.preload` nạp và trong dòng lệnh PHP, còn script
của website không gọi được `FFI::cdef()`. Quản trị viên có thể đặt
`ffi.enable=true` trong một tệp ini của riêng mình xếp sau tệp của panel (ví
dụ `99-local-ffi.ini` trong cùng thư mục; panel không bao giờ ghi tệp này).
Khi đó PHP của mọi website gọi được bất kỳ hàm thư viện C nào bằng tài khoản
của nó - vượt qua `disable_functions` và `open_basedir` - điều shared hosting
không được cho phép. `snpanel doctor` cảnh báo khi giá trị không phải
`preload`.

**Giữ qua các lần nâng cấp lsphp.** Panel ghi lại mỗi lần build ở
`/var/lib/snpanel-lsext/state.json` (root): phiên bản lsphp, PHP API của nó
(`PHP Extension`, và `PHP Extension Build` như `API20240924,NTS`), mã nguồn và
SHA-256, SHA-256 của module. Khi lsphp lên một bản phát hành PHP khác:

- **bản vá** (8.4.26 lên 8.4.27) giữ nguyên API, nhưng FFI và shmop lấy từ mã
  nguồn của bản phát hành đó, nên được build lại từ tarball mới (để bản sửa
  lỗi vào được module); mã nguồn của mcrypt là của PECL, không đổi theo bản
  vá, nên chỉ cần vẫn nạp được;
- **bản phụ** đổi API và thư mục extension: mọi module được build lại, tệp ini
  của nó gỡ ra trong lúc chờ để lsphp không cảnh báo thiếu tệp.

Việc kiểm tra này chạy mỗi ngày một lần (panel), sau khi cập nhật panel, trong
bước php của build máy chủ web và sau khi cập nhật hệ điều hành từ trang Cập
nhật. Build lỗi, hoặc module mà lsphp không nạp được, hiện ở chuông thông báo
và được gửi qua addon Thông báo (*Một extension lsphp do panel build cần được
kiểm tra*); build đã lỗi với đúng lsphp đó thì không tự thử lại.
`snpanel doctor` báo cùng nội dung (`lsphp-extensions`).

Từ dòng lệnh (root):

```bash
snpanel-helper lsphp-ext-status 8.4        # từng extension: nguồn, đang nạp, bản ghi (JSON); không thay đổi gì
snpanel-helper lsphp-ext-build 8.4 ffi     # xếp một lần build (ffi, shmop, mcrypt; imap khi có gói)
snpanel-helper lsphp-ext-log 8.4 ffi       # nhật ký của nó
snpanel-helper lsphp-ext-remove 8.4 ffi    # gỡ tệp ini và module, không build lại
snpanel-helper lsphp-ext-check             # việc kiểm tra hằng ngày làm
snpanel-helper lsphp-ext-tools-remove      # gỡ công cụ build mà panel đã cài
```

## Các khoá trong build.conf

| Khoá | Giá trị |
|---|---|
| `webserver` | `nginx`, `apache` hoặc `litespeed` (litespeed giữ Apache dự phòng) |
| `php_mode` | `php-fpm` hoặc `lsphp`; đi theo `webserver` (litespeed cần lsphp, nginx cần php-fpm) |
| `php_versions` | vd. `8.4,8.3`; bản đầu là mặc định |
| `waf` | `modsecurity` hoặc `off` |
| `lsws_license` | `trial` hoặc `serial` |
| `lsws_auto_return` | `yes` hoặc `no` |
| `lsws_admin` | `local` hoặc `public` |
| `lsws_admin_allow` | địa chỉ hoặc dải CIDR, cách nhau bằng dấu phẩy; để trống là cho mọi địa chỉ |

`build.conf` còn có `harden_userns`, lựa chọn của root về user namespace, mà
`snpanel build set` không đổi. Mọi lệnh và tuỳ chọn của `snpanel build`, cùng
phần siết máy chủ, nằm ở [commands.vi.md](commands.vi.md#muc-6).
