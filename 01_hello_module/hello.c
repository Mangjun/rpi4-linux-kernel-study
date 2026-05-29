#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

static int __init hello_init(void)
{
	// 커널 로그에 출력
	pr_info("Hello, Kerenl 6.12! Module Loaded.\n");
	return 0; // 0을 반환해야 정상적으로 로드
}

static void __exit hello_exit(void)
{
	pr_info("Goodbye, Kernel! Module Unloaded.\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Embedded Developer");
MODULE_DESCRIPTION("A Simple Hello World Kernel Module");
