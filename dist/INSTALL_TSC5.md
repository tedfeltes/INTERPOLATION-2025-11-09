# How to install StakeDXF on a Trimble TSC5

The file you need is:

```text
dist/StakeDXF-tsc5.apk
```

That is an **Android installer**. It goes on the **TSC5 only** (not the iPhone).

## Fast path (OneDrive)

1. Put `StakeDXF-tsc5.apk` in your OneDrive (from a computer, or download the release/PR artifact).
2. On the **TSC5**, open the **OneDrive** app and download the APK to the device.
3. Open the **Files** app (or Downloads).
4. Tap `StakeDXF-tsc5.apk`.
5. If Android blocks it, tap **Settings** on the prompt and turn on:
   - **Allow from this source** for **Files** (or OneDrive / Chrome — whichever app you used to open the APK).
6. Go back and tap **Install**.
7. Open the **StakeDXF** app from the app drawer.

## Alternate path (USB cable)

1. On a Windows PC, copy `StakeDXF-tsc5.apk` somewhere easy to find.
2. Unlock the TSC5 and connect USB-C.
3. On the TSC5 notification, choose **File Transfer** (not Charge only).
4. From Windows File Explorer, copy the APK into the TSC5 **Download** folder.
5. On the TSC5, open **Files** → **Downloads** → tap the APK → **Install**
   (enable **Allow from this source** for Files if prompted).

## If Install is greyed out / “not allowed”

Your TSC5 may be under a company Google/MDM policy that blocks unknown APKs. Trimble documents this for Installation Manager too:

> Devices with a company-managed Google account may block APK installs unless IT enables **Load From Unknown Sources**.

Ask IT to allow unknown-source installs for your controller, or to push the APK through your managed app store.

## After it installs — convert a DWG

1. Open **StakeDXF**
2. Tap **Choose DWG / DXF**
3. Browse to the drawing (OneDrive / Files)
4. Tap **Convert for Trimble Access**
5. Tap **Share / Save DXF**
6. Save/copy into:

```text
Trimble Data/Projects/<your project>/
```

7. In Trimble Access: Map → Layer manager → **Map files** → tap the DXF twice (selectable) → Stakeout

## Common mistakes

| Mistake | Result |
| --- | --- |
| Trying to open the APK on iPhone | Won’t install — iPhone can’t run Android APKs |
| Opening the GitHub repo / zip instead of the `.apk` | Nothing useful installs |
| Never enabling “Allow from this source” | Tap does nothing / blocked |
| Company policy blocks unknown apps | Need IT unlock |
| Leaving USB mode on “Charging” | PC can’t copy the APK over |

## Confirm you have the right file

- Name ends with `.apk`
- Size about **25 MB**
- Package id: `com.stakedxf.stakedxf`
- App label after install: **StakeDXF**
