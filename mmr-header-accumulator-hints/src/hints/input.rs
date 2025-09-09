use std::collections::HashMap;

use cairo_vm_base::cairo_type::{CairoType, CairoWritable};
use cairo_vm_base::vm::cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm_base::vm::cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_ptr_from_var_name, get_relocatable_from_var_name};
use cairo_vm_base::vm::cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError;
use cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine;
use cairo_vm_base::vm::cairo_vm::Felt252;

use crate::types::{BeaconHeaderCairo, BeaconMmrUpdateCairo, LastLeafProofCairo, MmrSnapshotCairo};

pub const HINT_WRITE_BEACON_INPUT: &str = "write_beacon_input()";

pub fn write_beacon_input(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let beacon_mmr_update: BeaconMmrUpdateCairo = exec_scopes
        .get::<BeaconMmrUpdateCairo>("beacon_mmr_update")
        .unwrap();
    let start_mmr_snapshot_ptr = get_relocatable_from_var_name(
        "start_mmr_snapshot",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    beacon_mmr_update
        .start_snapshot
        .to_memory(vm, start_mmr_snapshot_ptr)?;

    let end_mmr_snapshot_ptr = get_relocatable_from_var_name(
        "end_mmr_snapshot",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    beacon_mmr_update
        .end_snapshot
        .to_memory(vm, end_mmr_snapshot_ptr)?;

    // let last_leaf_proof_ptr = get_relocatable_from_var_name(
    //     "last_leaf_proof",
    //     vm,
    //     &hint_data.ids_data,
    //     &hint_data.ap_tracking,
    // )?;

    // beacon_input
    //     .last_leaf_proof
    //     .to_memory(vm, last_leaf_proof_ptr)?;

    let mut headers_ptr =
        get_ptr_from_var_name("headers", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    for header in beacon_mmr_update.added_headers.iter() {
        headers_ptr = header.to_memory(vm, headers_ptr)?;
    }

    let n_headers = get_relocatable_from_var_name(
        "n_headers",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    vm.insert_value(
        n_headers,
        Felt252::from(beacon_mmr_update.added_headers.len()),
    )?;

    Ok(())
}

impl CairoWritable for MmrSnapshotCairo {
    fn to_memory(
        &self,
        vm: &mut cairo_vm_base::vm::cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
    ) -> Result<
        cairo_vm_base::vm::cairo_vm::types::relocatable::Relocatable,
        cairo_vm_base::vm::cairo_vm::vm::errors::hint_errors::HintError,
    > {
        let address_start = address;
        let address = self.keccak_root.to_memory(vm, address)?;
        let address = self.poseidon_root.to_memory(vm, address)?;
        let address = self.elements_count.to_memory(vm, address)?;

        // Create segment for keccak peaks and store its pointer
        let keccak_peaks_segment = vm.add_memory_segment();
        vm.insert_value(address, keccak_peaks_segment)?;
        let mut segment_ptr = keccak_peaks_segment;
        for peak in &self.keccak_peaks {
            segment_ptr = peak.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;

        // Create segment for poseidon peaks and store its pointer
        let poseidon_peaks_segment = vm.add_memory_segment();
        vm.insert_value(address, poseidon_peaks_segment)?;
        let mut segment_ptr = poseidon_peaks_segment;
        for peak in &self.poseidon_peaks {
            segment_ptr = peak.to_memory(vm, segment_ptr)?;
        }
        let address = (address + 1)?;

        vm.insert_value(address, Felt252::from(self.poseidon_peaks.len()))?;
        let address = (address + 1)?;

        assert!(address == (address_start + Self::n_fields())?);

        Ok(address)
    }

    fn n_fields() -> usize {
        7
    }
}

impl CairoWritable for LastLeafProofCairo {
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

impl CairoWritable for BeaconHeaderCairo {
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
