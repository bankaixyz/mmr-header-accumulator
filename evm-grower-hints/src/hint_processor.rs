use crate::hints::{
    input::{ChainIntegration, MmrInput},
    mmr::{
        hint_is_position_in_mmr_array, mmr_bit_length, mmr_left_child,
        HINT_IS_POSITION_IN_MMR_ARRAY, MMR_BIT_LENGTH, MMR_LEFT_CHILD,
    },
};
use rust_vm_hints::default_hints::{default_hint_mapping, HintImpl};
use rust_vm_hints::{
    cairo_type::CairoWritable,
    vm::cairo_vm::{
        hint_processor::{
            builtin_hint_processor::{
                builtin_hint_processor_definition::{BuiltinHintProcessor, HintProcessorData},
                hint_utils::{get_ptr_from_var_name, get_relocatable_from_var_name},
            },
            hint_processor_definition::{HintExtension, HintProcessorLogic},
        },
        types::exec_scope::ExecutionScopes,
        vm::{
            errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker,
            vm_core::VirtualMachine,
        },
        Felt252,
    },
};
use std::any::Any;
use std::collections::HashMap;

pub struct CustomHintProcessor {
    hints: HashMap<String, HintImpl>,
    builtin_hint_proc: BuiltinHintProcessor,
}

pub const HINT_WRITE_BEACON_INPUT: &str = "write_beacon_input()";

impl Default for CustomHintProcessor {
    fn default() -> Self {
        Self::new()
    }
}

impl CustomHintProcessor {
    pub fn new() -> Self {
        Self {
            hints: Self::hints(),
            builtin_hint_proc: BuiltinHintProcessor::new_empty(),
        }
    }

    fn hints() -> HashMap<String, HintImpl> {
        let mut hints = default_hint_mapping();
        hints.insert(MMR_BIT_LENGTH.to_string(), mmr_bit_length);
        hints.insert(MMR_LEFT_CHILD.to_string(), mmr_left_child);
        hints.insert(
            HINT_IS_POSITION_IN_MMR_ARRAY.to_string(),
            hint_is_position_in_mmr_array,
        );
        hints
    }

    fn write_beacon_input(
        &self,
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
}

impl HintProcessorLogic for CustomHintProcessor {
    fn execute_hint(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        self.builtin_hint_proc
            .execute_hint(vm, exec_scopes, hint_data, constants)
    }

    fn execute_hint_extensive(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt252>,
    ) -> Result<HintExtension, HintError> {
        if let Some(hpd) = hint_data.downcast_ref::<HintProcessorData>() {
            let hint_code = hpd.code.as_str();

            let res = match hint_code {
                HINT_WRITE_BEACON_INPUT => self.write_beacon_input(vm, exec_scopes, hpd, constants),
                _ => Err(HintError::UnknownHint(
                    hint_code.to_string().into_boxed_str(),
                )),
            };

            if !matches!(res, Err(HintError::UnknownHint(_))) {
                return res.map(|_| HintExtension::default());
            }

            // First try our custom hints
            if let Some(hint_impl) = self.hints.get(hint_code) {
                return hint_impl(vm, exec_scopes, hpd, constants)
                    .map(|_| HintExtension::default());
            }

            // If not found, try the builtin hint processor
            return self
                .builtin_hint_proc
                .execute_hint(vm, exec_scopes, hint_data, constants)
                .map(|_| HintExtension::default());
        }

        Err(HintError::WrongHintData)
    }
}

impl ResourceTracker for CustomHintProcessor {}
