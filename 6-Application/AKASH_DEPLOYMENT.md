# TierPulse Akash Deployment

This repository now includes Akash deployment assets for the Shiny app in `6-Application`.

## 1) Build and publish container image

From repository root:

```bash
docker build -f 6-Application/Dockerfile -t ghcr.io/toxmon/tier_pulse:akash-v1 .
docker push ghcr.io/toxmon/tier_pulse:akash-v1
```

> Use explicit tags (no `latest`) to keep deployments reproducible.

## 2) Configure SDL

Edit `6-Application/akash.sdl.yaml` and set:

- `image` to your published image tag
- `POSTGRES_*` variables to your production database settings
- pricing (`amount`) as needed for your budget/region

## 3) Deploy with Akash CLI

```bash
provider-services tx deployment create 6-Application/akash.sdl.yaml \
  --from <wallet> \
  --node https://rpc.akashnet.net:443 \
  --chain-id akashnet-2 \
  --gas auto --gas-adjustment 1.3 --fees 5000uakt
```

Then choose a provider bid and create a lease:

```bash
provider-services query market bid list --owner <your-wallet-address> --state open
provider-services tx market lease create \
  --dseq <dseq> --gseq 1 --oseq 1 --provider <provider-address> \
  --from <wallet> --node https://rpc.akashnet.net:443 --chain-id akashnet-2 \
  --gas auto --gas-adjustment 1.3 --fees 5000uakt
```

Send the manifest:

```bash
provider-services send-manifest 6-Application/akash.sdl.yaml \
  --dseq <dseq> --oseq 1 --gseq 1 --from <wallet> --provider <provider-address>
```

## 4) Verify app endpoint

After lease is active, fetch the forwarded URL from provider status and open the app.
The container binds to `0.0.0.0:8888` as required by `app.R`.
