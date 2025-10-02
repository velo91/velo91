<?php
// menu.php
// gunakan variabel $active_menu dari file utama
?>

<ul class="nav flex-column">
	
	<!-- Dashboard -->
	<li class="<?= ($active_menu=='dashboard' ? 'active-parent' : '') ?>">
		<a href="dashboard-admin.php" class="<?= ($active_menu=='dashboard' ? 'active' : '') ?>">
			<i class="fa-solid fa-house"></i> Dashboard
		</a>
	</li>

	<!-- Users -->
	<li class="<?= (strpos($active_menu, 'users-') === 0 ? 'active-parent' : '') ?>">
		<a class="d-flex justify-content-between align-items-center <?= (strpos($active_menu, 'users-') === 0 ? 'active' : '') ?>" data-bs-toggle="collapse" href="#submenuUsers" role="button" aria-expanded="<?= (strpos($active_menu, 'users-') === 0 ? 'true' : 'false') ?>" aria-controls="submenuUsers">
			<span><i class="fa-solid fa-users"></i> Users</span>
			<i class="fa-solid fa-chevron-down small"></i>
		</a>
		<div class="collapse ps-4 <?= (strpos($active_menu, 'users-') === 0 ? 'show' : '') ?>" id="submenuUsers">
			<a href="users-list.php" class="<?= ($active_menu=='users-list' ? 'active' : '') ?>"><i class="fa-solid fa-list"></i> List Users</a>
			<a href="users-add.php" class="<?= ($active_menu=='users-add' ? 'active' : '') ?>"><i class="fa-solid fa-user-plus"></i> Add User
			</a>
		</div>
	</li>

	<!-- Reports -->
	<li class="<?= (strpos($active_menu, 'report-') === 0 ? 'active-parent' : '') ?>">
		<a class="d-flex justify-content-between align-items-center <?= (strpos($active_menu, 'report-') === 0 ? 'active' : '') ?>" data-bs-toggle="collapse" href="#submenuReports" role="button" aria-expanded="<?= (strpos($active_menu, 'report-') === 0 ? 'true' : 'false') ?>" aria-controls="submenuReports">
			<span><i class="fa-solid fa-chart-bar"></i> Reports</span>
			<i class="fa-solid fa-chevron-down small"></i>
		</a>
		<div class="collapse ps-4 <?= (strpos($active_menu, 'report-') === 0 ? 'show' : '') ?>" id="submenuReports">
			<a href="report-month.php" class="<?= ($active_menu=='report-month' ? 'active' : '') ?>"><i class="fa-regular fa-calendar"></i> Monthly Report</a>
			<a href="report-year.php" class="<?= ($active_menu=='report-year' ? 'active' : '') ?>"><i class="fa-solid fa-chart-line"></i> Yearly Report</a>
		</div>
	</li>

	<!-- Settings -->
	<li class="<?= ($active_menu=='settings' ? 'active-parent' : '') ?>">
		<a href="settings.php" class="<?= ($active_menu=='settings' ? 'active' : '') ?>"><i class="fa-solid fa-gear"></i> Settings</a>
	</li>
	
</ul>
