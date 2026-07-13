# Realtek r8152 USB 以太网驱动

[English](README.md) | 简体中文

适用于 Realtek RTL8152/RTL8153 系列 USB 以太网适配器的 Linux 内核树外驱动，
提供 DKMS 打包、自动安装 udev 规则、S5 网络唤醒和中心抽头短路检测控制。

## 概述

| 项目 | 值 |
| --- | --- |
| 驱动版本 | v2.22.1（2026-06-03） |
| 内核模块 | <code>r8152</code> |
| DKMS 包 | <code>r8152/2.22.1</code> |
| udev 规则 | <code>50-usb-realtek-net.rules</code> |
| 许可证 | GPL-2.0-only |

该驱动支持 Realtek USB 以太网控制器，以及 Microsoft、Samsung、Lenovo、
Linksys、NVIDIA、TP-Link、Getac 和 ASUS 的部分适配器。权威 USB 设备表定义
在 <code>r8152.c</code> 中。

## 环境要求

- 受支持的 Linux 内核及其匹配的内核头文件
- 用于在内核升级后自动重建模块的 DKMS
- GNU Make 和与内核兼容的 C 编译器
- 用于配置链路、网络唤醒、Ring 队列和流量控制的 <code>ethtool</code>
- 安装内核模块和 udev 规则所需的 root 权限

不同发行版的软件包名称可能不同。继续操作前，请安装 DKMS、编译工具链、
Make，以及与当前运行内核匹配的头文件。

## 安装

### DKMS 安装（推荐）

在项目目录中执行完整的 DKMS 安装流程：

~~~bash
sudo make dkms-install
~~~

该命令会：

1. 将所需源码复制到 <code>/usr/src/r8152-2.22.1</code>。
2. 向 DKMS 注册 <code>r8152/2.22.1</code>。
3. 为目标内核构建并安装模块。
4. 启用 DKMS，使其为后续内核自动安装模块。
5. 通过 DKMS 安装后钩子，将 <code>50-usb-realtek-net.rules</code>
   安装到 <code>/etc/udev/rules.d</code>。

使用以下命令验证安装：

~~~bash
dkms status -m r8152 -v 2.22.1
modinfo r8152
~~~

### 手动安装

在不注册 DKMS 的情况下构建并安装模块：

~~~bash
make modules
sudo make install
~~~

安装目标会卸载正在使用的 <code>r8153_ecm</code> 或 <code>r8152</code>
模块，安装新模块和 udev 规则，然后加载 <code>r8152</code>。

> [!WARNING]
> 卸载正在使用的网络驱动会立即中断通过该适配器建立的连接。

### 单独安装 udev 规则

仅安装 Realtek USB 配置规则：

~~~bash
sudo make install_rules
sudo udevadm control --reload-rules
~~~

如果发行版使用其他 udev 规则目录，可以覆盖 <code>RULEDIR</code>：

~~~bash
sudo make install_rules RULEDIR=/usr/lib/udev/rules.d
~~~

### 卸载 DKMS 包

删除所有已安装内核版本的模块、udev 规则和源码副本：

~~~bash
sudo make dkms-uninstall
~~~

## 模块参数

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| <code>s5_wol</code> | 布尔值 | <code>0</code> | 启用 S5 网络唤醒支持 |
| <code>ctap_short</code> | 布尔值 | <code>1</code> | 启用中心抽头短路检测 |

两个参数在模块加载后均为只读。要修改参数值，需要卸载并重新加载模块。

### 加载时配置

通过 <code>modprobe</code> 直接传入参数：

~~~bash
sudo modprobe r8152 s5_wol=1 ctap_short=0
~~~

如果模块已经加载，请先断开该适配器承载的网络流量，再重新加载：

~~~bash
sudo modprobe -r r8152
sudo modprobe r8152 s5_wol=1 ctap_short=0
~~~

### 持久化配置

创建 <code>/etc/modprobe.d/r8152.conf</code> 并写入所需参数：

~~~text
options r8152 s5_wol=1 ctap_short=1
~~~

如果发行版将 <code>r8152</code> 放入早期启动镜像，还需要重新生成 initramfs。

### 查看当前值

模块加载后，从 sysfs 读取当前生效的参数值：

~~~bash
cat /sys/module/r8152/parameters/s5_wol
cat /sys/module/r8152/parameters/ctap_short
~~~

布尔参数通常显示为 <code>Y</code> 或 <code>N</code>。

## 功能配置

### S5 网络唤醒

S5 网络唤醒默认关闭。启用模块中的相关路径，并为网络接口配置网络唤醒模式：

~~~bash
sudo modprobe r8152 s5_wol=1
sudo ethtool -s eth0 wol g
ethtool eth0
~~~

请将 <code>eth0</code> 替换为实际接口名称。能否从 S5 状态成功唤醒还取决于：

- 内核启用了 <code>CONFIG_PM</code>
- 适配器硬件和固件支持该功能
- 系统处于 S5 状态时仍向 USB 设备供电
- 固件或 BIOS 中的网络唤醒设置
- <code>ethtool</code> 报告了有效的网络唤醒模式

### 中心抽头短路检测

中心抽头短路检测默认开启。当硬件或布线环境需要时，可以在加载模块时关闭：

~~~bash
sudo modprobe r8152 ctap_short=0
~~~

## 网络调优

请将以下示例中的 <code>eth0</code> 替换为目标接口名称。

### 链路速率通告

根据目标链路模式使用对应的通告掩码：

| 链路模式 | 内核版本 | 通告掩码 |
| --- | --- | --- |
| 10 Mbit/s 全双工 | 任意受支持内核 | <code>0x0003</code> |
| 100 Mbit/s 全双工 | 任意受支持内核 | <code>0x000f</code> |
| 1 Gbit/s | 任意受支持内核 | <code>0x002f</code> |
| 2.5 Gbit/s | Linux 4.10 之前 | <code>0x802f</code> |
| 2.5 Gbit/s | Linux 4.10 或更高版本 | <code>0x80000000002f</code> |
| 5 Gbit/s | Linux 4.10 或更高版本 | <code>0x180000000002f</code> |
| 10 Gbit/s | Linux 4.10 或更高版本 | <code>0x180000000102f</code> |

使用以下命令应用掩码：

~~~bash
sudo ethtool -s eth0 autoneg on advertise 0x80000000002f
~~~

### Ring 队列大小

显示支持的和当前生效的 Ring 参数：

~~~bash
ethtool -g eth0
~~~

修改接收 Ring 队列大小：

~~~bash
sudo ethtool -G eth0 rx 100
~~~

### Copybreak 可调参数

读取并修改接收 copybreak 值：

~~~bash
ethtool --get-tunable eth0 rx-copybreak
sudo ethtool --set-tunable eth0 rx-copybreak 256
~~~

读取并修改发送 copybreak 值：

~~~bash
ethtool --get-tunable eth0 tx-copybreak
sudo ethtool --set-tunable eth0 tx-copybreak 256
~~~

### 流量控制

显示当前暂停帧配置：

~~~bash
ethtool -a eth0
~~~

关闭接收和发送流量控制：

~~~bash
sudo ethtool -A eth0 rx off tx off
~~~

开启接收流量控制，同时保持发送流量控制关闭：

~~~bash
sudo ethtool -A eth0 rx on tx off
~~~

## 发行版说明

### Fedora

安装或修改模块后重新生成 initramfs：

~~~bash
sudo dracut -f
~~~

### Ubuntu

刷新模块依赖并重新生成 initramfs：

~~~bash
sudo depmod -a
sudo update-initramfs -u
~~~

## Make 目标

| 目标 | 说明 |
| --- | --- |
| <code>make modules</code> | 为选定内核构建 <code>r8152.ko</code> |
| <code>make clean</code> | 删除内核模块构建产物 |
| <code>sudo make install</code> | 安装并加载模块，同时安装 udev 规则 |
| <code>sudo make install_rules</code> | 仅安装 udev 规则 |
| <code>sudo make uninstall_rules</code> | 仅删除 udev 规则 |
| <code>sudo make dkms-source</code> | 将 DKMS 源码包复制到 <code>/usr/src</code> |
| <code>sudo make dkms-add</code> | 复制并注册 DKMS 源码包 |
| <code>sudo make dkms-build</code> | 注册并构建 DKMS 模块 |
| <code>sudo make dkms-install</code> | 注册、构建并安装 DKMS 模块 |
| <code>sudo make dkms-uninstall</code> | 删除 DKMS 模块、规则和源码包 |

如果需要为当前运行内核之外的内核构建模块，可以覆盖
<code>KERNELDIR</code>：

~~~bash
make modules KERNELDIR=/lib/modules/<kernel-version>/build
~~~

## 项目文件

| 路径 | 用途 |
| --- | --- |
| <code>r8152.c</code> | Realtek USB 以太网驱动实现 |
| <code>compatibility.h</code> | 受支持内核的兼容性定义 |
| <code>Makefile</code> | 内核构建、安装、DKMS 和 udev 规则目标 |
| <code>dkms.conf</code> | DKMS 包配置 |
| <code>dkms-install-rules</code> | 安装 udev 规则的 DKMS 安装后钩子 |
| <code>50-usb-realtek-net.rules</code> | USB 设备配置规则 |
| <code>README.md</code> | 英文文档 |
| <code>README.zh.md</code> | 简体中文文档 |
| <code>LICENSE</code> | GNU 通用公共许可证第 2 版文本 |

## 许可证

驱动源码声明
<code>Copyright (c) 2024 Realtek Semiconductor Corp. All rights reserved.</code>，
并仅根据 GNU 通用公共许可证第 2 版分发。完整许可证文本请参阅
[LICENSE](LICENSE)。
