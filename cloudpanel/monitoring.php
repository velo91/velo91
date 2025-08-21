<?php
date_default_timezone_set('Asia/Jakarta');

// Mapping range ke jumlah data (per menit)
$minute_ranges = [
    1 => 5,     // 5 menit
    2 => 30,    // 30 menit
    3 => 60,    // 1 jam
    4 => 180,   // 3 jam
    5 => 360,   // 6 jam
    6 => 720,   // 12 jam
    7 => 1440   // 24 jam
];

// Default: 6 jam
$range = isset($_GET['range']) ? intval($_GET['range']) : 7;
$limit = $minute_ranges[$range] ?? 1440;

// Koneksi SQLite
$db = new PDO('sqlite:/home/clp/htdocs/app/data/db.sq3');

// Ambil data dan konversi waktu ke WIB
function get_data($db, $table, $where = '') {
    global $limit;
    $stmt = $db->query("SELECT created_at, value FROM $table $where ORDER BY created_at DESC LIMIT $limit");
    $rows = array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC));
    foreach ($rows as &$row) {
        $utc = new DateTime($row['created_at'], new DateTimeZone('UTC'));
        $utc->setTimezone(new DateTimeZone('Asia/Jakarta'));
        $row['created_at_wib'] = $utc->format('H:i');
    }
    return $rows;
}

$cpu_data = get_data($db, 'instance_cpu');
$memory_data = get_data($db, 'instance_memory');
$disk_data = get_data($db, 'instance_disk_usage', "WHERE disk = '/'");
$load_data = get_data($db, 'instance_load_average', "WHERE period = 1");

$cpuinfo = @file_get_contents('/proc/cpuinfo');
preg_match_all('/^processor/m', $cpuinfo, $matches);
$core = count($matches[0]);
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Monitoring</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css"/>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/7.0.0/css/all.min.css" rel="stylesheet">
  <style>
    body {
      background-color: #f8f9fa;
      transition: background-color 0.3s, color 0.3s;
    }
    canvas {
      background: white;
      padding: 10px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .chart-box {
      margin-bottom: 30px;
      opacity: 0;
    }
    .range a {
      font-weight: bold;
    }
    .dark-mode {
      background-color: #121212;
      color: #e4e4e4;
    }
    .dark-mode canvas {
      background-color: #1e1e1e;
    }
    /* Cyber Dynamic Background */
    :root {
      --bg-dark:#020610;
      --stream-color:rgba(0,255,200,0.15);
      --orb1:#21e9ff;
      --orb2:#7b5cff;
      --neon-glow: rgba(0,255,200,0.25);
    }
    /* Background base */
    .cyber-bg{
      position:fixed;
      inset:0;
      z-index:0;
      overflow:hidden;
      background: radial-gradient(circle at 50% 50%, #041a26 0%, #020610 100%);
    }
    /* Aliran data diagonal */
    .cyber-layer.streams{
      position:absolute; inset:0;
      background-image:
        repeating-linear-gradient(120deg, transparent 0 28px, var(--stream-color) 28px 30px);
      background-size: 300px 300px;
      animation: moveStreams 18s linear infinite;
      opacity:0.25;
    }
    @keyframes moveStreams{
      0%{background-position:0 0;}
      100%{background-position:600px 600px;}
    }
    /* Orb neon */
    .cyber-orb {
      position:absolute;
      width:800px; height:800px;
      border-radius:50%;
      filter: blur(200px);
      opacity:0.45;
      mix-blend-mode:screen;
    }
    .orb1 {
      background:var(--orb1);
      top:20%; left:10%;
      animation: moveOrb1 40s ease-in-out infinite alternate;
    }
    .orb2 {
      background:var(--orb2);
      top:60%; left:60%;
      animation: moveOrb2 55s ease-in-out infinite alternate;
    }
    @keyframes moveOrb1 {
      0%{transform:translate(0,0);
    }
    /* Glow lembut */
    .cyber-layer.glow{
      position:absolute; inset:0;
      background: radial-gradient(circle at center, var(--neon-glow), transparent 70%);
      filter: blur(100px);
      animation: glowPulse 10s ease-in-out infinite;
    }
    @keyframes glowPulse{
      0%,100%{opacity:0.5;}
      50%{opacity:0.85;}
    }
  </style>
</head>
<body class="dark-mode">

<!-- Cyber Dynamic Background -->
<div class="cyber-bg">
  <div class="cyber-layer streams"></div>
  <div class="cyber-orb orb1"></div>
  <div class="cyber-orb orb2"></div>
  <div class="cyber-layer glow"></div>
</div>

<?php
// Announcement Sound (Melodic airport announcement ding): https://mixkit.co/free-sound-effects/airport/
$minute = date("i"); // ambil menit sekarang
$file_audio = '/assets/announcement.mp3';
if($minute === "00") {
    echo '<audio autoplay>
            <source src="'.$file_audio.'" type="audio/wav">
          </audio>';
}
?>

<!-- Konten Bootstrap -->
<div class="container text-center position-relative">
  <div class="text-center mt-4 mb-4 range">
    <div class="btn-group" role="group" aria-label="Range Selector">
      <?php
        $labels = [1 => '5m', 2 => '30m', 3 => '1h', 4 => '3h', 5 => '6h', 6 => '12h', 7 => '24h'];
        foreach ($labels as $key => $label) {
            $class = ($range == $key) ? 'btn btn-sm btn-secondary active' : 'btn btn-sm btn-outline-secondary';
            echo "<a href='?range=$key' class='$class'>$label</a>";
        }
      ?>
    </div>
    <button id="toggleTheme" class="btn btn-sm btn-outline-secondary text-secondary"><i class="fas fa-moon"></i></button>
  </div>
  
  <div class="row">
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-microchip text-primary"></i> Penggunaan CPU <span id="status-cpu"></span>
      </h6>
      <canvas id="cpuChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-memory text-success"></i> Penggunaan RAM <span id="status-memory"></span>
      </h6>
      <canvas id="memoryChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-hdd text-warning"></i> Penggunaan SSD <span id="status-disk"></span>
      </h6>
      <canvas id="diskChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-chart-line text-danger"></i> Beban Server <span id="status-load"></span>
      </h6>
      <canvas id="loadChart"></canvas>
    </div>
  </div>
</div>

<script>
$(document).ready(function() {
  $(".chart-box").each(function(i) {
    // kasih delay biar muncul satu per satu
    let el = $(this);
    setTimeout(function() {
      el.addClass("animate__animated animate__fadeIn");
      el.css("opacity", 1); // baru tampil
    }, 300 * i);
  });
});

// Fungsi downsample (ambil n titik merata dari seluruh data)
function downsample(data, count) {
  if (data.length <= count) return data;
  let step = (data.length - 1) / (count - 1);
  let result = [];
  for (let i = 0; i < count; i++) {
    result.push(data[Math.round(i * step)]);
  }
  return result;
}

<?php /*
const timeLabels = <?= json_encode(array_map(fn($d) => $d . ' WIB', array_column($cpu_data, 'created_at_wib'))) ?>;
*/ ?>
const timeLabels = <?= json_encode(array_map(fn($d) => $d, array_column($cpu_data, 'created_at_wib'))) ?>;
const cpuValues = <?= json_encode(array_column($cpu_data, 'value')) ?>;
const cpuValueLast = cpuValues[cpuValues.length - 1];
const memoryValues = <?= json_encode(array_column($memory_data, 'value')) ?>;
const memoryValueLast = memoryValues[memoryValues.length - 1];
const diskValues = <?= json_encode(array_column($disk_data, 'value')) ?>;
const diskValueLast = diskValues[diskValues.length - 1];
const loadValues = <?= json_encode(array_column($load_data, 'value')) ?>;
const loadValueLast = loadValues[loadValues.length - 1];

// Jumlah titik yang mau ditampilkan di sumbu X
const POINTS = 7;

// Downsample semua data sekaligus (agar konsisten X axis-nya)
const labelFiltered = downsample(timeLabels, POINTS);
const cpuFiltered = downsample(cpuValues, POINTS);
const memoryFiltered = downsample(memoryValues, POINTS);
const diskFiltered = downsample(diskValues, POINTS);
const loadFiltered = downsample(loadValues, POINTS);

// Data lainnya
const maxLoad = loadFiltered.length > 0 ? Math.max(...loadFiltered) : 0;
console.log("maxLoad="+maxLoad);
const cpuCore = <?=$core?>;
console.log("cpuCore="+cpuCore);

function createChartMin0Max100(id, label, labels, data, ySuffix = '%', borderColor = 'blue', decimals = 0) {
  const isDark = $('body').hasClass('dark-mode');
  new Chart(document.getElementById(id), {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: label,
        data: data,
        borderColor: borderColor,
        tension: 0.3,
        fill: false
      }]
    },
    options: {
      animation: false,
      //animation: {
      //  duration: 500, // durasi animasi (ms)
      //  easing: 'linear' // gaya animasi
      //},
      //transitions: {
      //  active: {
      //    animation: {
      //      duration: 500
      //    }
      //  }
      //},
      responsive: true,
      plugins: {
        legend: {
            display: false
        }
      },
      scales: {
        x: {
          offset: true, // geser titik pertama dari grid awal
          ticks: {
              color: isDark ? '#ccc' : '#000',
              font: {
                size: 16
              }
          },
          grid: {
              color: isDark ? '#333' : '#ddd'
          }
        },
        y: {
          ticks: {
            stepSize: 25, // biar jadi 0%, 25%, 50%, 75%, 100%
            callback: value => Number(value).toFixed(decimals) + ySuffix,
            color: isDark ? '#ccc' : '#000',
            font: {
              size: 16
            }
          },
          grid: { color: isDark ? '#333' : '#ddd' },
          min: 0,
          max: 100
        }
      }
    }
  });
}

function createChartLoadAverage(id, label, labels, data, ySuffix = '%', borderColor = 'blue', decimals = 0, maxLoad, cpuCore) {
  const isDark = $('body').hasClass('dark-mode');
  new Chart(document.getElementById(id), {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: label,
        data: data,
        borderColor: borderColor,
        tension: 0.3,
        fill: false
      }]
    },
    options: {
      animation: false,
      //animation: {
      //  duration: 500, // durasi animasi (ms)
      //  easing: 'linear' // gaya animasi
      //},
      //transitions: {
      //  active: {
      //    animation: {
      //      duration: 500
      //    }
      //  }
      //},
      responsive: true,
      plugins: {
        legend: {
            display: false
        }
      },
      scales: {
        x: {
          //offset: true, // geser titik pertama dari grid awal
          ticks: {
              color: isDark ? '#ccc' : '#000',
              font: {
                size: 16
              }
          },
          grid: { color: isDark ? '#333' : '#ddd' }
        },
        y: {
          ticks: {
            stepSize: Math.ceil(cpuCore / 4),
            callback: value => Number(value).toFixed(decimals),
            color: isDark ? '#ccc' : '#000',
            font: {
              size: 16
            }
          },
          grid: {
              color: isDark ? '#333' : '#ddd'
          },
          min: 0,
          max: maxLoad < cpuCore ? Number(cpuCore).toFixed(decimals) : Number(maxLoad).toFixed(decimals)
        }
      }
    }
  });
}

function applyDarkMode(active) {
  if (active) {
    $('body').addClass('dark-mode');
    $('#toggleTheme').html(`<i class="fas fa-sun"></i>`);
  } else {
    $('body').removeClass('dark-mode');
    $('#toggleTheme').html(`<i class="fas fa-moon"></i>`);
  }
  localStorage.setItem('darkMode', active ? '1' : '0');
}

function statusBadgeCPUMemory(percent) {
    let badge = '';
    if (percent < 30) {
        badge = `<span class="badge text-bg-secondary fs-5">Ringan (${percent}%)</span>`;
    } else if (percent < 70) {
        badge = `<span class="badge text-bg-primary fs-5">Normal (${percent}%)</span>`;
    } else if (percent < 90) {
        badge = `<span class="badge text-bg-warning fs-5">Sibuk (${percent}%)</span>`;
    } else {
        badge = `<span class="badge text-bg-danger fs-5">Overload (${percent}%)</span>`;
    }
    return badge;
}

function statusBadgeDisk(percent) {
    let badge = '';
    if (percent < 70) {
        badge = `<span class="badge text-bg-success fs-5">Normal (${percent}%)</span>`;
    } else if (percent < 90) {
        badge = `<span class="badge text-bg-warning fs-5">Peringatan (${percent}%)</span>`;
    } else {
        badge = `<span class="badge text-bg-danger fs-5">Kritis (${percent}%)</span>`;
    }
    return badge;
}

function statusBadgeLoad(value) {
    const cpuCore = <?=$core?>;
    let badge = '';
    if (value < (cpuCore * 0.3)) {
      badge = `<span class="badge text-bg-secondary fs-5">Ringan (${value})</span>`;
    } else if (value < (cpuCore * 0.7)) {
      badge = `<span class="badge text-bg-primary fs-5">Normal (${value})</span>`;
    } else if (value < (cpuCore * 1.0)) {
      badge = `<span class="badge text-bg-warning fs-5">Sibuk (${value})</span>`;
    } else {
      badge = `<span class="badge text-bg-danger fs-5">Overload (${value})</span>`;
    }
    return badge;
}

$(function() {
  const darkPref = localStorage.getItem('darkMode') === '1';
  applyDarkMode(darkPref);
  $('#toggleTheme').click(function () {
    const isDark = !$('body').hasClass('dark-mode');
    applyDarkMode(isDark);
    location.reload(); // refresh agar chart mengikuti mode
  });
  // tampilkan chart
  createChartMin0Max100("cpuChart", "CPU", labelFiltered, cpuFiltered, '%', 'blue');
  createChartMin0Max100("memoryChart", "Memory", labelFiltered, memoryFiltered, '%', 'green');
  createChartMin0Max100("diskChart", "Disk", labelFiltered, diskFiltered, '%', 'orange');
  createChartLoadAverage("loadChart", "Load", timeLabels, loadValues, '', 'red', 0, maxLoad, cpuCore);
  // tampilkan status
  $("#status-cpu").html(statusBadgeCPUMemory(cpuValueLast));
  $("#status-memory").html(statusBadgeCPUMemory(memoryValueLast));
  $("#status-disk").html(statusBadgeDisk(diskValueLast));
  $("#status-load").html(statusBadgeLoad(loadValueLast));
  // auto refresh every 60 seconds
  setTimeout(() => location.reload(), 60000);
});
</script>

<script>
let wakeLock = null;

async function keepAwake() {
  try {
    wakeLock = await navigator.wakeLock.request("screen");
    console.log("Wake lock aktif");
  } catch (err) {
    console.error(`Gagal minta wake lock: ${err.name}, ${err.message}`);
  }
}

// aktifkan saat halaman load
document.addEventListener("DOMContentLoaded", keepAwake);

// jika tab jadi tidak aktif, kadang lock dilepas → coba request ulang
document.addEventListener("visibilitychange", () => {
  if (wakeLock !== null && document.visibilityState === "visible") {
    keepAwake();
  }
});
</script>

</body>
</html>
