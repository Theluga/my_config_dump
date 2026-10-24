# ===== 1. UTF-8 and Envs ===== 
$OutputEncoding = [Console]::InputEncoding = 
 [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) 

$env:LANG = "C.UTF-8" 
$PSNativeCommandArgumentPassing = 'Standard' # make PowerShell more linux like 

# ===== 2. Native ANSI Single-Line Prompt (Git-Cached) ===== 
$script:CachedGitInfo = '' 
$script:GitCacheTime = [datetime]::MinValue 
$script:GitCachePath = '' 

function prompt { 
 $esc = [char]27 
 $reset = "$esc[0m" 
 $blue = "$esc[38;5;39m" 
 $green = "$esc[38;5;114m" 
 $yellow = "$esc[38;5;220m" 
 $pink = "$esc[38;5;212m" 

 $path = (Get-Location).Path.Replace('\', '/') 
 $now = [datetime]::Now 

 # Refresh after 2 seconds or immediately when changing directories. 
 if ( 
 $path -cne $script:GitCachePath -or 
 ($now - $script:GitCacheTime).TotalSeconds -gt 2 
 ) { 
 $script:GitCachePath = $path 
 $script:GitCacheTime = $now 
 $script:CachedGitInfo = '' 

 if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) { 
 $status = git status --porcelain=v1 --branch --untracked-files=normal 2>$null 

 if ($LASTEXITCODE -eq 0 -and $status.Count -gt 0) { 
 $branchLine = $status | Select-Object -First 1 

 if ($branchLine -match '^## (.+)$') { 
 $branch = $Matches[1] -replace '\.\.\..*$', '' 
 $dirty = @($status | Select-Object -Skip 1).Count -gt 0 

 # Preserve the short commit hash for detached HEAD. 
 if ($branch -match '^HEAD(?:\s|$)') { 
 $hash = git rev-parse --short HEAD 2>$null 
 if ($LASTEXITCODE -eq 0 -and $hash) { 
 $branch = $hash 
 } 
 } 

 $gitColor = if ($dirty) { $yellow } else { $green } 
 $script:CachedGitInfo = " ${gitColor}$([char]0xE0A0) $branch$reset" 
 } 
 } 
 } 
 } 

 "$blue$path$reset$script:CachedGitInfo ${pink}$([char]0x276F)$reset " 
} 

# ===== 3. Functions and External GNU Utilities ===== 

function which { 
 param( 
 [Parameter(Mandatory, Position = 0)] 
 [string]$Name 
 ) 

 Get-Command $Name -All -ErrorAction SilentlyContinue | 
 ForEach-Object { 
 $path = if ($_.Path) { $_.Path } else { $_.Definition } 

 if ($path) { 
 $path.Replace('\', '/') # -replace '\.exe$', '' 
 } 
 } 
} 

$gnu_alias = @('cat', 'grep', 'ls', 'man') 

foreach ($name in $gnu_alias) { 
 $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | 
 Select-Object -First 1 

 if ($cmd) { 
 $exe = $cmd.Path.Replace('\', '/') 
 Remove-Item "Alias:\$name" -Force -ErrorAction SilentlyContinue 
 Remove-Item "Function:\$name" -Force -ErrorAction SilentlyContinue 
 Set-Alias -Name $name -Value $exe -Option AllScope 
 } 
} 

# ===== 4. PSReadLine: Zsh-like Experience ===== 

Import-Module PSReadLine -ErrorAction SilentlyContinue 

# não salvar comandos iniciando com espaço no histórico 
Set-PSReadLineOption -AddToHistoryHandler { 
 param($line) 
 return -not $line.StartsWith(' ') 
} 

# Persistent history, similar to Zsh 
Set-PSReadLineOption -EditMode Emacs 
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally 
Set-PSReadLineOption -MaximumHistoryCount 50000 

# Inline autosuggestions from history 
try { 
 Set-PSReadLineOption -PredictionSource History 
 Set-PSReadLineOption -PredictionViewStyle InlineView 
} catch {} 

# Syntax highlighting: Nord-inspired colors 
Set-PSReadLineOption -Colors @{ 
 Command = '#81A1C1' 
 Parameter = '#8FBCBB' 
 String = '#A3BE8C' 
 Operator = '#ECEFF4' 
 Variable = '#D8DEE9' 
 Number = '#B48EAD' 
 Member = '#88C0D0' 
 Comment = '#616E88' 
 Error = '#BF616A' 
} 

# ===== 5. Substring Search + RAM Cached History ===== 

$global:PSHistorySearch = @{ 
 Active = $false 
 Original = '' 
 Matches = @() 
 Index = -1 
 LastResult = '' 
 AllHistory = $null 
} 

function Get-CachedHistory { 
 $historyPath = (Get-PSReadLineOption).HistorySavePath 
 $allHistory = @() 

 if ($historyPath -and (Test-Path -LiteralPath $historyPath)) { 
 $allHistory = @( 
 Get-Content -LiteralPath $historyPath -Encoding UTF8 -ErrorAction SilentlyContinue 
 ) 
 } 

 [array]::Reverse($allHistory) 
 $global:PSHistorySearch.AllHistory = $allHistory 

 return $global:PSHistorySearch.AllHistory 
} 

function Invoke-SubstringHistorySearch { 
 param( 
 [ValidateSet('Backward', 'Forward')] 
 [string]$Direction 
 ) 

 $line = '' 
 $cursor = 0 

 [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState( 
 [ref]$line, [ref]$cursor 
 ) 

 $state = $global:PSHistorySearch 

 # Continue cycling if the current line is the last search result. 
 $continuing = $state.Active -and ($line -ceq $state.LastResult) 

 if (-not $continuing) { 
 # Loaded once and kept in RAM (no disk lag on arrow keys) 
 $allHistory = Get-CachedHistory 

 # Empty input means normal chronological history browsing. 
 # Otherwise, match the query anywhere in the command. 
 if ([string]::IsNullOrEmpty($line)) { 
 $matches = $allHistory 
 } else { 
 $matches = @( 
 $allHistory | Where-Object { 
 $_.IndexOf( 
 $line, 
 [System.StringComparison]::OrdinalIgnoreCase 
 ) -ge 0 
 } 
 ) 
 } 

 $state.Original = $line 
 $state.Matches = @($matches) 
 $state.Index = -1 
 $state.Active = $true 
 $state.LastResult = $line 
 } 

 if ($state.Matches.Count -eq 0) { 
 $state.Active = $false 
 return 
 } 

 if ($Direction -eq 'Backward') { 
 # Up: move to older matching commands. 
 $state.Index++ 

 if ($state.Index -ge $state.Matches.Count) { 
 $state.Index = 0 
 } 
 } else { 
 # Down: move toward newer matches. 
 $state.Index-- 

 if ($state.Index -lt 0) { 
 $original = $state.Original 
 $state.Active = $false 
 $state.LastResult = '' 

 [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState( 
 [ref]$line, [ref]$cursor 
 ) 

 [Microsoft.PowerShell.PSConsoleReadLine]::Replace( 
 0, $line.Length, $original 
 ) 
 return 
 } 
 } 

 $result = $state.Matches[$state.Index] 
 $state.LastResult = $result 

 [Microsoft.PowerShell.PSConsoleReadLine]::Replace( 
 0, $line.Length, $result 
 ) 
} 

Set-PSReadLineKeyHandler -Key UpArrow -ScriptBlock { 
 param($key, $arg) 
 Invoke-SubstringHistorySearch -Direction Backward 
} 

Set-PSReadLineKeyHandler -Key DownArrow -ScriptBlock { 
 param($key, $arg) 
 Invoke-SubstringHistorySearch -Direction Forward 
} 

# ===== Tab Completion + Path Separators ===== 

Set-PSReadLineOption -CompletionQueryItems 100 
# Show all completion candidates without a yes/no prompt. 
# Set-PSReadLineOption -CompletionQueryItems ([int]::MaxValue) 

# Tab: menu completion, then convert \ to / 
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { 
 param($key, $arg) 

 [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete($key, $arg) 

 $line = '' 
 $cursor = 0 

 [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState( 
 [ref]$line, [ref]$cursor 
 ) 

 $updated = $line.Replace('\', '/') 

 if ($updated -cne $line) { 
 [Microsoft.PowerShell.PSConsoleReadLine]::Replace( 
 0, $line.Length, $updated 
 ) 
 [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition( 
 [Math]::Min($cursor, $updated.Length) 
 ) 
 } 
} 

# Ctrl+\ : convert existing backslashes to forward slashes 
Set-PSReadLineKeyHandler -Chord 'Ctrl+\' -ScriptBlock { 
 $line = '' 
 $cursor = 0 

 [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState( 
 [ref]$line, [ref]$cursor 
 ) 

 $updated = $line.Replace('\', '/') 

 [Microsoft.PowerShell.PSConsoleReadLine]::Replace( 
 0, $line.Length, $updated 
 ) 

 [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition( 
 [Math]::Min($cursor, $updated.Length) 
 ) 
} 

# Word navigation and deletion 
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord 
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord 
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord 
Set-PSReadLineKeyHandler -Chord 'Ctrl+Delete' -Function KillWord  
