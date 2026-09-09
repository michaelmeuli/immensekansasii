# Git notes

## Every file shows as "modified" (not a CRLF/LF issue)

This repo lives on a Ceph-backed shared filesystem (`/shares/...`). That
storage forces group `rwx` (mode `775`) on files, even though they were
committed as `644`. Git then reports every tracked file as modified
(`mode change 100644 => 100755`) even though the file content is byte-for-byte
identical — it looks like a line-ending problem but it's actually just file
permission bits that this filesystem doesn't preserve correctly.

If you see this, run:

```sh
git config core.fileMode false
```

This tells git to ignore permission-only changes in this repo (it's a local,
repo-only setting — it does not affect the remote or other clones). After
running it, `git status` should come back clean.
