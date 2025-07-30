<?php
// Allowlist memudahkan kita karena bisa bikin whitelist tidak perlu restart CrowdSec jadi langsung ngefek ketika ditambahkan/dihapus
// Berbeda dengan whitelist pakai Enricher file (/etc/crowdsec/parsers/s02-enrich/XXX.yaml) karena perlu restart CrowdSec terlebih dahulu supaya ngefek
//
// Buat allowlist di server cloud:
// cscli allowlist create semua_ip_kampus -d 'Semua IP Kampus yang didapat dari cronjob'
//
// Ini tidak perlu dijalankan, tapi kalau mau hapus 1 allowlist berlaku untuk semua ip didalamnya, pakai:
// cscli allowlists delete NAMA_ALLOWLIST
//
// Baca dokumentasi di https://docs.crowdsec.net/docs/next/cscli/cscli_allowlists
//
// cscli allowlist list
// cscli allowlist inspect semua_ip_kampus
// cscli allowlist check 36.68.106.83
// cscli allowlist add semua_ip_kampus 36.68.106.83
// cscli allowlist remove semua_ip_kampus 36.68.106.83
//
// Cronjob di server local:
// */5 * * * * curl -s -X POST -H "Authorization: Bearer vkeArXEx5P57" -d "kampus=kampusA" https://my.domain.id/update-ip.php > /dev/null

// Daftar token per kampus
$secrets = [
    "kampusA" => "xxx", // ...
    "kampusB" => "yyy", // ...
    "kampusC" => "zzz", // ...
];

// Ambil Authorization header
$headers = getallheaders();
if (!isset($headers['Authorization'])) {
    http_response_code(401);
    exit("Unauthorized");
}

list($type, $token) = explode(' ', $headers['Authorization'], 2);
if ($type !== "Bearer") {
    http_response_code(401);
    exit("Unauthorized");
}

// Ambil parameter kampus dari POST
$kampus = $_POST['kampus'] ?? null;

if (!$kampus || !isset($secrets[$kampus]) || $secrets[$kampus] !== $token) {
    http_response_code(403);
    exit("Forbidden");
}

$file = __DIR__ . "/ip-{$kampus}.txt";
$ip = $_SERVER['REMOTE_ADDR'];

// Default
$ip_sebelumnya = "";

// Kalau file sudah ada, ambil ip_saat_ini lama
if (file_exists($file)) {
    $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (str_starts_with($line, 'ip_saat_ini:')) {
            $parts = explode(':', $line, 2);
            if (isset($parts[1])) {
                $old_ip = trim($parts[1]);
                // Kalau beda → ip_sebelumnya diisi, kalau sama → tetap kosong
                if ($old_ip !== $ip) {
                    $ip_sebelumnya = $old_ip;
                }
            }
            break;
        }
    }
}

// Tulis ulang dengan IP baru dan lama
$content = "ip_saat_ini: $ip\nip_sebelumnya: $ip_sebelumnya\n";
file_put_contents($file, $content);

echo "Update: ip_saat_ini=$ip, ip_sebelumnya=$ip_sebelumnya";
