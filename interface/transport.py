"""Transportes de bytes. El resto de la aplicacion solo necesita write(bytes) y read(timeout) -> bytes."""
from __future__ import annotations
import queue
import shutil
import subprocess
import threading
import time
from abc import ABC, abstractmethod
from typing import List, Optional, Sequence, Tuple


class TransportError(Exception):
    pass


class Transport(ABC):
    @abstractmethod
    def write(self, data: bytes) -> None: ...

    @abstractmethod
    def read(self, timeout: float) -> bytes:
        """Devuelve los bytes disponibles (puede ser b'' si no llego nada en `timeout` segundos)."""

    def close(self) -> None:
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


class Nios2TerminalTransport(Transport):
    """JTAG UART (Intel) a traves del programa `nios2-terminal` que instala Quartus / Nios II.

    Se lanza como proceso hijo y se le habla por stdin/stdout. Abre una 'Nios II Command Shell' o
    anade <quartus>/bin (o <quartus>/bin64) al PATH para que se encuentre el ejecutable; tambien se
    puede indicar la ruta con `executable`.  `cable`, `device` e `instance` son los de nios2-terminal
    (normalmente basta con no indicar nada si solo hay un USB-Blaster; `instance` es el numero que
    se puso al JTAG UART en Platform Designer). Todo lo que nios2-terminal imprime por stderr
    (mensaje de conexion, errores) queda en `self.diagnostics`.
    """

    def __init__(self, cable: Optional[str] = None, device: Optional[int] = None,
                 instance: Optional[int] = None, executable: Optional[str] = None,
                 extra_args: Sequence[str] = ()):
        exe = executable or shutil.which("nios2-terminal")
        if not exe:
            raise TransportError("No encuentro 'nios2-terminal'. Abre una 'Nios II Command Shell' o anade la "
                                 "carpeta bin de Quartus al PATH (o usa --nios2-terminal RUTA).")
        args = [exe]
        if cable is not None:
            args += ["--cable", str(cable)]
        if device is not None:
            args += ["--device", str(device)]
        if instance is not None:
            args += ["--instance", str(instance)]
        args += list(extra_args)
        self.args = args
        self.diagnostics: List[str] = []
        self._q: "queue.Queue[bytes]" = queue.Queue()
        self._proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE, bufsize=0)
        threading.Thread(target=self._pump_stdout, daemon=True).start()
        threading.Thread(target=self._pump_stderr, daemon=True).start()
        time.sleep(0.3)
        if self._proc.poll() is not None:
            raise TransportError("nios2-terminal termino al arrancar:\n" + "\n".join(self.diagnostics))

    def _pump_stdout(self):
        out = self._proc.stdout
        while True:
            chunk = out.read(4096) if hasattr(out, "read") else b""
            if not chunk:
                break
            self._q.put(chunk)

    def _pump_stderr(self):
        for line in iter(self._proc.stderr.readline, b""):
            self.diagnostics.append(line.decode("utf-8", "replace").rstrip())

    def write(self, data: bytes) -> None:
        if self._proc.poll() is not None:
            raise TransportError("nios2-terminal ya no esta en ejecucion")
        self._proc.stdin.write(data)
        self._proc.stdin.flush()

    def read(self, timeout: float) -> bytes:
        try:
            data = self._q.get(timeout=timeout)
        except queue.Empty:
            return b""
        while True:                                   # vaciar lo que haya
            try:
                data += self._q.get_nowait()
            except queue.Empty:
                return data

    def close(self) -> None:
        try:
            self._proc.stdin.close()
        except Exception:
            pass
        try:
            self._proc.terminate()
        except Exception:
            pass


class MemoryTransport(Transport):
    """Extremo de un enlace en memoria (para pruebas y para el emulador). Se crea con MemoryTransport.pair()."""

    def __init__(self, rx: "queue.Queue[bytes]", tx: "queue.Queue[bytes]"):
        self._rx, self._tx = rx, tx

    @staticmethod
    def pair() -> Tuple["MemoryTransport", "MemoryTransport"]:
        a, b = queue.Queue(), queue.Queue()
        return MemoryTransport(a, b), MemoryTransport(b, a)

    def write(self, data: bytes) -> None:
        self._tx.put(bytes(data))

    def read(self, timeout: float) -> bytes:
        try:
            data = self._rx.get(timeout=timeout)
        except queue.Empty:
            return b""
        while True:
            try:
                data += self._rx.get_nowait()
            except queue.Empty:
                return data


class CrLfTransport(Transport):
    """Envuelve otro transporte y convierte '\\n' en '\\r\\n' en ambos sentidos: emula un terminal en modo texto.
    Sirve para comprobar que el protocolo de lineas hexadecimales no se corrompe por esa conversion."""

    def __init__(self, inner: Transport):
        self.inner = inner

    def write(self, data: bytes) -> None:
        self.inner.write(data.replace(b"\n", b"\r\n"))

    def read(self, timeout: float) -> bytes:
        return self.inner.read(timeout).replace(b"\n", b"\r\n")

    def close(self) -> None:
        self.inner.close()
