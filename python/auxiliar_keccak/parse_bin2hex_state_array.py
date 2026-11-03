"""
    Este script convierte un vector binario de 1600 bits a un arreglo de 5x5 lanes
    de 8 bytes (16 hexadecimales) y los imprime en forma de keccak state array
"""

# funcion auxiliar para invertir lanes de 64 bits a forma de inversion de caracteres, NO de enteros
def reverse_bits_64(bitstr):
    return bitstr[::-1]

"""
parsing de bits a state array como lo establece el estandar:

  A[x,y,z] = S[w*(5y + x) + z], con w = 64
  
Con cada indice de lane: lane_index = 5y + x

indices de la forma:
[ 0  1  2  3  4  ]
[ 5  6  7  8  9  ]
[ 10 11 12 13 14 ]
[ 15 16 17 18 19 ]
[ 20 21 22 23 24 ]
para cada lane:
A[0,0]
A[1,0]
A[2,0]
A[3,0]
A[4,0]
A[0,1]
A[1,1]
...
A[4,4]
"""
def bin_state_to_matrix(bin_string):

    bin_string = bin_string.strip()

    if len(bin_string) != 1600:
        print("Error: input must be 1600 bits")
        return None

    A = [[0]*5 for _ in range(5)]

    for y in range(5):
        for x in range(5):

            lane_index = x + 5*y
            start = lane_index * 64
            end = start + 64

            lane_bits = bin_string[start:end]

            lane_bits = reverse_bits_64(lane_bits)

            lane_value = int(lane_bits, 2)

            A[x][y] = lane_value

    return A

def print_matrix(A):

    print("")
    print("Keccak state A[x][y]:")
    print("")

    for y in range(5):
        for x in range(5):
            print("{:016x}".format(A[x][y]), end=" ")
        print("")


def main():

    print("Enter 1600 binary bits vector:")

    bin_string = input().strip()

    A = bin_state_to_matrix(bin_string)

    if A is not None:
        print_matrix(A)


if __name__ == "__main__":
    main()
