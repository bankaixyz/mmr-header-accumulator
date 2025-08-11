
pub mod input;
pub mod mmr;

// pub fn run_hint(
//     vm: &mut VirtualMachine,
//     exec_scope: &mut ExecutionScopes,
//     hint_data: &HintProcessorData,
//     constants: &HashMap<String, Felt252>,
// ) -> Result<(), HintError> {
//     let hints = [print::run_hint, sha::run_hint];

//     for hint in hints.iter() {
//         let res = hint(vm, exec_scope, hint_data, constants);
//         if !matches!(res, Err(HintError::UnknownHint(_))) {
//             return res;
//         }
//     }
//     Err(HintError::UnknownHint(
//         hint_data.code.to_string().into_boxed_str(),
//     ))
// }
