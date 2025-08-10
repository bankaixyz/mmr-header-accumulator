from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.registers import get_fp_and_pc
from src.mmr.utils import assert_mmr_size_is_valid, compute_peaks_positions, bag_peaks, get_full_mmr_peak_values, compute_height_pre_alloc_pow2, get_roots
from src.mmr.types import MmrSnapshot
from src.debug.lib import print_felt_hex, print_uint256, print_felt

// Stores the values inside peaks_values_poseidon and peaks_values_keccak in two dictionaries represented by their end pointers,
// such that:
// - dict_poseidon[peak_positions[i]] = peaks_values_poseidon[i]
// - dict_keccak[peak_positions[i]] = &peaks_values_keccak[i].
// Since cairo dicts only allow felts values, for keccak, the Uint256 is stored by casting a pointer of the value to a felt.
// See the function get_full_mmr_peak_values for the reverse operation.
//
// Implicit arguments:
// - dict_end_poseidon: DictAccess* - the end of the dictionary for the Poseidon MMR
// - dict_end_keccak: DictAccess* - the end of the dictionary for the Keccak MMR
//
// Params:
// - index: felt - the index of the array to be stored in the dictionary
//   Should be equal to the computed peaks_len given the validated MMR size, - 1.
// - peaks_positions: felt* - the array of positions of the peaks
// - peaks_values_poseidon: felt* - the array of values of the peaks for the Poseidon MMR
// - peaks_values_keccak: Uint256* - the array of values of the peaks for the Keccak MMR
func initialize_peaks_dicts{dict_end_poseidon: DictAccess*, dict_end_keccak: DictAccess*}(
    index: felt, peaks_positions: felt*, peaks_values_poseidon: felt*, peaks_values_keccak: Uint256*
) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();
    local keccak_peak_value: Uint256;
    assert keccak_peak_value.low = peaks_values_keccak[index].low;
    assert keccak_peak_value.high = peaks_values_keccak[index].high;

    if (index == 0) {
        dict_write{dict_ptr=dict_end_poseidon}(
            key=peaks_positions[0], new_value=peaks_values_poseidon[0]
        );
        dict_write{dict_ptr=dict_end_keccak}(
            key=peaks_positions[0], new_value=cast(&keccak_peak_value, felt)
        );

        return ();
    } else {
        dict_write{dict_ptr=dict_end_poseidon}(
            key=peaks_positions[index], new_value=peaks_values_poseidon[index]
        );
        dict_write{dict_ptr=dict_end_keccak}(
            key=peaks_positions[index], new_value=cast(&keccak_peak_value, felt)
        );
        return initialize_peaks_dicts(
            index=index - 1,
            peaks_positions=peaks_positions,
            peaks_values_poseidon=peaks_values_poseidon,
            peaks_values_keccak=peaks_values_keccak,
        );
    }
}

// Appends block headers hashes to both MMR using the previous MMR information
//
// Implicit arguments :
// - poseidon_leafs: felt* - array of poseidon hashes of block headers
// - keccak_leafs: Uint256* - array of keccak hashes of block headers
// - mmr_array_poseidon: felt* - array of new nodes to fill for the Poseidon MMR
// - mmr_array_keccak: Uint256* - array of new nodes to fill for the Keccak MMR
// - mmr_array_len: felt - length of mmr arrays
// - mmr_offset: felt - offset of mmr arrays. ie : mmr_array_poseidon[i] is the i+mmr_offset-th+1 node of the MMR
// - peaks_dict_poseidon: DictAccess* - previous peaks of the Poseidon MMR
// - peaks_dict_keccak: DictAccess* - previous peaks of the Keccak MMR
// - pow2_array: felt* - array of powers of 2
//
// Params:
// - index: felt - index of block header hash to append to MMR. Should initially be 0.
// - n_leaves: felt - The total number of leaves to append.
func construct_mmr{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_leafs: felt*,
    mmr_array_poseidon: felt*,
    keccak_leafs: Uint256*,
    mmr_array_keccak: Uint256*,
    mmr_array_len: felt,
    mmr_offset: felt,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(index: felt, n_leaves: felt) {
    alloc_locals;

    if (index == n_leaves) {
        return ();
    }

    // Append leaves to mmr arrays. They are already hashed.

    assert mmr_array_poseidon[mmr_array_len] = poseidon_leafs[index];
    assert mmr_array_keccak[mmr_array_len].low = keccak_leafs[index].low;
    assert mmr_array_keccak[mmr_array_len].high = keccak_leafs[index].high;

    let mmr_array_len = mmr_array_len + 1;

    // Append extra nodes to mmr arrays if merging is needed
    merge_subtrees_if_applicable(height=0);
    return construct_mmr(index=index + 1, n_leaves=n_leaves);
}

// 3              15
//              /    \
//             /      \
//            /        \
//           /          \
// 2        7            14
//        /   \        /    \
// 1     3     6      10    13     18
//      / \   / \    / \   /  \   /  \
// 0   1   2 4   5  8   9 11  12 16  17 19
// Recursively append nodes to MMR arrays if merging is needed (ie : checks if the height of the next position is higher than the current one)
// Implicit arguments :
// - mmr_array_poseidon: felt* - array of new nodes to fill for the Poseidon MMR
// -mmr_array_keccak: Uint256* - array of new nodes to fill for the Keccak MMR
//  -mmr_array_len: felt - length of mmr arrays
// - mmr_offset: felt - offset of mmr arrays. ie : mmr_array_poseidon[i] is the i+mmr_offset-th+1 node of the MMR
// - peaks_dict_poseidon: DictAccess* - previous peaks of the Poseidon MMR
// - peaks_dict_keccak: DictAccess* - previous peaks of the Keccak MMR
// - pow2_array: felt* - array of powers of 2
//
// Params:
// - height: felt - current height of the node at the last position of the MMR
func merge_subtrees_if_applicable{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    mmr_array_poseidon: felt*,
    mmr_array_keccak: Uint256*,
    mmr_array_len: felt,
    mmr_offset: felt,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(height: felt) {
    alloc_locals;

    tempvar next_pos: felt = mmr_array_len + mmr_offset + 1;
    let height_next_pos = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(next_pos);

    if (height_next_pos == height + 1) {
        // The height of the next position is one level higher than the current one.
        // It means than the last element in the array is a right children.

        // Compute left and right positions of the subtree to merge
        local left_pos = next_pos - pow2_array[height + 1];
        local right_pos = next_pos - 1;

        // %{ print(f"Merging {ids.left_pos} + {ids.right_pos} at index {ids.next_pos} and height {ids.height_next_pos} ") %}

        // Get the values of the left and right children at those positions:
        let (x_poseidon: felt, x_keccak: Uint256) = get_full_mmr_peak_values(left_pos);
        let (y_poseidon: felt, y_keccak: Uint256) = get_full_mmr_peak_values(right_pos);

        // Compute H(left, right) for both hash functions
        let (hash_poseidon) = poseidon_hash(x_poseidon, y_poseidon);
        let (keccak_input: felt*) = alloc();
        let inputs_start = keccak_input;
        keccak_add_uint256{inputs=keccak_input}(num=x_keccak, bigend=1);
        keccak_add_uint256{inputs=keccak_input}(num=y_keccak, bigend=1);
        let (res_keccak_little: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
        let (res_keccak) = uint256_reverse_endian(res_keccak_little);

        // Append each parent to the corresponding MMR arrays
        assert mmr_array_poseidon[mmr_array_len] = hash_poseidon;
        assert mmr_array_keccak[mmr_array_len].low = res_keccak.low;
        assert mmr_array_keccak[mmr_array_len].high = res_keccak.high;

        let mmr_array_len = mmr_array_len + 1;
        // Continue merging if needed:
        return merge_subtrees_if_applicable(height=height + 1);
    } else {
        // Next position is not a parent, no need to merge.
        return ();
    }
}

// Hashes a subtree path from a leaf up to its peak in the MMR using Poseidon.
// Decides left/right at each step from MMR positions via height comparison.
// Params:
// - element: felt - current node value (start with the leaf hash)
// - height: felt - current node height in the MMR (leaves are height 0; increment by 1 per level up)
// - position: felt - current MMR position of the node (1-indexed as in compute_height_pre_alloc_pow2)
// - inclusion_proof: felt* - siblings from leaf to peak (left-to-right in ascent order)
// - inclusion_proof_len: felt - number of siblings to consume
// Returns:
// - peak: felt - computed peak value for this subtree
// - peak_pos: felt - MMR position of the resulting peak
// - peak_height: felt - height of the resulting peak
// Orientation rule:
// - If compute_height(pos+1) == compute_height(pos) + 1, element is a right child.
//   Parent position is pos + 1 and hash order is H(sibling, element).
// - Else element is a left child. Parent position is pos + 2^(height+1) and hash
//   order is H(element, sibling).
func hash_subtree_path_poseidon{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
}(
    element: felt,
    height: felt,
    position: felt,
    inclusion_proof: felt*,
    inclusion_proof_len: felt,
) -> (peak: felt, peak_pos: felt, peak_height: felt) {
    alloc_locals;
    if (inclusion_proof_len == 0) {
        return (peak=element, peak_pos=position, peak_height=height);
    }

    let position_height = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(position);
    let next_height = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(position + 1);

    if (next_height == position_height + 1) {
        // element is right child: parent at position + 1, H(sibling, element)
        let (parent) = poseidon_hash([inclusion_proof], element);
        return hash_subtree_path_poseidon(
            parent,
            height + 1,
            position + 1,
            inclusion_proof=inclusion_proof + 1,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    } else {
        // element is left child: parent at position + 2^(height+1) - 1, H(element, sibling)
        let (parent) = poseidon_hash(element, [inclusion_proof]);
        let next_pos = position + pow2_array[height + 1];
        return hash_subtree_path_poseidon(
            parent,
            height + 1,
            next_pos,
            inclusion_proof=inclusion_proof + 1,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    }
}

// Hashes a subtree path from a leaf up to its peak in the MMR using Keccak over Uint256.
// Decides left/right at each step from MMR positions via height comparison.
// Params:
// - element: Uint256 - current node value (start with the leaf hash)
// - height: felt - current node height in the MMR (leaves are height 0; increment by 1 per level up)
// - position: felt - current MMR position of the node (1-indexed as in compute_height_pre_alloc_pow2)
// - inclusion_proof: Uint256* - siblings from leaf to peak (left-to-right in ascent order)
// - inclusion_proof_len: felt - number of siblings to consume
// Returns:
// - peak: Uint256 - computed peak value for this subtree
// - peak_pos: felt - MMR position of the resulting peak
// - peak_height: felt - height of the resulting peak
// Orientation rule:
// - If compute_height(pos+1) == compute_height(pos) + 1, element is a right child.
//   Parent position is pos + 1 and Keccak is computed as Keccak(sibling, element).
// - Else element is a left child. Parent position is pos + 2^(height+1) and Keccak
//   is computed as Keccak(element, sibling).
func hash_subtree_path_keccak{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*,
}(
    element: Uint256,
    height: felt,
    position: felt,
    inclusion_proof: Uint256*,
    inclusion_proof_len: felt,
) -> (peak: Uint256, peak_pos: felt, peak_height: felt) {
    alloc_locals;
    if (inclusion_proof_len == 0) {
        return (peak=element, peak_pos=position, peak_height=height);
    }

    let position_height = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(position);
    let next_height = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(position + 1);

    if (next_height == position_height + 1) {
        // element is right child: parent at position + 1, Keccak(sibling, element)
        let (buf: felt*) = alloc();
        let buf_start = buf;
        keccak_add_uint256{inputs=buf}(num=[inclusion_proof], bigend=1);
        keccak_add_uint256{inputs=buf}(num=element, bigend=1);
        let (parent_be: Uint256) = keccak(inputs=buf_start, n_bytes=2 * 32);
        let (parent) = uint256_reverse_endian(parent_be);
        return hash_subtree_path_keccak(
            parent,
            height + 1,
            position + 1,
            inclusion_proof=inclusion_proof + Uint256.SIZE,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    } else {
        // element is left child: parent at position + 2^(height+1) - 1, Keccak(element, sibling)
        let (buf2: felt*) = alloc();
        let buf2_start = buf2;
        keccak_add_uint256{inputs=buf2}(num=element, bigend=1);
        keccak_add_uint256{inputs=buf2}(num=[inclusion_proof], bigend=1);
        let (parent_be2: Uint256) = keccak(inputs=buf2_start, n_bytes=2 * 32);
        let (parent2) = uint256_reverse_endian(parent_be2);
        let next_pos = position + pow2_array[height + 1];
        return hash_subtree_path_keccak(
            parent2,
            height + 1,
            next_pos,
            inclusion_proof=inclusion_proof + Uint256.SIZE,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    }
}