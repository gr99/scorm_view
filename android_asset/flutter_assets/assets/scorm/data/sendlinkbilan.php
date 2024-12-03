<?php

$var_p = "";
if(isset($_GET['p'])){
	$var_p = $_GET['p'];
	$var_p = str_replace("@", "-", $var_p);
	$var_p = str_replace(".", "-", $var_p);
}

$var_u = "";
if(isset($_GET['u'])){
	$var_u = $_GET['u'];
}

$var_b = "";
if(isset($_GET['b'])){
	$var_b = $_GET['b'];
}

function curPageURL() {
	$pageURL = 'http';
	if ($_SERVER["HTTPS"] == "on") {$pageURL .= "s";}
	$pageURL .= "://";
	if ($_SERVER["SERVER_PORT"] != "80") {
		$pageURL .= $_SERVER["SERVER_NAME"].":".$_SERVER["SERVER_PORT"].$_SERVER["REQUEST_URI"];
	} else {
		$pageURL .= $_SERVER["SERVER_NAME"].$_SERVER["REQUEST_URI"];
	}
	return $pageURL;
}

$to = 'renou.damien@live.fr';

$jour  = date("d-m-Y");
$heure = date("H:i:s");

$verif_envoi_mail = false;

if (function_exists('mail')){
		
	$sujet = "Reception d'un Bilan - $jour $heure";
	$body = "Bilan \n\n";
	$body .= "user : ".$var_u." \n";
	$body .= "result : ".$var_b." \n";
	
	$explodeUrl = explode('data/',curPageURL());
	$urldest = $explodeUrl[0].'data/history.html';
	
	$body .= "Historique des bilans : ".$urldest." \n";
	
	$body .= "\n";
	$headers = 'From: noreply@cloudlearning.fr' . "\r\n";
	
	if(@mail($to, $sujet, $body, $headers)){
		$verif_envoi_mail=true;
	}

}

if ($verif_envoi_mail === FALSE) echo "ko";
else echo "ok";

$ident = '';

if($var_u!=''){
	
	if(strpos($var_u, '@') === false){
		
		$ident = $var_u;
		
	}else{
		
		$explode = explode( '@', $var_u );
		$part1 = strtolower($explode[0]);
		$firstpart = 'error';
		if(strlen($part1)>7){
			$firstpart=substr($part1,0,6);
		}else{
			if(strlen($part1)>3){
				$firstpart=substr($part1,0,2);
			}
		}
		$part2 = strtolower($explode[1]);
		$ident = $firstpart.'****@'.$part2;
		
	}
	
}

