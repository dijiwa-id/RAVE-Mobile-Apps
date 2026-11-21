# Backup desain vinyl v1 (sebelum refine vintage/hyperrealistic, 2026-11-21)

Salinan persis file pada commit `1de9ca9` (file ini belum diubah saat dicadangkan).

## Rollback (dari root repo)

```bash
(cd design-backup/vinyl-v1-2026-11-21 && find . -type f ! -name README.md -exec cp --parents {} ../../ \;) && git status
# atau lewat git:
git checkout 1de9ca9 -- lib/screens/intro.dart lib/screens/now_playing.dart lib/widgets/vinyl.dart 
```

Lalu hapus aset tekstur baru bila tak dipakai lagi (mis. `textures/vinyl-*.webp`).

## File
- `lib/screens/intro.dart`
- `lib/screens/now_playing.dart`
- `lib/widgets/vinyl.dart`
