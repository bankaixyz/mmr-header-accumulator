from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.core.utils import felt_divmod

func get_hash_value{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    rlp: felt*, word_idx: felt, offset: felt
) -> (res: Uint256) {
    let shifter = (8 - offset) * 8;
    let devisor = pow2_array[offset * 8];

    let rlp_0 = rlp[word_idx];
    let (rlp_0, thrash) = felt_divmod(rlp_0, devisor);
    let rlp_1 = rlp[word_idx + 1];
    let rlp_2 = rlp[word_idx + 2];
    let (rlp_2_left, rlp_2_right) = felt_divmod(rlp_2, devisor);
    let rlp_3 = rlp[word_idx + 3];
    let rlp_4 = rlp[word_idx + 4];
    let (tash, rlp_4) = felt_divmod(rlp_4, devisor);

    let res_low = rlp_2_right * pow2_array[shifter + 64] + rlp_1 * pow2_array[shifter] + rlp_0;
    let res_high = rlp_4 * pow2_array[shifter + 64] + rlp_3 * pow2_array[shifter] + rlp_2_left;

    let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
    return (res=result);
}
