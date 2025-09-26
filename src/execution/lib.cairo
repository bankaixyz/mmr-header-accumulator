from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak

from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from src.core.ssz import SSZ
from src.core.sha import SHA256
from src.execution.utils import get_hash_value
from src.debug.lib import print_uint256, print_string
from src.mmr.leaf_hash import poseidon_uint256, keccak_uint256
from src.mmr.types import MmrSnapshot, LastLeafProof
from src.mmr.lib import initialize_peaks, finalize_mmr, grow_mmr
from src.mmr.utils import assert_is_last_leaf_in_mmr
from src.mmr.core import hash_subtree_path_poseidon, hash_subtree_path_keccak

func run_execution_mmr_update{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    sha256_ptr: felt*,
}() -> (
    new_keccak_root: Uint256, new_poseidon_root: felt, new_mmr_size: felt, last_header_root: Uint256
) {
    alloc_locals;

    let (headers: felt**) = alloc();
    let (headers_bytes_len: felt*) = alloc();
    local n_headers: felt;

    local start_mmr_snapshot: MmrSnapshot;
    local end_mmr_snapshot: MmrSnapshot;
    local last_leaf_proof: LastLeafProof;

    %{ write_execution_input() %}

    let (
        start_peaks_dict_poseidon, start_peaks_dict_keccak, peaks_dict_poseidon, peaks_dict_keccak
    ) = initialize_peaks(start_mmr_snapshot=start_mmr_snapshot, end_mmr_snapshot=end_mmr_snapshot);

    with pow2_array, peaks_dict_poseidon, peaks_dict_keccak {
        verify_last_leaf(proof=last_leaf_proof, start_mmr=start_mmr_snapshot);
    }

    let (poseidon_hashes: felt*) = alloc();
    let (keccak_hashes: Uint256*) = alloc();

    tempvar is_genesis: felt;
    // The tree is empty, if the elements_count is 1. in this case, we need to skip the initial linkage check
    if (start_mmr_snapshot.elements_count == 1) {
        is_genesis = 1;
    } else {
        is_genesis = 0;
    }

    let (last_header_root) = assert_header_linkage(
        previous_header_hash=last_leaf_proof.header_root,
        headers=headers,
        headers_bytes_len=headers_bytes_len,
        index=0,
        count=n_headers,
        poseidon_hashes=poseidon_hashes,
        keccak_hashes=keccak_hashes,
        is_genesis=is_genesis,
    );

    with peaks_dict_poseidon, peaks_dict_keccak {
        let (new_poseidon_root, new_keccak_root, new_mmr_size) = grow_mmr(
            mmr_size=start_mmr_snapshot.elements_count,
            keccak_leafs=keccak_hashes,
            poseidon_leafs=poseidon_hashes,
            n_headers=n_headers,
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
        new_keccak_root=new_keccak_root,
        new_poseidon_root=new_poseidon_root,
        new_mmr_size=new_mmr_size,
        last_header_root=last_header_root,
    );
}

// To ensure we dont have any gaps in the MMR, we verify the proof of the last leaf of each MMR
// this should then be the parent_root of the first header we add to the MMR
func verify_last_leaf{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(proof: LastLeafProof, start_mmr: MmrSnapshot) {
    alloc_locals;

    let (poseidon_leaf) = poseidon_uint256(leaf=proof.header_root);

    let (peak_poseidon, peak_poseidon_pos, _) = hash_subtree_path_poseidon(
        element=poseidon_leaf,
        height=0,
        position=proof.header_position,
        inclusion_proof=proof.poseidon_path,
        inclusion_proof_len=proof.path_len,
    );

    let (peak_poseidon_value) = dict_read{dict_ptr=peaks_dict_poseidon}(key=peak_poseidon_pos);
    assert peak_poseidon_value = peak_poseidon;

    let (keccak_leaf) = keccak_uint256(leaf=proof.header_root);
    let (peak_keccak, peak_keccak_pos, _) = hash_subtree_path_keccak(
        element=keccak_leaf,
        height=0,
        position=proof.header_position,
        inclusion_proof=proof.keccak_path,
        inclusion_proof_len=proof.path_len,
    );

    let (peak_keccak_ptr: Uint256*) = dict_read{dict_ptr=peaks_dict_keccak}(key=peak_keccak_pos);
    assert peak_keccak.low = peak_keccak_ptr.low;
    assert peak_keccak.high = peak_keccak_ptr.high;

    assert_is_last_leaf_in_mmr(mmr_size=start_mmr.elements_count, position=proof.header_position);

    return ();
}

func assert_header_linkage{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    sha256_ptr: felt*,
}(
    previous_header_hash: Uint256,
    headers: felt**,
    headers_bytes_len: felt*,
    index: felt,
    count: felt,
    poseidon_hashes: felt*,
    keccak_hashes: Uint256*,
    is_genesis: felt,
) -> (last_header_hash: Uint256) {
    alloc_locals;
    if (count == index) {
        return (last_header_hash=previous_header_hash);
    }

    let (parent_hash) = get_hash_value(rlp=headers[index], word_idx=0, offset=4);
    if (is_genesis != 1) {
        assert parent_hash.high = previous_header_hash.high;
        assert parent_hash.low = previous_header_hash.low;
    }

    let (header_hash_keccak: Uint256) = cairo_keccak(
        inputs=headers[index], n_bytes=headers_bytes_len[index]
    );

    let (poseidon_hash) = poseidon_uint256(header_hash_keccak);
    let (keccak_hash) = keccak_uint256(header_hash_keccak);

    assert poseidon_hashes[0] = poseidon_hash;
    assert keccak_hashes[0].low = keccak_hash.low;
    assert keccak_hashes[0].high = keccak_hash.high;

    return assert_header_linkage(
        previous_header_hash=header_hash_keccak,
        headers=headers,
        headers_bytes_len=headers_bytes_len,
        index=index + 1,
        count=count - 1,
        poseidon_hashes=poseidon_hashes + 1,
        keccak_hashes=keccak_hashes + Uint256.SIZE,
        is_genesis=0,
    );

    
}