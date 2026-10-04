# Chromaton tasks. Run through make.cmd in the project root:
#   .\make help
# Finds Godot by the GODOT environment variable, then godot on PATH, then the
# winget install folder. Windows PowerShell 5.1 syntax, so it runs anywhere.
param(
	[Parameter(Position = 0)][string]$Task = "help",
	[Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Find-Godot {
	$gui = $null
	if ($env:GODOT -and (Test-Path $env:GODOT)) {
		$gui = (Resolve-Path $env:GODOT).Path
	} else {
		$cmd = Get-Command godot -ErrorAction SilentlyContinue
		if ($cmd) {
			$gui = $cmd.Source
		} else {
			$pkgs = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
			if (Test-Path $pkgs) {
				$found = Get-ChildItem $pkgs -Directory -Filter "GodotEngine.GodotEngine_*" |
					ForEach-Object { Get-ChildItem $_.FullName -Filter "Godot_v4*_win64.exe" } |
					Sort-Object Name -Descending | Select-Object -First 1
				if ($found) { $gui = $found.FullName }
			}
		}
	}
	if (-not $gui) {
		throw "Godot not found. Install it (winget install GodotEngine.GodotEngine) or set GODOT to the Godot executable."
	}
	# The console build prints to the terminal and waits; use it for tools.
	$console = $gui -replace "_win64\.exe$", "_win64_console.exe"
	if (-not (Test-Path $console)) { $console = $gui }
	return @{ Gui = $gui; Console = $console }
}

# Runs Godot in the console and returns its exit code.
function Invoke-Godot([string[]]$GodotArgs) {
	$g = Find-Godot
	& $g.Console @GodotArgs | Out-Host
	return $LASTEXITCODE
}

# Starts the game in its own window (no console) and returns at once.
function Start-Game([string[]]$GameArgs) {
	$g = Find-Godot
	$all = @("--path", $Root)
	if ($GameArgs.Count -gt 0) { $all += "--"; $all += $GameArgs }
	Start-Process -FilePath $g.Gui -ArgumentList $all -WorkingDirectory $Root | Out-Null
	return 0
}

function Invoke-Tool([string]$Script) {
	return Invoke-Godot @("--headless", "--path", $Root, "--script", "res://tools/$Script.gd")
}

# Godot's version as its export-template folder names it, e.g. 4.7.2.stable.
function Get-GodotVersion {
	$g = Find-Godot
	$v = (& $g.Console --version | Select-Object -Last 1).Trim()
	if ($v -notmatch '^(\d+\.\d+(\.\d+)?\.[a-z0-9]+)') { throw "Can't read the Godot version from '$v'." }
	return $Matches[1]
}

function Get-TemplateDir {
	return Join-Path $env:APPDATA "Godot\export_templates\$(Get-GodotVersion)"
}

# Installs the export templates for this Godot from a .tpz file, downloading
# it from Godot's GitHub releases (about 1.3 GB) when none is given.
function Install-Templates([string]$Tpz) {
	$dir = Get-TemplateDir
	$version = Get-GodotVersion
	if (-not $Tpz) {
		$tag = $version -replace '\.([a-z][a-z0-9]*)$', '-$1'
		$url = "https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"
		$Tpz = Join-Path $env:TEMP "Godot_v${tag}_export_templates.tpz"
		Write-Host "Downloading $url (about 1.3 GB)..."
		& curl.exe -fL -o $Tpz $url
		if ($LASTEXITCODE -ne 0) { throw "Download failed." }
	}
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Tpz).Path)
	try {
		New-Item -ItemType Directory -Force $dir | Out-Null
		foreach ($e in $zip.Entries) {
			if (-not $e.Name) { continue }
			$out = Join-Path $dir ($e.FullName -replace '^templates/', '')
			New-Item -ItemType Directory -Force (Split-Path -Parent $out) | Out-Null
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
		}
	} finally {
		$zip.Dispose()
	}
	Write-Host "Export templates installed in $dir"
	return 0
}

# Exports the web build (.\make export web) to build/web and zips it as
# build/chromaton-web.zip, ready to upload to itch.io.
function Export-Web {
	if (-not (Test-Path (Join-Path (Get-TemplateDir) "web_nothreads_release.zip"))) {
		throw "Export templates for Godot $(Get-GodotVersion) are missing. Run: .\make templates"
	}
	$web = Join-Path $Root "build\web"
	if (Test-Path $web) { Remove-Item -Recurse -Force $web }
	New-Item -ItemType Directory -Force $web | Out-Null
	$code = Invoke-Godot @("--headless", "--path", $Root, "--export-release", "Web", (Join-Path $web "index.html"))
	if ($code -ne 0 -or -not (Test-Path (Join-Path $web "index.html"))) {
		Write-Host "Web export failed."
		return 1
	}
	$zip = Join-Path $Root "build\chromaton-web.zip"
	if (Test-Path $zip) { Remove-Item -Force $zip }
	Compress-Archive -Path (Join-Path $web "*") -DestinationPath $zip
	Write-Host "Web build: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
	return 0
}

# Serves build/web on http://localhost:<port>/ for trying the web build in a
# browser (it won't load from file://). Runs until Ctrl+C.
function Serve-Web([int]$Port) {
	$web = Join-Path $Root "build\web"
	if (-not (Test-Path (Join-Path $web "index.html"))) {
		Write-Host "No web build yet. Run: .\make export web"
		return 1
	}
	$types = @{ ".html" = "text/html"; ".js" = "application/javascript"; ".wasm" = "application/wasm";
		".pck" = "application/octet-stream"; ".png" = "image/png"; ".json" = "application/json" }
	$listener = New-Object System.Net.HttpListener
	$listener.Prefixes.Add("http://localhost:$Port/")
	$listener.Start()
	Write-Host "Serving build/web on http://localhost:$Port/  (Ctrl+C to stop)"
	try {
		while ($listener.IsListening) {
			$ctx = $listener.GetContext()
			$rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
			if ($rel -eq "") { $rel = "index.html" }
			$file = [System.IO.Path]::GetFullPath((Join-Path $web $rel))
			$res = $ctx.Response
			if ($file.StartsWith($web) -and (Test-Path $file -PathType Leaf)) {
				$bytes = [System.IO.File]::ReadAllBytes($file)
				$ext = [System.IO.Path]::GetExtension($file).ToLower()
				$res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
				$res.Headers.Add("Cache-Control", "no-store")
				$res.ContentLength64 = $bytes.Length
				$res.OutputStream.Write($bytes, 0, $bytes.Length)
			} else {
				$res.StatusCode = 404
			}
			$res.Close()
		}
	} finally {
		$listener.Stop()
	}
	return 0
}

# Finds itch.io's butler by the BUTLER environment variable, then butler on
# PATH, then %LOCALAPPDATA%\butler (where it can be unpacked without admin).
function Find-Butler {
	if ($env:BUTLER -and (Test-Path $env:BUTLER)) { return (Resolve-Path $env:BUTLER).Path }
	$cmd = Get-Command butler -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }
	$local = Join-Path $env:LOCALAPPDATA "butler\butler.exe"
	if (Test-Path $local) { return $local }
	return $null
}

# The version a build is published under: the date and commit, e.g.
# 2026.10.04-127c7bd, with -dirty when the tree has uncommitted changes.
function Get-BuildVersion {
	$hash = (& git -C $Root rev-parse --short HEAD).Trim()
	$v = "$(Get-Date -Format 'yyyy.MM.dd')-$hash"
	if (& git -C $Root status --porcelain) { $v += "-dirty" }
	return $v
}

# Checks what a push to itch.io needs, so a release stops before the slow
# steps: butler, a login, and a target (user/game:channel, from the argument
# or the ITCH_TARGET environment variable). Returns the target, or $null.
function Get-ItchTarget([string]$Target) {
	if (-not (Find-Butler)) {
		Write-Host "butler not found. Unpack it into $(Join-Path $env:LOCALAPPDATA 'butler') (https://itch.io/docs/butler/), or put it on PATH."
		return $null
	}
	# butler login saves its key in %USERPROFILE%\.config\itch on Windows too.
	if (-not (Test-Path (Join-Path $env:USERPROFILE ".config\itch\butler_creds")) -and -not $env:BUTLER_API_KEY) {
		Write-Host "butler isn't logged in. Run once: .\make butler login"
		return $null
	}
	if (-not $Target) { $Target = $env:ITCH_TARGET }
	if (-not $Target) {
		Write-Host "No itch target: pass user/game:channel, or set ITCH_TARGET."
		return $null
	}
	if ($Target -notmatch '^[^/:\s]+/[^/:\s]+:[^/:\s]+$') {
		Write-Host "The itch target must look like user/game:channel, e.g. someone/chromaton:web (got '$Target')."
		return $null
	}
	return $Target
}

# Pushes build/web to itch.io with butler, as it is (.\make deploy).
function Deploy-Web([string]$Target) {
	$Target = Get-ItchTarget $Target
	if (-not $Target) { return 1 }
	$web = Join-Path $Root "build\web"
	if (-not (Test-Path (Join-Path $web "index.html"))) {
		Write-Host "No web build yet. Run: .\make export web"
		return 1
	}
	$version = Get-BuildVersion
	Write-Host "Pushing build/web to $Target as $version..."
	& (Find-Butler) push $web $Target --userversion $version --if-changed | Out-Host
	return $LASTEXITCODE
}

# The whole release to itch.io (.\make release itch): from a committed tree
# only, so the published version names a commit; then every test, a fresh
# web export, and the push.
function Release-Itch([string]$Target) {
	$Target = Get-ItchTarget $Target
	if (-not $Target) { return 1 }
	if (& git -C $Root status --porcelain) {
		Write-Host "Uncommitted changes: commit them first, so the release matches a commit."
		return 1
	}
	Write-Host "Releasing $(Get-BuildVersion) to $Target"
	$code = Invoke-Godot @("--headless", "--path", $Root, "--script", "res://tests/test_all.gd")
	if ($code -ne 0) {
		Write-Host "Tests failed; nothing was released."
		return $code
	}
	$code = Export-Web
	if ($code -ne 0) { return $code }
	return Deploy-Web $Target
}

function Show-Help {
	Write-Host @"
Chromaton tasks: .\make <task> [args]

Play
  play [args]          start the game (args go to the game, e.g. --unlock-all)
  level <id>           jump into one level, e.g. .\make level wash_out
  unlock               start with every level open

Test
  test [suite ...]     run all test suites, or only these (sim, paint, levels, inventions, workbench, journal)
  check                compile every script and report errors with line numbers
  bench                time the workbench's drawing on every level, running and dragging

Design tools (rewrite files under docs/, levels/ or data/)
  solve                prove each level's star counts (docs/level-report.md)
  cards                derive pattern cards from target pictures
  algebra              check the color algebra (docs/algebra-report.md)
  words                the journal's Words from the lexicon (data/words.json)

Share
  export <platform>    build the game for a platform; only web for now:
                       export web writes build/web and build/chromaton-web.zip (for itch.io)
  serve [port]         play the web build at http://localhost:8060/ (after export web)
  release <store> [target]
                       publish from a committed tree: tests, a fresh build, the upload; only itch
                       for now: release itch pushes the web build (target as for deploy)
  deploy [target]      push build/web to itch.io as it is; target is user/game:channel,
                       or set ITCH_TARGET (after export web)
  butler [args]        run itch.io's butler (e.g. butler login, once); bare, print which one
  templates [tpz]      install Godot's export templates (downloads about 1.3 GB unless given a .tpz)

Other
  shot <level> <png> [options]
                       save a screenshot and quit; level can also be 'levels',
                       'journal' (or 'book'), 'options' or 'intro'; options: --ticks=N --phase=0.5 --finish --wrong --empty --page=N --stale
                       --tab=T --solved=N --piece=K --word=N (journal) --peek[=K] --news --fan (a level)
                       --grid --paints --touch
  import               import new fonts or other assets
  godot                print which Godot this script uses
"@
}

$code = 0
switch ($Task) {
	"help" { Show-Help }
	"play" { $code = Start-Game $Rest }
	"level" {
		if ($Rest.Count -lt 1) { throw "usage: .\make level <id>" }
		$code = Start-Game (@("--level=" + $Rest[0]) + ($Rest | Select-Object -Skip 1))
	}
	"unlock" { $code = Start-Game (@("--unlock-all") + $Rest) }
	"test" {
		$a = @("--headless", "--path", $Root, "--script", "res://tests/test_all.gd")
		if ($Rest.Count -gt 0) { $a += "--"; $a += $Rest }
		$code = Invoke-Godot $a
	}
	"check" { $code = Invoke-Tool "check_scripts" }
	"bench" { $code = Invoke-Godot @("--headless", "--fixed-fps", "60", "--path", $Root, "--script", "res://tools/bench_draw.gd") }
	"solve" { $code = Invoke-Tool "level_solver" }
	"cards" { $code = Invoke-Tool "make_cards" }
	"algebra" { $code = Invoke-Tool "algebra_check" }
	"words" { $code = Invoke-Tool "make_words" }
	"shot" {
		if ($Rest.Count -lt 2) { throw "usage: .\make shot <level> <png> [options]" }
		$png = $Rest[1]
		if (-not [System.IO.Path]::IsPathRooted($png)) { $png = Join-Path (Get-Location) $png }
		$png = [System.IO.Path]::GetFullPath($png)
		$a = @("--path", $Root, "--", "--screenshot=$($Rest[0]):$png") + ($Rest | Select-Object -Skip 2)
		$code = Invoke-Godot $a
	}
	"export" {
		switch ($(if ($Rest.Count -gt 0) { $Rest[0] } else { "" })) {
			"web" { $code = Export-Web }
			default {
				Write-Host "usage: .\make export <platform>   (platforms: web)"
				$code = 1
			}
		}
	}
	"serve" { $code = Serve-Web ($(if ($Rest.Count -gt 0) { [int]$Rest[0] } else { 8060 })) }
	"deploy" { $code = Deploy-Web ($Rest | Select-Object -First 1) }
	"release" {
		switch ($(if ($Rest.Count -gt 0) { $Rest[0] } else { "" })) {
			"itch" { $code = Release-Itch ($Rest | Select-Object -Skip 1 -First 1) }
			default {
				Write-Host "usage: .\make release <store> [target]   (stores: itch)"
				$code = 1
			}
		}
	}
	"butler" {
		$b = Find-Butler
		if (-not $b) {
			Write-Host "butler not found. Unpack it into $(Join-Path $env:LOCALAPPDATA 'butler') (https://itch.io/docs/butler/), or put it on PATH."
			$code = 1
		} elseif ($Rest.Count -eq 0) {
			Write-Host "butler: $b"
			& $b -V | Out-Host
		} else {
			& $b @Rest | Out-Host
			$code = $LASTEXITCODE
		}
	}
	"templates" { $code = Install-Templates ($Rest | Select-Object -First 1) }
	"import" { $code = Invoke-Godot @("--headless", "--path", $Root, "--import") }
	"godot" {
		$g = Find-Godot
		Write-Host "game:    $($g.Gui)"
		Write-Host "console: $($g.Console)"
	}
	default {
		Write-Host "Unknown task '$Task'."
		Show-Help
		$code = 1
	}
}
exit $code
