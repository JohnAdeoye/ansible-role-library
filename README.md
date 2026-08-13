# ansible-role-library

Reusable, idempotent Ansible roles for Linux fleet management, targeting **RHEL 9 / Rocky 9** and
**Ubuntu 22.04**. Each role is self-contained, has a typed argument spec, and ships a Molecule
scenario that runs in CI.

| Role | Purpose |
|---|---|
| [`base_hardening`](roles/base_hardening) | CIS Benchmark **Level 1** baseline — filesystem, kernel, SSH, PAM, auditd, time sync, banners, host firewall |
| [`nginx`](roles/nginx) | NGINX install + templated vhosts, TLS, security headers, rate limiting, log rotation |
| [`patch_orchestration`](roles/patch_orchestration) | Serialised fleet patching — pre-flight checks, snapshot hook, patch, reboot-if-needed, health gate |
| [`user_lifecycle`](roles/user_lifecycle) | Declarative users/groups/sudo/SSH keys with a real deprovisioning path (lock → archive → remove) |

## Design rules

Every role in this library follows the same contract:

1. **Idempotent.** A second run reports zero changes. CI asserts this (`--check` after converge).
2. **Typed inputs.** Every role has `meta/argument_specs.yml`, so bad input fails at parse time with
   a useful message instead of halfway through a play.
3. **No silent cross-distro drift.** OS differences live in `vars/{{ ansible_os_family }}.yml`,
   never in inline `when: ansible_os_family == ...` scattered through tasks.
4. **Tagged.** Every task block carries tags so you can run a slice (`--tags ssh,sysctl`) instead of
   the whole role.
5. **Reversible where it matters.** Hardening tasks that can lock you out (SSH, firewall) validate
   config before reloading and are guarded by `*_enabled` flags.

## Requirements

- Ansible core >= 2.14 (`pip install -r requirements.txt`)
- Collections from `requirements.yml` (`make deps`)
- Target hosts reachable over SSH with a `become`-capable account

## Quick start

```bash
make deps                                   # install collections + python deps
ansible-galaxy install -r requirements.yml  # (what `make deps` runs)

# Point at your own inventory
ansible-playbook -i inventory/hosts.ini playbooks/harden.yml --check --diff
ansible-playbook -i inventory/hosts.ini playbooks/harden.yml
```

Consume a single role from another project:

```yaml
# requirements.yml
roles:
  - name: base_hardening
    src: https://github.com/OWNER/ansible-role-library.git
    scm: git
    version: main
```

## Using the roles

### base_hardening

```yaml
- hosts: all
  become: true
  roles:
    - role: base_hardening
      vars:
        base_hardening_ssh_permit_root_login: "no"
        base_hardening_ssh_allow_groups: [ssh-users]
        base_hardening_firewall_enabled: true
        base_hardening_firewall_allowed_tcp: [22, 80, 443]
        base_hardening_auditd_enabled: true
```

Full variable reference: [`roles/base_hardening/README.md`](roles/base_hardening/README.md).
CIS control mapping: [`docs/cis-mapping.md`](docs/cis-mapping.md).

### nginx

```yaml
- role: nginx
  vars:
    nginx_sites:
      - name: app
        server_name: app.lab.internal
        listen: 443
        tls:
          cert: /etc/pki/tls/certs/app.crt
          key: /etc/pki/tls/private/app.key
        locations:
          - path: /
            proxy_pass: http://127.0.0.1:8080
```

### patch_orchestration

```yaml
- hosts: web
  serial: "25%"          # role assumes you set serial at the play level
  become: true
  roles:
    - role: patch_orchestration
      vars:
        patch_orchestration_reboot: when-needed
        patch_orchestration_health_url: "https://{{ inventory_hostname }}/healthz"
```

### user_lifecycle

```yaml
- role: user_lifecycle
  vars:
    user_lifecycle_users:
      - name: jdoe
        state: present
        groups: [wheel]
        ssh_keys: ["ssh-ed25519 AAAA... jdoe@laptop"]
      - name: former-employee
        state: offboarded    # lock, expire, archive homedir, kill sessions
```

## Testing

```bash
make lint                 # yamllint + ansible-lint (profile: production)
make test                 # molecule test, all roles, all scenarios
make test ROLE=nginx      # single role
```

Molecule drives Docker containers for `rockylinux:9` and `ubuntu:22.04`. CI runs the same
matrix on every push — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

Because systemd-dependent tasks cannot fully run in a plain container, roles detect
`ansible_virtualization_type == 'docker'` and skip service *starts* while still asserting
config file content. The verify step tests the rendered artifacts, which is what the role is
actually responsible for.

## Repository layout

```
roles/<role>/
├── defaults/main.yml          # every tunable, documented inline
├── meta/main.yml              # galaxy metadata + platforms
├── meta/argument_specs.yml    # typed validation of the public interface
├── tasks/main.yml             # thin dispatcher -> per-concern task files
├── handlers/main.yml
├── templates/                 # .j2, all with an "ansible managed" header
├── vars/{RedHat,Debian}.yml   # all OS divergence lives here
└── molecule/default/          # converge + verify + idempotence
```

## License

MIT — see [LICENSE](LICENSE).
