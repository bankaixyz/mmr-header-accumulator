from starkware.cairo.common.registers import get_fp_and_pc, get_label_location
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// Returns q and r such that:
//  0 <= q < rc_bound, 0 <= r < div and value = q * div + r.
//
// Assumption: 0 < div <= PRIME / rc_bound.
// Prover assumption: value / div < rc_bound.
// Modified version of unsigned_div_rem with inlined range checks.
func felt_divmod{range_check_ptr}(value, div) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.div)
        assert 0 < ids.div <= PRIME // range_check_builtin.bound, \
            f'div={hex(ids.div)} is out of the valid range.'
        ids.q, ids.r = divmod(ids.value, ids.div)
    %}
    assert [range_check_ptr + 2] = div - 1 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * div + r;
    return (q, r);
}


// Computes x//y and x%y.
// Assumption: y must be a power of 2
// params:
//   x: the dividend.
//   y: the divisor.
// returns:
//   q: the quotient.
//   r: the remainder.
func bitwise_divmod{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (q: felt, r: felt) {
    if (y == 1) {
        let bitwise_ptr = bitwise_ptr;
        return (q=x, r=0);
    } else {
        assert bitwise_ptr.x = x;
        assert bitwise_ptr.y = y - 1;
        let x_and_y = bitwise_ptr.x_and_y;

        let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return (q=(x - x_and_y) / y, r=x_and_y);
    }
}

// Returns the number of bits in x.
// Implicits arguments:
// - pow2_array: felt* - A pointer such that pow2_array[i] = 2^i for i in [0, 127].
// Params:
// - x: felt - Input value.
// Assumptions for the caller:
// - 1 <= x < 2^127
// Returns:
// - bit_length: felt - Number of bits in x.
func get_felt_bitlength{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{ ids.bit_length = ids.x.bit_length() %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits
    tempvar N = pow2_array[bit_length];
    tempvar n = pow2_array[bit_length - 1];
    assert [range_check_ptr] = bit_length;
    assert [range_check_ptr + 1] = 127 - bit_length;
    assert [range_check_ptr + 2] = N - x - 1;
    assert [range_check_ptr + 3] = x - n;
    tempvar range_check_ptr = range_check_ptr + 4;
    return bit_length;
}

// Utility to get a pointer on an array of 2^i from i = 0 to 128.
func pow2alloc128() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
    dw 0x100000000000000000000000000000000;
}