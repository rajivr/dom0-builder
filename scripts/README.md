# dom0-builder-qemu\_aarch64

## `Dockerfile.image`

You need `qemu-aarch64` binary to be present when using QEMU user-mode
emulation.

```
$ cd dom0-builder-qemu_aarch64/scripts/

$ docker build --force-rm --squash --file Dockerfile.image -t dom0-builder-qemu_aarch64 .
```

## `/vos_run`

Go to the directory containing `ViryaOS` tree.

```
$ docker run --rm --privileged=true -ti -v $(pwd):/home/builder/src -v /tmp:/tmp \
    dom0-builder-qemu_aarch64 /vos_run
```

## `Dockerfile.package`

```
$ cd dom0-builder-qemu_aarch64/scripts/

$ docker build --force-rm --squash --file Dockerfile.package -t dom0-builder-qemu_aarch64-package .
```
