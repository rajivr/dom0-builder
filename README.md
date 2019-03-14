# dom0-builder

## `Dockerfile.image`

```
$ cd dom0-builder/

$ docker build --force-rm --squash --file Dockerfile.image -t dom0-builder .
```

## `/vos_run`

Go to the directory containing `ViryaOS` tree.

```
$ docker run --rm --privileged=true -ti -v $(pwd):/home/builder/src -v /tmp:/tmp \
    dom0-builder /vos_run
```

## `Dockerfile.package`

```
$ cd dom0-builder/

$ docker build --force-rm --file Dockerfile.package -t dom0-builder-package .
```
