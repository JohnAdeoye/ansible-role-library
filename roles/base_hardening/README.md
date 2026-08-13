# base_hardening

CIS Benchmark **Level 1** baseline for RHEL/Rocky 9 and Ubuntu 22.04.

Covers sections 1.1 (filesystems), 1.7 (banners), 2.1 (time), 2.2 (services),
3.1–3.4 (kernel network parameters and host firewall), 4.1–4.2 (auditd and logging),
5.2 (SSH), 5.3 (PAM), 5.4 (accounts) and 6.1 (file permissions).

Full control-by-control mapping, including the items this role deliberately does not
automate: [`../../docs/cis-mapping.md`](../../docs/cis-mapping.md).

## Two things that will lock you out

Read these before the first production run.

**`base_hardening_ssh_allow_groups`** defaults to `[]`, which writes *no* `AllowGroups`
directive. That is a deliberate CIS deviation. The moment you set it, only members of
those groups can log in — so create the group and put your admin account in it
*first*, verify with a second SSH session still open, then set the variable.

**`base_hardening_firewall_default_policy: deny`** takes effect on the first run. The role
adds the allow rules before flipping the policy, but if `base_hardening_firewall_allowed_tcp`
does not contain the port you are connected on, you lose the host. It defaults to
`[22]`; change `base_hardening_ssh_port` and this together, never separately.

## Usage

```yaml
- hosts: all
  become: true
  roles:
    - role: base_hardening
      vars:
        base_hardening_ssh_allow_groups: [ssh-users]
        base_hardening_firewall_allowed_tcp: [22, 80, 443]
        base_hardening_auditd_immutable: true       # production
        base_hardening_lockout_include_root: false  # unless you have console access
```

Preview before enforcing — templates still render, live system changes are skipped:

```bash
ansible-playbook site.yml --check --diff -e base_hardening_enforce=false
```

Apply one section at a time on an existing fleet:

```bash
ansible-playbook site.yml --tags sysctl,banner
ansible-playbook site.yml --tags ssh          # after you have set allow_groups
ansible-playbook site.yml --tags firewall     # last
```

## Tags

| Tag | Section | Tag | Section |
|---|---|---|---|
| `filesystem` | 1.1 | `auditd` | 4.1 |
| `banner` | 1.7 | `logging` | 4.2 |
| `time` | 2.1 | `ssh` | 5.2 |
| `services` | 2.2 | `pam` | 5.3 |
| `sysctl` | 3.1–3.3 | `accounts` | 5.4 |
| `firewall` | 3.4 | `permissions` | 6.1 |

`cis1` … `cis6` select a whole benchmark section.

## Variables

Every variable is documented inline in [`defaults/main.yml`](defaults/main.yml), and the
public interface is typed in [`meta/argument_specs.yml`](meta/argument_specs.yml) — pass a
string where an int is expected and the play fails immediately with the variable name.

The most commonly overridden ones:

| Variable | Default | Notes |
|---|---|---|
| `base_hardening_enforce` | `true` | `false` = render config, skip live changes |
| `base_hardening_ssh_allow_groups` | `[]` | See the lockout warning above |
| `base_hardening_ssh_permit_root_login` | `"no"` | Quote it — YAML turns bare `no` into `false` |
| `base_hardening_firewall_allowed_tcp` | `[22]` | Must include your SSH port |
| `base_hardening_ipv6_enabled` | `true` | `false` disables IPv6 at the kernel |
| `base_hardening_auditd_immutable` | `false` | `true` = `-e 2`, needs a reboot to change |
| `base_hardening_lockout_include_root` | `false` | `true` can lock root out |
| `base_hardening_pwquality_minlen` | `14` | CIS minimum |
| `base_hardening_uid_min` | `1000` | Boundary between system and human accounts |

## What it will not do

- **Repartition a running host.** CIS 1.1.2–1.1.5 want `/tmp`, `/var`, `/var/log`,
  `/var/tmp` and `/home` on separate filesystems. The role applies hardened mount
  options to whichever of those already are separate, and prints a list of the ones
  that are not. Partitioning is a build-time decision — see the kickstart and cloud-init
  templates in the `homelab-proxmox-cluster` repo.
- **Delete or renumber accounts.** A second UID 0 account fails the run with an
  explanatory message rather than being silently removed.
- **Fix world-writable or unowned files.** These are reported for review; chmod-ing
  them blind breaks working software.
- **Level 2 controls.** No SELinux policy authoring, no `noexec` on `/var`, no
  process accounting. Level 2 is workload-specific.

## Testing

```bash
molecule test              # rocky9 + ubuntu2204, converge -> idempotence -> verify
molecule converge          # leave containers up
molecule verify
```

`verify.yml` asserts on rendered artifacts — the actual contents of `sshd_config`,
`pwquality.conf`, the audit rules, file modes — rather than on Ansible's own change
reporting, and runs `sshd -t` and `auditctl -R` to prove the generated config parses.

Container caveat: tasks that need a real kernel (sysctl, modprobe, mount) or a real
init are skipped when `ansible_virtualization_type` is a container. Those paths are
exercised by the Vagrant scenario in `homelab-proxmox-cluster`, not here.
