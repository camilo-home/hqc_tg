#!/usr/bin/env python3
from Crypto.Cipher import AES

class NIST_CTR_DRBG:
    def __init__(self, entropy_input):
        # El estado interno arranca en ceros (32 bytes de clave AES-256, 16 bytes de Vector)
        self.Key = b'\x00' * 32
        self.V = b'\x00' * 16
        # Inicializa usando la entropía de 48 bytes
        self.update(entropy_input)

    def update(self, provided_data):
        temp = b''
        aes = AES.new(self.Key, AES.MODE_ECB)
        
        # Genera 48 bytes (3 bloques de 16 bytes)
        for i in range(3):
            # Incrementa V (contador de 128 bits)
            V_int = (int.from_bytes(self.V, 'big') + 1) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            self.V = V_int.to_bytes(16, 'big')
            # Encripta V con AES
            temp += aes.encrypt(self.V)
        
        # Si se proveyó entropía, se hace XOR con la salida generada
        if provided_data is not None:
            temp = bytes(a ^ b for a, b in zip(temp, provided_data))
        
        # Actualiza el estado (Nuevos Key y V)
        self.Key = temp[:32]
        self.V = temp[32:48]

    def randombytes(self, length):
        temp = b''
        aes = AES.new(self.Key, AES.MODE_ECB)
        
        # Genera los bytes necesarios
        while len(temp) < length:
            V_int = (int.from_bytes(self.V, 'big') + 1) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            self.V = V_int.to_bytes(16, 'big')
            temp += aes.encrypt(self.V)
        
        output = temp[:length]
        
        # Después de cada extracción, el DRBG del NIST obliga a actualizar el estado sin nueva entropía
        self.update(None)
        
        return output

if __name__ == "__main__":
    # 1. Creamos la entropía inicial de 48 bytes incremental (00, 01, 02... 2F)
    entropy_input = bytes(range(48))

    # 2. Inicializamos el generador simulando la llamada a randombytes_init()
    drbg = NIST_CTR_DRBG(entropy_input)

    # 3. Replicamos el bucle for de 100 iteraciones del test_kat.c
    for count in range(100):
        # Genera 48 bytes pseudoaleatorios
        seed = drbg.randombytes(48)
        
        print(f"count = {count}")
        print(f"seed = {seed.hex().upper()}\n")