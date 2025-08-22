from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import KeccakBuiltin, PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.builtin_keccak.keccak import keccak_uint256s_bigend
from src.core.utils import bitwise_divmod

func keccak_uint256{range_check_ptr, keccak_ptr: KeccakBuiltin*, bitwise_ptr: BitwiseBuiltin*}(
    leaf: Uint256
) -> (res: Uint256) {
    let (__fp__, _) = get_fp_and_pc();

    let (hash) = keccak_uint256s_bigend(1, &leaf);
    return (res=hash);
}

func poseidon_uint256{range_check_ptr, poseidon_ptr: PoseidonBuiltin*}(leaf: Uint256) -> (
    res: felt
) {
    let (hash) = poseidon_hash(leaf.low, leaf.high);
    return (res=hash);
}
