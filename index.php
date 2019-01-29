<?
	function get_server_memory_usage(){

		$free = shell_exec('free');
		$free = (string)trim($free);
		$free_arr = explode("\n", $free);
		$mem = explode(" ", $free_arr[1]);
		$mem = array_filter($mem);
		$mem = array_merge($mem);
		$memory_usage = $mem[2]/$mem[1]*100;

		return $memory_usage;
	}

	function get_server_cpu_usage(){

		$load = sys_getloadavg();
		return $load[0];
	}

	function runtest(){
		$sTime = microtime(true);

		$res=0;
		for($i=0; $i<=33333333;$i++){
			$res += $i + 1;
			$res = 2+$res;
		}

		$lTime = microtime(true);

		$time = ($lTime - $sTime);

		return json_encode(["TotalTime: " => $time, "Result" => $res]);
	}

?>

<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>Title</title>
</head>
<body>
New Code for ECS (PHP) V1

<br/>
<br/>
<br/>


<img width="300" height="200" src="img/400006hpr2KA17.jpg"/>
<img width="300" height="200" src="img/400006x3PTPquF.jpg"/>
<img width="300" height="200" src="img/400006diZeTesv.jpg"/>
<img width="300" height="200" src="img/4000067OF5fxlk.jpg"/>
<img width="300" height="200" src="img/4000068geM1o6c.jpg"/>


<br/>
<br/>
<br/>

<?
echo runtest();
?>

<br/>
<br/>

<?

echo '<p><span class="description">Server Memory Usage:</span> <span class="result">= '. get_server_memory_usage() .' %</span></p>';
echo '<p><span class="description">Server CPU Usage: </span> <span class="result">= ' .get_server_cpu_usage() .'%</span></p>';

?>



</body>
</html>