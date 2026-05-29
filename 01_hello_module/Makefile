obj-m += hello.o

KDIR ?= /home/mangjun/linux_kernel/rpi-linux

ARCH = arm64
CROSS_COMPILE = aarch64-linux-gnu-

all:
	make -C $(KDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	make -C $(KDIR) M=$(PWD) clean
