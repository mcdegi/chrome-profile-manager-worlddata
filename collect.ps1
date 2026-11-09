$ErrorActionPreference = 'Stop'
$repository = 'mcdegi/chrome-profile-manager-worlddata'
$collectorTag = 'collector-v0.2.14'
$collectorSha256 = 'BBEC90AA52DECA15222DA5E57293E906A17FA3BA58966CE577C6D535D7172ED1'
if ($env:GITHUB_REPOSITORY -ne $repository -or !$env:RUNNER_TEMP) { throw 'This workflow only runs in its public data repository.' }
$toolRoot = Join-Path $env:RUNNER_TEMP 'cpm-worlddata'
New-Item -ItemType Directory -Path $toolRoot | Out-Null
$exe = Join-Path $toolRoot 'collector.exe'
$state = Join-Path $toolRoot 'state'
$output = Join-Path $toolRoot 'output'

function Download([string]$Url, [string]$Path, [long]$Maximum) {
    $handler = [Net.Http.HttpClientHandler]::new(); $handler.UseCookies = $false
    $http = [Net.Http.HttpClient]::new($handler); $http.Timeout = [TimeSpan]::FromSeconds(90)
    try {
        $reply = $http.GetAsync($Url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $reply.EnsureSuccessStatusCode() | Out-Null
            if ($reply.Content.Headers.ContentLength -gt $Maximum) { throw 'Download exceeds limit.' }
            $inputStream = $reply.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $target = [IO.File]::Create($Path)
            try {
                $bytes = [byte[]]::new(8192); [long]$total = 0
                while (($read = $inputStream.Read($bytes,0,$bytes.Length)) -gt 0) { $total += $read; if ($total -gt $Maximum) { throw 'Download exceeds limit.' }; $target.Write($bytes,0,$read) }
            } finally { $target.Dispose(); $inputStream.Dispose() }
        } finally { $reply.Dispose() }
    } finally { $http.Dispose() }
}
function Invoke-Collector([string[]]$Arguments, [int]$TimeoutSeconds = 480) {
    foreach ($argument in $Arguments) { if ($argument.Contains('"')) { throw 'Unexpected argument quote.' } }
    $line = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $errors = Join-Path $toolRoot 'collector-error.txt'
    $process = Start-Process -FilePath $exe -ArgumentList $line -WorkingDirectory $toolRoot -WindowStyle Hidden -RedirectStandardError $errors -RedirectStandardOutput (Join-Path $toolRoot 'collector-output.txt') -PassThru
    if (!$process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill(); $process.WaitForExit(); throw 'Collector exceeded its deadline.' }
    $process.Refresh()
    if ($process.ExitCode -ne 0 -and (Test-Path -LiteralPath $errors)) { $classification = [IO.File]::ReadAllText($errors).Trim(); if ($classification -match '^WorldDataCollector: [A-Za-z0-9]+(?:; phase=[a-z-]+)?$') { Write-Host $classification } }
    return $process.ExitCode
}
function Get-ContentFile([string]$Name, [bool]$Optional = $false) {
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $reply = & gh api --include "repos/$repository/contents/$Name" 2>$null
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    $text = $reply -join "`n"
    if ($code -ne 0) { if ($Optional -and $text -match '^HTTP/\S+ 404(?:\s|$)') { return $null }; throw 'Cannot read repository metadata.' }
    $parts = $text -split '\r?\n\r?\n',2
    if ($parts.Count -ne 2) { throw 'Invalid metadata response.' }
    return ($parts[1] | ConvertFrom-Json)
}
function Put-ContentFile([string]$Name, [string]$Text, [string]$Message, $Existing) {
    $body = @{message=$Message; branch='main'; content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text))}
    if ($Existing) { $body.sha = $Existing.sha }
    $file = Join-Path $toolRoot ('request-' + [Guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($file, ($body | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    & gh api --method PUT "repos/$repository/contents/$Name" --input $file --silent
    if ($LASTEXITCODE -ne 0) { throw 'Cannot commit repository metadata.' }
}
function From-ContentFile($Value) { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($Value.content -replace '\s',''))) }
function ManifestFromEnvelope([string]$Text) {
    $envelope = $Text | ConvertFrom-Json
    return ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($envelope.Manifest)) | ConvertFrom-Json)
}

$hostEntry = Get-ContentFile 'feeds/de258-host.json' $true
if ($hostEntry -and ((From-ContentFile $hostEntry) | ConvertFrom-Json).Kind -eq 'server') {
    'Collection belongs to Windows Server; GitHub scheduler does not fetch world data.' | Add-Content $env:GITHUB_STEP_SUMMARY
    exit 0
}

Download "https://github.com/$repository/releases/download/$collectorTag/collector.exe" $exe 16777216
if ((Get-FileHash -LiteralPath $exe).Hash -ne $collectorSha256) { throw 'Collector checksum mismatch.' }
$feedEntry = Get-ContentFile 'feeds/de258.json'
$feedText = From-ContentFile $feedEntry
$manifest = ManifestFromEnvelope $feedText
if ($manifest.World -ne 'de258' -or $manifest.Tag -notmatch '^de258-\d{8}T\d{6}Z$') { throw 'Invalid world metadata.' }
$feed = Join-Path $toolRoot 'previous.json'
$bundle = Join-Path $toolRoot 'previous.zip'
[IO.File]::WriteAllText($feed, $feedText, [Text.UTF8Encoding]::new($false))
Download "https://github.com/$repository/releases/download/$($manifest.Tag)/worlddata.zip" $bundle 67108864
if ((Invoke-Collector @('--worlddata-cloud','restore',$bundle,$state,$feed)) -ne 0) { throw 'Previous signed state cannot be restored.' }

# Persist the reservation independently of the dataset. A failed or cancelled
# collection must not reset its hourly game-server cooldown on the next runner.
$attemptEntry = Get-ContentFile 'feeds/de258-attempt.json' $true
$nextDue = [DateTimeOffset]::MinValue
if ($attemptEntry) {
    $attempt = (From-ContentFile $attemptEntry) | ConvertFrom-Json
    $stamp = if ($attempt.CompletedUtc) { [long]$attempt.CompletedUtc } else { [long]$attempt.ReservedUntilUtc }
    if ($stamp -le 0) { throw 'Damaged persistent reservation.' }
    $nextDue = [DateTimeOffset]::FromUnixTimeSeconds($stamp).AddHours(1)
}
foreach ($name in @('maps.attempt','conquests.attempt')) {
    $ticks = [long][IO.File]::ReadAllText((Join-Path $state "WorldData/de258/$name"))
    $due = [DateTimeOffset]::new($ticks,[TimeSpan]::Zero).AddHours(1)
    if ($due -gt $nextDue) { $nextDue = $due }
}
$wait = $nextDue - [DateTimeOffset]::UtcNow
if ($wait.TotalMinutes -gt 15) { 'The last reservation is still current; existing dataset retained.' | Add-Content $env:GITHUB_STEP_SUMMARY; exit 0 }
if ($wait.TotalSeconds -gt 0) { Start-Sleep -Seconds ([Math]::Ceiling($wait.TotalSeconds) + 1) }
$reservation = @{AttemptedUtc=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); ReservedUntilUtc=[DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds(); CompletedUtc=$null}
Put-ContentFile 'feeds/de258-attempt.json' ($reservation | ConvertTo-Json -Compress) 'Reserve hourly de258 collection' $attemptEntry
try { $exit = Invoke-Collector @('--worlddata-cloud','collect',$state,$output) }
finally {
    $reservation.CompletedUtc = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Put-ContentFile 'feeds/de258-attempt.json' ($reservation | ConvertTo-Json -Compress) 'Complete de258 collection attempt' (Get-ContentFile 'feeds/de258-attempt.json')
}
if ($exit -eq 3) { 'No newer complete world snapshot; existing dataset retained.' | Add-Content $env:GITHUB_STEP_SUMMARY; exit 0 }
if ($exit -ne 0) { throw 'World data collection failed; previous signed data remains available.' }
$nextFeed = [IO.File]::ReadAllText((Join-Path $output 'de258.json'))
$next = ManifestFromEnvelope $nextFeed
if ($next.CapturedUtc -le $manifest.CapturedUtc) { throw 'Collector did not produce a newer capture.' }
$assets = @('worlddata.zip','player-starts.csv','de258.json','manifest.json') | ForEach-Object { Join-Path $output $_ }
$notes = Join-Path $output 'notes.txt'
"de258 public world data. Capture UTC: $([DateTimeOffset]::FromUnixTimeSeconds($next.CapturedUtc).ToString('o')). CSV: player_id,timestamp (Unix seconds UTC). Full signed state; no manager settings or credentials." | Set-Content -LiteralPath $notes -Encoding UTF8
& gh release create $next.Tag @assets --repo $repository --draft --target main --title "de258 $($next.Tag)" --notes-file $notes --latest=false
if ($LASTEXITCODE -ne 0) { throw 'Draft upload failed.' }
$verify = Join-Path $toolRoot 'verify'; New-Item -ItemType Directory -Path $verify | Out-Null
& gh release download $next.Tag --repo $repository --dir $verify
if ($LASTEXITCODE -ne 0) { throw 'Draft download failed.' }
foreach ($asset in $assets) { if ((Get-FileHash -LiteralPath $asset).Hash -ne (Get-FileHash -LiteralPath (Join-Path $verify ([IO.Path]::GetFileName($asset)))).Hash) { throw 'Uploaded file mismatch.' } }
& gh release edit $next.Tag --repo $repository --draft=false --latest
if ($LASTEXITCODE -ne 0) { throw 'Draft publication failed.' }
$current = Get-ContentFile 'feeds/de258.json'
if ((ManifestFromEnvelope (From-ContentFile $current)).CapturedUtc -gt $next.CapturedUtc) { throw 'A newer pointer already exists; refusing rollback.' }
Put-ContentFile 'feeds/de258.json' $nextFeed "Publish de258 $($next.Tag)" $current

$all = @(); $page = 1
do {
    $items = & gh api "repos/$repository/releases?per_page=100&page=$page" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect retained snapshots.' }
    $all += @($items); $page++
} while (@($items).Count -eq 100 -and $page -le 10)
$cutoff = [DateTimeOffset]::UtcNow.AddHours(-48)
foreach ($release in $all) {
    if ($release.draft -or $release.tag_name -eq $next.Tag -or $release.tag_name -notmatch '^de258-\d{8}T\d{6}Z$') { continue }
    $capture = [DateTimeOffset]::ParseExact($release.tag_name,"'de258-'yyyyMMdd'T'HHmmss'Z'",[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal)
    if ($capture -lt $cutoff) {
        & gh release delete $release.tag_name --repo $repository --yes --cleanup-tag
        if ($LASTEXITCODE -ne 0) { throw 'Snapshot retention cleanup failed.' }
    }
}
"Published $($next.Tag). Dataset and CSV verified. Older snapshots retained for 48 hours; newest complete state remains available." | Add-Content $env:GITHUB_STEP_SUMMARY
