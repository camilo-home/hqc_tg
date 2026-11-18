"""Parametros de HQC y descripcion de los tres nucleos (una etapa por bitstream).

Todos los objetos criptograficos son cadenas de bytes en el orden EXACTO de la especificacion
(byte 0 primero); no hay enteros ni cambios de endianness en la capa criptografica.
"""
from __future__ import annotations
from dataclasses import dataclass
from enum import IntEnum


class Core(IntEnum):
    """Etapa implementada por el bitstream cargado en la FPGA."""
    KEYGEN = 1
    ENCAPS = 2
    DECAPS = 3


@dataclass(frozen=True)
class HqcParams:
    name: str
    param_id: int      # identificador que anuncia la FPGA en INFO (1 = HQC-128)
    seed_sz: int       # seed_kem / seed_pke / seed_dk / seed_ek
    m_sz: int          # mensaje m
    salt_sz: int       # salt
    sigma_sz: int      # sigma (parte de la clave secreta)
    ek_sz: int         # clave publica  = seed_ek || s
    dk_sz: int         # clave secreta  = ek || seed_dk || sigma || seed_kem
    ct_sz: int         # texto cifrado  = u || v || salt
    ss_sz: int         # secreto compartido

    # ---- formatos de entrada/salida de cada nucleo (lo que viaja en el payload de RUN / RESULT) ----
    def in_len(self, core: Core) -> int:
        return {Core.KEYGEN: self.seed_sz,                               # seed_kem
                Core.ENCAPS: self.ek_sz + self.m_sz + self.salt_sz,      # ek || m || salt
                Core.DECAPS: self.dk_sz + self.ct_sz}[core]              # dk || ct

    def out_len(self, core: Core) -> int:
        return {Core.KEYGEN: self.dk_sz,                                 # dk  (ek = dk[:ek_sz])
                Core.ENCAPS: self.ct_sz + self.ss_sz,                    # ct || ss
                Core.DECAPS: self.ss_sz}[core]                           # ss


HQC128 = HqcParams(name="HQC-128", param_id=1, seed_sz=32, m_sz=16, salt_sz=16, sigma_sz=16,
                   ek_sz=2241, dk_sz=2321, ct_sz=4433, ss_sz=32)

PARAMS_BY_ID = {HQC128.param_id: HQC128}
