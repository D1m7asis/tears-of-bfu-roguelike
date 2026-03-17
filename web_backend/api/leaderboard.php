<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(204);
	exit;
}

$dataDir = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'data';
$dataFile = $dataDir . DIRECTORY_SEPARATOR . 'leaderboard.json';
$limit = max(1, min(100, (int)($_GET['limit'] ?? 20)));
$action = (string)($_GET['action'] ?? '');

if (!is_dir($dataDir) && !mkdir($dataDir, 0777, true) && !is_dir($dataDir)) {
	fail('Unable to create data directory.', 500);
}

if (!file_exists($dataFile)) {
	file_put_contents($dataFile, json_encode(['entries' => []], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

if ($_SERVER['REQUEST_METHOD'] === 'GET' || $action === 'list') {
	$payload = load_payload($dataFile);
	$entries = isset($payload['entries']) && is_array($payload['entries']) ? $payload['entries'] : [];
	usort($entries, 'compare_entries');
	$entries = array_slice($entries, 0, $limit);
	echo json_encode(['ok' => true, 'entries' => array_values($entries)], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
	exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
	fail('Unsupported request method.', 405);
}

$rawBody = file_get_contents('php://input');
$body = json_decode($rawBody ?: '', true);
if (!is_array($body)) {
	fail('Invalid JSON payload.', 400);
}

$playerName = sanitize_name((string)($body['player_name'] ?? 'BFU Runner'));
$score = max(0, (int)($body['score'] ?? 0));
$kills = max(0, (int)($body['kills'] ?? 0));
$basement = max(1, (int)($body['basement'] ?? 1));
$timeSeconds = max(0, (int)($body['time_seconds'] ?? 0));
$mode = sanitize_name((string)($body['mode'] ?? 'endless'), 20);

$payload = load_payload($dataFile);
$entries = isset($payload['entries']) && is_array($payload['entries']) ? $payload['entries'] : [];
$entries[] = [
	'player_name' => $playerName,
	'score' => $score,
	'kills' => $kills,
	'basement' => $basement,
	'time_seconds' => $timeSeconds,
	'mode' => $mode,
	'created_at' => gmdate('c'),
];

usort($entries, 'compare_entries');

$entries = array_slice($entries, 0, 200);
$payload['entries'] = array_values($entries);
file_put_contents($dataFile, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), LOCK_EX);

echo json_encode([
	'ok' => true,
	'message' => 'Run saved.',
	'entries' => array_slice($payload['entries'], 0, $limit),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

function load_payload(string $path): array
{
	$json = file_get_contents($path);
	$payload = json_decode($json ?: '', true);
	return is_array($payload) ? $payload : ['entries' => []];
}

function sanitize_name(string $value, int $maxLength = 24): string
{
	$value = trim($value);
	if ($value === '') {
		return 'BFU Runner';
	}
	$value = preg_replace('/[^\p{L}\p{N}\s_\-\.]/u', '', $value) ?? 'BFU Runner';
	$value = trim($value);
	if ($value === '') {
		return 'BFU Runner';
	}
	return mb_substr($value, 0, $maxLength);
}

function compare_entries(array $a, array $b): int
{
	$scoreCompare = ($b['score'] ?? 0) <=> ($a['score'] ?? 0);
	if ($scoreCompare !== 0) {
		return $scoreCompare;
	}

	$basementCompare = ($b['basement'] ?? 0) <=> ($a['basement'] ?? 0);
	if ($basementCompare !== 0) {
		return $basementCompare;
	}

	$killsCompare = ($b['kills'] ?? 0) <=> ($a['kills'] ?? 0);
	if ($killsCompare !== 0) {
		return $killsCompare;
	}

	return ($b['time_seconds'] ?? 0) <=> ($a['time_seconds'] ?? 0);
}

function fail(string $message, int $status): void
{
	http_response_code($status);
	echo json_encode(['ok' => false, 'error' => $message], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
	exit;
}
