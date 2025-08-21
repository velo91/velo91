<?php
date_default_timezone_set('Asia/Jakarta');

// Mapping range ke jumlah data (per menit)
$minute_ranges = [
    1 => 5,     // 5 menit
    2 => 30,    // 30 menit
    3 => 60,    // 1 jam
    4 => 180,   // 3 jam
    5 => 360,   // 6 jam
    6 => 720    // 12 jam
];

// Default: 6 jam
$range = isset($_GET['range']) ? intval($_GET['range']) : 5;
$limit = $minute_ranges[$range] ?? 360;

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
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Monitoring CloudPanel</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
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
    /* ====== CYBER BACKGROUND ====== */
    :root{
      --cyber-bg-1:#021018;
      --cyber-bg-2:#041b2a;
      --neon-1:#21e9ff;
      --neon-2:#05ffa1;
      --neon-3:#7b5cff;
      --grid-color: rgba(255,255,255,0.08);
      --stream-color: rgba(33,233,255,0.14);
      --scanline: rgba(255,255,255,0.03);
    }
    .cyber-bg{
      position:fixed;
      inset:0;
      overflow:hidden;
      z-index:0; /* tetap di bawah Bootstrap container */
      background: linear-gradient(180deg, var(--cyber-bg-1), var(--cyber-bg-2));
    }
    .cyber-layer{
      position:absolute;
      inset:-10%;
      pointer-events:none;
    }
    /* Gradient */
    .cyber-layer.gradient{
      background: conic-gradient(from 0deg at 60% 40%, 
                   rgba(33,233,255,0.12), rgba(5,255,161,0.06), rgba(123,92,255,0.10), rgba(33,233,255,0.12));
      filter: blur(40px);
      animation: moveGradient 18s linear infinite;
      opacity:0.7;
    }
    @keyframes moveGradient{
      0%{transform: rotate(0deg) scale(1);}
      100%{transform: rotate(360deg) scale(1);}
    }
    /* Grid */
    .cyber-layer.grid{
      background-image:
        linear-gradient(to right, var(--grid-color) 1px, transparent 1px),
        linear-gradient(to bottom, var(--grid-color) 1px, transparent 1px);
      background-size: 40px 40px;
      animation: driftGrid 24s linear infinite;
    }
    @keyframes driftGrid{
      0%{transform:translate(0,0);}
      100%{transform:translate(-40px,-40px);}
    }
    /* Streams */
    .cyber-layer.streams{
      background-image:
        repeating-linear-gradient(60deg, transparent 0 18px, var(--stream-color) 18px 20px);
      background-size: 220px 220px;
      animation: moveStreams 9s linear infinite;
    }
    @keyframes moveStreams{
      0%{background-position:0 0;}
      100%{background-position:440px 440px;}
    }
    /* Glow */
    .cyber-layer.glow{
      background: radial-gradient(500px 300px at 80% 30%, rgba(33,233,255,0.18), transparent 65%);
      filter: blur(30px);
      animation: glowPulse 6s ease-in-out infinite;
    }
    @keyframes glowPulse{
      0%,100%{opacity:0.6;}
      50%{opacity:0.9;}
    }
    /* Scanlines */
    .cyber-layer.scanlines{
      background: repeating-linear-gradient(to bottom, transparent 0 2px, var(--scanline) 2px 3px);
      animation: flicker 2s steps(60) infinite;
    }
    @keyframes flicker{
      0%,100%{opacity:0.9;}
      50%{opacity:0.7;}
    }
    /* Pastikan container Bootstrap di atas background */
    .container{
      position: relative;
      z-index: 1;
    }
  </style>
</head>
<body class="dark-mode">

<!-- Cyber Background -->
<div class="cyber-bg">
  <div class="cyber-layer gradient"></div>
  <div class="cyber-layer grid"></div>
  <div class="cyber-layer streams"></div>
  <div class="cyber-layer glow"></div>
  <div class="cyber-layer scanlines"></div>
</div>

<!-- Konten Bootstrap -->
<div class="container text-center position-relative">
  <div class="text-center mt-4 mb-4 range">
    <div class="btn-group" role="group" aria-label="Range Selector">
      <?php
        $labels = [1 => '5m', 2 => '30m', 3 => '1h', 4 => '3h', 5 => '6h', 6 => '12h'];
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
        <i class="fas fa-microchip text-primary"></i> CPU Usage <span id="status-cpu"></span>
      </h6>
      <canvas id="cpuChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-memory text-success"></i> RAM Usage <span id="status-memory"></span>
      </h6>
      <canvas id="memoryChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-hdd text-warning"></i> SSD Usage <span id="status-disk"></span>
      </h6>
      <canvas id="diskChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center text-white fs-6">
        <i class="fas fa-chart-line text-danger"></i> Load Average 1m <span id="status-load"></span>
      </h6>
      <canvas id="loadChart"></canvas>
    </div>
  </div>
</div>

<script>
<?php /*
const timeLabels = <?= json_encode(array_map(fn($d) => $d . ' WIB', array_column($cpu_data, 'created_at_wib'))) ?>;
*/ ?>
const timeLabels = <?= json_encode(array_map(fn($d) => $d, array_column($cpu_data, 'created_at_wib'))) ?>;
const cpuValues = <?= json_encode(array_column($cpu_data, 'value')) ?>;
const cpuValueLast = cpuValues[cpuValues.length - 1];
const memoryValues = <?= json_encode(array_column($memory_data, 'value')) ?>;
const memoryValueLast = memoryValues[cpuValues.length - 1];
const diskValues = <?= json_encode(array_column($disk_data, 'value')) ?>;
const diskValueLast = diskValues[cpuValues.length - 1];
const loadValues = <?= json_encode(array_column($load_data, 'value')) ?>;
const loadValueLast = loadValues[cpuValues.length - 1];

function createChartMin0Max100(id, label, data, ySuffix = '%', borderColor = 'blue', decimals = 0) {
  const isDark = $('body').hasClass('dark-mode');
  new Chart(document.getElementById(id), {
    type: 'line',
    data: {
      labels: timeLabels,
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
      responsive: true,
      plugins: {
        legend: { display: false }
      },
      scales: {
        x: {
          ticks: { color: isDark ? '#ccc' : '#000' },
          grid: { color: isDark ? '#333' : '#ddd' }
        },
        y: {
          ticks: {
            callback: value => Number(value).toFixed(decimals) + ySuffix,
            color: isDark ? '#ccc' : '#000'
          },
          grid: { color: isDark ? '#333' : '#ddd' },
          min: 0,
          max: 100
        }
      }
    }
  });
}

function createChartNoMinMax(id, label, data, ySuffix = '%', borderColor = 'blue', decimals = 0) {
  const isDark = $('body').hasClass('dark-mode');
  new Chart(document.getElementById(id), {
    type: 'line',
    data: {
      labels: timeLabels,
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
      responsive: true,
      plugins: {
        legend: { display: false }
      },
      scales: {
        x: {
          ticks: { color: isDark ? '#ccc' : '#000' },
          grid: { color: isDark ? '#333' : '#ddd' }
        },
        y: {
          ticks: {
            callback: value => Number(value).toFixed(decimals) + ySuffix,
            color: isDark ? '#ccc' : '#000'
          },
          grid: { color: isDark ? '#333' : '#ddd' }
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
    <?php
    $cpuinfo = @file_get_contents('/proc/cpuinfo');
    preg_match_all('/^processor/m', $cpuinfo, $matches);
    $core = count($matches[0]);
    ?>
    const cpuCore = <?=$core?>;
    let badge = '';
    if (value < (cpuCore * 0.3)) {
      badge = `<span class="badge text-bg-secondary fs-5">Ringan (${value}%)</span>`;
    } else if (value < (cpuCore * 0.7)) {
      badge = `<span class="badge text-bg-primary fs-5">Normal (${value}%)</span>`;
    } else if (value < (cpuCore * 1.0)) {
      badge = `<span class="badge text-bg-warning fs-5">Sibuk (${value}%)</span>`;
    } else {
      badge = `<span class="badge text-bg-danger fs-5">Overload (${value}%)</span>`;
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
  createChartMin0Max100("cpuChart", "CPU", cpuValues, '%', 'blue');
  createChartMin0Max100("memoryChart", "Memory", memoryValues, '%', 'green');
  createChartMin0Max100("diskChart", "Disk", diskValues, '%', 'orange');
  createChartNoMinMax("loadChart", "Load", loadValues, '', 'red', 2);
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
