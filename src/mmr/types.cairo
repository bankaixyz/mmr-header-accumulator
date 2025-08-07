from starkware.cairo.common.uint256 import Uint256

struct MmrSnapshot {
    size: felt,
    poseidon_root: felt,
    poseidon_peaks: felt*,
    keccak_root: Uint256,
    keccak_peaks: Uint256*,
    peaks_len: felt,
}



