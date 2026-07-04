# BTIK Git Workflow

## Clone Repository

```bash
git clone git@github.com:ubbg-dev/siakad.git
```

## Masuk ke Project

```bash
cd siakad
```

## Ambil Perubahan Terbaru

```bash
git pull
```

## Cek Status

```bash
git status
```

## Tambahkan Perubahan

```bash
git add .
```

## Commit

```bash
git commit -m "Perbaiki validasi login"
```

## Kirim ke GitHub

```bash
git push
```

## Terapkan ke production

masuk ke folder project tersebut, lalu

```bash
git pull
```

---

## Aturan BTIK

- Pastikan file yang tidak perlu dipublikasikan sudah masuk ke `.gitignore`.
- Periksa hasil `git status` sebelum melakukan `git commit`.
- Jangan melakukan `git push --force` tanpa persetujuan maintainer.

---

## Jika Repository Berpindah

Cek alamat remote saat ini.

```bash
git remote -v
```

Ubah ke repository baru.

**SSH**

```bash
git remote set-url origin git@github.com:ubbg-dev/siakad.git
```

**HTTPS**

```bash
git remote set-url origin https://github.com/ubbg-dev/siakad.git
```

Verifikasi kembali.

```bash
git remote -v
```
