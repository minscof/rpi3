qemu-system-arm.exe -kernel kernel-qemu-4.1.7-jessie -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw init=/bin/bash" -hda img-mini-rpi-1.212.img