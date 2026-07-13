# Realtek r8152 USB Ethernet Driver

English | [简体中文](README.zh.md)

Out-of-tree Linux kernel driver for Realtek RTL8152/RTL8153-family USB Ethernet
adapters, with DKMS packaging, automatic udev rule installation, S5
Wake-on-LAN, and center tap short detection controls.

## Overview

| Item | Value |
| --- | --- |
| Driver version | v2.22.1 (2026-06-03) |
| Kernel module | <code>r8152</code> |
| DKMS package | <code>r8152/2.22.1</code> |
| udev rule | <code>50-usb-realtek-net.rules</code> |
| License | GPL-2.0-only |

The driver supports Realtek USB Ethernet controllers and selected adapters
from Microsoft, Samsung, Lenovo, Linksys, NVIDIA, TP-Link, Getac, and ASUS.
The authoritative USB device table is defined in <code>r8152.c</code>.

## Requirements

- A supported Linux kernel and matching kernel headers
- DKMS for automatic rebuilds after kernel upgrades
- GNU Make and a kernel-compatible C compiler
- <code>ethtool</code> for link, Wake-on-LAN, ring, and flow-control settings
- Root privileges for module and udev rule installation

Package names vary by distribution. Install the equivalent of DKMS, the
compiler toolchain, Make, and the headers for the running kernel before
continuing.

## Installation

### DKMS installation (recommended)

Run the complete DKMS installation workflow from the project directory:

~~~bash
sudo make dkms-install
~~~

This command:

1. Copies the required source files to <code>/usr/src/r8152-2.22.1</code>.
2. Registers <code>r8152/2.22.1</code> with DKMS.
3. Builds and installs the module for the target kernel.
4. Enables DKMS automatic installation for future kernels.
5. Installs <code>50-usb-realtek-net.rules</code> in
   <code>/etc/udev/rules.d</code> through the DKMS post-install hook.

Verify the installation with:

~~~bash
dkms status -m r8152 -v 2.22.1
modinfo r8152
~~~

### Manual installation

Build and install the module without registering it with DKMS:

~~~bash
make modules
sudo make install
~~~

The install target unloads an active <code>r8153_ecm</code> or
<code>r8152</code> module, installs the new module and udev rule, and then
loads <code>r8152</code>.

> [!WARNING]
> Unloading an active network driver immediately interrupts connections using
> that adapter.

### Install the udev rule separately

Install only the Realtek USB configuration rule:

~~~bash
sudo make install_rules
sudo udevadm control --reload-rules
~~~

Override <code>RULEDIR</code> when a distribution uses a different udev rule
directory:

~~~bash
sudo make install_rules RULEDIR=/usr/lib/udev/rules.d
~~~

### Uninstall the DKMS package

Remove every installed kernel build, the udev rule, and the source copy:

~~~bash
sudo make dkms-uninstall
~~~

## Module Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| <code>s5_wol</code> | Boolean | <code>0</code> | Enables S5 Wake-on-LAN support |
| <code>ctap_short</code> | Boolean | <code>1</code> | Enables center tap short detection |

Both parameters are read-only after the module is loaded. Unload and reload
the module to change their values.

### Load-time configuration

Pass parameters directly to <code>modprobe</code>:

~~~bash
sudo modprobe r8152 s5_wol=1 ctap_short=0
~~~

If the module is already loaded, disconnect network traffic from the adapter
before reloading it:

~~~bash
sudo modprobe -r r8152
sudo modprobe r8152 s5_wol=1 ctap_short=0
~~~

### Persistent configuration

Create <code>/etc/modprobe.d/r8152.conf</code> with the desired values:

~~~text
options r8152 s5_wol=1 ctap_short=1
~~~

Rebuild the initramfs if the distribution includes <code>r8152</code> in the
early boot image.

### Inspect current values

After loading the module, read the active parameter values from sysfs:

~~~bash
cat /sys/module/r8152/parameters/s5_wol
cat /sys/module/r8152/parameters/ctap_short
~~~

Boolean parameters are normally displayed as <code>Y</code> or <code>N</code>.

## Feature Configuration

### S5 Wake-on-LAN

S5 Wake-on-LAN is disabled by default. Enable the module path and configure a
Wake-on-LAN mode on the network interface:

~~~bash
sudo modprobe r8152 s5_wol=1
sudo ethtool -s eth0 wol g
ethtool eth0
~~~

Replace <code>eth0</code> with the actual interface name. Successful wake from
S5 also depends on:

- A kernel built with <code>CONFIG_PM</code>
- Supported adapter hardware and firmware
- USB power remaining available in the S5 state
- Firmware or BIOS Wake-on-LAN settings
- A valid Wake-on-LAN mode reported by <code>ethtool</code>

### Center tap short detection

Center tap short detection is enabled by default. Disable it while loading the
module when required by the hardware or cabling environment:

~~~bash
sudo modprobe r8152 ctap_short=0
~~~

## Network Tuning

Replace <code>eth0</code> in the following examples with the target interface.

### Link speed advertisement

Use the appropriate advertisement mask:

| Link mode | Kernel | Advertisement mask |
| --- | --- | --- |
| 10 Mbit/s full duplex | Any supported kernel | <code>0x0003</code> |
| 100 Mbit/s full duplex | Any supported kernel | <code>0x000f</code> |
| 1 Gbit/s | Any supported kernel | <code>0x002f</code> |
| 2.5 Gbit/s | Before Linux 4.10 | <code>0x802f</code> |
| 2.5 Gbit/s | Linux 4.10 or later | <code>0x80000000002f</code> |
| 5 Gbit/s | Linux 4.10 or later | <code>0x180000000002f</code> |
| 10 Gbit/s | Linux 4.10 or later | <code>0x180000000102f</code> |

Apply a mask with:

~~~bash
sudo ethtool -s eth0 autoneg on advertise 0x80000000002f
~~~

### Ring size

Display the supported and active ring parameters:

~~~bash
ethtool -g eth0
~~~

Change the receive ring size:

~~~bash
sudo ethtool -G eth0 rx 100
~~~

### Copybreak tunables

Read and update the receive copybreak value:

~~~bash
ethtool --get-tunable eth0 rx-copybreak
sudo ethtool --set-tunable eth0 rx-copybreak 256
~~~

Read and update the transmit copybreak value:

~~~bash
ethtool --get-tunable eth0 tx-copybreak
sudo ethtool --set-tunable eth0 tx-copybreak 256
~~~

### Flow control

Display the current pause-frame configuration:

~~~bash
ethtool -a eth0
~~~

Disable receive and transmit flow control:

~~~bash
sudo ethtool -A eth0 rx off tx off
~~~

Enable receive flow control while leaving transmit flow control disabled:

~~~bash
sudo ethtool -A eth0 rx on tx off
~~~

## Distribution Notes

### Fedora

Regenerate the initramfs after installing or changing the module:

~~~bash
sudo dracut -f
~~~

### Ubuntu

Refresh module dependencies and regenerate the initramfs:

~~~bash
sudo depmod -a
sudo update-initramfs -u
~~~

## Make Targets

| Target | Description |
| --- | --- |
| <code>make modules</code> | Builds <code>r8152.ko</code> for the selected kernel |
| <code>make clean</code> | Removes kernel module build artifacts |
| <code>sudo make install</code> | Installs and loads the module and installs the udev rule |
| <code>sudo make install_rules</code> | Installs only the udev rule |
| <code>sudo make uninstall_rules</code> | Removes only the udev rule |
| <code>sudo make dkms-source</code> | Copies the DKMS source package to <code>/usr/src</code> |
| <code>sudo make dkms-add</code> | Copies and registers the DKMS source package |
| <code>sudo make dkms-build</code> | Registers and builds the DKMS module |
| <code>sudo make dkms-install</code> | Registers, builds, and installs the DKMS module |
| <code>sudo make dkms-uninstall</code> | Removes the DKMS module, rule, and source package |

Override <code>KERNELDIR</code> to build for a kernel other than the running
kernel:

~~~bash
make modules KERNELDIR=/lib/modules/<kernel-version>/build
~~~

## Project Files

| Path | Purpose |
| --- | --- |
| <code>r8152.c</code> | Realtek USB Ethernet driver implementation |
| <code>compatibility.h</code> | Compatibility definitions for supported kernels |
| <code>Makefile</code> | Kernel build, installation, DKMS, and udev rule targets |
| <code>dkms.conf</code> | DKMS package configuration |
| <code>dkms-install-rules</code> | DKMS post-install hook for the udev rule |
| <code>50-usb-realtek-net.rules</code> | USB device configuration rule |
| <code>README.md</code> | English documentation |
| <code>README.zh.md</code> | Simplified Chinese documentation |
| <code>LICENSE</code> | GNU General Public License version 2 text |

## License

The driver source declares
<code>Copyright (c) 2024 Realtek Semiconductor Corp. All rights reserved.</code>
and is distributed under the GNU General Public License version 2 only. See
[LICENSE](LICENSE) for the complete license text.
