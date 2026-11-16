# Installateur du collecteur ODM pour Windows.
# Lancé par le fichier « installer-odm.cmd » téléchargé depuis le site (Mon compte),
# qui fournit ODM_URL, ODM_KEY et ODM_CLE dans l'environnement.
# Enregistré en UTF-8 avec BOM : Windows PowerShell 5.1 lit sinon les accents de travers.
# Relançable sans risque : il met à jour ce qui existe déjà.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
function Etape($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Ok($t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Stop-Erreur($t) { Write-Host "`n   ERREUR : $t" -ForegroundColor Red; exit 1 }

if (-not $env:ODM_URL -or -not $env:ODM_KEY -or -not $env:ODM_CLE) {
  Stop-Erreur "Lance plutôt le fichier installer-odm.cmd téléchargé depuis le site (Mon compte)."
}

$dossier = Join-Path $env:LOCALAPPDATA "ODM"
$script  = Join-Path $dossier "claude_usage.py"
$base    = "https://gamgie.github.io/ODM/collecteur"
New-Item -ItemType Directory -Force $dossier | Out-Null

function Recharger-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
}
function Trouver-Python {
  foreach ($c in @("py", "python", "python3")) {
    try {
      $p = & $c -c "import sys; print(sys.executable)" 2>$null
      if ($LASTEXITCODE -eq 0 -and $p -and (Test-Path $p.Trim())) { return $p.Trim() }
    } catch {}
  }
  return $null
}

# ---------- 1. Python ----------
Etape "1/5  Python"
$py = Trouver-Python
if (-not $py) {
  Write-Host "   Python absent : installation avec winget..."
  try {
    winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements | Out-Host
  } catch { Stop-Erreur "winget indisponible. Installe Python depuis python.org (cocher « Add to PATH »), puis relance." }
  Recharger-Path
  $py = Trouver-Python
  if (-not $py) { Stop-Erreur "Python installé mais introuvable. Ferme cette fenêtre et relance installer-odm.cmd." }
}
$pyw = Join-Path (Split-Path $py) "pythonw.exe"
if (-not (Test-Path $pyw)) { $pyw = $py }
Ok $py

# ---------- 2. Collecteur ----------
Etape "2/5  Collecteur"
Invoke-WebRequest "$base/claude_usage.py?t=$(Get-Random)" -OutFile $script -UseBasicParsing
$json = @{ supabase_url = $env:ODM_URL; supabase_key = $env:ODM_KEY; cle_collecteur = $env:ODM_CLE } | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $dossier "config.json"), $json, (New-Object Text.UTF8Encoding $false))
Ok "installé dans $dossier"

# ---------- 3. Claude Code et connexion ----------
Etape "3/5  Connexion à Claude"
# Un vrai essai, pas seulement la présence du fichier : un ancien jeton peut être révoqué.
function Tester-Connexion {
  $ancien = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $py $script --test *> $null } catch {}
  $ok = ($LASTEXITCODE -eq 0); $ErrorActionPreference = $ancien; return $ok
}
$claude = Join-Path $HOME ".local\bin\claude.exe"
if (Tester-Connexion) {
  Ok "connecté (jauges lues)"
} else {
  if (-not (Test-Path $claude)) {
    Write-Host "   Installation de Claude Code (ligne de commande)..."
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
  }
  if (-not (Test-Path $claude)) { Stop-Erreur "Claude Code introuvable après installation ($claude)." }
  $binDir = Split-Path $claude
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$binDir*") { [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User") }
  Write-Host ""
  Write-Host "   Claude va s'ouvrir dans cette fenêtre pour (re)connecter ton compte." -ForegroundColor Yellow
  Write-Host "   1. Si Claude ne propose pas la connexion, tape  /login  puis Entrée." -ForegroundColor Yellow
  Write-Host "   2. Choisis ton compte Claude (abonnement) et valide dans le navigateur." -ForegroundColor Yellow
  Write-Host "   3. Quand c'est fait, tape  /exit  puis Entrée." -ForegroundColor Yellow
  Read-Host "   Appuie sur Entrée pour continuer"
  & $claude
  if (-not (Tester-Connexion)) { Stop-Erreur "Connexion à Claude toujours refusée. Relance installer-odm.cmd ; dans Claude, tape /login." }
  Ok "connecté (jauges lues)"
}

# ---------- 4. Premier relevé ----------
Etape "4/5  Premier relevé"
& $py $script
if ($LASTEXITCODE -ne 0) { Stop-Erreur "le relevé a échoué (détails ci-dessus et dans $dossier\log.txt)." }
Ok "relevé envoyé : il apparaît sur le site"

# ---------- 5. Tâche planifiée ----------
Etape "5/5  Relevé automatique toutes les 30 minutes"
try { Unregister-ScheduledTask -TaskName "ODM collecteur" -Confirm:$false -ErrorAction SilentlyContinue } catch {}   # ancienne tâche éventuelle
$action   = New-ScheduledTaskAction -Execute $pyw -Argument "`"$script`"" -WorkingDirectory $dossier
$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30)
# Sur un portable, Windows bloque par défaut les tâches sur batterie : on l'autorise.
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName "ODM collecteur" -Action $action -Trigger $trigger -Settings $settings -Description "Relève les jauges Claude pour le site ODM" -Force | Out-Null
Ok "tâche « ODM collecteur » créée (fonctionne aussi sur batterie)"

Write-Host "`nTerminé. Journal : $dossier\log.txt" -ForegroundColor Green
Write-Host "Pour arrêter : Unregister-ScheduledTask -TaskName 'ODM collecteur'"
