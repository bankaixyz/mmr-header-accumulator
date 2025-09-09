from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.registers import get_fp_and_pc
from src.mmr.types import MmrSnapshot
from src.mmr.core import initialize_peaks_dicts, construct_mmr
from src.mmr.utils import (
    assert_mmr_size_is_valid,
    compute_peaks_positions,
    bag_peaks,
    get_full_mmr_peak_values,
    compute_height_pre_alloc_pow2 as compute_height,
    get_roots,
)
from src.debug.lib import print_felt_hex, print_uint256, print_felt, print_string

func initialize_peaks{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
}(start_mmr_snapshot: MmrSnapshot, end_mmr_snapshot: MmrSnapshot) -> (
    start_peaks_dict_poseidon: DictAccess*,
    start_peaks_dict_keccak: DictAccess*,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
) {
    alloc_locals;

    // Ensure the MMR size is valid
    assert_mmr_size_is_valid{pow2_array=pow2_array}(start_mmr_snapshot.elements_count);
    assert_mmr_size_is_valid{pow2_array=pow2_array}(end_mmr_snapshot.elements_count);  // Sanity check

    // Compute previous_peaks_positions given the previous MMR size (from left to right), as well:
    let (start_peaks_positions: felt*, start_peaks_positions_len: felt) = compute_peaks_positions{
        pow2_array=pow2_array
    }(start_mmr_snapshot.elements_count);

    // Compute bagged peaks
    let (bagged_peaks_poseidon, bagged_peaks_keccak) = bag_peaks(
        start_mmr_snapshot.poseidon_peaks,
        start_mmr_snapshot.keccak_peaks,
        start_peaks_positions_len,
    );

    // Compute roots
    let (root_poseidon) = poseidon_hash(start_mmr_snapshot.elements_count, bagged_peaks_poseidon);

    let (keccak_input: felt*) = alloc();
    let inputs_start = keccak_input;
    keccak_add_uint256{inputs=keccak_input}(num=Uint256(start_mmr_snapshot.elements_count, 0), bigend=1);
    keccak_add_uint256{inputs=keccak_input}(num=bagged_peaks_keccak, bigend=1);
    let (root_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
    let (root_keccak) = uint256_reverse_endian(root_keccak);

    // Check that the start roots matche the ones provided in the program's input:
    assert 0 = root_poseidon - start_mmr_snapshot.poseidon_root;
    assert 0 = root_keccak.low - start_mmr_snapshot.keccak_root.low;
    assert 0 = root_keccak.high - start_mmr_snapshot.keccak_root.high;

    // Initialize peaks dicts
    let (local peaks_dict_poseidon) = default_dict_new(default_value=0);
    let (local peaks_dict_keccak) = default_dict_new(default_value=0);
    tempvar start_peaks_dict_poseidon = peaks_dict_poseidon;
    tempvar start_peaks_dict_keccak = peaks_dict_keccak;

    initialize_peaks_dicts{
        dict_end_poseidon=peaks_dict_poseidon, dict_end_keccak=peaks_dict_keccak
    }(
        start_peaks_positions_len - 1,
        start_peaks_positions,
        start_mmr_snapshot.poseidon_peaks,
        start_mmr_snapshot.keccak_peaks,
    );

    return (
        start_peaks_dict_poseidon, start_peaks_dict_keccak, peaks_dict_poseidon, peaks_dict_keccak
    );
}

func grow_mmr{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(mmr_size: felt, keccak_leafs: Uint256*, poseidon_leafs: felt*, n_headers: felt) -> (
    new_mmr_root_poseidon: felt, new_mmr_root_keccak: Uint256, new_mmr_size: felt
) {
    let (mmr_array_keccak: Uint256*) = alloc();
    let (mmr_array_poseidon: felt*) = alloc();
    let mmr_array_len = 0;
    let mmr_offset = mmr_size;

    with poseidon_leafs, keccak_leafs, mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, mmr_offset, peaks_dict_poseidon, peaks_dict_keccak {
        construct_mmr(index=0, n_leaves=n_headers);
    }

    with mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, peaks_dict_poseidon, peaks_dict_keccak, mmr_offset {
        let (new_mmr_root_poseidon: felt, new_mmr_root_keccak: Uint256) = get_roots();
    }

    return (
        new_mmr_root_poseidon=new_mmr_root_poseidon,
        new_mmr_root_keccak=new_mmr_root_keccak,
        new_mmr_size=mmr_array_len + mmr_offset,
    );
}

// Ensure the DictAccess is valid and the new roots match the expected values
func finalize_mmr{range_check_ptr}(
    end_mmr_snapshot: MmrSnapshot,
    new_mmr_root_poseidon: felt,
    new_mmr_root_keccak: Uint256,
    new_mmr_size: felt,
    start_peaks_dict_poseidon: DictAccess*,
    peaks_dict_poseidon: DictAccess*,
    start_peaks_dict_keccak: DictAccess*,
    peaks_dict_keccak: DictAccess*,
) {
    // Ensure the dict accesses are valid
    default_dict_finalize(start_peaks_dict_poseidon, peaks_dict_poseidon, 0);
    default_dict_finalize(start_peaks_dict_keccak, peaks_dict_keccak, 0);

    // Assert the new roots match the expected values
    assert end_mmr_snapshot.poseidon_root = new_mmr_root_poseidon;
    assert end_mmr_snapshot.keccak_root.low = new_mmr_root_keccak.low;
    assert end_mmr_snapshot.keccak_root.high = new_mmr_root_keccak.high;
    assert end_mmr_snapshot.elements_count = new_mmr_size;

    print_string('New Poseidon root: ');
    print_felt_hex(new_mmr_root_poseidon);
    print_string('New Keccak root: ');
    print_uint256(new_mmr_root_keccak);
    print_string('New MMR size: ');
    print_felt(new_mmr_size);

    return ();
}
