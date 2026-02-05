### Scaffold new app manifests

Run from repo root or any path; the script resolves paths automatically.

Example:
```powershell
pwsh ./tools/scaffold-app/New-App.ps1 -AppName my-service -ContainerName api -ContainerPort 8080 -Image ghcr.io/you/my-service:latest -Env homelab-dev -Namespace homelab-dev -RepoURL git@github.com:MarkBenjaminKatamba/homelab-gitops.git -TargetRevision HEAD
```

Generates:
- `apps/bases/<AppName>/{deployment.yaml,service.yaml,kustomization.yaml}`
- `apps/overlays/<Env>/<AppName>/{kustomization.yaml,version.yaml}`
- `argocd/apps/<AppName>.yaml`

Template variables:
- `{{APP_NAME}}`, `{{CONTAINER_NAME}}`, `{{CONTAINER_PORT}}`, `{{IMAGE}}`, `{{ENV}}`, `{{NAMESPACE}}`, `{{REPO_URL}}`, `{{TARGET_REVISION}}`

### GUI option

Run the GUI to fill fields and click Generate:
```powershell
pwsh ./tools/scaffold-app/New-App.GUI.ps1
```
The GUI calls the same `New-App.ps1` under the hood.


