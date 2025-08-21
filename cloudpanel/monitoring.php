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
  </style>
</head>
<body class="dark-mode">
<div class="container">
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
    <button id="toggleTheme" class="btn btn-sm btn-outline-secondary"><i class="fas fa-moon"></i></button>
  </div>
  
  <div class="row">
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center fs-6">
        <i class="fas fa-microchip text-primary"></i> CPU Usage <span id="current-value-cpu" class="badge text-bg-light fs-5"></span>
      </h6>
      <canvas id="cpuChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center fs-6">
        <i class="fas fa-memory text-success"></i> Memory Usage <span id="current-value-memory" class="badge text-bg-light fs-5"></span>
      </h6>
      <canvas id="memoryChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center fs-6">
        <i class="fas fa-hdd text-warning"></i> Disk Usage <span id="current-value-disk" class="badge text-bg-light fs-5"></span>
      </h6>
      <canvas id="diskChart"></canvas>
    </div>
    <div class="col-lg-6 col-12 chart-box">
      <h6 class="text-center fs-6">
        <i class="fas fa-chart-line text-danger"></i> Load Average 1m <span id="current-value-load" class="badge text-bg-light fs-5"></span>
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
    $('#toggleTheme').addClass('text-white');
    $('#toggleTheme').html(`<i class="fas fa-sun"></i>`);
    $('#current-value-cpu').removeClass('text-bg-dark').addClass('text-bg-light');
    $('#current-value-memory').removeClass('text-bg-dark').addClass('text-bg-light');
    $('#current-value-disk').removeClass('text-bg-dark').addClass('text-bg-light');
    $('#current-value-load').removeClass('text-bg-dark').addClass('text-bg-light');
  } else {
    $('body').removeClass('dark-mode');
    $('#toggleTheme').addClass('text-black');
    $('#toggleTheme').html(`<i class="fas fa-moon"></i>`);
    $('#current-value-cpu').removeClass('text-bg-light').addClass('text-bg-dark');
    $('#current-value-memory').removeClass('text-bg-light').addClass('text-bg-dark');
    $('#current-value-disk').removeClass('text-bg-light').addClass('text-bg-dark');
    $('#current-value-load').removeClass('text-bg-light').addClass('text-bg-dark');
  }
  localStorage.setItem('darkMode', active ? '1' : '0');
}

$(function() {
  const darkPref = localStorage.getItem('darkMode') === '1';
  applyDarkMode(darkPref);

  $('#toggleTheme').click(function () {
    const isDark = !$('body').hasClass('dark-mode');
    applyDarkMode(isDark);
    location.reload(); // refresh agar chart mengikuti mode
  });

  createChartMin0Max100("cpuChart", "CPU", cpuValues, '%', 'blue');
  $("#current-value-cpu").text(cpuValueLast + "%");
  createChartMin0Max100("memoryChart", "Memory", memoryValues, '%', 'green');
  $("#current-value-memory").text(memoryValueLast + "%");
  createChartMin0Max100("diskChart", "Disk", diskValues, '%', 'orange');
  $("#current-value-disk").text(diskValueLast + "%");
  createChartNoMinMax("loadChart", "Load", loadValues, '', 'red', 2);
  $("#current-value-load").text(loadValueLast);

  // Auto refresh every 60 seconds
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
