Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scaffoldScript = Join-Path $scriptRoot 'New-App.ps1'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Scaffold New App'
$form.Size = New-Object System.Drawing.Size(560, 520)
$form.StartPosition = 'CenterScreen'

function New-Label {
    param([string]$Text, [int]$X, [int]$Y)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.AutoSize = $true
    return $l
}

function New-Textbox {
    param([string]$Text, [int]$X, [int]$Y, [int]$W=360)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Text = $Text
    $t.Location = New-Object System.Drawing.Point($X,$Y)
    $t.Size = New-Object System.Drawing.Size($W, 23)
    return $t
}

$xL = 20
$xT = 170
$y = 20
$dy = 34

$lblApp = New-Label 'AppName' $xL $y; $txtApp = New-Textbox '' $xT $y; $y += $dy
$lblContainer = New-Label 'ContainerName' $xL $y; $txtContainer = New-Textbox 'api' $xT $y; $y += $dy
$lblPort = New-Label 'ContainerPort' $xL $y; $txtPort = New-Textbox '8080' $xT $y; $y += $dy
$lblImage = New-Label 'Image' $xL $y; $txtImage = New-Textbox 'ghcr.io/you/app:latest' $xT $y; $y += $dy
$lblEnv = New-Label 'Env' $xL $y; $txtEnv = New-Textbox 'homelab-dev' $xT $y; $y += $dy
$lblNs = New-Label 'Namespace' $xL $y; $txtNs = New-Textbox 'homelab-dev' $xT $y; $y += $dy
$lblRepo = New-Label 'RepoURL' $xL $y; $txtRepo = New-Textbox 'git@github.com:MarkBenjaminKatamba/homelab-gitops.git' $xT $y; $y += $dy
$lblRev = New-Label 'TargetRevision' $xL $y; $txtRev = New-Textbox 'HEAD' $xT $y; $y += $dy

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Generate'
$btnRun.Location = New-Object System.Drawing.Point(170, $y)
$btnRun.Size = New-Object System.Drawing.Size(120, 30)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Close'
$btnClose.Location = New-Object System.Drawing.Point(310, $y)
$btnClose.Size = New-Object System.Drawing.Size(120, 30)
$y += 40

$output = New-Object System.Windows.Forms.TextBox
$output.Multiline = $true
$output.ScrollBars = 'Vertical'
$output.ReadOnly = $true
$output.Location = New-Object System.Drawing.Point(20, $y)
$output.Size = New-Object System.Drawing.Size(500, 200)

function Append-Out([string]$text) { $output.AppendText($text + [Environment]::NewLine) }

$btnRun.Add_Click({
    $output.Clear()
    if ([string]::IsNullOrWhiteSpace($txtApp.Text)) { Append-Out 'AppName is required.'; return }
    if (-not [int]::TryParse($txtPort.Text, [ref]([int]0))) { Append-Out 'ContainerPort must be an integer.'; return }
    if (-not (Test-Path $scaffoldScript)) { Append-Out "Scaffold script not found: $scaffoldScript"; return }

    function Quote-Arg([string]$s) {
        if ($null -eq $s) { return '""' }
        if ($s -match '[\s\"`]') {
            return '"' + ($s -replace '"', '\"') + '"'
        }
        return $s
    }

    $rawArgs = @(
        '-File', $scaffoldScript,
        '-AppName', $txtApp.Text,
        '-ContainerName', $txtContainer.Text,
        '-ContainerPort', $txtPort.Text,
        '-Image', $txtImage.Text,
        '-Env', $txtEnv.Text,
        '-Namespace', $txtNs.Text,
        '-RepoURL', $txtRepo.Text,
        '-TargetRevision', $txtRev.Text
    )
    $quotedArgs = $rawArgs | ForEach-Object { Quote-Arg $_ }
    $argString = ($quotedArgs -join ' ')

    Append-Out ('Running: pwsh ' + $argString)

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'pwsh'
        $psi.Arguments = $argString
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $stdOut = $p.StandardOutput.ReadToEnd()
        $stdErr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        if ($stdOut) { Append-Out $stdOut }
        if ($stdErr) { Append-Out $stdErr }
        Append-Out ("Exited with code " + $p.ExitCode)
    }
    catch {
        Append-Out ("Error: " + $_.Exception.Message)
    }
})

$btnClose.Add_Click({ $form.Close() })

$form.Controls.AddRange(@(
    $lblApp,$txtApp,
    $lblContainer,$txtContainer,
    $lblPort,$txtPort,
    $lblImage,$txtImage,
    $lblEnv,$txtEnv,
    $lblNs,$txtNs,
    $lblRepo,$txtRepo,
    $lblRev,$txtRev,
    $btnRun,$btnClose,
    $output
))

[void]$form.ShowDialog()


