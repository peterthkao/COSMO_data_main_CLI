# COSMO_data_main_CLI

Converts COSMO CubeSat raw downlink CSVs into **Level 0 science CDF** and **HK CDF**
files from the command line. No script editing — everything is passed as arguments.

## Requirements

| | |
|---|---|
| MATLAB | R2019b or newer (developed and tested on **R2024a**) |
| Toolbox | **Aerospace Toolbox** — required, `create_COSMO_cdf` calls `ecef2lla` |
| CDF library | None. Writing uses MATLAB's built-in `cdflib`. |
| OS | Tested on Windows. Nothing is Windows-specific, but it has not been run on Linux/macOS. |

The script checks for the Aerospace Toolbox on startup and fails with a clear message
if it is missing.

## Contents

```
COSMO_data_main_CLI/
├── COSMO_data_main_CLI.m     entry point
├── toolbox/                  6 dependencies, do not rename or move
│   ├── read_CCSDS.m
│   ├── cosmo_conversion.m
│   ├── read_COSMO_science.m
│   ├── read_COSMO_hk.m
│   ├── create_COSMO_cdf.m
│   └── create_COSMO_hk.m
└── README.md
```

Self-contained: unpack anywhere. The script adds its own `toolbox/` to the MATLAB path
at runtime, so no `pathdef` or startup changes are needed.

## Input layout

`dataPath` is the folder that **contains** the downlink folders — not a downlink folder
itself:

```
<dataPath>/
├── COSMO_20260801T033702/
│   └── COSMO_raw_..._APID_519.csv
└── COSMO_20260801T072755/
    ├── COSMO_raw_..._APID_1625.csv
    └── COSMO_raw_..._APID_520.csv
```

Downlink folders must be named `COSMO_YYYYMMDDTHHMMSS`. Within a folder, each CSV is
matched by its APID suffix (`*1625.csv`, `*520.csv`, `*519.csv`), so the rest of the
filename does not matter. At most one CSV per APID per folder.

## Quick start

Start with a dry run — it resolves and prints which folders would be processed, and
writes nothing:

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','dryRun',true)"
```

Then convert the newest downlink:

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV')"
```

Run it from inside the package folder, or `cd` there first:

```bash
matlab -batch "cd('C:\path\to\COSMO_data_main_CLI'); COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV')"
```

### Common variations

One specific downlink:

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','folder','COSMO_20260801T033702')"
```

Every downlink (slow — Level 0 files run ~100–250 MB each for a full pass):

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','folder','COSMO*')"
```

HK only, skipping the large Level 0 files:

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','makeL0Cdf',false)"
```

Custom output locations:

```bash
matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','level0Path','E:\out\L0','hkPath','E:\out\HK')"
```

## Options

| Name | Default | Meaning |
|---|---|---|
| `dataPath` | **required** | Folder containing the `COSMO_*` downlink folders |
| `folder` | newest downlink | Folder name or pattern, e.g. `COSMO*` |
| `level0Path` | `<package>\output\Level 0` | Level 0 output; created if missing |
| `hkPath` | `<package>\output\HK` | HK output; created if missing |
| `toolboxPath` | `<package>\toolbox` | Normally leave alone |
| `makeL0Cdf` | `true` | Write the Level 0 CDF |
| `makeHK` | `true` | Write the HK CDF |
| `dryRun` | `false` | List target folders, write nothing |

With no `folder`, the newest downlink is chosen by the **timestamp in the folder name**,
not the folder's modification time — cloud sync rewrites mtimes out of order, so they
are not trustworthy.

## Output

Files are named from the **data time span**, not the downlink folder name:

```
UCB_TEST_S1_L0_<start>_<end>_0001.cdf     in level0Path
HK_<start>_<end>_0001.cdf                 in hkPath
```

Re-runs are safe: an existing file with the same name is deleted and rewritten.

## Partial downlinks

A contact does not always carry all three packets, and the two products need different
subsets:

- **Level 0** ← APID 1625 (science) and/or 520 (position/velocity)
- **HK** ← APID 519 (payload) and/or 520 (XACT)

Whatever is available gets written. A missing family becomes **zero-record variables**,
so the file keeps its full variable layout (40 for Level 0, 149 for HK) with no
fabricated values — several variables are `CDF_UINT1` and cannot represent NaN, so a
placeholder would be indistinguishable from a real "invalid/disabled" reading. Reading
one of those variables back returns an empty array.

A folder with none of the three APIDs is skipped.

> **Caveat:** a Level 0 file written without APID 520 has no `GPS_Time`. The Level 1
> stage requires both `GPS_Time` and `Scalar_Time`, so such a file will not contribute
> to Level 1 — it is for direct reading only. The script prints a `NOTE:` when this
> happens.

## Exit codes

`0` if every matched folder produced at least one file; `1` if any folder was skipped or
failed. Useful for scripting.

A run over a **mix** of folders where some are expected to be skipped will report `1`.
To inspect the status without the process erroring, capture the return value:

```matlab
s = COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','folder','COSMO*');
```

## Reading the output

Use MATLAB's built-in reader:

```matlab
info = cdfinfo(file);
d = cdfread(file,'Variables','pld_sc_mag_state','ConvertEpochToDatenum',true,'CombineRecords',true);
```

`info.Variables(:,3)` gives the record count per variable — `0` marks an absent family.

## Expected, harmless warnings

Both appear on normal successful runs:

- `Column headers from the file were modified to make them valid MATLAB identifiers` — from `readtable`.
- `The following error was caught while executing 'onCleanup' class destructor: ... The CDF file ID argument is invalid` — a double-close after the file was already closed cleanly. The CDF is complete and valid.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `dataPath is required` | Pass `dataPath` — see Quick start |
| `The Aerospace Toolbox is required` | Install/license the Aerospace Toolbox |
| `No downlink folder matches "X*"` | Check the pattern and that `dataPath` is the parent folder |
| `Raw CSV path does not exist` | Bad `dataPath` |
| `expected at most one CSV per APID` | Two CSVs for the same APID in one folder — remove the duplicate |
| `Not enough input arguments` in `read_CCSDS` | A `folder` value that resolves to a folder's *contents*. The script appends `*` automatically, so this should not occur — report it if it does. |

## Scope

Level 0 and HK only. Level 1, HK daily, and Level 2 are produced by `COSMO_data_main.m`
and are not part of this package.
