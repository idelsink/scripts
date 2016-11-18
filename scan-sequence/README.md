# scan-sequence

Run a sequence of scan commands via a simple `ini` file.

```sh
scan-sequence config-file [output-path]
```

## Dependencies

-   ruby
-   ruby gems: iniparse colorize fileutils

-   Install ruby
```sh
apt-get install ruby
# or
dnf install ruby
# or ...
```
-   Install gems
```sh
gem install iniparse colorize fileutils
```

## Sequence example

See the [example.ini](./example.ini) file:

```ini
[default]
; disable section
disabled=false
; basename of scanned image
name=scan
; nr of scans; 0 is ask
scans=1
; if more then 1 scan, image file needs a number appended
; does this need zero padding if more then, for example 10?
zero_padding=true
; scan command to use
scan_comm=scanimage
; scan format
format=--format=jpeg
; scan mode: Color|Gray|Lineart ...
mode=--mode=Color
; depth: 8|16
depth=--depth=8
; resolution: 4800|2400|1200|600|300|150|100|75dpi
resolution=--resolution=300
; geometry if scan supports it: -l 0 -x 100 -t 0 -y 100
geometry=
; extra parameters
; this can be used multiple times
scan_comm_p=-p
; save command e.g. --save, --file or '>' output stream
save_comm=>
; file extension
ext=.jpg
; pause before each scan
pause_before_scan=false
```
