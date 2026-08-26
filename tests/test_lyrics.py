import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("omajam_mpd", str(ROOT / "bin" / "omajam-mpd"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
BRIDGE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(BRIDGE)


class LyricsParserTests(unittest.TestCase):
    def test_parses_billy_talent_style_crlf_tag(self):
        rows = BRIDGE.parse_lrc(
            "[00:25.53] Wherever I go, wherever I go\r\n"
            "[00:28.58] I have to question the hand that I hold close\r\n"
            "[03:31.19] \r\n"
        )
        self.assertEqual([row["stamp"] for row in rows], ["0:25.53", "0:28.58", "3:31.19"])
        self.assertEqual(rows[0]["text"], "Wherever I go, wherever I go")
        self.assertEqual(rows[-1]["text"], "")

    def test_expands_multiple_timestamps_and_applies_offset(self):
        rows = BRIDGE.parse_lrc(
            "[offset:+500]\n[00:02.00][00:01.500]Same line\n[00:03]Later"
        )
        self.assertEqual([(row["time"], row["text"]) for row in rows], [
            (2.0, "Same line"), (2.5, "Same line"), (3.5, "Later"),
        ])

    def test_ignores_headers_and_invalid_seconds(self):
        rows = BRIDGE.parse_lrc("[ar:Billy Talent]\n[00:60.00]Bad\n[01:02.5]Good")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["text"], "Good")

    def test_reads_embedded_lyrics_with_ffprobe(self):
        payload = json.dumps({
            "format": {"tags": {"LYRICS": "[00:25.53] Wherever I go\n[00:28.58] Close"}}
        })
        completed = BRIDGE.subprocess.CompletedProcess([], 0, stdout=payload, stderr="")
        with tempfile.TemporaryDirectory() as directory:
            track = pathlib.Path(directory) / "Billy Talent" / "Afraid of Heights.flac"
            track.parent.mkdir()
            track.touch()
            with mock.patch.object(BRIDGE.subprocess, "run", return_value=completed) as run:
                rows = BRIDGE.embedded_lyrics(directory, "Billy Talent/Afraid of Heights.flac")
            self.assertEqual([row["text"] for row in rows], ["Wherever I go", "Close"])
            self.assertEqual(pathlib.Path(run.call_args.args[0][-1]), track)

    def test_rejects_paths_outside_music_root(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(BRIDGE.embedded_lyrics(directory, "../outside.flac"), [])


if __name__ == "__main__":
    unittest.main()
