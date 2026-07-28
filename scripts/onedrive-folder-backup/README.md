# OneDrive folder backup (scheduled robocopy)

Copies specific local folders into matching folders under your OneDrive sync directory on a schedule. The OneDrive app then keeps the cloud copy up to date.

## Setup (once)

1. Copy this folder somewhere permanent on the Windows PC, e.g.  
   `C:\Tools\onedrive-folder-backup\`
2. Edit `folders.json`:
   - Set `source` to the local folder
   - Set `dest` to a path **relative to OneDrive** (or an absolute path under OneDrive)
   - Set `"enabled": true` for each folder you want
3. Optional: set `oneDriveRoot` if auto-detect picks the wrong account (`OneDrive` vs `OneDrive - Company`).
4. Test once:

```powershell
cd C:\Tools\onedrive-folder-backup
powershell -ExecutionPolicy Bypass -File .\Backup-FoldersToOneDrive.ps1
```

5. Install the hourly scheduled task:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-BackupTask.ps1
```

Every 30 minutes instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-BackupTask.ps1 -IntervalMinutes 30
```

## Config example

```json
{
  "oneDriveRoot": "",
  "defaults": {
    "mirror": false,
    "excludeDirs": [".git", "node_modules", ".vs", "__pycache__"],
    "excludeFiles": ["Thumbs.db", "desktop.ini", "~$*", "*.tmp"]
  },
  "folders": [
    {
      "name": "Projects",
      "source": "D:\\Projects",
      "dest": "Backups\\Projects",
      "enabled": true
    },
    {
      "name": "FieldCAD",
      "source": "D:\\CAD\\Active",
      "dest": "Backups\\CAD\\Active",
      "enabled": true,
      "mirror": true
    }
  ]
}
```

| Field | Meaning |
|-------|---------|
| `mirror: false` (default) | Add/update files on OneDrive; **do not delete** extras on the destination |
| `mirror: true` | Exact mirror — files removed locally are removed from the OneDrive backup folder |
| `dest` | Relative to OneDrive root unless it is an absolute path |

## Logs

Written under `logs\backup-YYYYMMDD.log` next to the scripts.

## Uninstall task

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-BackupTask.ps1 -Uninstall
```

## Notes

- Destination must stay inside the OneDrive sync folder so the OneDrive client can upload.
- Keep OneDrive signed in and running; the task runs only while you are logged on.
- First run of a large folder can take a while; later runs are incremental (`/XO`).
- This is not point-in-time versioning beyond what OneDrive version history already provides.
