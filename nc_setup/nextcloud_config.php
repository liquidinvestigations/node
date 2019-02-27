<?php

/**
 *Nextcloud config file.
 */
$CONFIG = array(

'trusted_domains' =>  
  array (
   $_ENV['NC_HOST'],
  ),
  
'allow_user_to_change_display_name' => false,
'skeletondirectory' => '',
'updatechecker' => false,
'has_internet_connection' =>false,
'appstoreenabled' => false,
'theme' => 'liquid'
);
?>