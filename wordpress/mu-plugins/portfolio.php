<?php
/* Plugin Name: Portfolio deployment controls */
// The grading site is a read-only journal. Author through the deployment workflow.
add_filter('xmlrpc_enabled', '__return_false');
add_filter('comments_open', '__return_false', 20, 2);
add_filter('pings_open', '__return_false', 20, 2);
add_action('send_headers', static function (): void {
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('X-Frame-Options: SAMEORIGIN');
    header('Cache-Control: no-store');
});
