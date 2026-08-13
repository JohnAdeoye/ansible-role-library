# patch_orchestration

Serialised fleet patching: pre-flight checks, optional snapshot, patch, conditional
reboot, health gate, and a per-host report.

## The role patches one host — the play controls the rollout

```yaml
- hosts: web
  become: true
  serial: "25%"            # batch size
  max_fail_percentage: 0   # stop the rollout on the first failed host
  roles:
    - role: patch_orchestration
      vars:
        patch_orchestration_reboot: when-needed
        patch_orchestration_required_services: [nginx]
        patch_orchestration_health_url: "https://{{ inventory_hostname }}/healthz"
```

`serial` + `max_fail_percentage: 0` is the safety mechanism. The role's health gate
fails the host; `max_fail_percentage: 0` turns that into a **stopped rollout** instead
of a fleet-wide outage you find out about the next morning. Without both, the health
check is decoration.

## Sequence

1. **Pre-flight** — free space on `/`, `/var` and `/boot`; required services already
   running; no reboot already pending; no other package transaction in flight.
   A full `/boot` is the one that actually bites: the kernel package fails halfway and
   leaves dnf in a state you have to unpick by hand.
2. **Snapshot** (optional) — runs `patch_orchestration_snapshot_command`, delegated to
   the controller by default. Deliberately a command rather than a provider module, so
   it works with Proxmox, LVM, ZFS or anything else.
3. **Patch** — `dnf` or `apt`, scoped to `all`, `security` or `minimal`. Excluded
   packages are held for the duration and released afterwards.
4. **Reboot detection** — `/var/run/reboot-required` on Debian, `needs-restarting -r`
   on RHEL. Neither is exposed as a fact, so both are checked explicitly.
5. **Reboot** — `never`, `when-needed` (default) or `always`.
6. **Health gate** — waits for `systemctl is-system-running`, reports failed units,
   asserts the required services are back, and optionally probes an HTTP endpoint with
   retries.
7. **Report** — a JSON file per host on the controller with the exact package versions
   before and after, whether it rebooted, and the running kernel.

## Reports

```
patch-reports/web-01.lab.internal.json
```

```json
{
  "host": "web-01.lab.internal",
  "distribution": "Ubuntu 22.04",
  "kernel": "5.15.0-91-generic",
  "scope": "security",
  "reboot_required": true,
  "rebooted": true,
  "changed_package_count": 12,
  "changed_packages": [
    {"name": "openssl", "before": "3.0.2-0ubuntu1.12", "after": "3.0.2-0ubuntu1.15"}
  ]
}
```

Without this, "we patched last Tuesday" is the entire audit trail.

## Notes

- `apt` has no native `--security` flag. The role restricts the candidate set to the
  `-security` pocket, which is what `unattended-upgrades` does internally.
- The Molecule scenario has **no idempotence step**. `state: latest` is not idempotent
  by definition — a new upstream package between two runs makes the second one change
  something. Asserting idempotence there would produce a test that fails at random
  times of day for reasons unrelated to the code.
- Reboot and post-reboot health are not exercised in containers. That path is covered
  by the Vagrant scenario in `homelab-proxmox-cluster`.

## Testing

```bash
molecule test
```
