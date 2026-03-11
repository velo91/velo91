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
// */5 * * * * curl -s -X POST -H "Authorization: Bearer xxx" -d "kampus=kampusA" -d "ip_alt=$(curl -s api.ipify.org)" https://my.domain.id/update-ip.php > /dev/null

// Daftar token per kampus
$secrets = [
    "kampusA" => "xxx", // ...
    "kampusB" => "yyy", // ...
    "kampusC" => "zzz", // ...
];

// Ambil Authorization header
$headers = getallheaders();
if (!isset($headers['Authorization'])) {
    //http_response_code(401);
    exit("Unauthorized");
}

list($type, $token) = explode(' ', $headers['Authorization'], 2);
if ($type !== "Bearer") {
    //http_response_code(401);
    exit("Unauthorized");
}

// Ambil parameter kampus dari POST
$kampus = $_POST['kampus'] ?? '';
if (!$kampus || !isset($secrets[$kampus]) || $secrets[$kampus] !== $token) {
    //http_response_code(403);
    exit("Forbidden");
}
$ip_alt = $_POST['ip_alt'] ?? '';

function getRealIP() {
    if (!empty($_SERVER['HTTP_CF_CONNECTING_IP'])) {
        return $_SERVER['HTTP_CF_CONNECTING_IP'];
    }

    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }

    if (!empty($_SERVER['HTTP_X_REAL_IP'])) {
        return $_SERVER['HTTP_X_REAL_IP'];
    }

    return $_SERVER['REMOTE_ADDR'];
}

$file = __DIR__."/ip-$kampus.txt";

$ip_cloud = getRealIP();

$ip_saat_ini = $ip_cloud;
$ip_saat_ini_alt = "";

if($ip_alt && $ip_alt != $ip_cloud){
    $ip_saat_ini_alt = $ip_alt;
}

$ip_sebelumnya = "";
$ip_sebelumnya_alt = "";

if(file_exists($file)){

    $data = file($file, FILE_IGNORE_NEW_LINES);

    foreach($data as $line){

        if(strpos($line,"ip_saat_ini:")===0){
            $old = trim(explode(":",$line)[1]);
            if($old != $ip_saat_ini){
                $ip_sebelumnya = $old;
            }
        }

        if(strpos($line,"ip_saat_ini_alt:")===0){
            $old = trim(explode(":",$line)[1]);
            if($old != $ip_saat_ini_alt){
                $ip_sebelumnya_alt = $old;
            }
        }

    }
}

$content =
"ip_saat_ini: $ip_saat_ini
ip_saat_ini_alt: $ip_saat_ini_alt
ip_sebelumnya: $ip_sebelumnya
ip_sebelumnya_alt: $ip_sebelumnya_alt
";

file_put_contents($file,$content);

echo $content;
