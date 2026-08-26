# OmaJam - Lyrics+ Edition

An MPD client for the Omarchy Quattro bar with synchronized embedded lyrics,
album artwork, queue management, library browsing, playlists, search, and
keyboard-first controls.

## Credit And Origin

This project is an MIT-licensed edition of
[OmaJam](https://github.com/matjam/omajam), created by
[Nathan Ollerenshaw (matjam)](https://github.com/matjam).

Nathan designed and implemented the original MPD bridge, queue and library
browsers, search, playlist management, bar widget, album-art cache, settings,
format language, keyboard controls, and overall rmpc-inspired interface. This
edition keeps that foundation and adds the Lyrics+ functionality described
below. It is maintained independently and is not an official OmaJam release.

## What Lyrics+ Changes

- Adds a Lyrics tab before Settings (`9` for Lyrics, `0` for Settings).
- Reads synchronized LRC lyrics embedded in local FLAC and M4A metadata.
- Shows a dedicated album-art lyrics stage instead of a generic table.
- Highlights and vertically centers the current line with smooth auto-follow.
- Fades surrounding lines according to their distance from the current line.
- Shows timestamps on hover and seeks when a lyric is clicked or activated.
- Shows radial progress inside the active lyric line.
- Pauses auto-follow briefly during manual browsing and offers a return action.
- Displays timed blank lines as an animated instrumental marker.
- Hides artwork automatically when the panel is too narrow.
- Changes MPD volume by 2% when scrolling the small panel volume bar.

The rest of the MPD client remains OmaJam: queue editing, directory/artist/
album/genre browsing, stored playlists, search, cover art, notifications,
transport controls, output state, and the mpc-compatible bar label formatter.

## Requirements

- Omarchy Quattro
- Python 3
- MPD
- `ffprobe` from FFmpeg, used only to read embedded lyrics from local files

The MPD server may be remote for normal playback and browsing, but embedded
lyrics require the corresponding music files to exist on the same machine as
the Omarchy shell. The default local music root is `~/Music`.

Install MPD and FFmpeg through your normal system package workflow before
enabling the plugin.

## Install

```bash
omarchy plugin add https://github.com/Razkaroth/omajam-lyrics-plus.git --enable
```

Choose a bar section when prompted. If the original `matjam.omajam` is enabled,
disable or remove it to avoid running two MPD clients:

```bash
omarchy plugin disable matjam.omajam
```

Update or remove Lyrics+ with:

```bash
omarchy plugin update io.github.razkaroth.omajam-lyrics-plus
omarchy plugin remove io.github.razkaroth.omajam-lyrics-plus
```

Removal deletes the plugin only. It does not remove MPD, your MPD database, or
your music.

## MPD Setup

A minimal user MPD configuration at `~/.config/mpd/mpd.conf` looks like:

```conf
music_directory "~/Music"
playlist_directory "~/.local/share/mpd/playlists"
db_file "~/.local/share/mpd/database"
state_file "~/.local/state/mpd/state"
auto_update "yes"

audio_output {
    type "pipewire"
    name "PipeWire"
}
```

Start MPD through your normal user-session setup, then scan the library:

```bash
omarchy-shell -q omajam-lyrics-plus-mpd update
```

The server defaults to `127.0.0.1:6600`. Host, port, password, and the local
lyrics directory are available in the widget settings. An empty host follows
`$MPD_HOST`, including its `password@host` form.

## Embedded Lyrics

MPD's `readcomments` command omits multiline Vorbis comments on common local
setups. Lyrics+ therefore resolves the current MPD file URI beneath the
configured local music root and asks `ffprobe` for its `LYRICS` metadata.

Supported synchronized LRC features include:

- `[mm:ss]`, `[mm:ss.xx]`, and `[mm:ss.xxx]` timestamps
- `.` or `:` fractional separators
- multiple timestamps on one line
- duplicate timestamps
- positive and negative `[offset:]` values
- LF and CRLF line endings
- timed blank instrumental lines

Paths are canonicalized and rejected if they resolve outside the configured
music root. Streams and remote-only files simply show that no synchronized
embedded lyrics are available. Lyrics are read on demand and are not uploaded
or sent to an external lyrics service.

## Tabs

| Key | Tab | Purpose |
| --- | --- | --- |
| `1` | Queue | Current queue and cover |
| `2` | Directories | Music tree on disk |
| `3` | Artists | Artist, album, track |
| `4` | Album Artists | Album artist, album, track |
| `5` | Albums | Albums and tracks |
| `6` | Genre | Genre, album, track |
| `7` | Playlists | Stored MPD playlists |
| `8` | Search | Search all indexed tags |
| `9` | Lyrics | Synchronized embedded lyrics |
| `0` | Settings | Plugin and MPD settings |

## Main Controls

| Keys | Action |
| --- | --- |
| `j` / `k`, arrows | Move |
| `enter` | Play selection, or seek to selected lyric |
| `a` / `A` | Add selection / all visible items |
| `d` / `D` | Delete selection / clear queue |
| `p`, `s` | Play/pause, stop |
| `<` / `>` | Previous, next |
| `f` / `b` | Seek forward/back five seconds |
| `.` / `,` | Volume up/down five percent |
| `/`, `n`, `N` | Find, next match, previous match |
| `tab`, `1`-`9`, `0` | Switch tabs |
| `?` | Show all keybindings |
| `q`, `esc` | Close |

In Lyrics, scrolling or keyboard navigation pauses automatic following for
four seconds. Click **Return to current line** to resume immediately. Hover a
line to reveal its timestamp; click it to seek.

The small volume bar in the panel header remains click-to-set and also changes
MPD volume by 2% per upward or downward scroll event.

## Command Line

```bash
omarchy-shell io.github.razkaroth.omajam-lyrics-plus client
omarchy-shell io.github.razkaroth.omajam-lyrics-plus settings
omarchy-shell io.github.razkaroth.omajam-lyrics-plus search "billy talent"
omarchy-shell io.github.razkaroth.omajam-lyrics-plus key 9

omarchy-shell -q omajam-lyrics-plus-mpd toggle
omarchy-shell omajam-lyrics-plus-mpd status
omarchy-shell -q omajam-lyrics-plus-mpd volume +2
omarchy-shell -q omajam-lyrics-plus-mpd update
```

## Storage And Security

- The plugin runs unsandboxed with your user permissions, like all Omarchy shell
  plugins.
- It connects only to the configured MPD server.
- Album art is cached under `~/.cache/omajam` and pruned automatically.
- It invokes local `ffprobe` for the current song when the Lyrics tab is opened.
- An MPD password saved through settings is plain text in
  `~/.config/omarchy/shell.json`; use `$MPD_HOST=password@host` to keep it out of
  that file.
- No `sudo` or `pkexec` is required by the plugin.

## Development

Validate and test from the repository root:

```bash
omarchy plugin validate .
./.github/scripts/marketplace-check.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

## License

MIT. See [LICENSE](LICENSE).

The license preserves Nathan Ollerenshaw's copyright for the original OmaJam
code and records Nicolás Aranda's copyright for Lyrics+ modifications.
