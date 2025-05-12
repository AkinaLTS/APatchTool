![socialify](https://socialify.git.ci/AkinaAcct/APatchTool/image?description=1&forks=1&issues=1&name=1&owner=1&pulls=1&stargazers=1&theme=Dark)

# APatchTool

## What is this

A script automating the process of patching the kernel with [KernelPatch](https://github.com/bmax121/KernelPatch), and supports the following features:

- User-specified image path or get from current Android device.  
- User-specified KernelPatch version. Or default, latest release.  
- User-specified SuperKey. [What is SuperKey?](https://apatch.dev/faq.html#what-is-superkey)
- Supports directly install.
- Supports OTA updates.
- Supports embedding KPMs.

## Usage

### Android

- Open Termux

- Prepare

```sh
cd ${HOME}
curl -LO https://raw.githubusercontent.com/AkinaAcct/APatchAutoPatchTool/main/AAP.sh
chmod +x AAP.sh
```

- Run

Usage:

```sh
./AAP.sh -h
```

### Linux

> [!NOTE]
> This should work. If you encounter any problems, please submit an issue with logs provided by debug mode.

- Just like in Termux:

```sh
cd ${HOME}
curl -LO https://raw.githubusercontent.com/AkinaAcct/APatchAutoPatchTool/main/AAP.sh
chmod +x AAP.sh
```

- Run

Usage:

```sh
./AAP.sh -h
```

## Reporting Bugs

If you have issues or need feedback, please run `AAP.sh` in debug mode. To enable debug mode, run:

```sh
APTOOLDEBUG=1 ./AAP.sh [ARGS] | tee AAP_Log_$(date +"%Y-%m-%d_%H:%M:%S").txt
```

Logs will be stored in AAP_Log_\[date]_\[time].txt  
Create an issue on github, and upload it as the log.

---

If you encounter any issues, please submit an issue on github.

---

## Credits

- [Magisk](https://github.com/topjohnwu/magisk): For magiskboot

- [KernelPatch](https://github.com/bmax121/KernelPatch): For kptools and kpimg
