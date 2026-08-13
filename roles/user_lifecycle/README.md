# user_lifecycle

Declarative users, groups, sudo rights and SSH keys — with an offboarding path that is
not just `state: absent`.

## Why `offboarded` exists

Most user roles offer `present` and `absent`. For someone leaving, `absent` is the
wrong answer: it destroys the audit trail and orphans every file they owned, which
turns up months later as a directory full of files owned by UID 4001.

`state: offboarded` runs a sequence instead, in this order:

1. Lock the password and set the shell to `nologin`
2. Expire the account outright (`chage -E 0`) — a locked password alone still allows
   key-based and PAM-delegated logins on some configurations
3. Remove `authorized_keys`
4. Remove sudo rights
5. Strip secondary group memberships
6. `SIGTERM` anything still running as them — an open SSH session survives every step
   above
7. Archive the home directory to a root-owned tarball
8. Optionally remove the home directory, and only then the account

Steps 7 and 8 are gated: the role will not delete a home directory unless archiving is
enabled, so there is no configuration where data disappears without a copy.

## Usage

```yaml
- role: user_lifecycle
  vars:
    user_lifecycle_groups:
      - name: developers
        gid: 4200

    user_lifecycle_users:
      - name: alice
        comment: "Alice Admin"
        uid: 4001                 # pin UIDs so ownership matches across hosts
        groups: [developers, wheel]
        sudo: full
        ssh_keys:
          - "ssh-ed25519 AAAA... alice@laptop"

      - name: bob
        uid: 4002
        groups: [developers]
        sudo:                     # a command list, not blanket root
          - /usr/bin/systemctl restart nginx
          - /usr/bin/journalctl
        sudo_nopasswd: true
        ssh_keys:
          - "ssh-ed25519 AAAA... bob@laptop"

      - name: former-employee
        state: offboarded
```

## Declarative, not additive

Two defaults make this a reconciler rather than an append-only script:

- `user_lifecycle_exclusive_keys: true` — a key on the host but not in `ssh_keys` is
  **removed**. This is what makes key revocation actually work. Turn it off and a
  revoked key survives on every host forever.
- `append: false` on group membership — the `groups` list is the complete set, so
  removing a group from the list removes the user from it.

## Validation before mutation

`validate.yml` runs first and fails the play before any account is touched if it finds
duplicate names or UIDs, an invalid `state`, a plaintext password where a crypt hash
belongs, or a string in `ssh_keys` that does not look like a public key (a pasted
*private* key is a serious leak, and it is an easy mistake to make).

Sudo drop-ins are written with `validate: visudo -cf %s`, so a malformed entry cannot
break `sudo` for everyone on the host.

## Testing

```bash
molecule test
```

The scenario provisions three accounts with different sudo shapes and offboards a
pre-existing user who has a key, a sudo file and real data in their home directory. It
then asserts the leaver is locked *and* expired, their key and sudo rights are gone,
their home directory was archived with the data intact, and the account itself still
exists.
