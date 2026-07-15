# Full Adhan audio

Full-length Adhan files played in-process by `AVAudioPlayer` at the prayer
instant (spec §9 — they exceed the 30 s notification-sound cap). Drop the files
here and run `xcodegen generate`; matched by filename in `NotificationSound`:

| NotificationSound | file                |
|-------------------|---------------------|
| `.adhanMakkah`    | `adhan-makkah.m4a`  |
| `.adhanMadinah`   | `adhan-madinah.m4a` |

These are the bundled Adhans. Users can also import their own audio (Settings →
Notifications → Custom sounds), stored under Application Support and referenced by
`NotificationSound.custom(_:)` / `CustomSound` — see `CustomAdhanLibrary`. Until the
bundled files are added, full-Adhan playback no-ops with a log; everything else works.
