---------------------------------------------------------------------------
-- Universidade Federal de Minas Gerais (UFMG)
---------------------------------------------------------------------------
-- Project: Reed-Solomon Encoder
-- Design: RS Multiplier
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity rs_full_multiplier_core is
    generic (
        WORD_LENGTH : natural range 2 to 10;
        PRIMITIVE_POLYNOMIAL : natural range 0 to 2047 := 0
    );
    port (
        i1 : in std_logic_vector(WORD_LENGTH-1 downto 0);
        i2 : in std_logic_vector(WORD_LENGTH-1 downto 0);
        o : out std_logic_vector(WORD_LENGTH-1 downto 0)
    );
end rs_full_multiplier_core;

architecture behavioral of rs_full_multiplier_core is
    type std_logic_vector_array is array (natural range <>) of std_logic_vector;
    type integer_array is array (natural range <>) of integer;
    constant DEFAULT_PRIMITIVE_POLYNOMIALS : integer_array(2 to 10) := (
        2 => 7,    -- x^2  + x   + 1
        3 => 11,   -- x^3  + x   + 1
        4 => 19,   -- x^4  + x   + 1
        5 => 37,   -- x^5  + x^2 + 1
        6 => 67,   -- x^6  + x   + 1
        7 => 131,  -- x^7  + x   + 1
        8 => 285,  -- x^8  + x^4 + x^3 + x^2 + 1
        9 => 529,  -- x^9  + x^4 + 1
        10 => 1033 -- x^10 + x^3 + 1
    );

    function resolve_primitive_polynomial(word_length : natural;
                                          primitive_polynomial : natural) return natural is
    begin
        if primitive_polynomial = 0 then
            return DEFAULT_PRIMITIVE_POLYNOMIALS(word_length);
        else
            return primitive_polynomial;
        end if;
    end function;


    function is_primitive_polynomial_supported(word_length : natural;
                                               primitive_polynomial : natural) return boolean is
    begin
        if primitive_polynomial = DEFAULT_PRIMITIVE_POLYNOMIALS(word_length) then
            return true;
        elsif word_length = 5 and primitive_polynomial = 55 then
            return true;
        elsif word_length = 5 and primitive_polynomial = 61 then
            return true;
        elsif word_length = 6 and primitive_polynomial = 103 then
            return true;
        elsif word_length = 6 and primitive_polynomial = 109 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 137 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 143 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 157 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 191 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 203 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 213 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 229 then
            return true;
        elsif word_length = 7 and primitive_polynomial = 247 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 299 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 351 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 355 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 357 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 361 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 391 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 451 then
            return true;
        elsif word_length = 8 and primitive_polynomial = 487 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 557 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 601 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 623 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 631 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 731 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 787 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 817 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 865 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 875 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 901 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 911 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 995 then
            return true;
        elsif word_length = 9 and primitive_polynomial = 1001 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1051 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1135 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1293 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1305 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1315 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1329 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1509 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1531 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1555 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1687 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1869 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 1891 then
            return true;
        elsif word_length = 10 and primitive_polynomial = 2041 then
            return true;
        else
            return false;
        end if;
    end function;

    constant SELECTED_PRIMITIVE_POLYNOMIAL : natural := resolve_primitive_polynomial(WORD_LENGTH, PRIMITIVE_POLYNOMIAL);
    signal w_and_out : std_logic_vector_array(0 to WORD_LENGTH-1)(WORD_LENGTH-1 downto 0);
    signal w_factors_overflow : std_logic_vector(WORD_LENGTH-2 downto 0);
begin
    assert is_primitive_polynomial_supported(WORD_LENGTH, SELECTED_PRIMITIVE_POLYNOMIAL)
        report "ASSERT FAILURE - PRIMITIVE_POLYNOMIAL is not supported for this WORD_LENGTH"
        severity failure;

    --generate all combinations of AND operation
    process(i1,i2)
    begin
        for I in 0 to WORD_LENGTH-1 loop
            for J in 0 to WORD_LENGTH-1 loop
                w_and_out(I)(J) <= i1(I) and i2(J);
            end loop;
        end loop;
    end process;

    gen_word_length_2_poly_7: if WORD_LENGTH = 2 and SELECTED_PRIMITIVE_POLYNOMIAL = 7 generate
        --galois field conversion
        --x^2 = x^1 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x + 1

        --calculation for x^2
        w_factors_overflow(0) <= w_and_out(1)(1); 

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0);
        o(1) <= w_and_out(0)(1) xor 
                w_and_out(1)(0) xor
                w_factors_overflow(0);
    end generate;

    gen_word_length_3_poly_11: if WORD_LENGTH = 3 and SELECTED_PRIMITIVE_POLYNOMIAL = 11 generate
        --galois field conversion
        --x^3 = x^1 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^1 + 1
        --x^4 => x^2 + x

        --calculation for x^3
        w_factors_overflow(0) <= w_and_out(2)(1) xor
                                 w_and_out(1)(2);
        --calculation for x^4
        w_factors_overflow(1) <= w_and_out(2)(2);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0);
        o(1) <= w_and_out(0)(1) xor 
                w_and_out(1)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);
        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1);
    end generate;

    gen_word_length_4_poly_19: if WORD_LENGTH = 4 and SELECTED_PRIMITIVE_POLYNOMIAL = 19 generate
        --galois field conversion
        --x^4 = x^1 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x + 1
        --x^5 => x^2 + x
        --x^6 => x^3 + x^2

        --calculation for x^4
        w_factors_overflow(0) <= w_and_out(3)(1) xor 
                                 w_and_out(2)(2) xor
                                 w_and_out(1)(3);
        --calculation for x^5
        w_factors_overflow(1) <= w_and_out(3)(2) xor 
                                 w_and_out(2)(3);
        --calculation for x^6
        w_factors_overflow(2) <= w_and_out(3)(3);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0);
        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1);
        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);
        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2);
    end generate;

    gen_word_length_5_poly_37: if WORD_LENGTH = 5 and SELECTED_PRIMITIVE_POLYNOMIAL = 37 generate
        --galois field conversion
        --x^5 = x^2 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^2 + 1
        --x^6 => x^3 + x
        --x^7 => x^4 + x^2
        --x^8 => x^3 + x^2 + 1

        --calculation for x^5
        w_factors_overflow(0) <= w_and_out(4)(1) xor 
                                 w_and_out(3)(2) xor
                                 w_and_out(2)(3) xor
                                 w_and_out(1)(4);
        --calculation for x^6
        w_factors_overflow(1) <= w_and_out(4)(2) xor 
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4);
        --calculation for x^7
        w_factors_overflow(2) <= w_and_out(4)(3) xor
                                 w_and_out(3)(4);
        --calculation for x^8
        w_factors_overflow(3) <= w_and_out(4)(4);


        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(3);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2);
    end generate;

    gen_word_length_5_poly_55: if WORD_LENGTH = 5 and SELECTED_PRIMITIVE_POLYNOMIAL = 55 generate
        --galois field conversion
        --x^5 = x^4 + x^2 + x + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^4 + x^2 + x + 1
        --x^6 => x^4 + x^3 + 1
        --x^7 => x^2 + 1
        --x^8 => x^3 + x

        --calculation for x^5
        w_factors_overflow(0) <= w_and_out(4)(1) xor 
                                 w_and_out(3)(2) xor
                                 w_and_out(2)(3) xor
                                 w_and_out(1)(4);
        --calculation for x^6
        w_factors_overflow(1) <= w_and_out(4)(2) xor 
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4);
        --calculation for x^7
        w_factors_overflow(2) <= w_and_out(4)(3) xor
                                 w_and_out(3)(4);
        --calculation for x^8
        w_factors_overflow(3) <= w_and_out(4)(4);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(3);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);
    end generate;

    gen_word_length_5_poly_61: if WORD_LENGTH = 5 and SELECTED_PRIMITIVE_POLYNOMIAL = 61 generate
        --galois field conversion
        --x^5 = x^4 + x^3 + x^2 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^4 + x^3 + x^2 + 1
        --x^6 => x^2 + x + 1
        --x^7 => x^3 + x^2 + x
        --x^8 => x^4 + x^3 + x^2

        --calculation for x^5
        w_factors_overflow(0) <= w_and_out(4)(1) xor 
                                 w_and_out(3)(2) xor
                                 w_and_out(2)(3) xor
                                 w_and_out(1)(4);
        --calculation for x^6
        w_factors_overflow(1) <= w_and_out(4)(2) xor 
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4);
        --calculation for x^7
        w_factors_overflow(2) <= w_and_out(4)(3) xor
                                 w_and_out(3)(4);
        --calculation for x^8
        w_factors_overflow(3) <= w_and_out(4)(4);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3);
    end generate;

    gen_word_length_6_poly_67: if WORD_LENGTH = 6 and SELECTED_PRIMITIVE_POLYNOMIAL = 67 generate
        --galois field conversion
        --x^6 = x + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^5
        --x^6 => x + 1
        --x^7 => x^2 + x^1
        --x^8 => x^3 + x^2
        --x^9 => x^4 + x^3
        --x^10 => x^5 + x^4

        --calculation for x^6
        w_factors_overflow(0) <= w_and_out(5)(1) xor 
                                 w_and_out(4)(2) xor
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4) xor
                                 w_and_out(1)(5);
        --calculation for x^7
        w_factors_overflow(1) <= w_and_out(5)(2) xor 
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5);
        --calculation for x^8
        w_factors_overflow(2) <= w_and_out(5)(3) xor 
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5);
        --calculation for x^9
        w_factors_overflow(3) <= w_and_out(5)(4) xor
                                 w_and_out(4)(5);
        --calculation for x^10
        w_factors_overflow(4) <= w_and_out(5)(5);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(4);
    end generate;

    gen_word_length_6_poly_103: if WORD_LENGTH = 6 and SELECTED_PRIMITIVE_POLYNOMIAL = 103 generate
        --galois field conversion
        --x^6 = x^5 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^5 + x^2 + x + 1
        --x^7  => x^5 + x^3 + 1
        --x^8  => x^5 + x^4 + x^2 + 1
        --x^9  => x^3 + x^2 + 1
        --x^10 => x^4 + x^3 + x

        --calculation for x^6
        w_factors_overflow(0) <= w_and_out(5)(1) xor 
                                 w_and_out(4)(2) xor
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4) xor
                                 w_and_out(1)(5);
        --calculation for x^7
        w_factors_overflow(1) <= w_and_out(5)(2) xor 
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5);
        --calculation for x^8
        w_factors_overflow(2) <= w_and_out(5)(3) xor 
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5);
        --calculation for x^9
        w_factors_overflow(3) <= w_and_out(5)(4) xor
                                 w_and_out(4)(5);
        --calculation for x^10
        w_factors_overflow(4) <= w_and_out(5)(5);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(4);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);
    end generate;

    gen_word_length_6_poly_109: if WORD_LENGTH = 6 and SELECTED_PRIMITIVE_POLYNOMIAL = 109 generate
        --galois field conversion
        --x^6 = x^5 + x^3 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^5 + x^3 + x^2 + 1
        --x^7  => x^5 + x^4 + x^2 + x + 1
        --x^8  => x + 1
        --x^9  => x^2 + x
        --x^10 => x^3 + x^2

        --calculation for x^6
        w_factors_overflow(0) <= w_and_out(5)(1) xor 
                                 w_and_out(4)(2) xor
                                 w_and_out(3)(3) xor
                                 w_and_out(2)(4) xor
                                 w_and_out(1)(5);
        --calculation for x^7
        w_factors_overflow(1) <= w_and_out(5)(2) xor 
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5);
        --calculation for x^8
        w_factors_overflow(2) <= w_and_out(5)(3) xor 
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5);
        --calculation for x^9
        w_factors_overflow(3) <= w_and_out(5)(4) xor
                                 w_and_out(4)(5);
        --calculation for x^10
        w_factors_overflow(4) <= w_and_out(5)(5);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);
    end generate;

    gen_word_length_7_poly_131: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 131 generate
        --galois field conversion
        --x^7 = x + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^5
        --x^6 => x^6
        --x^7 => x + 1
        --x^8 => x^2 + x
        --x^9 => x^3 + x^2
        --x^10 => x^4 + x^3
        --x^11 => x^5 + x^4
        --x^12 => x^6 + x^5

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor 
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor 
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor 
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor 
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_137: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 137 generate
        --galois field conversion
        --x^7 = x^3 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^3 + 1
        --x^8  => x^4 + x
        --x^9  => x^5 + x^2
        --x^10 => x^6 + x^3
        --x^11 => x^4 + x^3 + 1
        --x^12 => x^5 + x^4 + x

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(3);
    end generate;

    gen_word_length_7_poly_143: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 143 generate
        --galois field conversion
        --x^7 = x^3 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^3 + x^2 + x + 1
        --x^8  => x^4 + x^3 + x^2 + x
        --x^9  => x^5 + x^4 + x^3 + x^2
        --x^10 => x^6 + x^5 + x^4 + x^3
        --x^11 => x^6 + x^5 + x^4 + x^3 + x^2 + x + 1
        --x^12 => x^6 + x^5 + x^4 + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_157: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 157 generate
        --galois field conversion
        --x^7 = x^4 + x^3 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^4 + x^3 + x^2 + 1
        --x^8  => x^5 + x^4 + x^3 + x
        --x^9  => x^6 + x^5 + x^4 + x^2
        --x^10 => x^6 + x^5 + x^4 + x^2 + 1
        --x^11 => x^6 + x^5 + x^4 + x^2 + x + 1
        --x^12 => x^6 + x^5 + x^4 + x + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_191: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 191 generate
        --galois field conversion
        --x^7 = x^5 + x^4 + x^3 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^5 + x^4 + x^3 + x^2 + x + 1
        --x^8  => x^6 + x^5 + x^4 + x^3 + x^2 + x
        --x^9  => x^6 + x + 1
        --x^10 => x^5 + x^4 + x^3 + 1
        --x^11 => x^6 + x^5 + x^4 + x
        --x^12 => x^6 + x^4 + x^3 + x + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_203: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 203 generate
        --galois field conversion
        --x^7 = x^6 + x^3 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^6 + x^3 + x + 1
        --x^8  => x^6 + x^4 + x^3 + x^2 + 1
        --x^9  => x^6 + x^5 + x^4 + 1
        --x^10 => x^5 + x^3 + 1
        --x^11 => x^6 + x^4 + x
        --x^12 => x^6 + x^5 + x^3 + x^2 + x + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_213: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 213 generate
        --galois field conversion
        --x^7 = x^6 + x^4 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^6 + x^4 + x^2 + 1
        --x^8  => x^6 + x^5 + x^4 + x^3 + x^2 + x + 1
        --x^9  => x^5 + x^3 + x + 1
        --x^10 => x^6 + x^4 + x^2 + x
        --x^11 => x^6 + x^5 + x^4 + x^3 + 1
        --x^12 => x^5 + x^2 + x + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);
    end generate;

    gen_word_length_7_poly_229: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 229 generate
        --galois field conversion
        --x^7 = x^6 + x^5 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^6 + x^5 + x^2 + 1
        --x^8  => x^5 + x^3 + x^2 + x + 1
        --x^9  => x^6 + x^4 + x^3 + x^2 + x
        --x^10 => x^6 + x^4 + x^3 + 1
        --x^11 => x^6 + x^4 + x^2 + x + 1
        --x^12 => x^6 + x^3 + x + 1

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_7_poly_247: if WORD_LENGTH = 7 and SELECTED_PRIMITIVE_POLYNOMIAL = 247 generate
        --galois field conversion
        --x^7 = x^6 + x^5 + x^4 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^6 + x^5 + x^4 + x^2 + x + 1
        --x^8  => x^4 + x^3 + 1
        --x^9  => x^5 + x^4 + x
        --x^10 => x^6 + x^5 + x^2
        --x^11 => x^5 + x^4 + x^3 + x^2 + x + 1
        --x^12 => x^6 + x^5 + x^4 + x^3 + x^2 + x

        --calculation for x^7
        w_factors_overflow(0) <= w_and_out(6)(1) xor
                                 w_and_out(5)(2) xor
                                 w_and_out(4)(3) xor
                                 w_and_out(3)(4) xor
                                 w_and_out(2)(5) xor
                                 w_and_out(1)(6);
        --calculation for x^8
        w_factors_overflow(1) <= w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6);
        --calculation for x^9
        w_factors_overflow(2) <= w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6);
        --calculation for x^10
        w_factors_overflow(3) <= w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6);
        --calculation for x^11
        w_factors_overflow(4) <= w_and_out(6)(5) xor
                                 w_and_out(5)(6);
        --calculation for x^12
        w_factors_overflow(5) <= w_and_out(6)(6);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_8_poly_285: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 285 generate
        --galois field conversion
        --x^8 = x^4 + x^3 + x^2 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^5
        --x^6 => x^6
        --x^7 => x^7
        --x^8 => x^4 + x^3 + x^2 + 1
        --x^9 => x^5 + x^4 + x^3 + x
        --x^10 => x^6 + x^5 + x^4 + x^2
        --x^11 => x^7 + x^6 + x^5 + x^3
        --x^12 => x^7 + x^6 + x^3 + x^2 + 1
        --x^13 => x^7 + x^2 + x + 1
        --x^14 => x^4 + x + 1

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor 
                                 w_and_out(6)(2) xor
                                 w_and_out(5)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(3)(5) xor
                                 w_and_out(2)(6) xor
                                 w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor 
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor 
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor 
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor 
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                                 w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);
    end generate;

    gen_word_length_8_poly_299: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 299 generate
        --galois field conversion
        --x^8 = x^5 + x^3 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^5 + x^3 + x + 1
        --x^9  => x^6 + x^4 + x^2 + x
        --x^10 => x^7 + x^5 + x^3 + x^2
        --x^11 => x^6 + x^5 + x^4 + x + 1
        --x^12 => x^7 + x^6 + x^5 + x^2 + x
        --x^13 => x^7 + x^6 + x^5 + x^2 + x + 1
        --x^14 => x^7 + x^6 + x^5 + x^2 + 1

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

    end generate;

    gen_word_length_8_poly_351: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 351 generate
        --galois field conversion
        --x^8 = x^6 + x^4 + x^3 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^6 + x^4 + x^3 + x^2 + x + 1
        --x^9  => x^7 + x^5 + x^4 + x^3 + x^2 + x
        --x^10 => x^5 + x + 1
        --x^11 => x^6 + x^2 + x
        --x^12 => x^7 + x^3 + x^2
        --x^13 => x^6 + x^2 + x + 1
        --x^14 => x^7 + x^3 + x^2 + x

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

    end generate;

    gen_word_length_8_poly_355: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 355 generate
        --galois field conversion
        --x^8 = x^6 + x^5 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^6 + x^5 + x + 1
        --x^9  => x^7 + x^6 + x^2 + x
        --x^10 => x^7 + x^6 + x^5 + x^3 + x^2 + x + 1
        --x^11 => x^7 + x^5 + x^4 + x^3 + x^2 + 1
        --x^12 => x^4 + x^3 + 1
        --x^13 => x^5 + x^4 + x
        --x^14 => x^6 + x^5 + x^2

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

    end generate;

    gen_word_length_8_poly_357: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 357 generate
        --galois field conversion
        --x^8 = x^6 + x^5 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^6 + x^5 + x^2 + 1
        --x^9  => x^7 + x^6 + x^3 + x
        --x^10 => x^7 + x^6 + x^5 + x^4 + 1
        --x^11 => x^7 + x^2 + x + 1
        --x^12 => x^6 + x^5 + x^3 + x + 1
        --x^13 => x^7 + x^6 + x^4 + x^2 + x
        --x^14 => x^7 + x^6 + x^3 + 1

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

    end generate;

    gen_word_length_8_poly_361: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 361 generate
        --galois field conversion
        --x^8 = x^6 + x^5 + x^3 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^6 + x^5 + x^3 + 1
        --x^9  => x^7 + x^6 + x^4 + x
        --x^10 => x^7 + x^6 + x^3 + x^2 + 1
        --x^11 => x^7 + x^6 + x^5 + x^4 + x + 1
        --x^12 => x^7 + x^3 + x^2 + x + 1
        --x^13 => x^6 + x^5 + x^4 + x^2 + x + 1
        --x^14 => x^7 + x^6 + x^5 + x^3 + x^2 + x

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

    end generate;

    gen_word_length_8_poly_391: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 391 generate
        --galois field conversion
        --x^8 = x^7 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^7 + x^2 + x + 1
        --x^9  => x^7 + x^3 + 1
        --x^10 => x^7 + x^4 + x^2 + 1
        --x^11 => x^7 + x^5 + x^3 + x^2 + 1
        --x^12 => x^7 + x^6 + x^4 + x^3 + x^2 + 1
        --x^13 => x^5 + x^4 + x^3 + x^2 + 1
        --x^14 => x^6 + x^5 + x^4 + x^3 + x

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

    end generate;

    gen_word_length_8_poly_451: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 451 generate
        --galois field conversion
        --x^8 = x^7 + x^6 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^7 + x^6 + x + 1
        --x^9  => x^6 + x^2 + 1
        --x^10 => x^7 + x^3 + x
        --x^11 => x^7 + x^6 + x^4 + x^2 + x + 1
        --x^12 => x^6 + x^5 + x^3 + x^2 + 1
        --x^13 => x^7 + x^6 + x^4 + x^3 + x
        --x^14 => x^6 + x^5 + x^4 + x^2 + x + 1

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

    end generate;

    gen_word_length_8_poly_487: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 487 generate
        --galois field conversion
        --x^8 = x^7 + x^6 + x^5 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^7 + x^6 + x^5 + x^2 + x + 1
        --x^9  => x^5 + x^3 + 1
        --x^10 => x^6 + x^4 + x
        --x^11 => x^7 + x^5 + x^2
        --x^12 => x^7 + x^5 + x^3 + x^2 + x + 1
        --x^13 => x^7 + x^5 + x^4 + x^3 + 1
        --x^14 => x^7 + x^4 + x^2 + 1

        --calculation for x^8
        w_factors_overflow(0) <= w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7);
        --calculation for x^9
        w_factors_overflow(1) <= w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7);
        --calculation for x^10
        w_factors_overflow(2) <= w_and_out(7)(3) xor
                w_and_out(6)(4) xor
                w_and_out(5)(5) xor
                w_and_out(4)(6) xor
                w_and_out(3)(7);
        --calculation for x^11
        w_factors_overflow(3) <= w_and_out(7)(4) xor
                w_and_out(6)(5) xor
                w_and_out(5)(6) xor
                w_and_out(4)(7);
        --calculation for x^12
        w_factors_overflow(4) <= w_and_out(7)(5) xor
                w_and_out(6)(6) xor
                w_and_out(5)(7);
        --calculation for x^13
        w_factors_overflow(5) <= w_and_out(7)(6) xor
                w_and_out(6)(7);
        --calculation for x^14
        w_factors_overflow(6) <= w_and_out(7)(7);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

    end generate;

    gen_word_length_9_poly_529: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 529 generate
        --galois field conversion
        --x^9 = x^4 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^5
        --x^6 => x^6
        --x^7 => x^7
        --x^8 => x^8
        --x^9 => x^4 + 1
        --x^10 => x^5 + x
        --x^11 => x^6 + x^2
        --x^12 => x^7 + x^3
        --x^12 => x^8 + x^4
        --x^13 => x^5 + x^4 + 1
        --x^14 => x^6 + x^5 + x
        --x^15 => x^7 + x^6 + x^2
        --x^16 => x^8 + x^7 + x^3

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor 
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor 
                                 w_and_out(7)(3) xor
                                 w_and_out(4)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor 
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor 
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor 
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);

        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(3) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);
    end generate;

    gen_word_length_9_poly_557: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 557 generate
        --galois field conversion
        --x^9 = x^5 + x^3 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^5 + x^3 + x^2 + 1
        --x^10 => x^6 + x^4 + x^3 + x
        --x^11 => x^7 + x^5 + x^4 + x^2
        --x^12 => x^8 + x^6 + x^5 + x^3
        --x^13 => x^7 + x^6 + x^5 + x^4 + x^3 + x^2 + 1
        --x^14 => x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + x
        --x^15 => x^8 + x^7 + x^6 + x^4 + x^3 + 1
        --x^16 => x^8 + x^7 + x^4 + x^3 + x^2 + x + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_601: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 601 generate
        --galois field conversion
        --x^9 = x^6 + x^4 + x^3 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^6 + x^4 + x^3 + 1
        --x^10 => x^7 + x^5 + x^4 + x
        --x^11 => x^8 + x^6 + x^5 + x^2
        --x^12 => x^7 + x^4 + 1
        --x^13 => x^8 + x^5 + x
        --x^14 => x^4 + x^3 + x^2 + 1
        --x^15 => x^5 + x^4 + x^3 + x
        --x^16 => x^6 + x^5 + x^4 + x^2

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);
    end generate;
    gen_word_length_9_poly_623: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 623 generate
        --galois field conversion
        --x^9 = x^6 + x^5 + x^3 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^6 + x^5 + x^3 + x^2 + x + 1
        --x^10 => x^7 + x^6 + x^4 + x^3 + x^2 + x
        --x^11 => x^8 + x^7 + x^5 + x^4 + x^3 + x^2
        --x^12 => x^8 + x^4 + x^2 + x + 1
        --x^13 => x^6 + 1
        --x^14 => x^7 + x
        --x^15 => x^8 + x^2
        --x^16 => x^6 + x^5 + x^2 + x + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6);
    end generate;
    gen_word_length_9_poly_631: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 631 generate
        --galois field conversion
        --x^9 = x^6 + x^5 + x^4 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^6 + x^5 + x^4 + x^2 + x + 1
        --x^10 => x^7 + x^6 + x^5 + x^3 + x^2 + x
        --x^11 => x^8 + x^7 + x^6 + x^4 + x^3 + x^2
        --x^12 => x^8 + x^7 + x^6 + x^3 + x^2 + x + 1
        --x^13 => x^8 + x^7 + x^6 + x^5 + x^3 + 1
        --x^14 => x^8 + x^7 + x^5 + x^2 + 1
        --x^15 => x^8 + x^5 + x^4 + x^3 + x^2 + 1
        --x^16 => x^3 + x^2 + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);
    end generate;
    gen_word_length_9_poly_731: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 731 generate
        --galois field conversion
        --x^9 = x^7 + x^6 + x^4 + x^3 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^7 + x^6 + x^4 + x^3 + x + 1
        --x^10 => x^8 + x^7 + x^5 + x^4 + x^2 + x
        --x^11 => x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
        --x^12 => x^8 + x^7 + x^5 + x^4 + x^2 + 1
        --x^13 => x^8 + x^7 + x^5 + x^4 + 1
        --x^14 => x^8 + x^7 + x^5 + x^4 + x^3 + 1
        --x^15 => x^8 + x^7 + x^5 + x^3 + 1
        --x^16 => x^8 + x^7 + x^3 + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_787: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 787 generate
        --galois field conversion
        --x^9 = x^8 + x^4 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^4 + x + 1
        --x^10 => x^8 + x^5 + x^4 + x^2 + 1
        --x^11 => x^8 + x^6 + x^5 + x^4 + x^3 + 1
        --x^12 => x^8 + x^7 + x^6 + x^5 + 1
        --x^13 => x^7 + x^6 + x^4 + 1
        --x^14 => x^8 + x^7 + x^5 + x
        --x^15 => x^6 + x^4 + x^2 + x + 1
        --x^16 => x^7 + x^5 + x^3 + x^2 + x

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);
    end generate;
    gen_word_length_9_poly_817: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 817 generate
        --galois field conversion
        --x^9 = x^8 + x^5 + x^4 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^5 + x^4 + 1
        --x^10 => x^8 + x^6 + x^4 + x + 1
        --x^11 => x^8 + x^7 + x^4 + x^2 + x + 1
        --x^12 => x^4 + x^3 + x^2 + x + 1
        --x^13 => x^5 + x^4 + x^3 + x^2 + x
        --x^14 => x^6 + x^5 + x^4 + x^3 + x^2
        --x^15 => x^7 + x^6 + x^5 + x^4 + x^3
        --x^16 => x^8 + x^7 + x^6 + x^5 + x^4

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_865: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 865 generate
        --galois field conversion
        --x^9 = x^8 + x^6 + x^5 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^6 + x^5 + 1
        --x^10 => x^8 + x^7 + x^5 + x + 1
        --x^11 => x^5 + x^2 + x + 1
        --x^12 => x^6 + x^3 + x^2 + x
        --x^13 => x^7 + x^4 + x^3 + x^2
        --x^14 => x^8 + x^5 + x^4 + x^3
        --x^15 => x^8 + x^4 + 1
        --x^16 => x^8 + x^6 + x + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_875: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 875 generate
        --galois field conversion
        --x^9 = x^8 + x^6 + x^5 + x^3 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^6 + x^5 + x^3 + x + 1
        --x^10 => x^8 + x^7 + x^5 + x^4 + x^3 + x^2 + 1
        --x^11 => x^4 + 1
        --x^12 => x^5 + x
        --x^13 => x^6 + x^2
        --x^14 => x^7 + x^3
        --x^15 => x^8 + x^4
        --x^16 => x^8 + x^6 + x^3 + x + 1

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_901: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 901 generate
        --galois field conversion
        --x^9 = x^8 + x^7 + x^2 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^7 + x^2 + 1
        --x^10 => x^7 + x^3 + x^2 + x + 1
        --x^11 => x^8 + x^4 + x^3 + x^2 + x
        --x^12 => x^8 + x^7 + x^5 + x^4 + x^3 + 1
        --x^13 => x^7 + x^6 + x^5 + x^4 + x^2 + x + 1
        --x^14 => x^8 + x^7 + x^6 + x^5 + x^3 + x^2 + x
        --x^15 => x^6 + x^4 + x^3 + 1
        --x^16 => x^7 + x^5 + x^4 + x

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);
    end generate;
    gen_word_length_9_poly_911: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 911 generate
        --galois field conversion
        --x^9 = x^8 + x^7 + x^3 + x^2 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^7 + x^3 + x^2 + x + 1
        --x^10 => x^7 + x^4 + 1
        --x^11 => x^8 + x^5 + x
        --x^12 => x^8 + x^7 + x^6 + x^3 + x + 1
        --x^13 => x^4 + x^3 + 1
        --x^14 => x^5 + x^4 + x
        --x^15 => x^6 + x^5 + x^2
        --x^16 => x^7 + x^6 + x^3

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);
    end generate;
    gen_word_length_9_poly_995: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 995 generate
        --galois field conversion
        --x^9 = x^8 + x^7 + x^6 + x^5 + x + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^7 + x^6 + x^5 + x + 1
        --x^10 => x^5 + x^2 + 1
        --x^11 => x^6 + x^3 + x
        --x^12 => x^7 + x^4 + x^2
        --x^13 => x^8 + x^5 + x^3
        --x^14 => x^8 + x^7 + x^5 + x^4 + x + 1
        --x^15 => x^7 + x^2 + 1
        --x^16 => x^8 + x^3 + x

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_9_poly_1001: if WORD_LENGTH = 9 and SELECTED_PRIMITIVE_POLYNOMIAL = 1001 generate
        --galois field conversion
        --x^9 = x^8 + x^7 + x^6 + x^5 + x^3 + 1
        --0    => 0
        --x^0  => 1
        --x^1  => x
        --x^2  => x^2
        --x^3  => x^3
        --x^4  => x^4
        --x^5  => x^5
        --x^6  => x^6
        --x^7  => x^7
        --x^8  => x^8
        --x^9  => x^8 + x^7 + x^6 + x^5 + x^3 + 1
        --x^10 => x^5 + x^4 + x^3 + x + 1
        --x^11 => x^6 + x^5 + x^4 + x^2 + x
        --x^12 => x^7 + x^6 + x^5 + x^3 + x^2
        --x^13 => x^8 + x^7 + x^6 + x^4 + x^3
        --x^14 => x^6 + x^4 + x^3 + 1
        --x^15 => x^7 + x^5 + x^4 + x
        --x^16 => x^8 + x^6 + x^5 + x^2

        --calculation for x^9
        w_factors_overflow(0) <= w_and_out(8)(1) xor
                                 w_and_out(7)(2) xor
                                 w_and_out(6)(3) xor
                                 w_and_out(5)(4) xor
                                 w_and_out(4)(5) xor
                                 w_and_out(3)(6) xor
                                 w_and_out(2)(7) xor
                                 w_and_out(1)(8);
        --calculation for x^10
        w_factors_overflow(1) <= w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8);
        --calculation for x^11
        w_factors_overflow(2) <= w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8);
        --calculation for x^12
        w_factors_overflow(3) <= w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8);
        --calculation for x^13
        w_factors_overflow(4) <= w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8);
        --calculation for x^14
        w_factors_overflow(5) <= w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8);
        --calculation for x^15
        w_factors_overflow(6) <= w_and_out(8)(7) xor
                                 w_and_out(7)(8);
        --calculation for x^16
        w_factors_overflow(7) <= w_and_out(8)(8);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_10_poly_1033: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1033 generate
        --galois field conversion
        --x^10 = x^3 + 1
        --0   => 0
        --x^0 => 1
        --x^1 => x
        --x^2 => x^2
        --x^3 => x^3
        --x^4 => x^4
        --x^5 => x^5
        --x^6 => x^6
        --x^7 => x^7
        --x^8 => x^8
        --x^9 => x^0
        --x^10 => x^3 + 1
        --x^11 => x^4 + x
        --x^12 => x^5 + x^2
        --x^12 => x^6 + x^3
        --x^13 => x^7 + x^4
        --x^14 => x^8 + x^5
        --x^15 => x^9 + x^6
        --x^16 => x^7 + x^3 + 1
        --x^17 => x^8 + x^4 + x
        --x^18 => x^9 + x^5 + x^2

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor 
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor 
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor 
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor 
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor 
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);

        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);

        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);
        
        o(0) <= w_and_out(0)(0) xor 
                w_factors_overflow(0) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(0)(1) xor
                w_and_out(1)(0) xor 
                w_factors_overflow(1) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(9);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(9);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(6) xor
                w_factors_overflow(9);
    end generate;
    gen_word_length_10_poly_1051: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1051 generate
        --galois field conversion
        --x^10 = x^4 + x^3 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^4 + x^3 + x + 1
        --x^11  => x^5 + x^4 + x^2 + x
        --x^12  => x^6 + x^5 + x^3 + x^2
        --x^13  => x^7 + x^6 + x^4 + x^3
        --x^14  => x^8 + x^7 + x^5 + x^4
        --x^15  => x^9 + x^8 + x^6 + x^5
        --x^16  => x^9 + x^7 + x^6 + x^4 + x^3 + x + 1
        --x^17  => x^8 + x^7 + x^5 + x^3 + x^2 + 1
        --x^18  => x^9 + x^8 + x^6 + x^4 + x^3 + x

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_1135: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1135 generate
        --galois field conversion
        --x^10 = x^6 + x^5 + x^3 + x^2 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^6 + x^5 + x^3 + x^2 + x + 1
        --x^11  => x^7 + x^6 + x^4 + x^3 + x^2 + x
        --x^12  => x^8 + x^7 + x^5 + x^4 + x^3 + x^2
        --x^13  => x^9 + x^8 + x^6 + x^5 + x^4 + x^3
        --x^14  => x^9 + x^7 + x^4 + x^3 + x^2 + x + 1
        --x^15  => x^8 + x^6 + x^4 + 1
        --x^16  => x^9 + x^7 + x^5 + x
        --x^17  => x^8 + x^5 + x^3 + x + 1
        --x^18  => x^9 + x^6 + x^4 + x^2 + x

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_1293: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1293 generate
        --galois field conversion
        --x^10 = x^8 + x^3 + x^2 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^3 + x^2 + 1
        --x^11  => x^9 + x^4 + x^3 + x
        --x^12  => x^8 + x^5 + x^4 + x^3 + 1
        --x^13  => x^9 + x^6 + x^5 + x^4 + x
        --x^14  => x^8 + x^7 + x^6 + x^5 + x^3 + 1
        --x^15  => x^9 + x^8 + x^7 + x^6 + x^4 + x
        --x^16  => x^9 + x^7 + x^5 + x^3 + 1
        --x^17  => x^6 + x^4 + x^3 + x^2 + x + 1
        --x^18  => x^7 + x^5 + x^4 + x^3 + x^2 + x

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);
    end generate;
    gen_word_length_10_poly_1305: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1305 generate
        --galois field conversion
        --x^10 = x^8 + x^4 + x^3 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^4 + x^3 + 1
        --x^11  => x^9 + x^5 + x^4 + x
        --x^12  => x^8 + x^6 + x^5 + x^4 + x^3 + x^2 + 1
        --x^13  => x^9 + x^7 + x^6 + x^5 + x^4 + x^3 + x
        --x^14  => x^7 + x^6 + x^5 + x^3 + x^2 + 1
        --x^15  => x^8 + x^7 + x^6 + x^4 + x^3 + x
        --x^16  => x^9 + x^8 + x^7 + x^5 + x^4 + x^2
        --x^17  => x^9 + x^6 + x^5 + x^4 + 1
        --x^18  => x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + x + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_10_poly_1315: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1315 generate
        --galois field conversion
        --x^10 = x^8 + x^5 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^5 + x + 1
        --x^11  => x^9 + x^6 + x^2 + x
        --x^12  => x^8 + x^7 + x^5 + x^3 + x^2 + x + 1
        --x^13  => x^9 + x^8 + x^6 + x^4 + x^3 + x^2 + x
        --x^14  => x^9 + x^8 + x^7 + x^4 + x^3 + x^2 + x + 1
        --x^15  => x^9 + x^4 + x^3 + x^2 + 1
        --x^16  => x^8 + x^4 + x^3 + 1
        --x^17  => x^9 + x^5 + x^4 + x
        --x^18  => x^8 + x^6 + x^2 + x + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_10_poly_1329: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1329 generate
        --galois field conversion
        --x^10 = x^8 + x^5 + x^4 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^5 + x^4 + 1
        --x^11  => x^9 + x^6 + x^5 + x
        --x^12  => x^8 + x^7 + x^6 + x^5 + x^4 + x^2 + 1
        --x^13  => x^9 + x^8 + x^7 + x^6 + x^5 + x^3 + x
        --x^14  => x^9 + x^7 + x^6 + x^5 + x^2 + 1
        --x^15  => x^7 + x^6 + x^5 + x^4 + x^3 + x + 1
        --x^16  => x^8 + x^7 + x^6 + x^5 + x^4 + x^2 + x
        --x^17  => x^9 + x^8 + x^7 + x^6 + x^5 + x^3 + x^2
        --x^18  => x^9 + x^7 + x^6 + x^5 + x^3 + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_1509: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1509 generate
        --galois field conversion
        --x^10 = x^8 + x^7 + x^6 + x^5 + x^2 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^7 + x^6 + x^5 + x^2 + 1
        --x^11  => x^9 + x^8 + x^7 + x^6 + x^3 + x
        --x^12  => x^9 + x^6 + x^5 + x^4 + 1
        --x^13  => x^8 + x^2 + x + 1
        --x^14  => x^9 + x^3 + x^2 + x
        --x^15  => x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + 1
        --x^16  => x^9 + x^8 + x^7 + x^6 + x^5 + x^4 + x
        --x^17  => x^9 + 1
        --x^18  => x^8 + x^7 + x^6 + x^5 + x^2 + x + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_10_poly_1531: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1531 generate
        --galois field conversion
        --x^10 = x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + x + 1
        --x^11  => x^9 + x^8 + x^7 + x^6 + x^5 + x^4 + x^2 + x
        --x^12  => x^9 + x^4 + x^2 + x + 1
        --x^13  => x^8 + x^7 + x^6 + x^4 + x^2 + 1
        --x^14  => x^9 + x^8 + x^7 + x^5 + x^3 + x
        --x^15  => x^9 + x^7 + x^5 + x^3 + x^2 + x + 1
        --x^16  => x^7 + x^5 + x^2 + 1
        --x^17  => x^8 + x^6 + x^3 + x
        --x^18  => x^9 + x^7 + x^4 + x^2

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_1555: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1555 generate
        --galois field conversion
        --x^10 = x^9 + x^4 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^9 + x^4 + x + 1
        --x^11  => x^9 + x^5 + x^4 + x^2 + 1
        --x^12  => x^9 + x^6 + x^5 + x^4 + x^3 + 1
        --x^13  => x^9 + x^7 + x^6 + x^5 + 1
        --x^14  => x^9 + x^8 + x^7 + x^6 + x^4 + 1
        --x^15  => x^8 + x^7 + x^5 + x^4 + 1
        --x^16  => x^9 + x^8 + x^6 + x^5 + x
        --x^17  => x^7 + x^6 + x^4 + x^2 + x + 1
        --x^18  => x^8 + x^7 + x^5 + x^3 + x^2 + x

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);
    end generate;
    gen_word_length_10_poly_1687: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1687 generate
        --galois field conversion
        --x^10 = x^9 + x^6 + x^5 + x^4 + x^3 + x^2 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^9 + x^7 + x^4 + x^2 + x + 1
        --x^11  => x^9 + x^8 + x^7 + x^5 + x^4 + x^3 + 1
        --x^12  => x^8 + x^7 + x^6 + x^5 + x^2 + 1
        --x^13  => x^9 + x^8 + x^7 + x^6 + x^3 + x
        --x^14  => x^8 + x + 1
        --x^15  => x^9 + x^2 + x
        --x^16  => x^9 + x^7 + x^4 + x^3 + x + 1
        --x^17  => x^9 + x^8 + x^7 + x^5 + 1
        --x^18  => x^8 + x^7 + x^6 + x^4 + x^2 + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);
    end generate;
    gen_word_length_10_poly_1869: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1869 generate
        --galois field conversion
        --x^10 = x^9 + x^8 + x^6 + x^3 + x^2 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^9 + x^8 + x^6 + x^3 + x^2 + 1
        --x^11  => x^8 + x^7 + x^6 + x^4 + x^2 + x + 1
        --x^12  => x^9 + x^8 + x^7 + x^5 + x^3 + x^2 + x
        --x^13  => x^4 + 1
        --x^14  => x^5 + x
        --x^15  => x^6 + x^2
        --x^16  => x^7 + x^3
        --x^17  => x^8 + x^4
        --x^18  => x^9 + x^5

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(5);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(7);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(5);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(6);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(7);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_1891: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 1891 generate
        --galois field conversion
        --x^10 = x^9 + x^8 + x^6 + x^5 + x + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^9 + x^8 + x^6 + x^5 + x + 1
        --x^11  => x^8 + x^7 + x^5 + x^2 + 1
        --x^12  => x^9 + x^8 + x^6 + x^3 + x
        --x^13  => x^8 + x^7 + x^6 + x^5 + x^4 + x^2 + x + 1
        --x^14  => x^9 + x^8 + x^7 + x^6 + x^5 + x^3 + x^2 + x
        --x^15  => x^7 + x^5 + x^4 + x^3 + x^2 + x + 1
        --x^16  => x^8 + x^6 + x^5 + x^4 + x^3 + x^2 + x
        --x^17  => x^9 + x^7 + x^6 + x^5 + x^4 + x^3 + x^2
        --x^18  => x^9 + x^7 + x^4 + x^3 + x + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);
    end generate;
    gen_word_length_10_poly_2041: if WORD_LENGTH = 10 and SELECTED_PRIMITIVE_POLYNOMIAL = 2041 generate
        --galois field conversion
        --x^10 = x^9 + x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + 1
        --0     => 0
        --x^0   => 1
        --x^1   => x
        --x^2   => x^2
        --x^3   => x^3
        --x^4   => x^4
        --x^5   => x^5
        --x^6   => x^6
        --x^7   => x^7
        --x^8   => x^8
        --x^9   => x^9
        --x^10  => x^9 + x^8 + x^7 + x^6 + x^5 + x^4 + x^3 + 1
        --x^11  => x^3 + x + 1
        --x^12  => x^4 + x^2 + x
        --x^13  => x^5 + x^3 + x^2
        --x^14  => x^6 + x^4 + x^3
        --x^15  => x^7 + x^5 + x^4
        --x^16  => x^8 + x^6 + x^5
        --x^17  => x^9 + x^7 + x^6
        --x^18  => x^9 + x^6 + x^5 + x^4 + x^3 + 1

        --calculation for x^10
        w_factors_overflow(0) <= w_and_out(9)(1) xor
                                 w_and_out(8)(2) xor
                                 w_and_out(7)(3) xor
                                 w_and_out(6)(4) xor
                                 w_and_out(5)(5) xor
                                 w_and_out(4)(6) xor
                                 w_and_out(3)(7) xor
                                 w_and_out(2)(8) xor
                                 w_and_out(1)(9);
        --calculation for x^11
        w_factors_overflow(1) <= w_and_out(9)(2) xor
                                 w_and_out(8)(3) xor
                                 w_and_out(7)(4) xor
                                 w_and_out(6)(5) xor
                                 w_and_out(5)(6) xor
                                 w_and_out(4)(7) xor
                                 w_and_out(3)(8) xor
                                 w_and_out(2)(9);
        --calculation for x^12
        w_factors_overflow(2) <= w_and_out(9)(3) xor
                                 w_and_out(8)(4) xor
                                 w_and_out(7)(5) xor
                                 w_and_out(6)(6) xor
                                 w_and_out(5)(7) xor
                                 w_and_out(4)(8) xor
                                 w_and_out(3)(9);
        --calculation for x^13
        w_factors_overflow(3) <= w_and_out(9)(4) xor
                                 w_and_out(8)(5) xor
                                 w_and_out(7)(6) xor
                                 w_and_out(6)(7) xor
                                 w_and_out(5)(8) xor
                                 w_and_out(4)(9);
        --calculation for x^14
        w_factors_overflow(4) <= w_and_out(9)(5) xor
                                 w_and_out(8)(6) xor
                                 w_and_out(7)(7) xor
                                 w_and_out(6)(8) xor
                                 w_and_out(5)(9);
        --calculation for x^15
        w_factors_overflow(5) <= w_and_out(9)(6) xor
                                 w_and_out(8)(7) xor
                                 w_and_out(7)(8) xor
                                 w_and_out(6)(9);
        --calculation for x^16
        w_factors_overflow(6) <= w_and_out(9)(7) xor
                                 w_and_out(8)(8) xor
                                 w_and_out(7)(9);
        --calculation for x^17
        w_factors_overflow(7) <= w_and_out(9)(8) xor
                                 w_and_out(8)(9);
        --calculation for x^18
        w_factors_overflow(8) <= w_and_out(9)(9);

        o(0) <= w_and_out(0)(0) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(8);

        o(1) <= w_and_out(1)(0) xor
                w_and_out(0)(1) xor
                w_factors_overflow(1) xor
                w_factors_overflow(2);

        o(2) <= w_and_out(2)(0) xor
                w_and_out(1)(1) xor
                w_and_out(0)(2) xor
                w_factors_overflow(2) xor
                w_factors_overflow(3);

        o(3) <= w_and_out(3)(0) xor
                w_and_out(2)(1) xor
                w_and_out(1)(2) xor
                w_and_out(0)(3) xor
                w_factors_overflow(0) xor
                w_factors_overflow(1) xor
                w_factors_overflow(3) xor
                w_factors_overflow(4) xor
                w_factors_overflow(8);

        o(4) <= w_and_out(4)(0) xor
                w_and_out(3)(1) xor
                w_and_out(2)(2) xor
                w_and_out(1)(3) xor
                w_and_out(0)(4) xor
                w_factors_overflow(0) xor
                w_factors_overflow(2) xor
                w_factors_overflow(4) xor
                w_factors_overflow(5) xor
                w_factors_overflow(8);

        o(5) <= w_and_out(5)(0) xor
                w_and_out(4)(1) xor
                w_and_out(3)(2) xor
                w_and_out(2)(3) xor
                w_and_out(1)(4) xor
                w_and_out(0)(5) xor
                w_factors_overflow(0) xor
                w_factors_overflow(3) xor
                w_factors_overflow(5) xor
                w_factors_overflow(6) xor
                w_factors_overflow(8);

        o(6) <= w_and_out(6)(0) xor
                w_and_out(5)(1) xor
                w_and_out(4)(2) xor
                w_and_out(3)(3) xor
                w_and_out(2)(4) xor
                w_and_out(1)(5) xor
                w_and_out(0)(6) xor
                w_factors_overflow(0) xor
                w_factors_overflow(4) xor
                w_factors_overflow(6) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);

        o(7) <= w_and_out(7)(0) xor
                w_and_out(6)(1) xor
                w_and_out(5)(2) xor
                w_and_out(4)(3) xor
                w_and_out(3)(4) xor
                w_and_out(2)(5) xor
                w_and_out(1)(6) xor
                w_and_out(0)(7) xor
                w_factors_overflow(0) xor
                w_factors_overflow(5) xor
                w_factors_overflow(7);

        o(8) <= w_and_out(8)(0) xor
                w_and_out(7)(1) xor
                w_and_out(6)(2) xor
                w_and_out(5)(3) xor
                w_and_out(4)(4) xor
                w_and_out(3)(5) xor
                w_and_out(2)(6) xor
                w_and_out(1)(7) xor
                w_and_out(0)(8) xor
                w_factors_overflow(0) xor
                w_factors_overflow(6);

        o(9) <= w_and_out(9)(0) xor
                w_and_out(8)(1) xor
                w_and_out(7)(2) xor
                w_and_out(6)(3) xor
                w_and_out(5)(4) xor
                w_and_out(4)(5) xor
                w_and_out(3)(6) xor
                w_and_out(2)(7) xor
                w_and_out(1)(8) xor
                w_and_out(0)(9) xor
                w_factors_overflow(0) xor
                w_factors_overflow(7) xor
                w_factors_overflow(8);
    end generate;
    --TODO: WORD_LENGTH 0 and 1 should be covered here as well.
    gen_not_supported: if WORD_LENGTH > 10 generate
        o <= (others => '0');
    end generate;
end behavioral;
