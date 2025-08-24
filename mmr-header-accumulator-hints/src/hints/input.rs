use std::collections::HashMap;

use cairo_vm_base::cairo_type::{CairoType, CairoWritable};
use cairo_vm_base::types::{felt::Felt, uint256::Uint256};
use cairo_vm_base::vm::cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm_base::vm::cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_ptr_from_var_name, get_relocatable_from_var_name};
use cairo_vm_base::vm::cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError;
use cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine;
use cairo_vm_base::vm::cairo_vm::Felt252;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BeaconHeader {
    pub slot: Felt,
    pub proposer_index: Felt,
    pub parent_root: Uint256,
    pub state_root: Uint256,
    pub body_root: Uint256,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct BeaconHeaderWithRoot {
    pub root: Uint256,
    pub header: BeaconHeader,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MmrSnapshot {
    #[serde(alias = "elements_count")]
    pub size: Felt,
    pub poseidon_root: Felt,
    #[serde(alias = "poseidon_peaks")]
    pub poseidon_peaks: Vec<Felt>,
    pub keccak_root: Uint256,
    #[serde(alias = "keccak_peaks")]
    pub keccak_peaks: Vec<Uint256>,
    pub peaks_len: Felt,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LastLeafProof {
    pub header_root: Uint256,
    pub header_position: Felt,
    pub path_len: Felt,
    pub poseidon_path: Vec<Felt>,
    pub keccak_path: Vec<Uint256>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ChainIntegration {
    pub name: String,
    pub network_id: Felt,
    pub start_height: Felt,
    pub end_height: Felt,
    pub headers: Vec<BeaconHeaderWithRoot>,
    pub last_leaf_proof: LastLeafProof,
    pub start_mmr: MmrSnapshot,
    pub end_mmr: MmrSnapshot,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MmrInput {
    pub epoch_number: Felt,
    pub block_number: Felt,
    pub chain_integrations: Vec<ChainIntegration>,
}

impl MmrInput {
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        let input: MmrInput = serde_json::from_str(json)?;
        Ok(input)
    }
}

pub fn write_beacon_input(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let mmr_input: MmrInput = exec_scopes.get::<MmrInput>("mmr_input").unwrap();
    let beacon_input: ChainIntegration = mmr_input.chain_integrations[0].clone();
    let start_mmr_snapshot_ptr = get_relocatable_from_var_name(
        "start_mmr_snapshot",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    beacon_input
        .start_mmr
        .to_memory(vm, start_mmr_snapshot_ptr)?;

    let end_mmr_snapshot_ptr = get_relocatable_from_var_name(
        "end_mmr_snapshot",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    beacon_input.end_mmr.to_memory(vm, end_mmr_snapshot_ptr)?;

    let last_leaf_proof_ptr = get_relocatable_from_var_name(
        "last_leaf_proof",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    beacon_input
        .last_leaf_proof
        .to_memory(vm, last_leaf_proof_ptr)?;

    let mut headers_ptr =
        get_ptr_from_var_name("headers", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    for header in beacon_input.headers.iter() {
        headers_ptr = header.header.to_memory(vm, headers_ptr)?;
    }

    let n_headers = get_relocatable_from_var_name(
        "n_headers",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    vm.insert_value(n_headers, Felt252::from(beacon_input.headers.len()))?;

    Ok(())
}

impl CairoWritable for MmrSnapshot {
    fn to_memory(
        &self,
        vm: &mut cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<
        cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
        cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError,
    > {
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
        vm: &mut cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<
        cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
        cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError,
    > {
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
        vm: &mut cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<
        cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
        cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError,
    > {
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
