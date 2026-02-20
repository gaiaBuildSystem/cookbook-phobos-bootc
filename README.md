# Cookbook for PhobOS using Bootable Containers (bootc)

<p align="center">
    <img
        src=".assets/cover.png"
        alt="Logo"
        width="800" />
</p>

This cookbook provides a collection of recipes to help you get started with PhobOS using Bootable Containers (bootc).

## Supported Boards -> Machine

> ⚠️ As this grows we could change the machine name to a more generic name.

> ⚠️ x86 32bit is not supported.

| Board              | Gaia Machine Name   |
|--------------------|---------------------|
| x86-64 Intel/amd64 | intel               |

## Prerequisites

- [Gaia project Gaia Core](https://github.com/gaiaBuildSystem/gaia);

## Build an Image

```bash
./gaia/scripts/bitcook/gaia.ts --buildPath /home/user/workdir --distro ./cookbook-phobos-bootc/distro-phobos-bootc-qemux86-64.json
```

This will build PhobOS for Intel x86-64 Platform using Bootable Containers (bootc).
