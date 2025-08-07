from starkware.cairo.common.uint256 import Uint256

struct BeaconHeader {
    slot: felt,
    proposer_index: felt,
    parent_root: Uint256,
    state_root: Uint256,
    body_root: Uint256,
}