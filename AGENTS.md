# Repository Agent Guide

## Scope

These instructions apply to the entire repository.

This repository packages the Realtek <code>r8152</code> out-of-tree Linux
kernel driver and maintains local integration features such as DKMS packaging,
udev rule installation, load-time module parameters, and bilingual
documentation.

## Branch Model

- <code>realtek-upstream</code> tracks snapshots released by Realtek.
- <code>master</code> is the integration branch and contains the local
  packaging, runtime controls, documentation, and compatibility work.
- Keep Realtek source updates isolated on <code>realtek-upstream</code>.
- Merge <code>realtek-upstream</code> into <code>master</code>; do not copy an
  upstream release directly over the integration branch.
- Do not switch branches while the worktree is dirty. Commit or safely preserve
  the current work first.
- Do not rewrite or rebase published upstream-history snapshots unless the user
  explicitly requests it.

The expected upstream update flow is:

~~~bash
git switch realtek-upstream
# Replace the files supplied by the new Realtek release.
git add -A
git commit -m "chore(upstream): update Realtek driver to vX.Y.Z"

git switch master
git merge realtek-upstream
~~~

Resolve the merge on <code>master</code> while preserving the local DKMS,
module-parameter, udev, and documentation behavior.

## Important Files

| Path | Responsibility |
| --- | --- |
| <code>r8152.c</code> | Driver implementation and module parameters |
| <code>compatibility.h</code> | Compatibility definitions for supported kernels |
| <code>Makefile</code> | Kernel build, installation, DKMS, and udev targets |
| <code>dkms.conf</code> | DKMS package metadata and build command |
| <code>dkms-install-rules</code> | DKMS post-install udev rule hook |
| <code>50-usb-realtek-net.rules</code> | Realtek USB configuration rule |
| <code>README.md</code> | English documentation |
| <code>README.zh.md</code> | Simplified Chinese documentation |
| <code>LICENSE</code> | Verbatim GPLv2 license text |

## Driver Configuration

The locally maintained driver exposes these read-only module parameters:

| Parameter | Default | Behavior |
| --- | --- | --- |
| <code>s5_wol</code> | <code>0</code> | Enables the S5 Wake-on-LAN path |
| <code>ctap_short</code> | <code>1</code> | Enables center tap short detection |

Preserve the following rules:

- Both features must remain selectable at module load time with
  <code>modprobe</code>.
- Keep both parameters read-only after load unless a complete live
  reconfiguration path is implemented.
- S5 Wake-on-LAN code is compiled when <code>CONFIG_PM</code> is available and
  is gated at runtime by <code>s5_wol</code>.
- Register the reboot notifier only when S5 Wake-on-LAN is enabled, and
  unregister it only after successful registration.
- Apply <code>ctap_short</code> during PHY configuration and keep the UPS flags
  synchronized with the selected value.
- Do not restore <code>RTL8152_S5_WOL</code>,
  <code>CONFIG_CTAP_SHORT</code>, or <code>CONFIG_CTAP_SHORT_OFF</code> as
  compile-time feature switches.
- The optional <code>RTL8152_DEBUG</code> compile-time switch is unrelated and
  may remain available.

Example load command:

~~~bash
sudo modprobe r8152 s5_wol=1 ctap_short=0
~~~

## DKMS and udev Rules

- Keep the DKMS package name as <code>r8152</code>.
- Keep all package version declarations synchronized:
  - <code>DRIVER_VERSION</code> in <code>r8152.c</code>
  - <code>DKMS_VERSION</code> in <code>Makefile</code>
  - <code>PACKAGE_VERSION</code> in <code>dkms.conf</code>
- Update the DKMS source-file list whenever a required build, hook, rule,
  license, or documentation file is renamed or added.
- Keep both <code>README.md</code> and <code>README.zh.md</code> in the DKMS
  source package.
- Keep udev rule installation implemented by the Makefile target
  <code>install_rules</code>.
- Keep the DKMS <code>POST_INSTALL</code> hook delegated to
  <code>dkms-install-rules</code>, which calls the Makefile target.
- The default rule destination is
  <code>/etc/udev/rules.d/50-usb-realtek-net.rules</code>; preserve
  <code>RULEDIR</code> and <code>DESTDIR</code> overrides.
- <code>CLEAN</code> is deprecated by modern DKMS and is not required because
  DKMS creates a fresh build directory. Add it only when explicitly targeting
  an older DKMS release that requires it.
- Keep <code>dkms-uninstall</code> limited to known package files. Do not
  replace its guarded cleanup with an unrestricted recursive removal.

## Documentation

- Treat <code>README.md</code> and <code>README.zh.md</code> as a synchronized
  pair.
- Maintain a 1:1 structure: the same heading levels and order, corresponding
  tables, matching command examples, and equivalent warnings.
- Update both files in the same change whenever commands, parameters,
  defaults, versions, file names, installation paths, or supported workflows
  change.
- Keep the language switch links at the top of both files.
- Use <code>README.md</code> for English and <code>README.zh.md</code> for
  Simplified Chinese. Do not recreate <code>ReadMe.txt</code>.
- Prefer fenced code blocks with a language identifier, concise tables, and
  task-oriented installation examples.
- Document that unloading the active driver interrupts network connectivity.
- Do not claim that a Linux module build or hardware behavior was verified
  unless it was actually tested on Linux.

## Code Style

- Follow the existing Linux kernel C style.
- Use tabs for kernel-code indentation and keep preprocessor directives aligned
  with the surrounding source.
- Make focused changes. Do not mass-format <code>r8152.c</code> or rewrite
  unrelated Realtek code.
- Preserve the existing compatibility guards unless the supported kernel range
  is deliberately changed.
- Prefer runtime checks for user-selectable behavior and compile-time guards
  only for unavailable kernel APIs or optional debug code.
- Check return values when registering kernel notifiers or changing device
  state.
- Avoid new comments unless they explain non-obvious hardware or compatibility
  behavior.

## Build Commands

Build for the running kernel:

~~~bash
make modules
~~~

Build for a selected kernel:

~~~bash
make modules KERNELDIR=/lib/modules/<kernel-version>/build
~~~

Prepare and install through DKMS:

~~~bash
sudo make dkms-install
~~~

Install only the udev rule:

~~~bash
sudo make install_rules
~~~

Do not run installation, module unload, or module load commands merely as a
validation step. They modify the host and can disconnect its network.

## Validation

Run the smallest relevant checks first.

For every change:

~~~bash
git diff --check
~~~

For DKMS or hook changes:

~~~bash
bash -n dkms.conf
sh -n dkms-install-rules
make -n dkms-source DKMS_SOURCE_DIR=/tmp/r8152-dkms-source
~~~

For README changes:

~~~bash
rg '^#{1,3} ' README.md
rg '^#{1,3} ' README.zh.md
~~~

Confirm that the heading levels, section order, tables, and code blocks remain
structurally aligned.

On a Linux system with matching headers:

~~~bash
make clean
make modules
modinfo ./r8152.ko
~~~

Verify that <code>modinfo</code> reports both <code>s5_wol</code> and
<code>ctap_short</code>. When DKMS is available, also validate the add, build,
install, status, and removal lifecycle in an appropriate test environment.

If the current host is not Linux or lacks kernel headers, complete the static
checks and clearly state that the kernel build was not run.

## Safety

- Preserve unrelated user changes in a dirty worktree.
- Never use destructive Git commands to discard changes unless explicitly
  requested.
- Do not remove an installed in-tree driver, unload a live network module,
  write to <code>/usr/src</code>, or write to <code>/etc/udev</code> without
  explicit authorization.
- Use a temporary <code>DESTDIR</code>, <code>RULEDIR</code>, or
  <code>DKMS_SOURCE_DIR</code> for non-root installation-path tests.
- Treat S5 Wake-on-LAN as hardware-, firmware-, kernel-, and platform-dependent.
  Do not infer successful wake behavior from compilation alone.

## License

- The project is licensed under <code>GPL-2.0-only</code>.
- Preserve the Realtek source copyright notice.
- Keep <code>LICENSE</code> as the verbatim GNU GPL version 2 text.
- Do not insert project copyright statements into the GPL license text.
- Do not change the project license without explicit authorization from the
  copyright holder.

## Git Conventions

- Use Conventional Commits.
- Keep the subject concise, imperative, and normally no longer than 50
  characters.
- Add a body only when the reason, compatibility impact, migration, or safety
  concern is not obvious.
- Suitable examples include:
  - <code>feat(dkms): add module packaging</code>
  - <code>feat(driver): add load-time parameters</code>
  - <code>docs: rewrite bilingual readmes</code>
  - <code>chore(upstream): update Realtek driver</code>
- Do not commit, amend, switch branches, merge, push, or publish unless the user
  asks for that action.
- Before committing, review the staged file list and run
  <code>git diff --cached --check</code>.
