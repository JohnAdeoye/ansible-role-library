# CIS Level 1 control mapping

Which CIS Benchmark Level 1 controls the `base_hardening` role implements, which it
reports on without changing, and which it deliberately leaves alone.

Benchmarks referenced:

- CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0 (Level 1 — Server)
- CIS Ubuntu Linux 22.04 LTS Benchmark v2.0.0 (Level 1 — Server)

Section numbers differ slightly between the two documents. Where they diverge, the RHEL
numbering is used and the Ubuntu equivalent is noted.

Status key:

| Status | Meaning |
|---|---|
| **Enforced** | The role changes the system to meet the control, and `verify.yml` asserts it. |
| **Reported** | The role detects and reports a violation but does not change anything, because an automatic fix would be unsafe. |
| **Build-time** | Cannot be fixed on a running host; belongs in the image or kickstart. |
| **Out of scope** | Deliberately not handled — see the note. |

---

## 1 Initial setup

| Control | Status | Notes |
|---|---|---|
| 1.1.1.x Disable unused filesystems (cramfs, freevxfs, hfs, hfsplus, jffs2, squashfs, udf) | Enforced | `install <fs> /bin/false` in `/etc/modprobe.d/99-cis-filesystems.conf`. A `blacklist` line alone is insufficient — it only stops autoloading, not an explicit `modprobe`. Both are written. |
| 1.1.2 `/tmp` as a separate partition | Build-time | See "Partitioning" below. |
| 1.1.2.x `/tmp` nosuid, nodev, noexec | Enforced *if separate* | Applied via fstab when `/tmp` already is its own filesystem; otherwise reported. |
| 1.1.3–1.1.5 `/var`, `/var/tmp`, `/var/log`, `/var/log/audit` separate | Build-time | |
| 1.1.6 `/home` separate | Build-time | |
| 1.1.7 `/dev/shm` nosuid, nodev, noexec | Enforced | Always a tmpfs, so always fixable at runtime. |
| 1.1.8 Disable automounting | Enforced | `autofs` masked. |
| 1.1.9 Disable USB storage | Out of scope | Breaks legitimate use on lab hardware. Add `usb-storage` to `base_hardening_blocked_filesystems` if you want it. |
| 1.2.x Package repositories and GPG keys | Out of scope | Repository configuration is environment-specific; the Proxmox repo belongs in `homelab-proxmox-cluster`. |
| 1.3.x AIDE file integrity | Out of scope | Needs a baseline database and a place to store it off-host to mean anything. A checkbox install of AIDE with no monitored output is compliance theatre. |
| 1.4.x Bootloader password and permissions | Partly enforced | `grub.cfg` set to `0600`. A bootloader password is **not** set — it makes unattended reboots impossible, which is the wrong trade for a lab. Documented as a deviation. |
| 1.5.1 Core dumps restricted | Enforced | `fs.suid_dumpable=0`, `* hard core 0` in limits.d, and `Storage=none` for systemd-coredump. All three are needed; setting only the sysctl leaves systemd happily writing dumps. |
| 1.5.2 ASLR enabled | Enforced | `kernel.randomize_va_space=2`. |
| 1.6.x SELinux / AppArmor enabled and enforcing | Out of scope (Level 1 partial) | The role does not change MAC mode. Flipping SELinux to enforcing on a host with unlabelled files causes an outage on next boot; it is a per-workload decision. Audit rules watch the policy directories so changes are logged. |
| 1.7.x Warning banners for local and remote login | Enforced | `/etc/issue`, `/etc/issue.net`, `/etc/motd` rewritten with no `\m \r \s \v` escapes. Ubuntu's dynamic motd scripts are disabled, since they re-add version info on every login. |
| 1.8.x GDM configuration | Out of scope | Server builds have no display manager. |

## 2 Services

| Control | Status | Notes |
|---|---|---|
| 2.1.1 Time synchronisation in use | Enforced | chrony installed, configured, enabled. `systemd-timesyncd` masked — two daemons disciplining one clock is worse than none. |
| 2.1.2 chrony runs as a non-root user | Enforced | `user chrony` / `_chrony` per distro. |
| 2.2.x Special-purpose services removed | Enforced | Services in `base_hardening_masked_services` are stopped, disabled **and masked**. Masking matters: a merely disabled unit can still be socket-activated. Only units that actually exist on the host are touched. |
| 2.3.x Insecure clients removed | Enforced | telnet, rsh, talk, ypbind, tftp and the distro-specific server packages. |
| 2.4 Cron and at restricted to root | Enforced | `cron.allow`/`at.allow` created `0640`; `cron.deny`/`at.deny` removed. |

## 3 Network

| Control | Status | Notes |
|---|---|---|
| 3.1.1 IPv6 disabled if unused | Optional | `base_hardening_ipv6_enabled: false` disables it at the kernel. Default is **enabled**, because silently breaking IPv6 on a network that uses it is worse than the exposure. |
| 3.1.2 Wireless interfaces disabled | Out of scope | No wireless on the target hardware. |
| 3.2.1 IP forwarding disabled | Enforced | `net.ipv4.ip_forward=0`. **Must be overridden on Kubernetes nodes** — see the note below. |
| 3.2.2 Packet redirect sending disabled | Enforced | |
| 3.3.1 Source-routed packets not accepted | Enforced | |
| 3.3.2 ICMP redirects not accepted | Enforced | |
| 3.3.3 Secure ICMP redirects not accepted | Enforced | |
| 3.3.4 Suspicious packets logged | Enforced | `log_martians=1`. |
| 3.3.5 Broadcast ICMP requests ignored | Enforced | |
| 3.3.6 Bogus ICMP responses ignored | Enforced | |
| 3.3.7 Reverse path filtering enabled | Enforced | `rp_filter=1`. Note this is strict mode; asymmetric routing will break. |
| 3.3.8 TCP SYN cookies enabled | Enforced | |
| 3.3.9 IPv6 router advertisements not accepted | Enforced | Applied when IPv6 is enabled. |
| 3.4.x Host-based firewall configured | Enforced | firewalld on RHEL, ufw on Ubuntu. Allow rules are applied *before* the default policy flips to deny, and loopback is permitted explicitly. |

> **Kubernetes nodes.** `net.ipv4.ip_forward=0` and `rp_filter=1` will break pod
> networking. The `k8s-from-scratch` repo overrides both in its own group_vars and
> documents why — this is the most common way a hardening baseline silently breaks a
> cluster.

## 4 Logging and auditing

| Control | Status | Notes |
|---|---|---|
| 4.1.1.1 auditd installed | Enforced | |
| 4.1.1.2 auditd service enabled | Enforced | |
| 4.1.1.3 Auditing for processes that start before auditd | Enforced | `audit=1` appended to `GRUB_CMDLINE_LINUX`, then grub regenerated. |
| 4.1.2.x Audit log storage size and actions | Enforced | `max_log_file`, `num_logs`, `space_left_action`, `admin_space_left_action=halt`. Note that `halt` means the host powers off rather than lose records — alert on `space_left` well before that. |
| 4.1.3.1–4.1.3.14 Audit rules | Enforced | Time changes, identity, network environment, MAC policy, logins, sessions, sudo, DAC changes, failed file access, mounts, deletions, module loading, privileged commands. |
| 4.1.3.14 Privileged command execution | Enforced (variant) | CIS enumerates every setuid binary found by a `find` sweep. This role instead audits `execve` where `uid != euid` and `euid == 0`, which covers the same ground and does not drift every time a package adds a binary. Functionally equivalent, structurally different — flag it if your auditor diffs rule files literally. |
| 4.1.3.20 Audit configuration immutable | Optional | `base_hardening_auditd_immutable: true` writes `-e 2`. Off by default because it requires a reboot to change anything afterwards. **Turn it on in production.** |
| 4.2.1.x rsyslog / journald configuration | Enforced | journald set to persistent + compressed with size caps; rsyslog `$FileCreateMode 0640` when installed. |
| 4.2.3 Log files permissions | Enforced | Any file under `/var/log` that is world-readable or group-writable is set to `0640`. |
| 4.2.2.x Remote log host | Out of scope | Needs a log destination to point at. Configure `rsyslog` forwarding in a site-specific role. |

## 5 Access, authentication and authorisation

| Control | Status | Notes |
|---|---|---|
| 5.1.x Cron directory permissions | Enforced | `/etc/cron.*` set to `0700`, `/etc/crontab` to `0600`. |
| 5.2.1 `/etc/ssh/sshd_config` permissions | Enforced | `0600 root:root`. |
| 5.2.2/5.2.3 SSH host key permissions | Enforced | Private keys `0640 root:ssh_keys` on RHEL, `0600 root:root` on Ubuntu — the correct pair comes from `vars/`, not a hardcoded value. |
| 5.2.4 Access limited (AllowGroups) | **Opt-in** | Default writes no `AllowGroups`. This is a deliberate deviation: enabling it blind locks you out. Set `base_hardening_ssh_allow_groups` once the group exists. |
| 5.2.5 LogLevel INFO or VERBOSE | Enforced | |
| 5.2.6 UsePAM enabled | Enforced | |
| 5.2.7 PermitRootLogin disabled | Enforced | |
| 5.2.8 HostbasedAuthentication disabled | Enforced | |
| 5.2.9 PermitEmptyPasswords disabled | Enforced | |
| 5.2.10 PermitUserEnvironment disabled | Enforced | |
| 5.2.11 IgnoreRhosts enabled | Enforced | |
| 5.2.12 X11Forwarding disabled | Enforced | |
| 5.2.13–5.2.15 Strong ciphers, MACs, KEX | Enforced | Only AEAD and ETM constructions; no CBC, no MD5, no SHA-1 KEX, no `diffie-hellman-group1`. |
| 5.2.16 ClientAliveInterval / CountMax | Enforced | 300 / 3. |
| 5.2.17 LoginGraceTime | Enforced | 60s. |
| 5.2.18 Banner configured | Enforced | Points at `/etc/issue.net`. |
| 5.2.19 MaxAuthTries ≤ 4 | Enforced | |
| 5.2.20 MaxStartups | Enforced | `10:30:60`. |
| 5.2.21 MaxSessions ≤ 10 | Enforced | |
| 5.3.1 Password creation requirements | Enforced | `pwquality.conf`: minlen 14, one each of digit/upper/lower/other, difok 3, maxrepeat 3, dictcheck, usercheck, `enforce_for_root`. |
| 5.3.2 Lockout for failed attempts | Enforced | `faillock.conf`: deny 5, unlock_time 900. Root lockout is opt-in via `base_hardening_lockout_include_root` — enabling it without console access is how you lose a host permanently. |
| 5.3.3 Password reuse limited | Enforced | `remember=5` via `pwhistory.conf` (RHEL) or `common-password` (Debian). |
| 5.3.4 Strong password hashing | Enforced | `ENCRYPT_METHOD YESCRYPT`. |
| 5.4.1.x Password ageing | Enforced | max 365, min 1, warn 7, inactive lock 30. Applied to `login.defs` *and* to existing interactive accounts — setting only `login.defs` affects new users and nothing else, which is the usual mistake. |
| 5.4.2.1 Root is the only UID 0 account | **Reported** | A second UID 0 account fails the play with a message. The role will not delete or renumber an account. |
| 5.4.2.x System accounts non-login | Enforced | Accounts below `UID_MIN` with a real shell are set to nologin, excluding root, `sync`, `shutdown`, `halt`. |
| 5.4.3 Default group for root | Out of scope | Rarely wrong, and changing it has surprising side effects. |
| 5.4.4 Default umask 027 or stricter | Enforced | Both `login.defs` and `/etc/profile.d`. |
| 5.4.5 Default shell timeout | Enforced | `TMOUT=900`, readonly, exported. |
| 5.4.6 su access restricted | Enforced | `pam_wheel.so use_uid group=wheel`. |

## 6 System maintenance

| Control | Status | Notes |
|---|---|---|
| 6.1.1–6.1.7 Permissions on passwd/shadow/group/gshadow and backups | Enforced | Including the `-` suffixed backup files, which are frequently missed. |
| 6.1.8 No world-writable files | **Reported** | Listed, not fixed. `chmod`-ing an unknown world-writable file breaks working software often enough that it needs a human. |
| 6.1.9/6.1.10 No unowned or ungrouped files | **Reported** | Same reasoning. |
| 6.1.11 No unconfined SUID/SGID binaries | Out of scope | The audit rules log privileged execution instead. |
| 6.2.x User and group settings consistency | Out of scope | Handled by the `user_lifecycle` role, which owns account state declaratively. |

---

## Partitioning

CIS 1.1.2–1.1.6 require `/tmp`, `/var`, `/var/tmp`, `/var/log`, `/var/log/audit` and
`/home` to be separate filesystems. This cannot be fixed on a running host, so the role
applies hardened mount options to whichever of them already are separate and prints the
rest.

The build-time fix lives in the `homelab-proxmox-cluster` repo: the RHEL kickstart and
the Ubuntu autoinstall config both lay down a compliant LVM layout. Run
`base_hardening` against a host built from those and the mount-option controls apply
cleanly with nothing reported.

## Recorded deviations

These are conscious choices, not gaps. If you are using this against a real audit,
these are the rows you will need to argue.

| Control | Deviation | Reason |
|---|---|---|
| 1.4.1 Bootloader password | Not set | Prevents unattended reboot, which the patching role depends on. Mitigated by physical/hypervisor access control. |
| 1.6.x SELinux enforcing | Not changed | Flipping to enforcing on a host with unlabelled files is an outage. Per-workload decision. |
| 3.1.1 IPv6 disabled | Enabled by default | Disabling it breaks a network that uses it. Opt-in via a flag. |
| 4.1.3.20 Immutable audit rules | Off by default | Requires a reboot to iterate. Intended to be turned on in production. |
| 5.2.4 SSH AllowGroups | Off by default | Enabling blind locks you out of the fleet. |
| 5.3.2 Root lockout | Off by default | Needs out-of-band console access to be safe. |
| 6.1.8–6.1.10 World-writable / unowned files | Reported, not fixed | Automatic remediation breaks working software. |

## Verifying

The role's Molecule scenario asserts the enforced controls against the rendered
artifacts on both a Rocky 9 and an Ubuntu 22.04 container:

```bash
cd roles/base_hardening && molecule test
```

For an independent check, run a scanner against a real (non-container) host — the
role is not the thing that should be grading itself:

```bash
# OpenSCAP, RHEL 9
oscap xccdf eval --profile cis_server_l1 \
  --results /tmp/results.xml --report /tmp/report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
```

Expect the partitioning controls to fail on a host that was not built from the
kickstart, and the recorded deviations above to show as failures too. Everything else
should pass.
