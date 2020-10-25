# OpenComputers programs

## Preliminaries

- OpenOS 1.7.5
- OPPM latest version

```
oppm register guillaumearm/oc
```

## How to install on your current OS

```
oppm install -f traptools /
traptools init
```

## How to install on a disk

```
oppm install traptools /mnt/mydisk
```

## Install using a disk

```
install
traptools init
```

## How to use

```
man traptools
```

## Uninstall

```
traptools uninstall
```

## Update traptools

Uninstall then reinstall

## Global utils

TODO 1: write a full documentation for this

TODO 2: write unit tests

```
edit -r /boot/11_global_utils.lua
```

## Daemons

### /etc/rc.d/media

add osx-like `/media` in your filesystem

### /etc/rc.d/redstone-onoff

allow to poweron or halt your computer using a regular redstone signal

## Programs

### wd

wd (for working directory) is a collection of 3 cli programs (wd, setwd and wdlist) to help to navigate between different places.

Usage:

```
cd /home
setwd home

cd /
setwd root

cd /usr/bin
setwd

wdlist

wd home && pwd
wd root && pwd
wd && pwd
wd - && pwd
```

# libui

## Examples

Some demos files are provided with `libui-demo` package.

```
cd /usr/bin/demo
ls
```

## Minimal example (counter)

```
man libui > counter.lua
```

## Documentation

TODO: write a full documentation for libui

Please see exposed global ui utils:

```
edit -r /boot/13_ui_global_utils.lua
```

## Personalize color palette

```
edit /boot/12_color_palette.lua && /boot/12_color_palette.lua
```
