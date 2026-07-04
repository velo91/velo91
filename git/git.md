# BTIK Git Workflow

### Clone Repository

```bash
git clone git@github.com:ubbg-dev/siakad.git
```

### Masuk ke Project

```bash
cd siakad
```

### Ambil Perubahan Terbaru

```bash
git pull
```

### Cek Status

```bash
git status
```

### Tes koneksi SSH

```bash
ssh -T git@github.com
```

Kalau berhasil biasanya muncul seperti:
Hi username! You've successfully authenticated...
Artinya SSH Key masih berfungsi.

### Verifikasi Nama dan Email

```bash
git config user.name
git config user.email
```

### Ubah Nama (Semua Repository)

```bash
git config --global user.name "Achyar Munandar"
```

### Ubah Email (Semua Repository)

```bash
git config --global user.email "email@example.com"
```


---


## Tambahkan Perubahan

```bash
git add .
```

## Commit

```bash
git commit -m "Perbaiki validasi login"
```

## Dari folder tersebut, Kirim ke GitHub

```bash
git push
```

## Dari GitHub, Terapkan ke production

masuk ke folder project tersebut yang production, lalu

```bash
git pull
```


---


## Aturan BTIK

- Pastikan file dan folder yang tidak perlu dipublikasikan sudah masuk ke `.gitignore`.
- Periksa hasil `git status` sebelum melakukan `git commit`.
- Gunakan email yang terdaftar pada akun GitHub Anda agar riwayat commit dapat dikaitkan dengan akun GitHub yang benar, boleh email pribadi (tidak mesti email resmi).


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
