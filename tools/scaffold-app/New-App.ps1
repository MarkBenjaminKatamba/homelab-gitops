param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$ContainerName,

    [Parameter(Mandatory=$true)]
    [int]$ContainerPort,

    [Parameter(Mandatory=$true)]
    [string]$Image,

    [string]$Env = "homelab-dev",
    [string]$Namespace = "homelab-dev",
    [string]$RepoURL = "git@github.com:MarkBenjaminKatamba/homelab-gitops.git",
    [string]$TargetRevision = "HEAD"
)

$ErrorActionPreference = "Stop"

function Replace-TemplateVars {
    param(
        [string]$Content
    )
    $Content = $Content.Replace("{{APP_NAME}}", $AppName)
    $Content = $Content.Replace("{{CONTAINER_NAME}}", $ContainerName)
    $Content = $Content.Replace("{{CONTAINER_PORT}}", $ContainerPort)
    $Content = $Content.Replace("{{IMAGE}}", $Image)
    $Content = $Content.Replace("{{ENV}}", $Env)
    $Content = $Content.Replace("{{NAMESPACE}}", $Namespace)
    $Content = $Content.Replace("{{REPO_URL}}", $RepoURL)
    $Content = $Content.Replace("{{TARGET_REVISION}}", $TargetRevision)
    return $Content
}

function New-FromTemplate {
    param(
        [string]$TemplatePath,
        [string]$DestinationPath
    )
    $template = Get-Content -Raw -Path $TemplatePath
    $rendered = Replace-TemplateVars -Content $template
    $destDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Set-Content -Path $DestinationPath -Value $rendered -NoNewline
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

# Bases
$baseDir = Join-Path $root "apps\bases\$AppName"
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\base\deployment.yaml.tmpl") -DestinationPath (Join-Path $baseDir "deployment.yaml")
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\base\service.yaml.tmpl") -DestinationPath (Join-Path $baseDir "service.yaml")
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\base\kustomization.yaml.tmpl") -DestinationPath (Join-Path $baseDir "kustomization.yaml")

# Overlays
$overlayDir = Join-Path $root "apps\overlays\$Env\$AppName"
New-Item -ItemType Directory -Path $overlayDir -Force | Out-Null
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\overlay\kustomization.yaml.tmpl") -DestinationPath (Join-Path $overlayDir "kustomization.yaml")
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\overlay\version.yaml.tmpl") -DestinationPath (Join-Path $overlayDir "version.yaml")

# ArgoCD app
$argoDir = Join-Path $root "argocd\apps"
New-Item -ItemType Directory -Path $argoDir -Force | Out-Null
New-FromTemplate -TemplatePath (Join-Path $PSScriptRoot "templates\argo\application.yaml.tmpl") -DestinationPath (Join-Path $argoDir "$AppName.yaml")

Write-Host "Scaffolded app '$AppName' for env '$Env'."


