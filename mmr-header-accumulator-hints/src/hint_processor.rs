use crate::hints::{
    input::{write_beacon_input, HINT_WRITE_BEACON_INPUT},
    mmr::{
        hint_is_position_in_mmr_array, mmr_bit_length, mmr_left_child,
        HINT_IS_POSITION_IN_MMR_ARRAY, MMR_BIT_LENGTH, MMR_LEFT_CHILD,
    },
};
use cairo_vm_base::default_hints::{default_hint_mapping, HintImpl};
use cairo_vm_base::vm::cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{
            BuiltinHintProcessor, HintProcessorData,
        },
        hint_processor_definition::{HintExtension, HintProcessorLogic},
    },
    types::exec_scope::ExecutionScopes,
    vm::{
        errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker,
        vm_core::VirtualMachine,
    },
    Felt252,
};
use std::any::Any;
use std::collections::HashMap;

pub struct CustomHintProcessor {
    hints: HashMap<String, HintImpl>,
    builtin_hint_proc: BuiltinHintProcessor,
}

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
                HINT_WRITE_BEACON_INPUT => write_beacon_input(vm, exec_scopes, hpd, constants),
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
