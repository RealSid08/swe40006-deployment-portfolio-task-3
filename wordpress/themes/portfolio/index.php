<?php
if (!defined('ABSPATH')) { exit; }
global $wp_version;
$database_label = DB_HOST === 'localhost' ? 'Local MariaDB on EC2' : 'Amazon RDS MariaDB';
$node = substr(hash('sha256', gethostname()), 0, 8);
?>
<!doctype html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo('charset'); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?php bloginfo('name'); ?> | SWE40006</title>
  <link rel="stylesheet" href="<?php echo esc_url(get_stylesheet_uri()); ?>">
  <?php wp_head(); ?>
</head>
<body>
<main>
  <nav><strong>SWE40006 / PORTFOLIO 03</strong><span>Sidhaarth Krishnan</span></nav>
  <header>
    <p class="label">Software Deployment and Evolution</p>
    <h1><?php bloginfo('name'); ?></h1>
    <p class="lead">From a single web server to a replaceable web tier. A WordPress journal documenting an application deployed on AWS.</p>
  </header>
  <div class="layout">
    <section aria-label="Journal entries">
      <?php while (have_posts()): the_post(); ?>
      <article>
        <p class="label">Deployment journal</p>
        <h2><?php the_title(); ?></h2>
        <?php the_content(); ?>
      </article>
      <?php endwhile; ?>
    </section>
    <aside aria-label="Runtime status">
      <h2>Deployment status</h2>
      <span class="status">WordPress is serving this page</span>
      <dl>
        <dt>Application</dt><dd>WordPress <?php echo esc_html($wp_version); ?></dd>
        <dt>Web runtime</dt><dd>Apache / PHP <?php echo esc_html(PHP_VERSION); ?></dd>
        <dt>Database</dt><dd><?php echo esc_html($database_label); ?></dd>
        <dt>Responding node</dt><dd><code><?php echo esc_html($node); ?></code></dd>
        <dt>Health check</dt><dd><a href="/health.php">View live health response</a></dd>
      </dl>
      <p class="note">The journal content is stored in the database. The node identifier changes when a different web server handles the request.</p>
    </aside>
  </div>
  <footer>Semester 2, 2026 &nbsp; / &nbsp; AWS cloud deployment portfolio</footer>
</main>
<?php wp_footer(); ?>
</body>
</html>
