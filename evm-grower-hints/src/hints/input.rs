use rust_vm_hints::cairo_type::{CairoType, CairoWritable};
use rust_vm_hints::types::{felt::Felt, uint256::Uint256};
use rust_vm_hints::types::serde_utils::{deserialize_from_any, deserialize_vec_from_string};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BeaconHeader {
    #[serde(deserialize_with = "deserialize_from_any")]
    pub slot: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub proposer_index: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub parent_root: Uint256,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub state_root: Uint256,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub body_root: Uint256,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BeaconHeaderWithRoot {
    #[serde(deserialize_with = "deserialize_from_any")]
    pub root: Uint256,
    pub header: BeaconHeader,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MmrSnapshot {
    #[serde(alias = "elements_count")]
    #[serde(deserialize_with = "deserialize_from_any")]
    pub size: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub poseidon_root: Felt,
    #[serde(alias = "poseidon_peaks")]
    #[serde(deserialize_with = "deserialize_vec_from_string")]
    pub poseidon_peaks: Vec<Felt>,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub keccak_root: Uint256,
    #[serde(alias = "keccak_peaks")]
    #[serde(deserialize_with = "deserialize_vec_from_string")]
    pub keccak_peaks: Vec<Uint256>,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub peaks_len: Felt,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LastLeafProof {
    #[serde(deserialize_with = "deserialize_from_any")]
    pub header_root: Uint256,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub header_position: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub path_len: Felt,
    #[serde(deserialize_with = "deserialize_vec_from_string")]
    pub poseidon_path: Vec<Felt>,
    #[serde(deserialize_with = "deserialize_vec_from_string")]
    pub keccak_path: Vec<Uint256>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ChainIntegration {
    pub name: String,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub network_id: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub start_height: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub end_height: Felt,
    pub headers: Vec<BeaconHeaderWithRoot>,
    pub last_leaf_proof: LastLeafProof,
    pub start_mmr: MmrSnapshot,
    pub end_mmr: MmrSnapshot,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MmrInput {
    #[serde(deserialize_with = "deserialize_from_any")]
    pub epoch_number: Felt,
    #[serde(deserialize_with = "deserialize_from_any")]
    pub block_number: Felt,
    pub chain_integrations: Vec<ChainIntegration>,
}

impl MmrInput {
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        let input: MmrInput = serde_json::from_str(json)?;
        Ok(input)
    }
}

impl CairoWritable for MmrSnapshot {
    fn to_memory(
        &self,
        vm: &mut rust_vm_hints::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable, rust_vm_hints::vm::cairo_vm::vm::errors::hint_errors::HintError> {
        let address_start = address;
        let address = self.size.to_memory(vm, address)?;
        let address = self.poseidon_root.to_memory(vm, address)?;

        // Create segment for poseidon peaks and store its pointer
        let poseidon_peaks_segment = vm.add_memory_segment();
        vm.insert_value(address, poseidon_peaks_segment)?;
        let mut segment_ptr = poseidon_peaks_segment;
        for peak in &self.poseidon_peaks {
            segment_ptr = peak.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;

        let address = self.keccak_root.to_memory(vm, address)?;

        // Create segment for keccak peaks and store its pointer
        let keccak_peaks_segment = vm.add_memory_segment();
        vm.insert_value(address, keccak_peaks_segment)?;
        let mut segment_ptr = keccak_peaks_segment;
        for peak in &self.keccak_peaks {
            segment_ptr = peak.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;
        let address = self.peaks_len.to_memory(vm, address)?;

        assert!(address == (address_start + Self::n_fields())?);

        Ok(address)
    }

    fn n_fields() -> usize {
        7
    }
}

impl CairoWritable for LastLeafProof {
    fn to_memory(
        &self,
        vm: &mut rust_vm_hints::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable, rust_vm_hints::vm::cairo_vm::vm::errors::hint_errors::HintError> {
        let address_start = address;
        let address = self.header_root.to_memory(vm, address)?;
        let address = self.header_position.to_memory(vm, address)?;
        let address = self.path_len.to_memory(vm, address)?;

        // Create segment for poseidon path and store its pointer
        let poseidon_path_segment = vm.add_memory_segment();
        vm.insert_value(address, poseidon_path_segment)?;
        let mut segment_ptr = poseidon_path_segment;
        for path in &self.poseidon_path {
            segment_ptr = path.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;

        // Create segment for keccak path and store its pointer
        let keccak_path_segment = vm.add_memory_segment();
        vm.insert_value(address, keccak_path_segment)?;
        let mut segment_ptr = keccak_path_segment;
        for path in &self.keccak_path {
            segment_ptr = path.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;

        assert!(address == (address_start + Self::n_fields())?);

        Ok(address)
    }

    fn n_fields() -> usize {
        6
    }
}

impl CairoWritable for BeaconHeader {
    fn to_memory(
        &self,
        vm: &mut rust_vm_hints::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<rust_vm_hints::vm::cairo_vm::types::relocatable::Relocatable, rust_vm_hints::vm::cairo_vm::vm::errors::hint_errors::HintError> {
        let address_start = address;
        let address = self.slot.to_memory(vm, address)?;
        let address = self.proposer_index.to_memory(vm, address)?;
        let address = self.parent_root.to_memory(vm, address)?;
        let address = self.state_root.to_memory(vm, address)?;
        let address = self.body_root.to_memory(vm, address)?;

        assert!(address == (address_start + Self::n_fields())?);

        Ok(address)
    }

    fn n_fields() -> usize {
        8
    }
}