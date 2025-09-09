use cairo_vm_base::types::{felt::Felt, uint256::Uint256};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BeaconHeaderCairo {
    pub slot: Felt,
    pub proposer_index: Felt,
    pub parent_root: Uint256,
    pub state_root: Uint256,
    pub body_root: Uint256,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MmrSnapshotCairo {
    pub keccak_root: Uint256,
    pub poseidon_root: Felt,
    pub elements_count: Felt,
    pub leafs_count: Felt,
    pub keccak_peaks: Vec<Uint256>,
    pub poseidon_peaks: Vec<Felt>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LastLeafProofCairo {
    pub header_root: Uint256,
    pub header_position: Felt,
    pub path_len: Felt,
    pub poseidon_path: Vec<Felt>,
    pub keccak_path: Vec<Uint256>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeaconMmrUpdateCairo {
    pub start_snapshot: MmrSnapshotCairo,
    pub end_snapshot: MmrSnapshotCairo,
    pub added_headers: Vec<BeaconHeaderCairo>,
    pub last_leaf_proof: Option<LastLeafProofCairo>,
}