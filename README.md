# Backline AI Helm Charts

This GitHub repository is the official source for Backline AI Helm charts.

## About Helm

Helm is the package manager for Kubernetes. For more information about Helm and how to use charts, visit the [official Helm documentation](https://helm.sh/docs/).

## Contributing

All pull requests must be approved by code owners before merging.

### Pull Request Requirements

- **Title**: Must include type and scope according to [Conventional Commits](https://www.conventionalcommits.org/) recommendations
- **Chart Version**: Must be bumped appropriately. The *README Version Sync* workflow copies `version` / `appVersion` into the chart's `README.md` on the pull request. A release that removes values or changes upgrade behaviour also gets an `Upgrading to <version>` note there
- **Documentation**: All variables must be documented in `README.md` of the changed chart
- **Tests**: `helm lint` and the chart's unit tests must pass; add or update tests under `charts/<chart>/tests/` for changed behaviour

### Running the tests

Unit tests use the [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin and need no cluster. CI runs them on every pull request.

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest.git --version v1.1.2
helm dependency build charts/backline
helm lint charts/backline --set accessKey=test
helm unittest charts/backline --with-subchart=false
```

