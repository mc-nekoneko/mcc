# MCC PaperMC runtime images

MCC builds deterministic Paper and Velocity runtime images from the PaperMC Fill v3 API. Resolution happens once before a Docker build. The resulting manifest pins the project, version, build, Java runtime image digest, download URL, and SHA-256 checksum.

## Tracks and tags

`config/tracks.json` is the allowlist. Unsupported releases are never accepted unless their exact version and build are listed there.

- `current`: supported production line; may move `current`, `latest`, and the version alias.
- `previous`: prior configured production line; may move `previous` and the version alias.
- `legacy`: exact unsupported version/build pairs; never moves an alias.
- `preview`: explicitly configured prerelease line; may move `preview` and the version alias.
- `custom`: manually requested supported production build; never moves an alias.

Canonical tags include every runtime input, for example `3.5.1-b615-j21-r1`. Compatibility tags such as `3.5.1-615` refer to the same immutable multi-architecture index. Production deployments should pin the OCI digest.

## Local resolution

```bash
scripts/resolve-papermc.sh \
  --project velocity \
  --track current \
  --version 3.5.1 \
  --build 615 > manifest.json
```

The resolver requires an identifying User-Agent, rejects unsupported builds outside the allowlist, rejects non-production channels on production tracks, and fails when Fill returns no builds.
