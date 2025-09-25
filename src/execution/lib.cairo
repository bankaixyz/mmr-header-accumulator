from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from src.beacon.types import BeaconHeader
from src.core.ssz import SSZ
from src.core.sha import SHA256
from src.debug.lib import print_uint256, print_string
from src.mmr.leaf_hash import poseidon_uint256, keccak_uint256
from src.mmr.types import MmrSnapshot, LastLeafProof
from src.mmr.lib import initialize_peaks, finalize_mmr, grow_mmr
from src.mmr.utils import assert_is_last_leaf_in_mmr
from src.mmr.core import hash_subtree_path_poseidon, hash_subtree_path_keccak

func run_beacon_mmr_update{
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
    local n_headers: felt;

    // local start_mmr_snapshot: MmrSnapshot;
    // local end_mmr_snapshot: MmrSnapshot;
    // local last_leaf_proof: LastLeafProof;

    %{ write_execution_input() %}

    let (poseidon_hashes: felt*) = alloc();
    let (keccak_hashes: Uint256*) = alloc();

    tempvar is_genesis: felt;
    // The tree is empty, if the elements_count is 1. in this case, we need to skip the initial linkage check
    if (start_mmr_snapshot.elements_count == 1) {
        is_genesis = 1;
    } else {
        is_genesis = 0;
    }



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

    if (is_genesis != 1) {
        let (parent_hash) = get_hash_value(rlp=headers[index], word_idx=0, offset=4);

        assert parent_hash.high = previous_header_hash.high;
        assert parent_hash.low = previous_header_hash.low;
    }

    let (header_hash_keccak: Uint256) = keccak(
        inputs=headers[index], n_bytes=headers_bytes_len[index]
    );

    let (poseidon_hash) = poseidon_uint256(header_hash_keccak);
    let (keccak_hash) = keccak_uint256(header_hash_keccak);

    
}