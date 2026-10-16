"""Access to the Cerberus price-transparency portal (FTPS) used by Rami Levy."""
from __future__ import annotations

import gzip
import io
import re
import threading
import time
import zipfile
from dataclasses import dataclass
from ftplib import FTP_TLS

HOST = "url.retail.publishedprices.co.il"
USER = "RamiLevi"
CHAIN_ID = "7290058140886"

# PriceFull7290058140886-001-023-20261013-001009.gz
FILE_RE = re.compile(
    r"^(?P<kind>PriceFull|PromoFull|Price|Promo|Stores)(?P<chain>\d+)-(?:(?P<sub>\d+)-)?(?P<store>\d+)-(?P<ts>\d{8}-?\d{4,6})",
    re.I,
)


@dataclass(frozen=True)
class RemoteFile:
    name: str
    kind: str  # pricefull / promofull / stores / price / promo
    store: str  # store id without leading zeros ("23"); "0" for Stores
    ts: str  # sortable timestamp string
    size: int


def connect(timeout: int = 120) -> FTP_TLS:
    ftp = FTP_TLS(HOST, USER, "", timeout=timeout)
    ftp.trust_server_pasv_ipv4_address = True
    ftp.prot_p()
    return ftp


def list_files() -> list[RemoteFile]:
    ftp = connect()
    try:
        try:
            raw = [(n, int(f.get("size") or 0)) for n, f in ftp.mlsd() if f.get("type") == "file"]
        except Exception:  # noqa: BLE001 - server without MLSD
            raw = [(n, 0) for n in ftp.nlst()]
    finally:
        try:
            ftp.quit()
        except Exception:  # noqa: BLE001
            ftp.close()
    out = []
    for name, size in raw:
        m = FILE_RE.match(name)
        if not m:
            continue
        out.append(
            RemoteFile(
                name=name,
                kind=m["kind"].lower(),
                store=str(int(m["store"])),
                ts=m["ts"].replace("-", "").ljust(14, "0"),
                size=size,
            )
        )
    return out


def latest_by_store(files: list[RemoteFile], kind: str) -> dict[str, RemoteFile]:
    best: dict[str, RemoteFile] = {}
    for f in files:
        if f.kind != kind:
            continue
        cur = best.get(f.store)
        if cur is None or f.ts > cur.ts:
            best[f.store] = f
    return best


def decompress(data: bytes) -> bytes:
    if data[:2] == b"\x1f\x8b":
        return gzip.decompress(data)
    if data[:2] == b"PK":
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            return z.read(z.namelist()[0])
    return data


class Downloader:
    """One FTPS connection per thread, reconnecting on failure."""

    def __init__(self) -> None:
        self._local = threading.local()

    def _ftp(self) -> FTP_TLS:
        ftp = getattr(self._local, "ftp", None)
        if ftp is None:
            ftp = connect()
            self._local.ftp = ftp
        return ftp

    def _drop(self) -> None:
        ftp = getattr(self._local, "ftp", None)
        self._local.ftp = None
        if ftp is not None:
            try:
                ftp.close()
            except Exception:  # noqa: BLE001
                pass

    def get(self, name: str, tries: int = 5) -> bytes:
        last: Exception | None = None
        for attempt in range(tries):
            try:
                buf = io.BytesIO()
                self._ftp().retrbinary("RETR " + name, buf.write)
                return decompress(buf.getvalue())
            except Exception as e:  # noqa: BLE001
                last = e
                self._drop()
                time.sleep(2 * (attempt + 1))
        raise RuntimeError(f"download failed for {name}: {last!r}")


def deltas_after(files: list[RemoteFile], kind: str, store: str, after_ts: str) -> list[RemoteFile]:
    """Intraday partial files (kind 'price' / 'promo') for a store, newer than the full file, oldest first."""
    return sorted((f for f in files if f.kind == kind and f.store == store and f.ts > after_ts), key=lambda f: f.ts)
