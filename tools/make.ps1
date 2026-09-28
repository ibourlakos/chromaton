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

function Show-Help {
	Write-Host @"
Chromaton tasks: .\make <task> [args]

Play
  play [args]          start the game (args go to the game, e.g. --unlock-all)
  level <id>           jump into one level, e.g. .\make level wash_out
  unlock               start with every level open

Test
  test [suite ...]     run all test suites, or only these (sim, paint, levels, inventions, workbench)
  check                compile every script and report errors with line numbers

Design tools (rewrite files under docs/ or levels/)
  solve                prove each level's star counts (docs/level-report.md)
  cards                derive pattern cards from target pictures
  algebra              check the color algebra (docs/algebra-report.md)

Other
  shot <level> <png> [options]
                       save a screenshot and quit; level can also be 'levels'
                       or 'book'; options: --ticks=N --phase=0.5 --finish --wrong --empty
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
	"solve" { $code = Invoke-Tool "level_solver" }
	"cards" { $code = Invoke-Tool "make_cards" }
	"algebra" { $code = Invoke-Tool "algebra_check" }
	"shot" {
		if ($Rest.Count -lt 2) { throw "usage: .\make shot <level> <png> [options]" }
		$png = $Rest[1]
		if (-not [System.IO.Path]::IsPathRooted($png)) { $png = Join-Path (Get-Location) $png }
		$png = [System.IO.Path]::GetFullPath($png)
		$a = @("--path", $Root, "--", "--screenshot=$($Rest[0]):$png") + ($Rest | Select-Object -Skip 2)
		$code = Invoke-Godot $a
	}
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
