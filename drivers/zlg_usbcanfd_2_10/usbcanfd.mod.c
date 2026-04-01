#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/elfnote-lto.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

BUILD_SALT;
BUILD_LTO_INFO;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif

static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x25f8bfc1, "module_layout" },
	{ 0x283fa325, "param_ops_uint" },
	{ 0x1bd17b3e, "can_change_mtu" },
	{ 0xd81a27d7, "usb_deregister" },
	{ 0x83f07a09, "usb_register_driver" },
	{ 0xf83251ef, "kfree_skb_reason" },
	{ 0x3eeb2322, "__wake_up" },
	{ 0x34d278b1, "can_put_echo_skb" },
	{ 0x755830df, "close_candev" },
	{ 0x92540fbf, "finish_wait" },
	{ 0x8ddd8aad, "schedule_timeout" },
	{ 0x8c26d495, "prepare_to_wait_event" },
	{ 0xfe487975, "init_wait_entry" },
	{ 0x34a0c653, "netif_tx_wake_queue" },
	{ 0x5d76950f, "can_get_echo_skb" },
	{ 0x48d56dfd, "device_create_file" },
	{ 0x33bddfeb, "wake_up_process" },
	{ 0xe2147518, "kthread_create_on_node" },
	{ 0x57a14207, "netdev_err" },
	{ 0xc5feb598, "register_candev" },
	{ 0xf07bb259, "alloc_candev_mqs" },
	{ 0xd9a5ea54, "__init_waitqueue_head" },
	{ 0xcefb0c9f, "__mutex_init" },
	{ 0xb8b9f817, "kmalloc_order_trace" },
	{ 0x27a2116c, "usb_control_msg" },
	{ 0xd58d4b67, "kmem_cache_alloc_trace" },
	{ 0xc1c7e6c0, "kmalloc_caches" },
	{ 0x8c676699, "netif_device_detach" },
	{ 0x11c3e6d6, "alloc_can_err_skb" },
	{ 0x15e326ad, "alloc_can_skb" },
	{ 0xac14fe76, "netif_rx" },
	{ 0x4235c1f3, "alloc_canfd_skb" },
	{ 0xc4f0da12, "ktime_get_with_offset" },
	{ 0xf0644ef8, "usb_unanchor_urb" },
	{ 0x69f38847, "cpu_hwcap_keys" },
	{ 0x14b89635, "arm64_const_caps_ready" },
	{ 0x3213f038, "mutex_unlock" },
	{ 0x98cf60b3, "strlen" },
	{ 0xdcb764ad, "memset" },
	{ 0x4dfa8d4b, "mutex_lock" },
	{ 0x865f28c0, "usb_free_urb" },
	{ 0x46834faf, "usb_submit_urb" },
	{ 0x802f71a3, "usb_anchor_urb" },
	{ 0xa72c0785, "usb_alloc_coherent" },
	{ 0x7504e97d, "usb_alloc_urb" },
	{ 0xb838aa76, "open_candev" },
	{ 0x3ea1b6e4, "__stack_chk_fail" },
	{ 0x4f18a01a, "usb_bulk_msg" },
	{ 0xbd6841d4, "crc16" },
	{ 0x37a0cba, "kfree" },
	{ 0x8abcf63a, "usb_free_coherent" },
	{ 0x962c8ae1, "usb_kill_anchored_urbs" },
	{ 0x112b81f7, "kthread_stop" },
	{ 0x9b6073e2, "device_remove_file" },
	{ 0x77d24c69, "free_candev" },
	{ 0xb09b7637, "unregister_netdev" },
	{ 0x745fbadf, "netdev_info" },
	{ 0x92997ed8, "_printk" },
	{ 0x4829a47e, "memcpy" },
	{ 0x3c3ff9fd, "sprintf" },
	{ 0x1fdc7df2, "_mcount" },
};

MODULE_INFO(depends, "can-dev");

MODULE_ALIAS("usb:v04CCp1240d*dc*dsc*dp*ic*isc*ip*in*");
MODULE_ALIAS("usb:v3068p0009d*dc*dsc*dp*ic*isc*ip*in*");

MODULE_INFO(srcversion, "2501043EF9402A79EE24242");
