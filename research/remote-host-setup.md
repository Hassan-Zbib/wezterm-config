# Carrying the zsh / starship / CLI setup onto SSH hosts and WSL

Research for [PEA-624](https://linear.app/peal/issue/PEA-624) (child of the wayfinder map PEA-520).
It feeds the grilling ticket [Explore: carrying the setup into SSH and WSL hosts](https://linear.app/peal/issue/PEA-623),
which has to pick a mechanism once it knows which hosts are in use. **This file surveys and compares; it does not pick.**

Researched 2026-09-27 against the repo at `6fa10f3`, the pinned Dotbot submodule (`0878407`), WezTerm `main`
(`b09b56c`, 2026-09-17), and the official docs linked under each claim. "Inference" marks conclusions drawn from
those sources rather than stated by them.

---

## 0. What is known and not known about the targets

| Target | What the repo says | Unknown |
|---|---|---|
| WSL | One distro, `Ubuntu`, wired as the `WSL:Ubuntu` domain, spawning `bash -l` in `/home/hassan`. The comment there says neither zsh nor fish is installed (`config/domains.lua:44-57`). Its only shell integration today is a bash snippet sourced across `/mnt/c` (`install.conf.yaml:87`, `home/.config/wsl/wezterm-integration.bash`). | Ubuntu release (22.04 vs 24.04 changes which tools apt can supply, see §3.6), WSL1 vs WSL2, whether systemd is on. |
| SSH | Only the F7 picker: it parses `~/.ssh/config` and types `ssh <alias>` into the current local pane (`utils/ssh-hosts.lua:83`). `ssh_domains = {}` is empty (`config/domains.lua`). | Which hosts, whether Hassan owns them (sudo? shared accounts?), distro/arch, outbound internet access from the host, how long-lived they are. |

---

## 1. Baseline: what in `home/` ports and what is Windows-only

The zsh config is mostly portable. The blockers are a few specific lines, plus the Dotbot config, which is
Windows-only at almost every step.

### 1.1 Shell dotfiles

| File / line | On Linux | Why |
|---|---|---|
| `.zshenv` (MSYS PATH guard) | No-op, safe | It only fires when `/usr/bin` is missing from PATH. |
| `.zprofile` (cached `/etc/profile` env) | **Runs, but wastes work every login** | The allowlist is MSYS variables. The safety net at `.zprofile:77` (`-z $MSYSTEM`) is always true on Linux, so each login shell deletes the cache and sources `/etc/profile` a second time. Needs an OS guard. |
| `.zshrc:32` `SHELL=/usr/bin/zsh` | Fine on Debian/Ubuntu | zsh is at `/usr/bin/zsh` there. Guarded by `-x` anyway. |
| `.zshrc:42` OSC 7 hard-codes `file://localhost` | Harmless for spawning (see §2.6) | Wrong for anything that reads the host part. The upstream `wezterm.sh` emits `${HOSTNAME}` ([wezterm.sh](https://github.com/wezterm/wezterm/blob/main/assets/shell-integration/wezterm.sh)). |
| `.zshrc:361,371` zoxide init + `cd() { __zoxide_z }` | **Hard dependency** | `_cached_init zoxide` is not guarded by `$+commands[zoxide]`. Without zoxide the cache is empty and `cd` calls an undefined `__zoxide_z`, so **`cd` stops working**. |
| `.zshrc:381` `__zoxide_pwd` override calls `cygpath` | **Breaks every `cd`** | `cygpath` exists only under MSYS/Cygwin. It needs the same `$OSTYPE == (msys\|cygwin)*` guard that `.zshrc:479` already uses for fzf-tab. |
| `.zshrc:316` `fzf --zsh` | Needs fzf **≥ 0.48.0** | The flag arrived in 0.48.0 ([fzf CHANGELOG](https://github.com/junegunn/fzf/blob/master/CHANGELOG.md)). An older fzf quietly leaves an empty cache: no Ctrl+T or Alt+C, though fzf-tab still works. |
| `.zshrc:390` `BAT_THEME='Catppuccin Macchiato'` | Needs bat **≥ 0.26.0** | Catppuccin was added in 0.26.0 ([bat CHANGELOG](https://github.com/sharkdp/bat/blob/master/CHANGELOG.md)). On older Debian/Ubuntu the binary is also named `batcat` ([bat README](https://github.com/sharkdp/bat#on-ubuntu-using-apt)), so `$+commands[bat]` is false and the alias and previews drop out silently. |
| `ccp()` (`powershell.exe` + `C:\` path), `alias pkgs` (UniGetUI.exe), `alias lssh` (`bin/lazyssh.exe`) | Windows-only | Harmless until called. `ccp` may work in WSL through interop. |
| carapace block, key bindings, history/atuin, antidote load, fzf-tab zstyles | Portable | The Windows workarounds in them are either guarded or no-ops. |
| `.zsh_plugins.txt` | Portable | antidote is pure zsh plus git ([antidote README](https://github.com/mattmc3/antidote)). |
| `.config/starship.toml` | Portable | Only `os.symbols` names Windows; other OSes fall back to starship defaults. `[hostname] ssh_only = true` and `[container]` already exist, so remote/container context appears automatically. The Nerd Font glyphs are drawn by the local WezTerm, so **the remote needs no font**. |
| `.config/atuin/config.toml` | Portable | `auto_sync = false`, so history does **not** follow you to another host unless atuin sync is turned on. |
| `.gitconfig` | **Windows paths** | `core.editor` points at the Windows VS Code, and the credential helper is `C:\Program Files\GitHub CLI\gh.exe`. |

### 1.2 `install.conf.yaml` / `./install` run unchanged on Linux

- `winget:` directive: the plugin shells out to `winget` ([dotbot-winget `winget.py`](https://github.com/zknx/dotbot-winget)). On Linux that raises, Dotbot's dispatcher catches it and logs "An error was encountered while executing action winget", and the run ends "Some tasks were not executed successfully" with exit 1 (`dotbot/src/dotbot/dispatcher.py:106-113`, `cli.py:177-181`).
- `link:` would link `~/bin/git`, a wrapper that `exec`s `/mingw64/bin/git` (`bin/git`). `.zshrc` puts `~/bin` first in PATH, so **this would break `git` on Linux**. It would also link `bin/lazyssh.exe` and create `~/AppData/...` and `~/Documents/PowerShell/...` trees.
- `shell:` steps: `install-zsh.sh` writes to `/c/Program Files/Git` and exits 1. The `wsl -e ...` step fails. The `ya pkg` steps need yazi. `install-zsh-plugins.sh` hard-codes the Windows `zsh.exe`, so it clones antidote and then skips the pre-bundle (safe: `.zshrc` bundles on first start).
- **What Dotbot offers for this** (pinned version): `-c/--config-file` accepts several files (`nargs="+"`, `cli.py:37-43`), `--only` / `--except <directive>` (README), and per-link `if:` evaluated in `$SHELL` (README: `if: '[ \`uname\` = Darwin ]'`). The Dotbot wiki's "Tips and Tricks" page documents an `install-profile` pattern: `meta/configs/*.yaml` plus `meta/profiles/<name>`, merged per host ([Dotbot wiki](https://github.com/anishathalye/dotbot/wiki/Tips-and-Tricks)).

---

## 2. Mechanisms

Each subsection covers what it **carries**, what it **needs on the remote**, how **host differences** are handled, and how **updates flow**.

### 2.1 This repo's Dotbot `./install` with a Linux profile

- **Carries:** anything listed in a Linux config: the zsh files, `.zsh_plugins.txt`, starship, atuin, eza, fastfetch configs, plus arbitrary `shell:` steps (e.g. calling a tool installer).
- **Needs on remote:** `git` (clone + submodules) and a Python 3 interpreter. `./install` already probes `python3`, then `python`, then `uv` (`install`). Dotbot's README states the Python version floor only for Windows (3.8+).
- **Host differences:** split `install.conf.yaml` into a shared file plus `windows.yaml` / `linux.yaml` and pass the right set with `-c`, or use `if:` on individual links, or adopt the wiki's profile layout. Differences inside a file (the zoxide/cygpath guard, `.zprofile`) still have to be `$OSTYPE` branches in the dotfiles themselves, because Dotbot has no templating. The Windows-only plugin `-p dotbot-winget/winget.py` is loaded by `./install` unconditionally. That is harmless as long as the Linux config contains no `winget:` block, since plugins only handle their own directive.
- **Updates:** `git pull && ./install` on each host. Links are symlinks into the clone, so a pull alone updates file contents. Only new links or steps need `./install`. Automation options: the wiki's `LocalCommand` trick (§2.4), or a cron/systemd timer on the host.
- **Fit:** the least new tooling, and the symlink model is identical to Windows. The cost is a real refactor of `install.conf.yaml` plus portability fixes in the dotfiles (all of §1.1). Every host also needs a clone of the whole repo, Lua config included, which is inert there.

### 2.2 chezmoi as the cross-platform layer

- **Carries:** files (copied by default, or symlinked with `mode = "symlink"` for non-template files), templates, scripts, and **externals**. `.chezmoiexternal.toml` can fetch antidote or plugin archives with a `refreshPeriod` ([include files from elsewhere](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/)).
- **Needs on remote:** nothing but a shell and curl/wget. `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>` installs a single binary (into `./bin` by default, **no root**) and applies ([install](https://www.chezmoi.io/install/)). `chezmoi ssh <host> <init-args>` does the whole thing from the local side. It is marked **"experimental, potentially destructive"** ([`chezmoi ssh`](https://www.chezmoi.io/reference/commands/ssh/)). chezmoi itself also runs natively on Windows (winget `twpayne.chezmoi`, scoop, choco).
- **Host differences:** Go `text/template` with `.chezmoi.os`, `.chezmoi.hostname` and user data. Whole files can be kept per OS via `include`, or skipped via a templated `.chezmoiignore` ([machine-to-machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)). Package installs are `run_onchange_` scripts, templated per OS, that re-run only when their content changes ([scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)).
- **Updates:** `chezmoi update` = `git pull --autostash --rebase` + apply ([update](https://www.chezmoi.io/reference/commands/update/)).
- **Cost to this repo:** chezmoi ignores every source file whose name starts with `.` except its own special files ([special files](https://www.chezmoi.io/reference/special-files/)). It encodes target state in names (`dot_zshrc`, `executable_`, `private_`, …) ([source state attributes](https://www.chezmoi.io/reference/source-state-attributes/)). So `home/.zshrc` would have to become `dot_zshrc` and so on. `.chezmoiroot` can point the source state at a subdirectory such as `home/` ([`.chezmoiroot`](https://www.chezmoi.io/reference/special-files/chezmoiroot/)), but the renames still break the "`home/` mirrors `~`" convention in `AGENTS.md`. The default copy mode also changes the Windows edit loop: herdr writing through its symlinked config (`install.conf.yaml` comment) would no longer land in the repo. Inference: a hybrid (chezmoi only for Linux hosts, `symlink_` or template files that read the existing `home/` files) is possible but gives two sources of truth for "what goes where".

### 2.3 yadm

- **Carries:** a bare git repo whose work-tree **is `$HOME`** (`~/.local/share/yadm/repo.git`), plus alternates, templates, encryption and a `~/.config/yadm/bootstrap` program ([yadm manual](https://github.com/yadm-dev/yadm/blob/master/yadm.md)).
- **Needs on remote:** git and bash (yadm is a bash script).
- **Host differences:** `##os.Linux`, `##distro.Ubuntu`, `##hostname.x`, `##class.Work` filename suffixes. yadm symlinks the best-scoring alternate. The manual notes WSL is reported as OS `WSL`, which gives a free WSL-vs-SSH split.
- **Updates:** `yadm pull`, then `yadm alt` / `yadm bootstrap`.
- **Fit:** poor for *this* repo. Its layout (Lua config at the root, dotfiles under `home/`) is not a `$HOME` work-tree, so yadm means a second, separate dotfiles repo or a restructure. Listed for completeness.

### 2.4 A bootstrap script pushed over SSH

- **Shape:** `ssh host 'bash -s' < bootstrap.sh`, or `ssh host 'curl … | sh'`. The script installs zsh and the tools, clones the repo (or just `home/`), links files, and optionally `chsh`.
- **Carries:** whatever the script does. It can be the Linux half of §2.1, since the script can just call `./install -c linux.yaml`.
- **Needs on remote:** a POSIX shell. git/curl only if the script fetches. sudo only for system packages or `chsh`.
- **Host differences:** plain `case "$(uname -s)"` / `/etc/os-release` branches in the script.
- **Updates:** re-run by hand, or automatically on connect. The Dotbot wiki documents a `LocalCommand` in `~/.ssh/config` that opens a second ssh session to pull or clone the dotfiles ([Dotbot wiki](https://github.com/anishathalye/dotbot/wiki/Tips-and-Tricks)). `LocalCommand` runs **on the local machine** after connecting and needs `PermitLocalCommand yes` (default `no`) ([ssh_config(5)](https://man.openbsd.org/ssh_config)). Inference: on Windows that local command runs under whatever shell OpenSSH for Windows uses, so it would need testing. `SendEnv`/`SetEnv` cannot carry config, because the server must `AcceptEnv` each name.

### 2.5 xxh: carry the shell per connection, install nothing

- **Carries:** a portable zsh (`xxh-shell-zsh`, "stable") plus prerun plugins for dotfiles, starship and zoxide, uploaded to `~/.xxh` on each connection. Delete `~/.xxh` and the host is untouched ([xxh README](https://github.com/xxh/xxh)).
- **Needs on remote:** ssh only, no root. **Target must be Linux x86_64** (ARM is community-supported).
- **Needs locally:** Python/pip (`pip install xxh-xxh`). **Windows as the client is an open issue** ([xxh#184 "Unable to run xxh on Windows"](https://github.com/xxh/xxh/issues/184)), so from this machine it would run from inside WSL. Last release 0.8.16 (2026-04-06).
- **Fit:** the only option for hosts you must not modify (shared or production boxes). It does not use antidote/`.zsh_plugins.txt` natively. Plugins come through xxh's own plugin system, so the config is carried in a different shape.

### 2.6 WezTerm `wezterm ssh`, SSH domains and the multiplexer: a transport, not a provisioner

None of WezTerm's remote features copy dotfiles or tools. What they change is how panes attach, and whether shell integration from the remote is useful.

| Mode | What it is | Remote needs | Shell integration |
|---|---|---|---|
| Plain `ssh` in a local pane (today's F7) | Local pane running `ssh.exe` | sshd | The remote shell's OSC 7/133/1337 bytes pass through ssh like any output, so the prompt jumps (133) and user vars (1337) work **if the remote shell emits them**. A *new split* is a local pane: WezTerm resolves the cwd from the OSC 7 **path only**, never the host (`mux/src/lib.rs` `resolve_cwd`), and discards a path that isn't readable locally, with a comment naming exactly this ssh case (`mux/src/domain.rs:429-445`). So the split opens a local shell in the default cwd, not on the remote. |
| `wezterm ssh host` / `SSH:<host>` domain / `ssh_domains` with `multiplexing = "None"` | WezTerm's built-in ssh client; each tab/pane is a new channel on one session. Panes die when the connection drops ([ssh](https://wezterm.org/ssh.html), [SshDomain](https://wezterm.org/config/lua/SshDomain.html)) | sshd | With `assume_shell = "Posix"`, new panes **open on the remote in the OSC 7 cwd** (WezTerm runs `cd <dir>; env … $SHELL` remotely; `mux/src/ssh.rs:275-285`). `default_prog` works here. `default_cwd` does not. ssh_config support is partial (`Match`/`Include` limits are documented). |
| `SSHMUX:<host>` / `ssh_domains` with `multiplexing = "WezTerm"` | Remote `wezterm-mux-server`; tabs survive disconnects, with predictive local echo ([multiplexing](https://wezterm.org/multiplexing.html)) | **"A compatible version of wezterm must be installed on the remote system"** (`remote_wezterm_path` if not on PATH) | Remote panes are real panes of the remote mux, so OSC 7/133/1337 all work natively. Inference: this repo tracks the WezTerm *nightly*, so "compatible" likely means keeping a matching nightly on each remote, which is an extra update stream. The map already notes user vars are wiped on reattach (wezterm#5832). |

Other points:

- `~/.ssh/config` hosts are **auto-populated** as `SSH:` and `SSHMUX:` domains ([multiplexing](https://wezterm.org/multiplexing.html)). The existing domain manager could spawn into them without adding config.
- In every mode, the integration a remote shell emits comes from **its own rc files**. So whichever mechanism above carries `.zshrc` also carries the OSC 7/133 hooks. Alternatively the stock [`wezterm.sh`](https://github.com/wezterm/wezterm/blob/main/assets/shell-integration/wezterm.sh) (bash+zsh; sets `WEZTERM_HOST` etc.) can be sourced. The Debian/Fedora wezterm packages activate it automatically ([shell integration](https://wezterm.org/shell-integration.html)).
- Inside tmux on the remote, user vars need `set -g allow-passthrough on` ([shell integration](https://wezterm.org/shell-integration.html)).
- **Session persistence caveat (inference):** `utils/sessions.lua` records `get_current_working_dir()` per pane. For a plain-ssh pane that is a remote path, which restores as a local pane in the default cwd.

### 2.7 WSL specifics: shared Windows files vs a native Linux home

- **Where the WSL tab lands:** the WSL domain already opens in `/home/hassan` on purpose (`config/domains.lua:51-57`). The repo comment says `/mnt/c` is slower. Microsoft says the same: "For the fastest performance speed, store your files in the WSL file system if you are working in a Linux command line" ([WSL file systems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)).
- **Option W1: link or source from the Windows clone.** For example, Linux symlinks `~/.zshrc -> /mnt/c/Users/hassa/.../home/.zshrc`, or the existing pattern of sourcing a file from `/mnt/c` (`install.conf.yaml:87`). This gives one source of truth with no pull on the Linux side. The costs: every shell start reads rc files over DrvFs, the hard-coded `/mnt/c/Users/hassa` path, and Windows-only lines in the shared files must be guarded (§1.1). Inference: the zsh caches (`~/.cache/zsh`) and antidote clones would still live on ext4, because `XDG_CACHE_HOME`/`$HOME` are Linux paths, so only the handful of rc files cross the boundary.
- **Option W2: a native clone in the Linux home.** WSL is then "just another Linux host": run whichever of §2.1–2.4 is chosen for SSH hosts, and `git pull` separately from Windows. That is two clones of the same repo on one machine.
- **Interop:** `[interop] appendWindowsPath` defaults to `true`, appending Windows PATH entries ([wsl.conf](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)). Windows tools must be called with their `.exe` extension ([file systems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)), so `starship.exe` from winget never shadows a Linux `starship`. Every Linux tool therefore has to be installed inside the distro. Inference, not measured here: the extra `/mnt/c` PATH entries are scanned when zsh hashes commands. `appendWindowsPath=false` is the knob if startup is slow.
- **Distro-wide settings** (automount root, metadata, systemd) live in `/etc/wsl.conf` and need `wsl --shutdown` to apply ([wsl.conf](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)).
- **Transport alternatives:** the `WSL:` domain (today), or an `ssh_domains` entry with `multiplexing = "None"` pointed at WSL's sshd. The SshDomain docs name "a locally hosted WSL instance" as the use case for that mode ([SshDomain](https://wezterm.org/config/lua/SshDomain.html)). A WSL domain passes the cwd through `wsl.exe --cd` (`mux/src/domain.rs:291-293`), so OSC 7 from zsh in WSL already gives splits in the same directory.

### 2.8 Installing the CLI tools on Linux

Not every winget ID needs a remote equivalent. WezTerm, PowerShell, the Nerd Font, UniGetUI and btop4win are GUI-side or Windows-only. The font is rendered locally. The shell-relevant set is: **zsh, git, starship, fzf, zoxide, atuin, carapace, eza, bat, delta, lazygit, yazi, btop, glow, fastfetch**. Of these, **zoxide is required** by `.zshrc` as written (§1.1), and fzf ≥ 0.48 and bat ≥ 0.26 are needed for full behaviour.

Ubuntu archive versions (Launchpad, `Release` pocket, queried 2026-09-27):

| Package | 22.04 jammy | 24.04 noble | 26.04 resolute |
|---|---|---|---|
| zsh | 5.8.1 | 5.9 | 5.9 |
| fzf | 0.29.0 ✗ | **0.44.1 ✗ (< 0.48)** | 0.67.0 |
| bat (`rust-bat`) | 0.19.0 | **0.24.0 ✗ (< 0.26)** | 0.25.0 ✗ |
| eza | — | 0.18.2 | 0.23.4 |
| zoxide | 0.4.3 | 0.9.3 | 0.9.8 |
| starship | — | — | 1.22.1 |
| atuin | — | — | 18.8.0 |
| btop | 1.2.3 | 1.3.0 | 1.4.6 |
| glow / fastfetch / lazygit | — | — | 2.1.1 / 2.57.1 / 0.57.0 |
| carapace, yazi | — | — | — |

So **on an LTS host, apt alone cannot satisfy this `.zshrc`**. Options:

- **mise** (single binary, `curl https://mise.run | sh` → `~/.local/bin/mise`, **no root**; also installable on Windows via scoop/winget) ([installing mise](https://mise.jdx.dev/installing-mise.html)). Its registry has an entry for **every one of the 13** tools above other than zsh and git (checked `registry/*.toml` in jdx/mise: atuin, bat, btop, carapace, delta, eza, fastfetch, fzf, glow, lazygit, starship, yazi, zoxide). The three entries read in full (btop, eza, starship) list the aqua backend ("curated binary recipes") first ([backends](https://mise.jdx.dev/dev-tools/backends/)). A global list lives in `~/.config/mise/config.toml` (`mise use -g`) and is updated with `mise upgrade`. That file could itself be a dotfile carried by §2.1–2.4. zsh itself still comes from apt (or xxh).
- **aqua directly:** the same registry mise's aqua backend uses, without mise's other features. (Not investigated further.)
- **Per-tool official installers / static binaries:** e.g. starship's `install.sh` defaults to `/usr/local/bin` (uses sudo when needed) with `-b/--bin-dir` for a user dir. atuin, zoxide and mise have similar scripts. Each tool is its own update stream, and each verifies (or doesn't) in its own way. Compare the repo's own stance on pinned hashes in `scripts/install-zsh.sh`.
- **Homebrew on Linux:** default prefix `/home/linuxbrew/.linuxbrew` (chosen so bottles work). It needs write access there, normally a sudo-created directory, plus a compiler toolchain ([Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux)). Heavier than mise for ~15 CLIs.
- **Nix / home-manager:** would cover both dotfiles and tools declaratively, but means a Nix install on each host. Not investigated in depth.

---

## 3. Comparison

| Mechanism | Carries files | Carries tools | Remote prerequisites | Root needed | Host differences | Update flow | Change to this repo |
|---|---|---|---|---|---|---|---|
| Dotbot + Linux profile (§2.1) | ✓ symlinks | via `shell:` steps | git, python3 | only for apt/chsh | multiple `-c` files, `if:`, `$OSTYPE` in dotfiles | `git pull` (+ `./install`) | split `install.conf.yaml`, portability guards |
| chezmoi (§2.2) | ✓ copies (or symlinks) | `run_onchange_` scripts, externals | curl/wget | no (binary in user dir) | templates, `.chezmoiignore` | `chezmoi update` | rename `home/` files (`dot_*`), break "mirrors `~`" |
| yadm (§2.3) | ✓ symlinked alternates | `bootstrap` | git, bash | no | `##os/distro/class` suffixes (WSL detected) | `yadm pull` | separate `$HOME`-shaped repo |
| Bootstrap over SSH (§2.4) | whatever it does | whatever it does | sh (+curl/git) | depends | `uname` branches | re-run or `LocalCommand` | one new script |
| xxh (§2.5) | ✓ per session (`~/.xxh`) | portable zsh + plugins | ssh; Linux x86_64 | no | n/a (ephemeral) | re-upload (`+if`) | new xxh plugin config; client must run in WSL |
| WezTerm ssh/mux domains (§2.6) | ✗ | ✗ (mux mode needs wezterm remotely) | sshd (+ wezterm for mux) | no | n/a | n/a | optional `ssh_domains` / `assume_shell` |
| WSL W1 shared `/mnt/c` (§2.7) | ✓ one copy | ✗ | tools installed in distro | for apt | guards in shared files | automatic (same files) | Linux links into `/mnt/c` |
| WSL W2 native clone (§2.7) | = the SSH choice | = the SSH choice | = the SSH choice | = | = | separate pull | none extra |

These layers stack rather than compete:

1. a **file layer** (Dotbot, chezmoi, yadm, a script, or xxh);
2. a **tool layer** (apt, mise/aqua, per-tool scripts, brew);
3. a **transport** (plain ssh, the `SSH:` domain, `SSHMUX:`, or the WSL domain).

Whatever is chosen, the §1.1 fixes (zoxide guard, cygpath guard, `.zprofile` guard, a real hostname in OSC 7, and not linking `bin/git`) are prerequisites.

---

## 4. Open facts that decide the choice (for the grilling ticket)

1. **Which SSH hosts, and are they Hassan's to modify?** Hosts you must not modify rule out every persistent option except xxh. Owned hosts favour Dotbot or chezmoi.
2. **sudo on those hosts?** Without it: no apt, no `chsh`. zsh must then already exist or come via xxh, and tools via mise or user-dir binaries.
3. **Distro and release (and arch).** On 24.04 and older, fzf/bat/starship/atuin etc. can't come from apt at the needed versions. xxh needs x86_64.
4. **Outbound internet from the hosts?** mise, chezmoi's installer, antidote and the plugin clones all fetch from GitHub. Offline hosts need things pushed from here (xxh, or scp'd binaries).
5. **Long-lived vs ephemeral hosts?** This decides whether a persistent install or a per-session carry fits.
6. **Should tabs survive disconnects?** If yes, `SSHMUX:` domains and a WezTerm build kept in lockstep with the local nightly on every host.
7. **WSL:** which Ubuntu release, and should WSL share files with the Windows clone (W1) or be treated as another Linux host (W2)? Should zsh become the WSL default shell (it is `bash -l` today)?
8. **Should shell history follow?** atuin sync is off (`auto_sync = false`), so each host keeps its own history unless that changes.
9. Related, not decided here: per-machine overrides are the other half of the split, in [Explore: host-specific overrides for a second machine](https://linear.app/peal/issue/PEA-617). A templating layer (chezmoi) would serve both. Dotbot profiles only cover file selection.

---

## Sources

Repo (at `6fa10f3`): `AGENTS.md`, `install`, `install.conf.yaml`, `home/.zshenv`, `home/.zprofile`, `home/.zshrc`,
`home/.zsh_plugins.txt`, `home/.config/starship.toml`, `home/.config/atuin/config.toml`, `home/.gitconfig`,
`home/.config/wsl/wezterm-integration.bash`, `bin/git`, `scripts/install-zsh.sh`, `scripts/install-zsh-plugins.sh`,
`config/domains.lua`, `utils/ssh-hosts.lua`, `utils/sessions.lua`, `dotbot/src/dotbot/{cli,dispatcher}.py`,
`dotbot/README.md`, `dotbot-winget/winget.py`.

- Dotbot wiki, Tips and Tricks: https://github.com/anishathalye/dotbot/wiki/Tips-and-Tricks
- WezTerm: shell integration https://wezterm.org/shell-integration.html · multiplexing https://wezterm.org/multiplexing.html · ssh https://wezterm.org/ssh.html · SshDomain https://wezterm.org/config/lua/SshDomain.html · `assets/shell-integration/wezterm.sh`, `mux/src/lib.rs` (`resolve_cwd`), `mux/src/domain.rs`, `mux/src/ssh.rs` at `b09b56c`
- chezmoi: install https://www.chezmoi.io/install/ · machine differences https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/ · scripts https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/ · externals https://www.chezmoi.io/user-guide/include-files-from-elsewhere/ · `ssh` https://www.chezmoi.io/reference/commands/ssh/ · `update` https://www.chezmoi.io/reference/commands/update/ · special files / `.chezmoiroot` / source-state attributes / target types (reference section)
- yadm manual: https://github.com/yadm-dev/yadm/blob/master/yadm.md
- xxh: https://github.com/xxh/xxh · https://github.com/xxh/xxh/issues/184
- OpenSSH ssh_config(5): https://man.openbsd.org/ssh_config
- Microsoft WSL: https://learn.microsoft.com/en-us/windows/wsl/filesystems · https://learn.microsoft.com/en-us/windows/wsl/wsl-config
- fzf CHANGELOG (0.48.0) and README: https://github.com/junegunn/fzf
- bat CHANGELOG (0.26.0 Catppuccin) and README (`batcat`): https://github.com/sharkdp/bat
- antidote README: https://github.com/mattmc3/antidote
- starship `install/install.sh` and config docs (`hostname.ssh_only`): https://github.com/starship/starship
- mise: https://mise.jdx.dev/installing-mise.html · https://mise.jdx.dev/dev-tools/backends/ · registry https://github.com/jdx/mise/tree/main/registry
- Homebrew on Linux: https://docs.brew.sh/Homebrew-on-Linux
- Ubuntu package versions: Launchpad API `getPublishedSources` (Release pocket), queried 2026-09-27
