# Short notification sounds

Bundled `.caf`/`.aiff` clips used as `UNNotificationSound` (≤ 30 s — the system
cap, spec §9). Drop the files here and run `xcodegen generate`; they are matched
by filename in `NotificationSound`:

| NotificationSound | file              |
|-------------------|-------------------|
| `.softChime`      | `soft-chime.caf`  |
| `.takbir`         | `takbir.caf`      |
| `.adhanMakkah`*   | `takbir.caf`      |
| `.adhanMadinah`*  | `takbir.caf`      |

\* Adhan selections use the short takbir clip for the *notification*; the full
Adhan plays in-process from `../Adhan/` (see §9). Until files are added,
notifications fall back to the system default sound.
