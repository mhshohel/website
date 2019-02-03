<?php


//$value = [
//	"site" => "shohel.me",
//	"hashttp" => 2,
//	"app" => "pb3",
//];
//
//echo json_encode($value);
date_default_timezone_set('Europe/Belgrade');

$servername = 'mysqldb';
$username = 'root';
$password = 'root';
$dbname = 'pbox14';

$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
$nums = "01234";

function Rands($char, $len=61){
	$int = rand(0,$len);
	return $char[$int];
}

function InsertRandomData($conn, $chars, $nums, $insertlen = 1000){
	$startTime = microtime(true);

	$list = [];

	$list[0] = 0;

	$success = 0;
	for($i = 0; $i < $insertlen; $i++) {
		$array = [];

		$fst = Rands($chars) . Rands($chars) . Rands($chars) . Rands($chars);
		$date = date("hisa");
		$lst = Rands($chars) . Rands($chars) . Rands($chars) . Rands($chars);

		$array['Guid'] = $date . $fst . $lst;
		$array['Url'] = $fst . $lst . ".com";
		$array['SecondaryUrl'] = $fst . $lst . ".net";
		$array['HasRequestedSSLCert'] = Rands($nums, 5);

		try {
			$sql = "INSERT INTO testsite (Guid, Url, SecondaryUrl, HasRequestedSSLCert) VALUES (?,?,?,?)";
			$stmt = $conn->prepare($sql);
			$stmt->execute([$array['Guid'], $array['Url'], $array['SecondaryUrl'], $array['HasRequestedSSLCert']]);

			//$list[] = $array;
			$success++;
		} catch (Exception $e) {

		}
	}

	$endTime = microtime(true);

	$list[0] = $endTime - $startTime;

//	echo json_encode($list);
	echo json_encode(["Time"=>$list[0], "Total"=>$success]);
}

try {
	$conn = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
	// set the PDO error mode to exception
	$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
//	echo "Connected successfully";

//	$sql = 'SELECT Url, SecondaryUrl, HasRequestedSSLCert FROM site WHERE Id="400006"';
//
//	$stmt = $conn->prepare($sql, array(PDO::ATTR_CURSOR => PDO::CURSOR_SCROLL));
//	$stmt->execute();
//
//	//$result = $stmt->fetch(PDO::FETCH_OBJ);
//	$result = $stmt->fetch(PDO::FETCH_ASSOC);
//
//	echo json_encode($result);

	//InsertRandomData($conn, $chars, $nums, 1);

}
catch(PDOException $e)
{
	echo $e->getMessage();
}