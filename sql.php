<?php

$servername = 'mysqldb';
$username = 'root';
$password = 'root';
$dbname = 'pbox14';


try {
	$conn = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
	// set the PDO error mode to exception
	$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
	echo "Connected successfully";

	$sql = 'SELECT * FROM site WHERE Id="400006"';
	foreach ($conn->query($sql) as $row) {
		echo json_encode($row);
	}
}
catch(PDOException $e)
{
	echo $e->getMessage();
}

