# normalize-filenames

Remove duplicate files caused by NFD (macOS) vs NFC (Windows) Unicode encoding conflicts.

清理因 macOS (NFD) 与 Windows (NFC) 编码差异导致的重复文件。

## Problem / 问题

macOS filesystems (APFS/HFS+) normalize filenames to **NFD** (decomposed form, e.g. `ガ` = `カ` + `゙`), while Windows uses **NFC** (composed form, e.g. `ガ`). When the same file is copied from a Mac and later re-imported from a Windows source, two "identical-looking" files appear — but they are byte-different duplicates.

macOS 文件系统强制使用 **NFD**（分解形式，如 `ガ` = `カ` + `゙`），Windows 使用 **NFC**（合成形式，如 `ガ`）。同一文件从 Mac 拷入后再从 Windows 源导入，就会产生"看起来一样、实际上不同"的重复文件。

| Encoding | Example | Platform |
|----------|---------|----------|
| **NFD** | ガ = U+30AB + U+3099 | macOS |
| **NFC** | ガ = U+30AC | Windows |

## Usage / 使用方法

```powershell
# Preview only (no files deleted) / 预览（不删除）
.\normalize-filenames.ps1 "D:\downloads"

# Execute deletion (keep NFC, delete NFD) / 执行（保留 NFC）
.\normalize-filenames.ps1 "D:\downloads" -Delete

# Or keep NFD instead / 或保留 NFD
.\normalize-filenames.ps1 "D:\downloads" -Delete -KeepNfd
```

**No runtime required** — PowerShell is built into every modern Windows.

**无需安装任何运行时**——PowerShell 是 Windows 自带功能。

> If PowerShell execution policy blocks scripts, use:
> ```
> powershell -ExecutionPolicy Bypass -File ".\normalize-filenames.ps1" "D:\downloads"
> ```

## Example / 示例

```
=== Unicode encoding analysis ===
Directory:  G:\telegram\30\audio\se
Total:      188
NFD (macOS): 25
NFC (Win):   25
Normal:     138

=== Duplicates (keep NFC, delete NFD) ===
Pairs:    25
To free:  2069.1 KB

  DELETE: スタジアムファンファーレ13.ogg
  KEEP:   スタジアムファンファーレ13.ogg
  SIZE:   100 KB
  ...
```

## Features / 特性

- **Dry-run first** — preview what will be deleted before committing
- **Safe matching** — verifies content is identical (binary comparison) before pairing
- **Bidirectional** — keep NFC (default) or NFD via `-KeepNfd`
- **No dependencies** — pure PowerShell, portable on any Windows machine

---

MIT License
