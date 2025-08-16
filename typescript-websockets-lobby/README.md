# typescript-websockets-lobby

This is a Typescript websockets server. It handles lobby creation and allows peers to exchange packets to create WebRTC P2P connections.

It is built and hosted on a Cloudflare worker.

### Running locally

Pre-requisite: [install yarn via corepack](https://yarnpkg.com/getting-started/install)

```
yarn
```

```
yarn start
```

### Secrets

Create a `dev.vars` and paste the secret key. This file is not committed.
