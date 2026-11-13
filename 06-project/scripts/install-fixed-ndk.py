"""Install the pinned official NDK with resumable, checksum-verified downloads."""
from pathlib import Path
import hashlib
import os
import shutil
import time
import urllib.request
import zipfile

SDK = Path(os.environ.get("ANDROID_SDK_ROOT", "D:/Documents/Android/Sdk")).resolve()
TARGET = (SDK / "ndk/29.0.14206865").resolve()
CACHE = (SDK / ".temp/fenleng-fridge-ndk29").resolve()
ARCHIVE = CACHE / "android-ndk-r29-windows.zip"
URL = "https://dl.google.com/android/repository/android-ndk-r29-windows.zip"
SIZE = 833850862
SHA1 = "ab3bb30fbb9e6903666d60c55d11e78b04e07472"

assert TARGET.is_relative_to(SDK) and CACHE.is_relative_to(SDK)
if TARGET.exists():
    assert (TARGET / "source.properties").is_file(), "Existing installation needs review"
    print("Pinned NDK already installed.", flush=True)
    raise SystemExit(0)
CACHE.mkdir(parents=True, exist_ok=True)
opener = urllib.request.build_opener(urllib.request.ProxyHandler({"https": "http://127.0.0.1:7897"}))
offset = ARCHIVE.stat().st_size if ARCHIVE.exists() else 0
assert offset <= SIZE
while offset < SIZE:
    end = min(SIZE - 1, offset + 8 * 1024 * 1024 - 1)
    for attempt in range(4):
        try:
            request = urllib.request.Request(URL, headers={"Range": f"bytes={offset}-{end}"})
            with opener.open(request, timeout=45) as response:
                if response.status != 206:
                    raise RuntimeError("Server did not honor range; retained cached data")
                content_range = response.headers.get("Content-Range", "")
                if not content_range.startswith(f"bytes {offset}-"):
                    raise RuntimeError("Unexpected range response")
                payload = response.read(end - offset + 1)
                if len(payload) != end - offset + 1:
                    raise RuntimeError("Incomplete download chunk")
            with ARCHIVE.open("ab") as output:
                output.write(payload)
            offset += len(payload)
            print(f"NDK cached {offset // (1024 * 1024)} / {SIZE // (1024 * 1024)} MiB", flush=True)
            break
        except Exception as error:
            print(f"Download retry {attempt + 1}: {type(error).__name__}", flush=True)
            if attempt == 3:
                raise
            time.sleep(1)
digest = hashlib.sha1()
with ARCHIVE.open("rb") as archive_file:
    for block in iter(lambda: archive_file.read(1024 * 1024), b""):
        digest.update(block)
assert digest.hexdigest() == SHA1, "Official NDK checksum mismatch"
with zipfile.ZipFile(ARCHIVE) as archive:
    for member in archive.infolist():
        assert (CACHE / member.filename).resolve().is_relative_to(CACHE)
    archive.extractall(CACHE)
source = (CACHE / "android-ndk-r29").resolve()
assert source.is_relative_to(CACHE) and (source / "source.properties").is_file()
assert not TARGET.exists()
TARGET.parent.mkdir(parents=True, exist_ok=True)
shutil.move(str(source), str(TARGET))
print("Installed and verified official NDK 29.0.14206865.", flush=True)
