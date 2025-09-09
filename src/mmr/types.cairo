from starkware.cairo.common.uint256 import Uint256

struct MmrSnapshot {
    elements_count: felt,
    poseidon_root: felt,
    poseidon_peaks: felt*,
    keccak_root: Uint256,
    keccak_peaks: Uint256*,
    peaks_len: felt,
}

struct LastLeafProof {
    header_root: Uint256,
    header_position: felt,
    path_len: felt,
    poseidon_path: felt*,
    keccak_path: Uint256*,
}
