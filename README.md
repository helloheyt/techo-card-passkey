# T-Echo Card Passkey

FIDO2 / passkey firmware with **NFC** for the **LilyGO T-Echo Card** (nRF52840).

# ⚠️ SECURITY WARNING: THIS IS NOT A SECURE SECURITY KEY

> [!CAUTION]
> **Experimental, early-stage project. For experiments and learning only.**
>
> - Your private keys are stored in the chip's **normal flash memory**. There is **no secure element**.
> - The board's UF2 bootloader lets **anyone who holds the card read the entire flash, keys included**,
>   in a few seconds. A lost or borrowed card means leaked keys.
> - Debug diagnostics are still built in.
> - It is **not FIDO certified**.
> - **Never use it as the only way to sign in to an account you care about.** Always keep another
>   sign-in method (another security key, a passkey on your phone, recovery codes).

> [!WARNING]
> **Even though it was tested and everything worked, the firmware is still experimental and your
> keys may be erased.** A bug, a failed update or a wrong file can delete every passkey on the card.

## Disclaimer

This project is provided "as is", without warranty of any kind. **Any problem or damage of any kind
caused by using this project is solely the user's responsibility. The author takes no responsibility
whatsoever**, including (but not limited to) lost accounts, lost or leaked keys, data loss and damaged
hardware. Not affiliated with or endorsed by Google, Nordic Semiconductor, LilyGO or the FIDO Alliance.

## What works

| Feature | Status |
|---|---|
| USB: register, sign in, PIN (CTAP 2.1) | works (tested on macOS) |
| NFC with iPhone (Safari) | register and sign in work |
| NFC with Android | partly tested |
| Passkeys and PIN survive restarts and updates | yes, when you use the *update* file |

**Buttons**

| Button | Action |
|---|---|
| **A** | Turns NFC on for 30 seconds. Also confirms "user presence" over USB. |
| **B** | Restart. **Double-press** to enter the UF2 bootloader (a USB drive named `NRF52BOOT` appears). |

## Install

### 1. Build the firmware files

You need macOS or Linux with `git`, `curl`, `python3`, `clang` and [Rust (rustup)](https://rustup.rs).

```bash
git clone https://github.com/helloheyt/techo-card-passkey.git
cd techo-card-passkey
./install.sh
```

The script downloads the pinned upstream sources and libraries (checking their SHA-256 hashes),
applies the patches from this repository and builds two files into `dist/`:

| File | When to use it |
|---|---|
| `techo-passkey-first-install.uf2` | **Once**, on a card coming from other firmware. **Erases the key storage.** |
| `techo-passkey-update.uf2` | Every later update. Keeps your passkeys and PIN. |

The first run downloads the Rust toolchain and takes a while.

### 2. Prepare the card (once)

1. Double-press **B**, then copy LilyGO's NFC-enabled bootloader update
   (`update-t_echo_card_nrf52840_bootloader-…_nosd_….uf2`, from the
   [LilyGO T-Echo-Card repository](https://github.com/Xinyuan-LilyGO/T-Echo-Card/tree/main/bootloader))
   to the `NRF52BOOT` drive.
2. Double-press **B** again and copy `nfc_uicr_repair_….uf2` from the same place
   (`bootloader/nfc_uicr_repair`). This turns on the NFC antenna pins.

### 3. Flash

1. Double-press **B** and copy `dist/techo-passkey-first-install.uf2` to `NRF52BOOT`.
2. Wait about 15 seconds, then press **B** once.
3. **Set a PIN** (recommended): in Chrome on a computer, with the card plugged in, go to
   Settings → Privacy and security → Security → Manage security keys → Create a PIN.

For later updates, use `dist/techo-passkey-update.uf2` the same way.

### 4. Use

- **USB:** plug it in, and press **A** when the website asks you to touch your key.
- **NFC:** press **A**, then within 30 seconds hold the card flat against the top of the phone's back.

If the card is not detected over USB right after flashing, press **B** once.

## How it works

The repository contains only patches and scripts. `install.sh` downloads Google OpenSK and Wasefire
at fixed versions, applies `patches/opensk.patch` and `patches/wasefire.patch` (T-Echo Card board,
NFC support, fast P-256 crypto, key storage kept across updates), downloads Nordic's NFC library,
builds Nordic's nrfx NFC driver and the P256-Cortex-M4 crypto library, then builds the firmware.
Third-party components are **not** part of this repository: they are downloaded from their official
sources by the script and stay under their own licenses.

Debug helpers end up in `work/OpenSK/tools/` (`techo_markers.py` reads diagnostics from a
`CURRENT.UF2` dump, `usb*.py` are small USB tests based on python-fido2).

## License

The contents of this repository are licensed under the **GNU Affero General Public License v3.0**
(see [LICENSE](LICENSE)), with the additional permission and notices in [NOTICE](NOTICE).
