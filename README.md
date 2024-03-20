# Nixpacks Build and Push Action

This GitHub Action utilizes Nixpacks to build your application into a Docker image and then pushes the image to a Docker registry. Nixpacks generates an OCI-compliant container image from your application source without the need for a Dockerfile.

## Features

- **Nixpacks Integration**: Leverages Nixpacks for building OCI-compliant Docker images from application source.
- **Flexible Tagging**: Allows multiple tags to be specified for the built image.
- **Metadata Addition**: Supports adding labels to the Docker image.
- **Platform Specification**: Enables building for specific target platforms.
- **Package Inclusion**: Offers the capability to include additional Nix and Apt packages in the build environment.

## Inputs

- `context`: The build's context, specifying the set of files located at the provided PATH or URL. It is required to point to your application source code.
- `tags`: A comma-separated list of tags to apply to the built image. This field is required.
- `labels`: An optional, comma-separated list of metadata labels to add to the image.
- `platforms`: An optional, comma-separated list of target platforms for the build.
- `pkgs`: Optional additional Nix packages to install in the environment.
- `apt`: Optional additional Apt packages to install in the environment.

## Usage

To use this action in your workflow, add the following step:

```yaml
- uses: your-repo/nixpacks-build-push-action@main
  with:
    context: './path-to-app'
    tags: 'latest,stable'
    labels: 'version=1.0,framework=express'
    platforms: 'linux/amd64,linux/arm64'
    pkgs: 'nodejs,npm'
    apt: 'curl,git'
```

Ensure that your GitHub Actions runner has Docker installed and configured correctly, especially if you're pushing to a private registry.

## Installation and Execution

The action automatically installs Nixpacks if it's not already present in the environment. Then, it constructs and executes a Nixpacks build command using the provided inputs. After the build, it pushes the tagged image(s) to the Docker registry.

### Note:

- The `tags` input is required to identify the image(s) in the registry uniquely.
- If `labels` or `platforms` are specified, they are added to the build command to include in the Docker image.
- Additional Nix or Apt packages can be specified through `pkgs` and `apt` inputs to customize the build environment.

## Conclusion

This GitHub Action simplifies the process of building and deploying containerized applications by leveraging the power of Nixpacks, making it easier to integrate into CI/CD pipelines without the need for Dockerfiles.