"""Protocolo PC <-> FPGA (ver PROTOCOLO.md).

Dos capas:
  * trama binaria  : TYPE(1) SEQ(1) LEN(2, big-endian) PAYLOAD CRC32(4, big-endian)
                     CRC32 estandar (zlib / IEEE 802.3) sobre TYPE..PAYLOAD
  * linea de texto : cada trama viaja como UNA linea ASCII  '>' + HEX + '\\n'  (PC -> FPGA)
                                                            '<' + HEX + '\\n'  (FPGA -> PC)
    Es transparente a la conversion de saltos de linea (\\n <-> \\r\\n), ignora cualquier otra linea
    (por ejemplo el texto de bienvenida de nios2-terminal) y se re-sincroniza solo en cada '\\n'.
"""
from __future__ import annotations
import struct
import zlib
from dataclasses import dataclass
from enum import IntEnum
from typing import List, Union

PROTO_VERSION = 1
MAX_PAYLOAD = 0xFFFF
HOST_PREFIX = b">"
DEV_PREFIX = b"<"
MAX_LINE = 2 * (MAX_PAYLOAD + 8) + 16            # tope de una linea valida (en caracteres)


class FrameType(IntEnum):
    REQ_INFO = 0x01
    REQ_RUN = 0x02
    REQ_RESET = 0x03
    RSP_INFO = 0x81
    RSP_RESULT = 0x82
    RSP_RESET = 0x83
    RSP_ERROR = 0xFF


class ErrorCode(IntEnum):
    BAD_CRC = 1          # la trama recibida por la FPGA tenia el CRC mal
    BAD_LENGTH = 2       # LEN no es el que exige el nucleo cargado
    BUSY = 3             # el nucleo esta ocupado
    BAD_REQUEST = 4      # tipo de trama desconocido
    CORE_TIMEOUT = 5     # el nucleo no termino (watchdog de la FPGA)


FLAG_EMULATED = 0x01     # bit 0 de INFO.flags: el dispositivo es un emulador por software


class FrameError(Exception):
    """Trama mal formada (hex invalido, longitud o CRC incorrectos)."""


@dataclass(frozen=True)
class Frame:
    ftype: int
    seq: int
    payload: bytes = b""


def encode_frame(frame: Frame) -> bytes:
    if len(frame.payload) > MAX_PAYLOAD:
        raise ValueError(f"payload de {len(frame.payload)} bytes (maximo {MAX_PAYLOAD})")
    body = struct.pack(">BBH", frame.ftype, frame.seq & 0xFF, len(frame.payload)) + frame.payload
    return body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def decode_frame(raw: bytes) -> Frame:
    if len(raw) < 8:
        raise FrameError("trama demasiado corta")
    ftype, seq, length = struct.unpack(">BBH", raw[:4])
    if len(raw) != 4 + length + 4:
        raise FrameError(f"longitud inconsistente: LEN={length}, bytes={len(raw)}")
    (crc,) = struct.unpack(">I", raw[-4:])
    if zlib.crc32(raw[:-4]) & 0xFFFFFFFF != crc:
        raise FrameError("CRC32 incorrecto")
    return Frame(ftype, seq, bytes(raw[4:4 + length]))


def to_line(frame: Frame, prefix: bytes) -> bytes:
    return prefix + encode_frame(frame).hex().upper().encode("ascii") + b"\n"


class LineDecoder:
    """Reensambla lineas de un flujo de bytes y devuelve Frame o FrameError por cada linea con ese prefijo."""

    def __init__(self, prefix: bytes):
        self.prefix = prefix
        self._buf = bytearray()

    def feed(self, data: bytes) -> List[Union[Frame, FrameError]]:
        self._buf += data
        out: List[Union[Frame, FrameError]] = []
        while True:
            nl = self._buf.find(b"\n")
            if nl < 0:
                if len(self._buf) > MAX_LINE:         # basura sin salto de linea: descartar
                    self._buf.clear()
                break
            line = bytes(self._buf[:nl]).strip()      # quita tambien '\r'
            del self._buf[:nl + 1]
            if not line.startswith(self.prefix):
                continue                              # ruido (banner de nios2-terminal, etc.)
            try:
                out.append(decode_frame(bytes.fromhex(line[len(self.prefix):].decode("ascii"))))
            except (ValueError, UnicodeDecodeError):
                out.append(FrameError("hex invalido"))
            except FrameError as e:
                out.append(e)
        return out


# ------------------------------------------------------------------ payloads
_INFO = struct.Struct(">BBBBHHI")      # proto_ver, core, param_id, flags, in_len, out_len, fclk_hz


@dataclass(frozen=True)
class DeviceInfo:
    proto_ver: int
    core: int
    param_id: int
    flags: int
    in_len: int
    out_len: int
    fclk_hz: int

    @property
    def emulated(self) -> bool:
        return bool(self.flags & FLAG_EMULATED)

    def pack(self) -> bytes:
        return _INFO.pack(self.proto_ver, self.core, self.param_id, self.flags,
                          self.in_len, self.out_len, self.fclk_hz)

    @staticmethod
    def unpack(payload: bytes) -> "DeviceInfo":
        if len(payload) != _INFO.size:
            raise FrameError(f"INFO de {len(payload)} bytes (esperados {_INFO.size})")
        return DeviceInfo(*_INFO.unpack(payload))


_RESULT_HEAD = struct.Struct(">BI")    # status, cycles


def pack_result(cycles: int, data: bytes, status: int = 0) -> bytes:
    return _RESULT_HEAD.pack(status, cycles & 0xFFFFFFFF) + data


def unpack_result(payload: bytes):
    if len(payload) < _RESULT_HEAD.size:
        raise FrameError("RESULT demasiado corto")
    status, cycles = _RESULT_HEAD.unpack(payload[:_RESULT_HEAD.size])
    return status, cycles, payload[_RESULT_HEAD.size:]


def pack_error(code: int, text: str = "") -> bytes:
    return bytes([code]) + text.encode("ascii", "replace")[:64]


def unpack_error(payload: bytes):
    if not payload:
        raise FrameError("ERROR vacio")
    return payload[0], payload[1:].decode("ascii", "replace")
