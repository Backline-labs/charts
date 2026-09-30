# Backline AI Helm Charts

This GitHub repository is the official source for Backline AI Helm charts.

## About Helm

Helm is the package manager for Kubernetes. For more information about Helm and how to use charts, visit the [official Helm documentation](https://helm.sh/docs/).

## Contributing

All pull requests must be approved by code owners before merging.

### Pull Request Requirements

- **Title**: Must include type and scope according to [Conventional Commits](https://www.conventionalcommits.org/) recommendations
- **Chart Version**: Must be bumped appropriately, together with the `Chart Version` / `App Version` lines in the chart's `README.md`. A release that removes values or changes upgrade behaviour also gets an `Upgrading to <version>` note there
- **Documentation**: All variables must be documented in `README.md` of the changed chart

