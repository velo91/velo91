<?php
// file utama kerangka dashboard
// pastikan $active_menu di-define di file pemanggil (misalnya users-add.php, dashboard-admin.php)
$active_menu = 'dashboard';
//$active_menu = 'users-list';
//$active_menu = 'report-month';
//$active_menu = 'report-year';
?>
<!DOCTYPE html>
<html lang="id">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Admin Dashboard - Sidebar Fixed</title>
	<!-- Google Fonts -->
	<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&family=Roboto+Condensed:wght@400;700&display=swap" rel="stylesheet">

	<!-- Bootstrap 5 + JQuery -->
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
	<script src="https://code.jquery.com/jquery-3.7.1.min.js" defer></script>
	<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" defer></script>
	
	<!-- Font Awesome 7 -->
	<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/7.0.0/css/all.min.css">
	
	<!-- Parsley.js (validasi form) -->
	<script src="https://cdnjs.cloudflare.com/ajax/libs/parsley.js/2.9.3/parsley.min.js" defer></script>
	
	<!-- Inputmask -->
	<script src="https://cdnjs.cloudflare.com/ajax/libs/inputmask/5.0.9/inputmask.min.js" defer></script>
	
	<!-- DataTables -->
	<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap5.min.css">
	<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js" defer></script>
	<script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap5.min.js" defer></script>
	<!-- DataTables Buttons -->
	<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
	<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js" defer></script>
	<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js" defer></script>
	<!-- JSZip untuk export Excel -->
	<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js" defer></script>
	<!-- Buttons HTML5 export -->
	<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js" defer></script>
	<!-- DataTables Custom Style -->
	<style>
	div.dt-buttons {padding-right: 10px;}
	.dataTables_length{display:inline;}
	.dataTables_filter{display:inline;float:right;}
	</style>

	<!-- ApexCharts -->
	<script src="https://cdn.jsdelivr.net/npm/apexcharts" defer></script>
	
	<!-- SweetAlert2 -->
	<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11" defer></script>
	
	<!-- LoadingOverlay -->
	<script src="https://cdn.jsdelivr.net/npm/gasparesganga-jquery-loading-overlay@2.1.7/dist/loadingoverlay.min.js" defer></script>
	
	<!-- QuillJS CSS -->
	<link href="https://cdn.quilljs.com/1.3.7/quill.snow.css" rel="stylesheet">
	<script src="https://cdn.quilljs.com/1.3.7/quill.min.js" defer></script>
	
	<!-- Pannellum (panorama 360) -->
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/pannellum@2.5.6/build/pannellum.css"/>
	<script src="https://cdn.jsdelivr.net/npm/pannellum@2.5.6/build/pannellum.js" defer></script>
	
	<style>
    body {
	  font-family: 'Roboto', sans-serif;
	  font-size: 0.9rem;
	}

    /* Sidebar Desktop */
    .sidebar-desktop {
      width: 220px;
      min-height: 100vh;
      background: #343a40;
      position: fixed;
      top: 56px; /* offset navbar */
      left: 0;
      padding-top: 10px;
    }
    .sidebar-desktop a {
      font-family: 'Roboto Condensed', sans-serif;
      color: #fff;
      text-decoration: none;
      padding: 10px 15px;
      display: block;
    }
    .sidebar-desktop a.active {
      background: #54606b;
      font-weight: bold;
    }
    .sidebar-desktop a:hover {
      background: #495057;
    }

	.sidebar-desktop img {
	  border: 2px solid #4c565f;
	}
	.sidebar-desktop h6 {
	  font-size: 0.95rem;
	  font-weight: 600;
	}
	.sidebar-desktop small {
	  font-size: 0.75rem;
	  color: #bbb;
	}

    /* Sidebar Mobile */
    .sidebar-mobile {
      background: #343a40;
    }
    .sidebar-mobile a {
      font-family: 'Roboto Condensed', sans-serif;
      color: #fff;
      text-decoration: none;
      padding: 10px 15px;
      display: block;
    }
    .sidebar-mobile a.active {
      background: #54606b;
      font-weight: bold;
    }
    .sidebar-mobile a:hover {
      background: #495057;
    }

    //* Active menu (utama & submenu) */
	.sidebar-desktop a.active,
	.sidebar-mobile a.active {
	  background: #4c565f; /* abu-abu sedikit lebih terang */
	  color: #fff !important;
	  font-weight: bold;
	}
	
	/* Jika parent active (punya submenu aktif) → blok induk juga dapat warna */
	.sidebar-desktop li.active-parent > a,
	.sidebar-mobile li.active-parent > a {
	  background: #4c565f;
	  color: #fff !important;
	  font-weight: bold;
	}
	.sidebar-desktop li.active-parent,
	.sidebar-mobile li.active-parent {
	  background: #4c565f;
	}

	/* Tambah border tipis antar menu item */
	.sidebar-desktop li,
	.sidebar-mobile li {
	  border-bottom: 1px solid rgba(255, 255, 255, 0.1); /* putih samar */
	}
	
	/* Hilangkan border terakhir biar lebih bersih */
	.sidebar-desktop li:last-child,
	.sidebar-mobile li:last-child {
	  border-bottom: none;
	}

    /* Tombol toggle sidebar (mobile) */
	.btn-toggle-sidebar {
	  background-color: #555;
	  border: none;
	  color: #fff;
	}
	.btn-toggle-sidebar:hover {
	  background-color: #444;
	  color: #fff;
	}

	/* Kasih jarak icon dengan teks menu */
	.sidebar-desktop a i,
	.sidebar-mobile a i {
	  margin-right: 8px; /* bisa 6px/10px sesuai selera */
	}
	.sidebar-desktop .collapse a i,
	.sidebar-mobile .collapse a i {
	  margin-right: 6px;
	}

    /* Content geser ke kanan */
    @media (min-width: 992px) {
      main {
        margin-left: 220px;
      }
    }
	</style>
</head>
<body>
  <!-- Navbar -->
  <nav class="navbar navbar-dark bg-dark fixed-top">
    <div class="container-fluid">
      <!-- Tombol toggle hanya muncul di mobile -->
      <button class="btn btn-toggle-sidebar d-lg-none" type="button" data-bs-toggle="offcanvas" data-bs-target="#sidebarMobile" aria-controls="sidebarMobile">
		<i class="fa-solid fa-bars"></i>
      </button>
      <a class="navbar-brand ms-2" href="#">Admin Panel</a>
      <div class="d-flex">
        <button class="btn btn-outline-light btn-sm"><i class="fa-solid fa-right-from-bracket"></i> Logout</button>
      </div>
    </div>
  </nav>

  <!-- Sidebar Desktop -->
  <div class="sidebar-desktop d-none d-lg-block text-white">
  	<div class="text-center p-3 border-bottom border-secondary">
	  <img src="https://placehold.co/130x130/EEE/31343C" alt="User Avatar" class="rounded-circle mb-2" width="130" height="130">
	  <h6 class="mb-0">Admin User</h6>
	  <small class="text-muted">Administrator</small>
	</div>
    <?php include 'menu.php'; ?>
  </div>

  <!-- Sidebar Mobile (Offcanvas) -->
  <div class="offcanvas offcanvas-start sidebar-mobile d-lg-none text-white" tabindex="-1" id="sidebarMobile">
    <div class="offcanvas-header">
      <h5 class="offcanvas-title">Menu</h5>
      <button type="button" class="btn-close btn-close-white" data-bs-dismiss="offcanvas"></button>
    </div>
    <div class="offcanvas-body p-0 d-flex flex-column">
      <?php include 'menu.php'; ?>
    </div>
  </div>

  <!-- Content -->
  <main class="p-4" style="margin-top:56px;">
    <h2>Selamat Datang, Admin!</h2>
    <p>✅ Sidebar desktop & mobile sinkron dari <code>menu.php</code>. Active menu ditentukan dengan variabel <code>$active_menu</code>.</p>

    <div class="row">
      <div class="col-md-4">
        <div class="card text-bg-primary mb-3">
          <div class="card-body">
            <h5 class="card-title">Users</h5>
            <p class="card-text fs-4">120</p>
          </div>
        </div>
      </div>
      <div class="col-md-4">
        <div class="card text-bg-success mb-3">
          <div class="card-body">
            <h5 class="card-title">Visitors</h5>
            <p class="card-text fs-4">530</p>
          </div>
        </div>
      </div>
      <div class="col-md-4">
        <div class="card text-bg-warning mb-3">
          <div class="card-body">
            <h5 class="card-title">Revenue</h5>
            <p class="card-text fs-4">$1,200</p>
          </div>
        </div>
      </div>
    </div>

    <h4>Contoh Tabel</h4>
	<table class="table table-striped table-bordered dataTables-01">
	  <thead class="table-dark">
	    <tr>
	      <th>#</th>
	      <th>Nama</th>
	      <th>Email</th>
	      <th>Status</th>
	    </tr>
	  </thead>
	  <tbody>
	    <tr><td>1</td><td>Budi</td><td>budi@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>2</td><td>Sari</td><td>sari@example.com</td><td><span class="badge bg-danger">Inactive</span></td></tr>
	    <tr><td>3</td><td>Andi</td><td>andi@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>4</td><td>Dewi</td><td>dewi@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>5</td><td>Agus</td><td>agus@example.com</td><td><span class="badge bg-danger">Inactive</span></td></tr>
	    <tr><td>6</td><td>Lina</td><td>lina@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>7</td><td>Rudi</td><td>rudi@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>8</td><td>Maya</td><td>maya@example.com</td><td><span class="badge bg-danger">Inactive</span></td></tr>
	    <tr><td>9</td><td>Joko</td><td>joko@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	    <tr><td>10</td><td>Tina</td><td>tina@example.com</td><td><span class="badge bg-success">Active</span></td></tr>
	  </tbody>
	</table>
	<script>
	document.addEventListener("DOMContentLoaded", function() {
	  $('.dataTables-01').DataTable({
	    stateSave: true,
	    dom: "Blfrtip",
	    buttons: [
		    {
		      extend: 'excel',
		      text: 'Export Excel',
		      className: 'btn btn-sm btn-success' // hijau Bootstrap
		    }
		],
	    paging: true,
	    searching: true,
	    ordering:  true,
	    lengthChange: true,
	    pageLength: 5,
	    language: {
	      url: "https://cdn.datatables.net/plug-ins/1.13.8/i18n/id.json"
	    }
	  });
	});
	</script>
	
  </main>

</body>
</html>
