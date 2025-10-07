<?php
session_start();
$url_favicon = 'https://img.icons8.com/?size=100&id=MT51l0HSFpBZ&format=png&color=000000';
$sandi = 'gpt';

$play_audio = false;

// Jika form dikirim
if (isset($_POST['auth_key'])) {
    if ($_POST['auth_key'] === $sandi) {
        $_SESSION['authenticated'] = true;
    } else {
        $error = "Password salah!";
    }
}

// Jika logout
if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: ".$_SERVER['PHP_SELF']);
    exit;
}

// Jika belum login maka tampilkan form login dan hentikan script
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true):
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Login Akses</title>
    <link rel="icon" href="<?=$url_favicon ?>">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light d-flex justify-content-center align-items-center vh-100">
    <div class="card p-4 shadow" style="min-width:300px;">
        <h5 class="text-center mb-3">Akses Monitoring</h5>
        <?php if (!empty($error)): ?>
        <div class="alert alert-danger text-center py-1">
            <?= htmlspecialchars($error) ?>
        </div>
        <?php endif; ?>
        <form method="post">
            <input type="password" name="auth_key" class="form-control mb-3" placeholder="Password" autofocus required>
            <button type="submit" class="btn btn-primary w-100">Masuk</button>
        </form>
    </div>
</body>
</html>
<?php exit; endif; ?>

<?php
date_default_timezone_set('Asia/Jakarta');
$minute_ranges = [
    1 => 5, // 5 menit
    2 => 30, // 30 menit
    3 => 60, // 1 jam
    4 => 180, // 3 jam
    5 => 360, // 6 jam
    6 => 720, // 12 jam
    7 => 1440 // 24 jam
];
$range = isset($_GET['range']) ? intval($_GET['range']) : 7; // Default: 6 jam
$limit = $minute_ranges[$range] ?? 1440;

// Koneksi SQLite
$db = new PDO('sqlite:/home/clp/htdocs/app/data/db.sq3');

// Ambil data dan konversi waktu ke WIB
function get_data($db, $table, $where = '') {
    global $limit;
    $stmt = $db->query("SELECT created_at,value FROM $table $where ORDER BY created_at DESC LIMIT $limit");
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

function get_swap_usage_percent() {
    $meminfo = @file('/proc/meminfo', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!$meminfo) return null;
    $swap_total = 0;
    $swap_free = 0;
    foreach ($meminfo as $line) {
        if (strpos($line, 'SwapTotal:') === 0) {
            $swap_total = (int) filter_var($line, FILTER_SANITIZE_NUMBER_INT);
        }
        if (strpos($line, 'SwapFree:') === 0) {
            $swap_free = (int) filter_var($line, FILTER_SANITIZE_NUMBER_INT);
        }
    }

    if ($swap_total <= 0) return 0; // tidak ada swap di sistem
    $swap_used = $swap_total - $swap_free;
    return round(($swap_used / $swap_total) * 100, 1); // satu angka desimal
}
$swap_usage_percent = get_swap_usage_percent();
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Monitoring</title>
    <link rel="icon" href="<?= $url_favicon ?>">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@7.1.0/css/all.min.css" rel="stylesheet">
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
    .container-fluid.layout-2x2 {
        max-width: 1500px;
        margin: 0 auto;
    }
    .chart-box {
        margin-bottom: 30px;
        opacity: 0;
        transform: translateY(15px);
        transition: opacity 0.6s ease, transform 0.6s ease;
    }
    .chart-box.show {
        opacity: 1;
        transform: translateY(0);
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
        --bg-dark: #020610;
        --stream-color: rgba(0,255,200,0.15);
        --orb1: #21e9ff;
        --orb2: #7b5cff;
        --neon-glow: rgba(0,255,200,0.25);
    }
    /* Background base */
    .cyber-bg {
        position: fixed;
        inset: 0;
        z-index: 0;
        overflow: hidden;
        background: radial-gradient(circle at 50% 50%, #041a26 0%, #020610 100%);
    }
    /* Aliran data diagonal */
    .cyber-layer.streams {
        position: absolute;
        inset: 0;
        background-image:
        repeating-linear-gradient(120deg, transparent 0 28px, var(--stream-color) 28px 30px);
        background-size: 300px 300px;
        animation: moveStreams 18s linear infinite;
        opacity: 0.25;
    }
    @keyframes moveStreams {
        0% {
            background-position: 0 0;
        }
        100% {
            background-position: 600px 600px;
        }
    }
    /* Orb neon */
    .cyber-orb {
        position: absolute;
        width: 800px;
        height: 800px;
        border-radius: 50%;
        filter: blur(200px);
        opacity: 0.45;
        mix-blend-mode: screen;
    }
    .orb1 {
        background: var(--orb1);
        top: 20%;
        left: 10%;
        animation: moveOrb1 40s ease-in-out infinite alternate;
    }
    .orb2 {
        background: var(--orb2);
        top: 60%;
        left: 60%;
        animation: moveOrb2 55s ease-in-out infinite alternate;
    }
    @keyframes moveOrb1 {
        0% {
            transform: translate(0,0);
        }
        /* Glow lembut */
        .cyber-layer.glow {
            position: absolute;
            inset: 0;
            background: radial-gradient(circle at center, var(--neon-glow), transparent 70%);
            filter: blur(100px);
            animation: glowPulse 10s ease-in-out infinite;
        }
        @keyframes glowPulse {
            0%,100% {
                opacity: 0.5;
            }
            50% {
                opacity: 0.85;
            }
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
    // (OUTDATED) Mall/Airport/Train/Cruise Announcement Chimes: https://www.youtube.com/watch?v=gw7k1TCg2qw&ab_channel=JoeyFortuna
    // Announcement Sound (Melodic airport announcement ding): https://mixkit.co/free-sound-effects/airport
    // Sound of Text (Download Google Translate Audio): https://soundoftext.cc
    if($play_audio===true) {
        $menit = date('i');
        $jam = date('H');
        if ($menit === '00') {
            if (in_array($jam, array('08', '09', '10', '11', '12', '13', '14', '15', '16', '17'))) {
                $kategori = ['aktivitas',
                    'motivasi',
                    'humor'];
                $pilihan_kategori = $kategori[array_rand($kategori)];
                $file_audio = "/assets/monitoring/{$jam}-{$pilihan_kategori}.mp3?";
            } else {
                $file_audio = "/assets/monitoring/announcement.mp3?";
            }
            echo '<audio autoplay>
          <source src="'.$file_audio.'" type="audio/wav">
        </audio>';
        }
    }
    ?>

    <!-- Konten Bootstrap -->
    <div class="container-fluid text-center position-relative">
        <div class="text-center mt-4 mb-4 range">
            <div class="btn-group">
                <?php
                $labels = [1 => '5m',
                    2 => '30m',
                    3 => '1h',
                    4 => '3h',
                    5 => '6h',
                    6 => '12h',
                    7 => '24h'];
                foreach ($labels as $key => $label) {
                    $class = ($range == $key)?'btn btn-sm btn-secondary active':'btn btn-sm btn-outline-secondary';
                    echo "<a href='?range=$key' class='$class'>$label</a>";
                }
                ?>
            </div>
            <button id="toggleTheme" class="btn btn-sm btn-outline-secondary text-secondary" title="Toggle Tema"><i class="fa fa-moon"></i></button>
            <button id="toggleLayout" class="btn btn-sm btn-outline-secondary text-secondary" title="Ganti Layout"><i class="fa fa-border-all"></i></button>
            <a href="?logout=1" class="btn btn-sm btn-outline-secondary text-secondary" title="Logout"><i class="fa fa-right-from-bracket"></i></a>
        </div>

        <div class="row" id="chartGrid">
            <div class="col-lg-6 col-12 chart-box">
                <h6><i class="fa fa-microchip"></i> CPU <span id="status-cpu"></span></h6><canvas id="cpuChart"></canvas>
            </div>
            <div class="col-lg-6 col-12 chart-box">
                <h6><i class="fa fa-memory"></i> RAM <span id="status-memory"></span> <?php if ($swap_usage_percent !== null): ?> SWAP <?=$swap_usage_percent?>%<?php endif; ?></h6><canvas id="memoryChart"></canvas>
            </div>
            <div class="col-lg-6 col-12 chart-box">
                <h6><i class="fa fa-hdd"></i> DISK <span id="status-disk"></span></h6><canvas id="diskChart"></canvas>
            </div>
            <div class="col-lg-6 col-12 chart-box">
                <h6><i class="fa fa-chart-line"></i> BEBAN <span id="status-load"></span></h6><canvas id="loadChart"></canvas>
            </div>
        </div>
    </div>

    <script>
        const timeLabels = <?= json_encode(array_column($cpu_data, 'created_at_wib')) ?>;
        const cpuValues = <?= json_encode(array_column($cpu_data, 'value')) ?>;
        const memoryValues = <?= json_encode(array_column($memory_data, 'value')) ?>;
        const diskValues = <?= json_encode(array_column($disk_data, 'value')) ?>;
        const loadValues = <?= json_encode(array_column($load_data, 'value')) ?>;
        const cpuCore = <?=$core ?>;

        const cpuValueLast = cpuValues.at(-1) ?? 0;
        const memoryValueLast = memoryValues.at(-1) ?? 0;
        const diskValueLast = diskValues.at(-1) ?? 0;
        const loadValueLast = loadValues.at(-1) ?? 0;

        function downsample(data, count) {
            if (data.length <= count)return data; let step = (data.length-1)/(count-1),
            res = []; for (let i = 0; i < count; i++)res.push(data[Math.round(i*step)]); return res;
        }

        // Jumlah titik yang mau ditampilkan di sumbu X
        const POINTS = 7;

        // Downsample semua data sekaligus (agar konsisten X axis-nya)
        const labelFiltered = downsample(timeLabels, POINTS);
        const cpuFiltered = downsample(cpuValues, POINTS);
        const memoryFiltered = downsample(memoryValues, POINTS);
        const diskFiltered = downsample(diskValues, POINTS);
        const loadFiltered = downsample(loadValues, POINTS);

        // Data lainnya
        const maxLoad = loadFiltered.length > 0?Math.max(...loadFiltered): 0;

        let charts = [];

        function createChart(id, label, labels, data, min = 0, max = 100, ySuffix = '%', borderColor = 'blue', decimals = 0) {
            const isDark = $('body').hasClass('dark-mode');
            const chart = new Chart(document.getElementById(id), {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: label, data: data, borderColor: borderColor, tension: 0.3, fill: false
                    }]
                },
                options: {
                    animation: false,
                    responsive: true,
                    plugins: {
                        legend: {
                            display: false
                        }},
                    scales: {
                        x: {
                            ticks: {
                                color: isDark ? '#ccc' : '#000',
                            },
                            grid: {
                                display: true,
                                drawBorder: true,
                                drawOnChartArea: true,
                                drawTicks: true,
                                color: isDark ? '#333' : '#ddd',
                            }
                        },
                        y: {
                            ticks: {
                                stepSize: (max-min)/4,
                                callback: value=>Number(value).toFixed(decimals)+ySuffix,
                                color: isDark?'#ccc': '#000'
                            },
                            grid: {
                                display: true,
                                drawBorder: true,
                                drawOnChartArea: true,
                                drawTicks: true,
                                color: isDark ? '#333' : '#ddd',
                            },
                            min: min,
                            max: max
                        }
                    }
                }
            });
            charts.push(chart);
        }

        function renderCharts() {
            charts.forEach(c => c.destroy());
            charts = [];
            createChart("cpuChart", "CPU", labelFiltered, cpuFiltered, 0, 100, '%', 'blue');
            createChart("memoryChart", "Memory", labelFiltered, memoryFiltered, 0, 100, '%', 'orange');
            createChart("diskChart", "Disk", labelFiltered, diskFiltered, 0, 100, '%', 'green');
            createChart("loadChart", "Load", labelFiltered, loadFiltered, 0, Math.max(cpuCore, maxLoad), '', 'purple');
        }

        function applyDarkMode(active) {
            if (active) {
                $('body').addClass('dark-mode'); $('#toggleTheme').html(`<i class="fa fa-sun"></i>`);
            } else {
                $('body').removeClass('dark-mode'); $('#toggleTheme').html(`<i class="fa fa-moon"></i>`);
            }
            localStorage.setItem('darkMode', active?'1': '0');
            renderCharts();
        }

        function applyLayout(type){
            const boxes = $('.chart-box');
            const container = $('.container-fluid');
            boxes.removeClass('col-lg-6 col-lg-3');
            container.removeClass('layout-1x4 layout-2x2');
        
            if(type === '1x4'){
                boxes.addClass('col-lg-3');
                container.addClass('layout-1x4');
                $('#toggleLayout').html('<i class="fa fa-border-all"></i>');
            } else {
                boxes.addClass('col-lg-6');
                container.addClass('layout-2x2');
                $('#toggleLayout').html('<i class="fa fa-arrows-left-right"></i>');
            }

            localStorage.setItem('layoutType', type);
            renderCharts();
        }

        $(function() {
            $(".chart-box").each(function(i) {
                const el = $(this);
                setTimeout(() => {
                el.addClass("show");
                }, 200 * i); // delay per elemen biar muncul satu per satu
            });

            applyDarkMode(localStorage.getItem('darkMode') === '1');
            applyLayout(localStorage.getItem('layoutType') || '2x2');
            renderCharts();

            $("#status-cpu").html(statusBadge(cpuValueLast));
            $("#status-memory").html(statusBadge(memoryValueLast));
            $("#status-disk").html(statusBadgeDisk(diskValueLast));
            $("#status-load").html(statusBadgeLoad(loadValueLast));

            $('#toggleTheme').click(()=>applyDarkMode(!$('body').hasClass('dark-mode')));
            $('#toggleLayout').click(()=> {
                const cur = localStorage.getItem('layoutType') || '2x2';
                applyLayout(cur === '2x2'?'1x4': '2x2');
            });

            setTimeout(()=> {
                window.location.replace(window.location.pathname + window.location.search);
            }, 60000);
        });

        function statusBadge(p) {
            if (p < 30)return`<span class="badge text-bg-secondary fs-5">Ringan (${p}%)</span>`; else if (p < 70)return`<span class="badge text-bg-success fs-5">Normal (${p}%)</span>`; else if (p < 90)return`<span class="badge text-bg-warning fs-5">Sibuk (${p}%)</span>`; else return`<span class="badge text-bg-danger fs-5">Overload (${p}%)</span>`;
        }
        function statusBadgeDisk(p) {
            if (p < 70)return`<span class="badge text-bg-success fs-5">Normal (${p}%)</span>`; else if (p < 90)return`<span class="badge text-bg-warning fs-5">Peringatan (${p}%)</span>`; else return`<span class="badge text-bg-danger fs-5">Kritis (${p}%)</span>`;
        }
        function statusBadgeLoad(v) {
            if (v < cpuCore*0.3)return`<span class="badge text-bg-secondary fs-5">Ringan (${v})</span>`; else if (v < cpuCore*0.7)return`<span class="badge text-bg-success fs-5">Normal (${v})</span>`; else if (v < cpuCore*1.0)return`<span class="badge text-bg-warning fs-5">Sibuk (${v})</span>`; else return`<span class="badge text-bg-danger fs-5">Overload (${v})</span>`;
        }
    </script>
</body>
</html>
