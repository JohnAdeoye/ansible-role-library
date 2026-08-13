# Changelog

All notable changes to this collection are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-13

First release. Packaged as the `johnadeoye.homelab` collection so that all four
roles can be consumed from a single repository — `ansible-galaxy role install`
treats a git repository as one role, so requesting several roles from the same
repository installs the same tree under each name.

### Added

- `base_hardening` — CIS Level 1 baseline for RHEL 9 and Ubuntu 22.04: SSH
  policy, kernel parameters, filesystem module blacklisting, `auditd` rules,
  password quality and lockout via PAM, and a host firewall.
- `nginx` — installation, virtual hosts, TLS, security headers, log rotation
  and SELinux booleans.
- `patch_orchestration` — serialised patching with pre-flight checks, reboot
  detection and health verification between batches.
- `user_lifecycle` — declarative users, groups, SSH keys and sudo rules, with
  offboarding that archives a home directory before locking the account.
- Molecule scenarios covering both RHEL and Ubuntu for every role, including an
  idempotence check.
