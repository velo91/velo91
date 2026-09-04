# Cara Install Extension VS Code dari File .vsix (Dark Velo)

## Prasyarat
- VS Code sudah terinstall
- Command `code` sudah bisa dipanggil dari terminal
  - Cek dengan: `code --version`
  - Kalau belum bisa, jalankan dulu di VS Code: `Ctrl+Shift+P` → ketik **Shell Command: Install 'code' command in PATH** → Enter

## Langkah Install

1. Buka terminal (Konsole/Bash di Kubuntu)

2. Jalankan command berikut:
   ```bash
   code --install-extension ~/Downloads/dark-velo-1.1.1.vsix
   ```

3. Tunggu sampai muncul pesan sukses, contoh:
   ```
   Installing extensions...
   Extension 'dark-velo-1.1.1.vsix' was successfully installed.
   ```

4. Restart VS Code (atau reload window) agar tema aktif:
   - `Ctrl+Shift+P` → **Developer: Reload Window**

5. Aktifkan tema:
   - `Ctrl+Shift+P` → **Preferences: Color Theme**
   - Pilih **Dark Velo** dari daftar

## Uninstall (jika perlu)
```bash
code --list-extensions
```
Cari extension ID-nya (biasanya format `publisher.dark-velo`), lalu:
```bash
code --uninstall-extension publisher.dark-velo
```

## Cara Alternatif (via GUI)
1. Buka VS Code
2. Klik ikon **Extensions** (`Ctrl+Shift+X`)
3. Klik ikon **...** (More Actions) di pojok kanan atas panel Extensions
4. Pilih **Install from VSIX...**
5. Browse ke `~/Downloads/dark-velo-1.1.1.vsix` lalu pilih
