```

            /\   /\
           ( ..   .. )      _  __ ____  ____
            \  Y  /        | |/ /|  _ \/ ___|
         /\_/\   /\_/\     | ' / | |_) \___ \
        (  o o     o o)    | . \ |  _ < ___) |
         \  ~   ~  /       |_|\_\|_| \_\____/
          \___^___/

```

# 🦊 KrsVim - An orange-fox nvim tailored for fox coders

![krsnv-cover](./.github/cover.png)
![krsnv-editor](./.github/editor-example.png)

My personal Neovim setup — a mini-distro, if you like. Fork it, use it, break it. Windows is first-class, WSL is layered on top, plain Linux should mostly hold up (open an issue if it doesn't 🦊).

Expect sharp edges and highly opinionated wiring.

---

## 🖥️ Dashboard shortcuts

The start screen. One letter per entry:

| Key | Opens |
|---|---|
| `f` | File Explorer (Desktop) |
| `p` | Recent projects |
| `l` | File Explorer (WSL) — Windows only, shown when WSL is installed |
| `w` | Wiki / documentation (`:NvimWiki`) |
| `e` | Plugins & extensions (`:Lazy`) |
| `m` | LSPs & languages (`:Mason`) |
| `q` | Quit |

Return to the dashboard from anywhere with `<C-S-m>`; closing the last open buffer also lands here.

---

## 📚 Documentation

Everything else — install, keybinds, debugging, launch profiles, custom modules — lives in the wiki:

**➡️ [docs/index.md](docs/index.md)**

Open it inside the editor with `w` on the dashboard, or `:NvimWiki`.
