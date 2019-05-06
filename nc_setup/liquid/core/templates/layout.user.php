<!DOCTYPE html>
<html class="ng-csp" data-placeholder-focus="false" lang="<?php p($_['language']); ?>" data-locale="<?php p($_['locale']); ?>" >
	<head data-user="<?php p($_['user_uid']); ?>" data-user-displayname="<?php p($_['user_displayname']); ?>" data-requesttoken="<?php p($_['requesttoken']); ?>">
		<meta charset="utf-8">
		<title>
			<?php
				p(!empty($_['application'])?$_['application'].' - ':'');
				p($theme->getTitle());
			?>
		</title>
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<meta name="referrer" content="no-referrer">
		<meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0">
		<meta name="apple-itunes-app" content="app-id=<?php p($theme->getiTunesAppId()); ?>">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black">
		<meta name="apple-mobile-web-app-title" content="<?php p((!empty($_['application']) && $_['appid']!='files')? $_['application']:$theme->getTitle()); ?>">
		<meta name="mobile-web-app-capable" content="yes">
		<meta name="theme-color" content="<?php p($theme->getColorPrimary()); ?>">
		<link rel="icon" href="<?php print_unescaped(image_path($_['appid'], 'favicon.ico')); /* IE11+ supports png */ ?>">
		<link rel="apple-touch-icon-precomposed" href="<?php print_unescaped(image_path($_['appid'], 'favicon-touch.png')); ?>">
		<link rel="mask-icon" sizes="any" href="<?php print_unescaped(image_path($_['appid'], 'favicon-mask.svg')); ?>" color="<?php p($theme->getColorPrimary()); ?>">
		<link rel="manifest" href="<?php print_unescaped(image_path($_['appid'], 'manifest.json')); ?>">
		<?php emit_css_loading_tags($_); ?>
		<?php emit_script_loading_tags($_); ?>
		<?php print_unescaped($_['headers']); ?>
	</head>
	<body id="<?php p($_['bodyid']);?>">
	<?php include 'layout.noscript.warning.php'; ?>

		<a href="#app-content" class="button primary skip-navigation skip-content"><?php p($l->t('Skip to main content')); ?></a>
		<a href="#app-navigation" class="button primary skip-navigation"><?php p($l->t('Skip to navigation of app')); ?></a>

		<div id="notification-container">
			<div id="notification"></div>
		</div>
		<header role="banner" id="header">
			<div class="header-left">
				<a href="<?php print_unescaped(link_to('', 'index.php')); ?>"
					id="nextcloud">
					<div class="logo logo-icon">
						<h1 class="hidden-visually">
							<?php p($theme->getName()); ?> <?php p(!empty($_['application'])?$_['application']: $l->t('Apps')); ?>
						</h1>
					</div>
				</a>

				<ul id="appmenu" <?php if ($_['themingInvertMenu']) { ?>class="inverted"<?php } ?>>
					<?php foreach ($_['navigation'] as $entry): ?>
						<li data-id="<?php p($entry['id']); ?>" class="hidden" tabindex="-1">
							<a href="<?php print_unescaped($entry['href']); ?>"
								<?php if ($entry['active']): ?> class="active"<?php endif; ?>
								aria-label="<?php p($entry['name']); ?>">
									<svg width="20" height="20" viewBox="0 0 20 20" alt="">
										<?php if ($_['themingInvertMenu']) { ?>
										<defs><filter id="invertMenuMain-<?php p($entry['id']); ?>"><feColorMatrix in="SourceGraphic" type="matrix" values="-1 0 0 0 1 0 -1 0 0 1 0 0 -1 0 1 0 0 0 1 0" /></filter></defs>
										<?php } ?>
										<image x="0" y="0" width="20" height="20" preserveAspectRatio="xMinYMin meet"<?php if ($_['themingInvertMenu']) { ?> filter="url(#invertMenuMain-<?php p($entry['id']); ?>)"<?php } ?> xlink:href="<?php print_unescaped($entry['icon'] . '?v=' . $_['versionHash']); ?>"  class="app-icon" />
									</svg>
								<div class="icon-loading-small-dark"
									 style="display:none;"></div>
								<span>
									<?php p($entry['name']); ?>
								</span>
							</a>
						</li>
					<?php endforeach; ?>
					<li id="more-apps" class="menutoggle"
						aria-haspopup="true" aria-controls="navigation" aria-expanded="false">
						<a href="#" aria-label="<?php p($l->t('More apps')); ?>">
							<div class="icon-more-white"></div>
							<span><?php p($l->t('More')); ?></span>
						</a>
					</li>
				</ul>

				<nav role="navigation">
					<div id="navigation" style="display: none;"  aria-label="<?php p($l->t('More apps menu')); ?>">
						<div id="apps">
							<ul>
								<?php foreach($_['navigation'] as $entry): ?>
									<li data-id="<?php p($entry['id']); ?>">
									<a href="<?php print_unescaped($entry['href']); ?>"
										<?php if( $entry['active'] ): ?> class="active"<?php endif; ?>
										aria-label="<?php p($entry['name']); ?>">
										<svg width="16" height="16" viewBox="0 0 16 16" alt="">
											<defs><filter id="invertMenuMore-<?php p($entry['id']); ?>"><feColorMatrix in="SourceGraphic" type="matrix" values="-1 0 0 0 1 0 -1 0 0 1 0 0 -1 0 1 0 0 0 1 0"></feColorMatrix></filter></defs>
											<image x="0" y="0" width="16" height="16" preserveAspectRatio="xMinYMin meet" filter="url(#invertMenuMore-<?php p($entry['id']); ?>)" xlink:href="<?php print_unescaped($entry['icon'] . '?v=' . $_['versionHash']); ?>"  class="app-icon"></image>
										</svg>
										<div class="icon-loading-small" style="display:none;"></div>
										<span><?php p($entry['name']); ?></span>
									</a>
									</li>
								<?php endforeach; ?>
							</ul>
						</div>
					</div>
				</nav>

			</div>

			<div class="header-right">
				<form class="searchbox" action="#" method="post" role="search" novalidate>
					<label for="searchbox" class="hidden-visually">
						<?php p($l->t('Search'));?>
					</label>
					<input id="searchbox" type="search" name="query"
						value="" required class="hidden icon-search-white"
						autocomplete="off">
					<button class="icon-close-white" type="reset"><span class="hidden-visually"><?php p($l->t('Reset search'));?></span></button>
				</form>
			</div>
		</div></header>

		<div id="sudo-login-background" class="hidden"></div>
		<form id="sudo-login-form" class="hidden">
			<label>
				<?php p($l->t('This action requires you to confirm your password')); ?><br/>
				<input type="password" class="question" autocomplete="new-password" name="question" value=" <?php /* Hack against browsers ignoring autocomplete="off" */ ?>"
				placeholder="<?php p($l->t('Confirm your password')); ?>" />
			</label>
			<input class="confirm" value="<?php p($l->t('Confirm')); ?>" type="submit">
		</form>

		<div id="content" class="app-<?php p($_['appid']) ?>" role="main">
			<?php print_unescaped($_['content']); ?>
		</div>

	</body>
</html>
