use rust_vm_hints::vm::cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const MMR_BIT_LENGTH: &str = "ids.bit_length = ids.mmr_len.bit_length()";

pub fn mmr_bit_length(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let x = get_integer_from_var_name("mmr_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name(
        "bit_length",
        MaybeRelocatable::Int(x.bits().into()),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const MMR_LEFT_CHILD: &str = "ids.in_mmr = 1 if ids.left_child <= ids.mmr_len else 0";

pub fn mmr_left_child(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_child = get_integer_from_var_name(
        "left_child",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    let mmr_len =
        get_integer_from_var_name("mmr_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let in_mmr = if left_child <= mmr_len {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };
    insert_value_from_var_name(
        "in_mmr",
        MaybeRelocatable::Int(in_mmr),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const HINT_IS_POSITION_IN_MMR_ARRAY: &str =
    "ids.is_position_in_mmr_array= 1 if ids.position > ids.mmr_offset else 0";

pub fn hint_is_position_in_mmr_array(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let position =
        get_integer_from_var_name("position", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let mmr_offset = get_integer_from_var_name(
        "mmr_offset",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let is_position_in_mmr_array = if position > mmr_offset {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };
    insert_value_from_var_name(
        "is_position_in_mmr_array",
        MaybeRelocatable::Int(is_position_in_mmr_array),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}
