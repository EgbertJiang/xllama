# Windows UWP Development VM

The supported build uses a Windows VM or the existing `build-uwp` GitHub Actions
workflow pinned to `windows-2022`. An experimental Linux cross-build was also
installed and exercised on a physical Xbox One S; it uses clang-cl, the Windows
SDK/CRT, native cppwinrt, and separately signed MSIX packaging rather than Windows
containers.

## Experimental Xbox One CPU compatibility

The published Release package targets Series S/X with AVX2. A local Xbox One S
startup dump showed exception `0xC000001D` at `xllama.exe + 0x19262D`, on a BMI2
`SHLX` instruction, before the app log was created. `GET /ext/xbox/info` identified
the device as Xbox One S. Reinstalling dependencies or changing App to Game does
not remove this CPU requirement.

`-CpuTarget Baseline` removes the AVX2 target from both the app and ggml.
The experimental `AVX` target enables AVX1 kernels; the default remains AVX2.
AMD documents Jaguar AVX support in its [GDC optimization guide](https://gpuopen.com/gdc-presentations/2023/GDC-2023-AMD-Ryzen-Processor-Software-Optimization.pdf).
The Linux AVX cross-build runs the tested 350M, 0.8B, 1.2B, Gemma 4 E2B and
Gemma 4 E4B quantized models on the physical One S. Windows MSBuild and other
hardware remain unverified.

```powershell
./scripts/build-uwp.ps1 -Backend unified -CpuTarget AVX -PatchedGenAI -PatchedOrt -BuildRevision 1052
```

Use a revision higher than the installed one. Follow the normal NuGet, vendor
DLL, submodule and signing setup below before building. After every package
update, verify **Dev Home → xllama → View details → App type → Game**. On the
tested One S, updating reset the new package to App; E2B then failed its
2,602,847,328-byte weight-buffer allocation. Selecting Game allowed it to load.

Real-console checks include Chinese completions and a simple arithmetic prompt
on all five models. At 6 threads and context 512, E2B Q3_K_S decoded at 3.99 tok/s
(median of three capped-64-token runs); E4B IQ2_M decoded at 1.71 tok/s in one
32-token run, peaking at 3822 MiB. These short checks are not a quality evaluation
or a long-context performance claim. Raw benchmark CSV host labels are legacy
hardcoded Series S; the run metadata identifies the actual One S.

The shipped DirectML text path loaded 793 MiB into a reported 3916 MiB GPU
budget but failed first prefill. `887A0005` means device removed; the exact ORT
1.24.4 source identifies the failing call as `CompileGraph`, not a measured
shader-dispatch hang. GenAI commit `a30f479` forces DML graph capture in two
places, so a session `disable_graph_fusion` entry alone does not isolate fusion.
An independently cross-built diagnostic GenAI DLL disables both capture paths;
it loads on this One S but has not enabled full-model GPU generation.

Plain ORT probes with CPU fallback disabled and provider profiling verified GPU
FP16 Add on DirectML 1.15.4. Isolated DirectML 1.8.2 and 1.12.1 substitutions also
passed FP32 Add. MatMul still failed; an actual FP16 MatMul dump showed
`0xC0000005` in `sc_dll.dll + 0x3157d7` (version 2020.10118.11900.10000), a null-base
read rather than an AVX2/BMI2 illegal instruction. Replacing matrix multiplication
with broadcast Mul and ReduceSum produced correct GPU results at 32 and 128
square dimensions. These operator probes do not establish language-model
correctness or throughput. Older DLL substitutions are compatibility experiments,
not supported ORT/GenAI version combinations.

The native probe reported Shader Model 5.1 and rejected three independently
compiled cs_6_0 DXIL blobs at pipeline creation with `0x80004005`. FXC cs_5_1
DXBC executed. Initial checksums localized a discrepancy to the last output
DWORD; adding unused physical buffer tail space and extending probe views fixed
the tested cases. Validated native STREAM results were 33.99 GB/s at 64 MiB and
39.85 GB/s at 1 GiB. The precise driver cause remains undetermined.

A native GGUF D3D12 compatibility port now runs real LFM models on this One S.
See [One S GPU evidence and configuration](gguf-gpu-decode.md). This bypasses the
failing DirectML text path; it does not establish that DirectML is fixed.

## One S developer storage and chat models

On the tested One S, increasing Dev Home storage from 5 to 29 GB expanded
`D:\DevelopmentFiles` (about 31 GB free) but did not enlarge the existing
`U:` application-data volume. A GGUF read and generation from the expanded
partition succeeded. Dev builds can now select this chat/embedding model root
by uploading `models-root.txt` to LocalState and restarting the app:

```text
D:\DevelopmentFiles\XllamaModels
```

Place each model in a catalogue-named subdirectory. The directory must already
be accessible to the app. Relative or malformed roots are rejected with a log
message and use the default. Existing LocalState models remain readable, and
API model discovery includes both roots. Downloads and USB imports continue to
use the application-owned LocalState directory: on this One S the WinRT download
API could not create files in DevelopmentFiles, although native model reads there
succeeded. Provision the expanded root through Device Portal. Removing the file restores the default
on the next process start. Store builds ignore this override. Image-generation
storage is unchanged and was not exercised by these chat tests.

## Host preflight

On the Arch host:

```bash
./scripts/check-uwp-host.sh
```

Expected host tools:

- Docker can stay Linux-only; it is useful for other work, not UWP packaging.
- QEMU/libvirt provide the Windows VM runtime.
- The user should be in `kvm` and `libvirt`.
- Start libvirt before creating or running the VM:

```bash
sudo systemctl enable --now libvirtd
```

Use at least 8 GB RAM and 70 GB disk for the Windows VM. More disk is better
because Visual Studio, Windows SDKs, and package artifacts are large.

## VM setup

Use either a Microsoft Windows developer VM, if downloads are available, or a
regular Windows 11 x64 ISO/evaluation install. The Microsoft developer VM is
preferred when available because it already includes Visual Studio 2022 with
UWP workloads, but Microsoft may temporarily disable those downloads.

For a manual Windows 11 VM:

1. Create a VM with `virt-manager` or `virt-install`.
2. Enable Developer Mode in Windows settings.
3. Install Git for Windows and PowerShell.
4. Open an elevated PowerShell prompt.
5. Clone this repository with submodules.
6. Run the Windows UWP setup check:

```powershell
.\scripts\setup-windows-uwp-dev.ps1 -Install
```

If Visual Studio is already installed, omit `-Install` to verify only:

```powershell
.\scripts\setup-windows-uwp-dev.ps1
```

The check must find:

- Visual Studio 2022 Build Tools or Community
- MSBuild
- Windows SDK tools: `MakeAppx.exe` and `signtool.exe`
- `nuget.exe`

## Build

Inside the Windows VM:

```powershell
git submodule update --init --recursive
.\scripts\build-uwp.ps1 -Configuration Release -Platform x64
```

The build script:

1. Restores NuGet packages (`nuget restore`).
2. Builds with MSBuild (`-Backend unified` matches the shipping artifact;
   `llamacpp` is the bench-only lane and the script default is an ORT-only local build).
3. Signs the package with the test certificate.

No model is packaged: distribution artifacts are prepared separately and must be self-contained (`scripts/merge_onnx_external_data.py`, `docs/uwp-constraints.md §8`).

The package output is under:

```text
uwp\AppPackages\
```

The final artifact set must include:

- the main `.msix`
- dependency `.appx` files from `Dependencies\x64`
- `uwp\xllama-test.cer`

## Deploy and diagnose

From the Linux host, after copying the artifacts back:

```bash
source ~/.config/xllama/xbox-env
./scripts/deploy.sh path/to/xllama_*.msix
./scripts/deploy.sh diagnose-startup
```

The startup log should show:

```text
[xllama] App::App()
[xllama] App::App() complete
[xllama] App::OnLaunched
[xllama] building MainPageController
[xllama] MainPageController built
[xllama] MainPageController init done
[xllama] Window.Content set
[xllama] Window activated
```

If the app crashes before printing any log entry, collect a minidump via WDP:

```bash
curl --basic -u "${XBOX_USER}:${XBOX_PASS}" -k -sS \
     "https://${XBOX_IP}:11443/api/debug/dump/usermode/dumps"
```

Use `./scripts/deploy.sh diagnose-startup` for process state, logs and minidumps;
Device Portal details are in `docs/device-portal.md`.
