from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import KeccakBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_uint256s_bigend
from starkware.cairo.common.builtin_keccak.keccak import (
    keccak_uint256s_bigend as builtin_keccak_uint256s_bigend,
)
from src.core.utils import bitwise_divmod

const USE_BUILTIN_KECCAK = 0;

func keccak_uint256_bigend{range_check_ptr, keccak_ptr: felt*, bitwise_ptr: BitwiseBuiltin*}(
    leaf: Uint256
) -> (res: Uint256) {
    let (__fp__, _) = get_fp_and_pc();

    let (hash) = keccak_uint256s_bigend(1, &leaf);

    return (res=hash);
}

func keccak_uint256_pair_bigend{range_check_ptr, keccak_ptr: felt*, bitwise_ptr: BitwiseBuiltin*}(
    leaf1: Uint256, leaf2: Uint256
) -> (res: Uint256) {
    let (__fp__, _) = get_fp_and_pc();

    let (leafs_felt_ptr: felt*) = alloc();
    let leafs_ptr = cast(leafs_felt_ptr, Uint256*);
    assert leafs_ptr[0] = leaf1;
    assert leafs_ptr[1] = leaf2;

    let (hash) = keccak_uint256s_bigend(2, leafs_ptr);
    return (res=hash);
}

func keccak_uint256s_bigend{range_check_ptr, keccak_ptr: felt*, bitwise_ptr: BitwiseBuiltin*}(
    n_leafs: felt, leafs: Uint256*
) -> (res: Uint256) {
    let (__fp__, _) = get_fp_and_pc();

    if (USE_BUILTIN_KECCAK == 1) {
        // Builtin keccak path (STONE): cast felt* to KeccakBuiltin* and call builtin keccak.
        let keccak_ptr_builtin = cast(keccak_ptr, KeccakBuiltin*);
        let (hash) = builtin_keccak_uint256s_bigend{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr_builtin
        }(n_leafs, leafs);

        // Cast ptr back to felt*
        tempvar keccak_ptr = cast(keccak_ptr_builtin, felt*);
        return (res=hash);
    }

    // Cairo-keccak path (STWO): uncomment to use the felt*-based implementation.
    let (hash) = cairo_keccak_uint256s_bigend(n_leafs, leafs);

    return (res=hash);
}
