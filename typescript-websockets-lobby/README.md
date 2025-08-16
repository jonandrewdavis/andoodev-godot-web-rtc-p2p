# typescript-websockets-lobby

This is a Typescript websockets server. It handles lobby creation and allows peers to exchange packets to create WebRTC P2P connections.

It is built and hosted on a Cloudflare worker.

### Running locally

Pre-requisite: [install yarn via corepack](https://yarnpkg.com/getting-started/install)

```
yarn set version 4.5
```

```
yarn
```

```
yarn start
```

### Secrets

Create a file called `.dev.vars` and paste the secret key. This file is not committed.

```
SECRET_KEY="____YOUR_RANDOM_SECRET_KEY____"
```

### How to set up in Cloudflare

- Fork this project
- Log in to Cloudflare
- Go to Compute (Workers)
- Select: "Import a repository"
- Select the repository in GitHub (connect if needed)
- Name the project: `typescript-websockets-lobby`
- Open Advanced settings
- Update root directory path to: `typescript-websockets-lobby/`
- Open Build Variables
  - Variable name: `SECRET_KEY`
  - Value: Copy from `.dev.vars` above
  - Encrypt

TODO: Do we need a build command?
Note: Do not change the watch path, the root should be where the worker is located.

### Troubleshooting

If you get this when building:

```
Installing project dependencies: yarn
12:03:32.773	➤ YN0000: · Yarn 4.5.0

➤ YN0028: │ The lockfile would have been modified by this install, which is explicitly forbidden.
```

Solution: try: `yarn set version 4.5`
