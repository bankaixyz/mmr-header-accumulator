use std::collections::HashMap;

use cairo_vm_base::default_hints::HintImpl;

use crate::hints::mmr::{
    hint_is_position_in_mmr_array, mmr_bit_length, mmr_left_child, HINT_IS_POSITION_IN_MMR_ARRAY,
    MMR_BIT_LENGTH, MMR_LEFT_CHILD,
};

pub mod input;
pub mod mmr;

pub fn get_hints() -> HashMap<String, HintImpl> {
    let mut hints = HashMap::<String, HintImpl>::new();
    hints.insert(MMR_BIT_LENGTH.to_string(), mmr_bit_length);
    hints.insert(MMR_LEFT_CHILD.to_string(), mmr_left_child);
    hints.insert(
        HINT_IS_POSITION_IN_MMR_ARRAY.to_string(),
        hint_is_position_in_mmr_array,
    );
    hints
}
