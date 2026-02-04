Here’s a concise, email-ready explanation you can paste and tweak as needed.

---

### Overview

This repository (`homelab-gitops`) is the GitOps control plane for my homelab Kubernetes cluster.  
Instead of manually applying YAML files with `kubectl`, I declare the desired state of all my apps in this repo, and Argo CD continuously syncs the cluster to match whatever is in `master`. That means changes are made with Git commits, not ad‑hoc commands, giving me versioning, history, and easy rollbacks.

The repo manages several apps (for example: `dockerfile-generator-frontend`, `dockerfile-generator-backend`, `taskflow-*`, `akalimu`, `sukuulu`) and also includes a small scaffolding tool that automatically generates all the YAML needed when I add a new app.

---

### How Argo CD connects to this repo

Inside the `argocd` folder there is a root Argo CD `Application` called `apps-root`:

- **`argocd/apps-root.yaml`** tells Argo CD:
  - Which repo to watch: `git@github.com:MarkBenjaminKatamba/homelab-gitops.git`
  - Which path in the repo defines applications: `argocd/apps`
  - To automatically sync (`automated`) and self-heal/prune resources in the cluster.

When `apps-root` is created in the Argo CD namespace, Argo CD recursively discovers and manages all the child `Application` objects defined in `argocd/apps/*.yaml`. Each of those children corresponds to one logical app in my homelab (e.g. `dockerfile-generator-frontend.yaml`).

So the flow is:

1. Argo CD watches this Git repo.
2. `apps-root` points Argo CD at the `argocd/apps` directory.
3. Each file in `argocd/apps` is an Argo CD `Application` that points to the real Kubernetes manifests for one app.

---

### Per‑application structure (bases and overlays)

Every app has the same general structure:

- **Base manifests** under `apps/bases/<app-name>/`
  - `deployment.yaml` – the core `Deployment` (image, container name, ports, resources, labels, etc.)
  - `service.yaml` – a `Service` exposing the app inside the cluster.
  - `kustomization.yaml` – a Kustomize file that ties the base resources together.

- **Environment overlays** under `apps/overlays/<environment>/<app-name>/`
  - For example: `apps/overlays/homelab-dev/dockerfile-generator-frontend/`.
  - Each overlay:
    - References the base with Kustomize.
    - Adds environment‑specific tweaks (e.g. name suffix `-dev`, different labels, replica count).
    - Optionally includes a `version.yaml` patch to override the container image tag (for rolling out specific versions or commit hashes).

- **Argo CD application definition** under `argocd/apps/<app-name>.yaml`
  - Points Argo CD to the overlay path.
  - Specifies the target namespace and cluster.
  - Enables automated sync and namespace creation.

Concretely, for `dockerfile-generator-frontend`:

- **Base** (`apps/bases/dockerfile-generator-frontend`):
  - A `Deployment` running `ghcr.io/markbenjaminkatamba/dockerfile-generator-frontend-dev:latest` on port 3000.
  - A `Service` that exposes port 80 and targets container port 3000.
  - A `kustomization.yaml` that includes both `deployment.yaml` and `service.yaml`.

- **Overlay** (`apps/overlays/homelab-dev/dockerfile-generator-frontend`):
  - Adds `nameSuffix: -dev` so the actual runtime resources are named `dockerfile-generator-frontend-dev`.
  - Uses Kustomize patches to:
    - Adjust labels and selectors for `Deployment` and `Service` to match the `-dev` naming.
    - Include `version.yaml`, which can override the exact container image tag (e.g. to a specific commit-based tag).

- **Argo CD application** (`argocd/apps/dockerfile-generator-frontend.yaml`):
  - `source.repoURL` points back to this Git repo.
  - `source.path` is `apps/overlays/homelab-dev/dockerfile-generator-frontend`.
  - `destination.namespace` is `homelab-dev`.
  - Sync policy is automated with `prune` and `selfHeal`, plus `CreateNamespace=true`.

This pattern is repeated for all apps, which keeps the repo consistent and easy to reason about.

---

### How changes are deployed (GitOps workflow)

Because everything is Git‑driven, my deploy process is:

1. **Edit manifests** in this repo (for example, update the image tag in a `version.yaml` or adjust resources in a base `deployment.yaml`).
2. **Commit and push** to the `master` branch on GitHub.
3. **Argo CD detects the change**:
   - Pulls the latest commit from GitHub.
   - Renders the corresponding Kustomize overlay.
   - Applies changes to the cluster.
4. If anything goes wrong, I can quickly **revert** by checking out an older commit and pushing again; Argo CD then rolls the cluster back to that previous desired state.

This gives me:

- A single source of truth for cluster configuration.
- Full history and code review for infra changes.
- Automated reconciliation (self-heal) if someone accidentally changes things directly in the cluster.

---

### Scaffolding tool: quickly adding new apps

To avoid manually creating multiple YAML files every time I add an app, the repo includes a small **scaffolding tool** under `tools/scaffold-app`.

It consists of:

- `New-App.ps1` – a PowerShell script that generates:
  - `apps/bases/<AppName>/{deployment.yaml,service.yaml,kustomization.yaml}`
  - `apps/overlays/<Env>/<AppName>/{kustomization.yaml,version.yaml}`
  - `argocd/apps/<AppName>.yaml`
- `New-App.GUI.ps1` – a simple GUI wrapper around the same script.
- Template files under `tools/scaffold-app/templates`:
  - `templates/base/*` for base Deployment/Service/Kustomization.
  - `templates/overlay/*` for environment overlays and version file.
  - `templates/argo/application.yaml.tmpl` for the Argo CD `Application`.

You run it like this (from the repo root):

```powershell
pwsh ./tools/scaffold-app/New-App.ps1 `
  -AppName my-service `
  -ContainerName api `
  -ContainerPort 8080 `
  -Image ghcr.io/you/my-service:latest `
  -Env homelab-dev `
  -Namespace homelab-dev `
  -RepoURL git@github.com:MarkBenjaminKatamba/homelab-gitops.git `
  -TargetRevision HEAD
```

Or, if you prefer a UI:

```powershell
pwsh ./tools/scaffold-app/New-App.GUI.ps1
```

The GUI lets you fill in those fields and then calls `New-App.ps1` behind the scenes.

The script then:

- Copies and fills in the templates, substituting values like:
  - `{{APP_NAME}}`, `{{CONTAINER_NAME}}`, `{{CONTAINER_PORT}}`,
  - `{{IMAGE}}`, `{{ENV}}`, `{{NAMESPACE}}`, `{{REPO_URL}}`, `{{TARGET_REVISION}}`.
- Lays out the files in the correct directory structure.
- Produces a ready‑to‑sync Argo CD `Application` for the new app.

After that, I just commit and push, and Argo CD will start managing the new application automatically.

---

### Why this setup is useful in my homelab

- **Consistency**: Every app follows the same base/overlay pattern and Argo CD setup.
- **Safety**: All changes are version‑controlled and can be rolled back via Git.
- **Automation**: Argo CD continuously keeps the cluster in sync with the repo.
- **Speed**: The scaffolding tool makes it trivial to onboard new services with correct manifests, without copy‑paste errors.

In short, this repository is the declarative, Git‑backed source of truth for the applications running in my homelab Kubernetes cluster, with Argo CD enforcing that state and a small scaffold tool to make adding new apps fast and repeatable.
