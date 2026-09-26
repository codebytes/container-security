# Runtime upgrade validation

The devcontainer is built and started on a disposable GitHub-hosted Linux runner. The job uses no cloud secrets, persists no checkout credentials, and never accesses a personal or Gateway Docker socket. The Docker-in-Docker feature owns its nested daemon.

The obsolete `enableNonRootDocker` option is removed; the version-4 feature configures the non-root Docker group. CI checks Docker and creates a temporary kind cluster, then removes it.
