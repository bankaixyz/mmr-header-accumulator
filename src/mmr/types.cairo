from starkware.cairo.common.uint256 import Uint256

struct MmrSnapshot {
    keccak_root: Uint256,
    poseidon_root: felt,
    elements_count: felt,
    keccak_peaks: Uint256*,
    poseidon_peaks: felt*,
    peaks_len: felt,
}

struct LastLeafProof {
    header_root: Uint256,
    header_position: felt,
    path_len: felt,
    poseidon_path: felt*,
    keccak_path: Uint256*,
}
