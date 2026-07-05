# Front Light Indicator — a KOReader plugin

Shows a small symbol in the [KOReader](https://github.com/koreader/koreader) status bar **while
the front light is on**, and **nothing at all when it is off** — an at-a-glance reminder that the
light is on (and quietly draining your battery).

## Features

- **Bottom status bar (footer)** — adds the indicator via KOReader's supported external-content
  API. The symbol appears only while the light is on; when it's off, nothing is shown and no space
  is used.
- **Top status bar (header)** — optional, for reflowable documents (EPUB, etc.). PDFs have no top
  status bar, so the option is greyed out there.
- **Symbol picker** — choose the glyph:
  - **Automatic** (default) follows your status bar item style — `☼` (Icons), `✺` (Compact), or
    `L` (Letters). The plain `L` only appears when your status bar uses the Letters style, which
    shows text abbreviations instead of icons.
  - Presets: `☼` `☀` `✺` `💡`.
  - **Custom…** — type any glyph or short text (e.g. `LIGHT`).
- In-app help on every option (long-press a menu row).

Every setting lives under **Device ▸ Front light indicator**. On devices without a front light the
plugin disables itself.

## Installation

KOReader loads plugins from folders named `*.koplugin`. Clone (or download) this repo **into a
folder called `frontlightindicator.koplugin`** inside your KOReader `plugins/` directory:

```sh
cd /path/to/koreader/plugins
git clone https://github.com/kanni/koreader-frontlight-indicator.git frontlightindicator.koplugin
```

The `plugins/` location depends on your platform (e.g. `koreader/plugins/` in the app directory,
or a `plugins/` folder under your KOReader home/data directory). Restart KOReader after installing.

## Development

The plugin is two files: [`_meta.lua`](_meta.lua) (metadata) and [`main.lua`](main.lua) (a
`WidgetContainer` subclass). It touches no KOReader core files — it uses
`ReaderFooter:addAdditionalFooterContent` and `ReaderCoptListener:addAdditionalHeaderContent`.

A quick syntax check without a full KOReader build (requires [LuaJIT](https://luajit.org/)):

```sh
luajit -e "assert(loadfile('main.lua'))"
```

## License

[AGPL-3.0](LICENSE), matching KOReader.
