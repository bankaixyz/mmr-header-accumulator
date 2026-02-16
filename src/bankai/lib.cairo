from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from src.mmr.leaf_hash import poseidon_uint256
from src.mmr.types import MmrSnapshot
from src.mmr.lib import initialize_peaks, finalize_mmr, grow_mmr

func run_bankai_mmr_update{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
}(
    leaf: Uint256
) -> (new_keccak_root: Uint256, new_poseidon_root: felt, new_mmr_size: felt) {
    alloc_locals;

    local start_mmr_snapshot: MmrSnapshot;
    local end_mmr_snapshot: MmrSnapshot;

    %{ write_bankai_input() %}

    let (
        start_peaks_dict_poseidon, start_peaks_dict_keccak, peaks_dict_poseidon, peaks_dict_keccak
    ) = initialize_peaks(start_mmr_snapshot=start_mmr_snapshot, end_mmr_snapshot=end_mmr_snapshot);

    let (poseidon_hashes: felt*) = alloc();
    let (keccak_hashes: Uint256*) = alloc();

    let (poseidon_hash) = poseidon_uint256(leaf=leaf);
    assert poseidon_hashes[0] = poseidon_hash;

    assert keccak_hashes[0].low = leaf.low;
    assert keccak_hashes[0].high = leaf.high;

    with peaks_dict_poseidon, peaks_dict_keccak {
        let (new_poseidon_root, new_keccak_root, new_mmr_size) = grow_mmr(
            mmr_size=start_mmr_snapshot.elements_count,
            keccak_leafs=keccak_hashes,
            poseidon_leafs=poseidon_hashes,
            n_headers=1,
        );
    }

    with peaks_dict_poseidon, peaks_dict_keccak {
        finalize_mmr(
            end_mmr_snapshot=end_mmr_snapshot,
            new_mmr_root_poseidon=new_poseidon_root,
            new_mmr_root_keccak=new_keccak_root,
            new_mmr_size=new_mmr_size,
            start_peaks_dict_poseidon=start_peaks_dict_poseidon,
            peaks_dict_poseidon=peaks_dict_poseidon,
            start_peaks_dict_keccak=start_peaks_dict_keccak,
            peaks_dict_keccak=peaks_dict_keccak,
        );
    }

    return (
        new_keccak_root=new_keccak_root, new_poseidon_root=new_poseidon_root, new_mmr_size=new_mmr_size
    );
}
