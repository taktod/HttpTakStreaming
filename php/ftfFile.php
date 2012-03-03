<?php
/**
 * response with xml data.
 * 
 * Copyright 2012 - 2012 by taktod. All rights reserved.
 * 
 * for examples...
 * rtmp://localhost/hts/ with publish name with livestream
 * streamPath will be...
 * /default/hts/livestream
 */
/** config */
$httpRoot = "http://localhost/";
$fileRoot = "/var/html/documentRoot/";
$interval = 3000;

/** input data */
$streamPath = $_REQUEST["path"];

/** make up file path... */
$fthFile = $fileRoot . $streamPath . ".fth";
$ftmFile = $fileRoot . $streamPath . "_*.ftm";

$id = filemtime($fthFile);

// find newest num of ftmFile
$files = scandir(dirname($ftmFile));
$filetime = 0;
foreach($files as $file) {
	$fullPath = dirname($ftmFile) . $file;
	if(preg_match("/{$streamPath}_(\d+)\.ftm$/", $fullPath, $matches) || filemtime($fullPath) > $filetime) {
		$time = filemtime($fullPath);
		$num = matches[1];
	}
}

echo <<<XML
<?xml version="1.0" encoding="UTF-8"?>
<httpTakStreaming>
	<packetInterval>{$interval}</packetInterval>
	<flvTakHeader id="{$id}">{$fthFile}</flvTakHeader>
	<flvTakMedia start="{$num}">{$ftmFile}</flvTakMedia>
</httpTakStreaming>
XML;