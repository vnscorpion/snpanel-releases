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

- **AlmaLinux 10.**
  - Trên Debian và Ubuntu, `snpanel build` tạm thời từ chối LiteSpeed; các
    máy đó dùng nginx.
  - Đường này không hỗ trợ CloudLinux.
- **Đĩa và RAM.** Trống ít nhất 5 GB trên `/`. RAM dưới 4 GB thì nên thêm
  swap 2 GB trước.
- **Mạng.** Máy phải kết nối được tới `license.litespeedtech.com`.
- **Cổng trống.** Không có gì khác đang nghe ở 8080/8443 (Apache) hay
  9080/9443 (LiteSpeed).
- **Kho PHP Remi.** Phải đã cấu hình (trình cài làm việc này). Mọi phiên bản
  PHP mà site đang dùng phải đã cài.
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
