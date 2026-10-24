#!/usr/bin/env python3
"""Boot a relocated release twice with isolated data and no developer runtime."""

import os
from pathlib import Path
import re
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def smoke(release):
    launcher = release / "bin" / "ci-book-tracker"
    subprocess.run([launcher, "--version"], check=True)
    with tempfile.TemporaryDirectory(prefix="ci-book-tracker-smoke-") as directory:
        data = Path(directory) / "data"
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        env = os.environ.copy()
        for key in ("SECRET_KEY_BASE", "DATABASE_PATH", "PHX_SERVER", "PHX_HOST"):
            env.pop(key, None)
        env.update(
            CI_BOOK_TRACKER_DATA_DIR=str(data),
            PORT=str(port),
            # The package must boot with its own ERTS, without Elixir/Mix on PATH.
            PATH="/usr/bin:/bin:/usr/sbin:/sbin",
        )
        secret = None
        for boot in range(2):
            with (Path(directory) / "server.log").open("w+") as log:
                process = subprocess.Popen([launcher], env=env, stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 60
                    while True:
                        if process.poll() is not None:
                            raise RuntimeError("Release exited before serving HTTP")
                        try:
                            with urllib.request.urlopen(
                                f"http://127.0.0.1:{port}", timeout=2
                            ) as response:
                                assert response.status == 200
                                page = response.read()
                                assert b'id="reading-log-selector"' in page
                                assets = re.findall(rb'(?:href|src)="(/assets/[^\"]+)"', page)
                                assert len(assets) >= 2
                            for asset in assets:
                                with urllib.request.urlopen(
                                    f"http://127.0.0.1:{port}" + asset.decode(), timeout=2
                                ) as response:
                                    assert response.status == 200
                                    assert response.read()
                            break
                        except (urllib.error.URLError, TimeoutError):
                            if time.monotonic() >= deadline:
                                raise RuntimeError("Release did not serve HTTP within 60s")
                            time.sleep(0.25)

                    saved = (data / "secret_key_base").read_bytes()
                    assert len(saved) >= 64
                    assert (data / "secret_key_base").stat().st_mode & 0o777 == 0o600
                    with sqlite3.connect(data / "reading_log.db") as db:
                        assert db.execute("SELECT count(*) FROM schema_migrations").fetchone()[0] > 0
                        if boot == 0:
                            secret = saved
                            db.execute("CREATE TABLE release_smoke_marker (value TEXT)")
                            db.execute("INSERT INTO release_smoke_marker VALUES ('preserved')")
                        else:
                            assert saved == secret
                            assert db.execute("SELECT value FROM release_smoke_marker").fetchone() == (
                                "preserved",
                            )
                except BaseException:
                    log.seek(0)
                    print(log.read(), file=sys.stderr)
                    raise
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
        print("Release smoke test passed: first boot, migrations, HTTP, and persistent restart")


if __name__ == "__main__":
    smoke(Path(sys.argv[1]).resolve())
