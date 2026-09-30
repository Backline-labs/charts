# Backline Helm charts

## Chart version bumps

Whenever `version` or `appVersion` changes in `charts/<chart>/Chart.yaml`, update `charts/<chart>/README.md` in the same change:

- Set the `**Chart Version:**` and `**App Version:**` lines to match `Chart.yaml`.
- Update the parameter tables for every value added, removed or changed.
- If the release removes or renames values, or changes behaviour on upgrade, add an `### Upgrading to <version>` section under `## Upgrading`.
