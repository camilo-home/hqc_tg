"""API de alto nivel: una clase Device con una operacion por etapa de HQC."""
from __future__ import annotations
import time
from dataclasses import dataclass
from typing import Optional

from .params import Core, HqcParams, HQC128, PARAMS_BY_ID
from .protocol import (DEV_PREFIX, HOST_PREFIX, DeviceInfo, ErrorCode, Frame, FrameError, FrameType,
                       LineDecoder, PROTO_VERSION, to_line, unpack_error, unpack_result)
from .transport import Transport


class HqcError(Exception):
    """Error base de la aplicacion."""


class DeviceError(HqcError):
    def __init__(self, code: int, text: str = ""):
        try:
            name = ErrorCode(code).name
        except ValueError:
            name = f"codigo {code}"
        super().__init__(f"la FPGA respondio ERROR {name}" + (f": {text}" if text else ""))
        self.code = code


class WrongCoreError(HqcError):
    pass


class LinkTimeout(HqcError):
    pass


@dataclass(frozen=True)
class KeygenResult:
    ek: bytes
    dk: bytes
    cycles: int
    seconds: Optional[float]      # tiempo de calculo en la FPGA = cycles / fclk (None si es un emulador)


@dataclass(frozen=True)
class EncapsResult:
    ct: bytes
    ss: bytes
    cycles: int
    seconds: Optional[float]


@dataclass(frozen=True)
class DecapsResult:
    ss: bytes
    cycles: int
    seconds: Optional[float]


class Device:
    def __init__(self, transport: Transport, timeout: float = 30.0, retries: int = 2):
        self.transport = transport
        self.timeout = timeout
        self.retries = retries
        self._seq = 0
        self._decoder = LineDecoder(DEV_PREFIX)
        self._info: Optional[DeviceInfo] = None

    # ------------------------------------------------------------ transporte de tramas
    def _request(self, ftype: FrameType, payload: bytes, expect: FrameType) -> Frame:
        last_problem = "sin respuesta"
        for attempt in range(self.retries + 1):
            self._seq = (self._seq + 1) & 0xFF
            seq = self._seq
            self.transport.write(to_line(Frame(ftype, seq, payload), HOST_PREFIX))
            deadline = time.monotonic() + self.timeout
            while time.monotonic() < deadline:
                data = self.transport.read(min(0.2, max(0.0, deadline - time.monotonic())))
                for item in self._decoder.feed(data):
                    if isinstance(item, FrameError):
                        last_problem = f"trama danada ({item})"
                        deadline = 0                          # reintentar la peticion (RUN es idempotente)
                        break
                    if item.seq != seq:
                        continue                              # respuesta atrasada de otra peticion
                    if item.ftype == FrameType.RSP_ERROR:
                        code, text = unpack_error(item.payload)
                        if code == ErrorCode.BAD_CRC:
                            last_problem = "la FPGA recibio la peticion con CRC erroneo"
                            deadline = 0
                            break
                        raise DeviceError(code, text)
                    if item.ftype != expect:
                        raise HqcError(f"respuesta inesperada 0x{item.ftype:02X} (esperaba 0x{expect:02X})")
                    return item
        raise LinkTimeout(f"sin respuesta valida de la FPGA tras {self.retries + 1} intentos ({last_problem})")

    # ------------------------------------------------------------ informacion del bitstream
    def info(self, refresh: bool = False) -> DeviceInfo:
        if self._info is None or refresh:
            info = DeviceInfo.unpack(self._request(FrameType.REQ_INFO, b"", FrameType.RSP_INFO).payload)
            if info.proto_ver != PROTO_VERSION:
                raise HqcError(f"version de protocolo {info.proto_ver} (esta aplicacion usa {PROTO_VERSION})")
            self._info = info
        return self._info

    @property
    def core(self) -> Core:
        return Core(self.info().core)

    @property
    def params(self) -> HqcParams:
        pid = self.info().param_id
        if pid not in PARAMS_BY_ID:
            raise HqcError(f"conjunto de parametros desconocido ({pid})")
        return PARAMS_BY_ID[pid]

    def reset(self) -> None:
        self._request(FrameType.REQ_RESET, b"", FrameType.RSP_RESET)

    # ------------------------------------------------------------ ejecucion
    def _run(self, core: Core, payload: bytes):
        info = self.info()
        if info.core != core:
            raise WrongCoreError(f"la FPGA tiene cargado el nucleo {Core(info.core).name}; "
                                 f"esta operacion necesita {core.name}. Carga el .sof correspondiente.")
        p = self.params
        if len(payload) != p.in_len(core):
            raise ValueError(f"entrada de {len(payload)} bytes; {core.name} espera {p.in_len(core)}")
        resp = self._request(FrameType.REQ_RUN, payload, FrameType.RSP_RESULT)
        status, cycles, data = unpack_result(resp.payload)
        if status != 0:
            raise DeviceError(status, "estado de RESULT distinto de 0")
        if len(data) != p.out_len(core):
            raise HqcError(f"salida de {len(data)} bytes; {core.name} deberia devolver {p.out_len(core)}")
        seconds = None if info.emulated or info.fclk_hz == 0 else cycles / info.fclk_hz
        return cycles, seconds, data

    @staticmethod
    def _check(name: str, value: bytes, size: int) -> bytes:
        value = bytes(value)
        if len(value) != size:
            raise ValueError(f"{name}: {len(value)} bytes (deben ser {size})")
        return value

    def keygen(self, seed_kem: bytes) -> KeygenResult:
        """KeyGen: seed_kem -> (ek, dk). dk = ek || seed_dk || sigma || seed_kem; ek = dk[:ek_sz]."""
        p = self.params
        cycles, seconds, dk = self._run(Core.KEYGEN, self._check("seed_kem", seed_kem, p.seed_sz))
        return KeygenResult(ek=dk[:p.ek_sz], dk=dk, cycles=cycles, seconds=seconds)

    def encaps(self, ek: bytes, m: bytes, salt: bytes) -> EncapsResult:
        """Encaps: (ek, m, salt) -> (ct, ss). La aleatoriedad (m, salt) la aporta el anfitrion."""
        p = self.params
        payload = (self._check("ek", ek, p.ek_sz) + self._check("m", m, p.m_sz)
                   + self._check("salt", salt, p.salt_sz))
        cycles, seconds, out = self._run(Core.ENCAPS, payload)
        return EncapsResult(ct=out[:p.ct_sz], ss=out[p.ct_sz:], cycles=cycles, seconds=seconds)

    def decaps(self, dk: bytes, ct: bytes) -> DecapsResult:
        """Decaps: (dk, ct) -> ss. Nunca falla: ante un ct invalido devuelve el secreto de rechazo implicito."""
        p = self.params
        payload = self._check("dk", dk, p.dk_sz) + self._check("ct", ct, p.ct_sz)
        cycles, seconds, ss = self._run(Core.DECAPS, payload)
        return DecapsResult(ss=ss, cycles=cycles, seconds=seconds)
