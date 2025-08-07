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
from src.mmr.utils import assert_mmr_size_is_valid, compute_peaks_positions, bag_peaks, get_full_mmr_peak_values, compute_height_pre_alloc_pow2 as compute_height, get_roots
from src.mmr.types import MmrSnapshot
from src.debug.lib import print_felt_hex, print_uint256, print_felt

func init_mmr{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
}(keccak_leafs: Uint256*, poseidon_leafs: felt*, n_headers: felt) {
    alloc_locals;

    local start_mmr_snapshot: MmrSnapshot;
    local end_mmr_snapshot: MmrSnapshot;

    %{
        def split_128(value: str) -> list[int]:
            if value.startswith("0x"):
                value = value[2:]
            
            value = value.zfill(64)

            high_hex = value[:32]
            low_hex = value[32:]

            low_int = int(low_hex, 16)
            high_int = int(high_hex, 16)

            return [low_int, high_int]

        start_mmr_data = program_input['chain_integrations'][0]['start_mmr']
        end_mmr_data = program_input['chain_integrations'][0]['end_mmr']

        # Write start_mmr
        ids.start_mmr_snapshot.size = start_mmr_data['elements_count']
        ids.start_mmr_snapshot.poseidon_root = int(start_mmr_data['poseidon_root'], 16)
        
        keccak_root_split = split_128(start_mmr_data['keccak_root'])
        ids.start_mmr_snapshot.keccak_root.low = keccak_root_split[0]
        ids.start_mmr_snapshot.keccak_root.high = keccak_root_split[1]

        ids.start_mmr_snapshot.peaks_len = len(start_mmr_data['poseidon_peaks'])

        poseidon_peaks_ptr = segments.add()
        ids.start_mmr_snapshot.poseidon_peaks = poseidon_peaks_ptr
        poseidon_peaks_data = [int(p, 16) for p in start_mmr_data['poseidon_peaks']]
        segments.write_arg(poseidon_peaks_ptr, poseidon_peaks_data)

        keccak_peaks_ptr = segments.add()
        ids.start_mmr_snapshot.keccak_peaks = keccak_peaks_ptr
        keccak_peaks_data = []
        for p in start_mmr_data['keccak_peaks']:
            split_peak = split_128(p)
            keccak_peaks_data.extend(split_peak)
        segments.write_arg(keccak_peaks_ptr, keccak_peaks_data)

        # Write end_mmr
        ids.end_mmr_snapshot.size = end_mmr_data['elements_count']
        ids.end_mmr_snapshot.poseidon_root = int(end_mmr_data['poseidon_root'], 16)
        
        keccak_root_split = split_128(end_mmr_data['keccak_root'])
        ids.end_mmr_snapshot.keccak_root.low = keccak_root_split[0]
        ids.end_mmr_snapshot.keccak_root.high = keccak_root_split[1]

        ids.end_mmr_snapshot.peaks_len = len(end_mmr_data['poseidon_peaks'])

        poseidon_peaks_ptr = segments.add()
        ids.end_mmr_snapshot.poseidon_peaks = poseidon_peaks_ptr
        poseidon_peaks_data = [int(p, 16) for p in end_mmr_data['poseidon_peaks']]
        segments.write_arg(poseidon_peaks_ptr, poseidon_peaks_data)

        keccak_peaks_ptr = segments.add()
        ids.end_mmr_snapshot.keccak_peaks = keccak_peaks_ptr
        keccak_peaks_data = []
        for p in end_mmr_data['keccak_peaks']:
            split_peak = split_128(p)
            keccak_peaks_data.extend(split_peak)
        segments.write_arg(keccak_peaks_ptr, keccak_peaks_data)

        print("Start MMR size: ", ids.start_mmr_snapshot.size)
        print("End MMR size: ", ids.end_mmr_snapshot.size)
    %}

    assert_mmr_size_is_valid{pow2_array=pow2_array}(start_mmr_snapshot.size);
    assert_mmr_size_is_valid{pow2_array=pow2_array}(end_mmr_snapshot.size); // Sanity check

    // Compute previous_peaks_positions given the previous MMR size (from left to right), as well:
    let (
        start_peaks_positions: felt*, start_peaks_positions_len: felt
    ) = compute_peaks_positions{pow2_array=pow2_array}(start_mmr_snapshot.size);

    // Based on the previous peaks positions, compute the previous roots:
    let (bagged_peaks_poseidon, bagged_peaks_keccak) = bag_peaks(
        start_mmr_snapshot.poseidon_peaks, start_mmr_snapshot.keccak_peaks, start_peaks_positions_len
    );

    let (root_poseidon) = poseidon_hash(start_mmr_snapshot.size, bagged_peaks_poseidon);

    let (keccak_input: felt*) = alloc();
    let inputs_start = keccak_input;
    keccak_add_uint256{inputs=keccak_input}(num=Uint256(start_mmr_snapshot.size, 0), bigend=1);
    keccak_add_uint256{inputs=keccak_input}(num=bagged_peaks_keccak, bigend=1);
    let (root_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
    let (root_keccak) = uint256_reverse_endian(root_keccak);

    // Check that the previous roots matche the ones provided in the program's input:
    assert 0 = root_poseidon - start_mmr_snapshot.poseidon_root;
    assert 0 = root_keccak.low - start_mmr_snapshot.keccak_root.low;
    assert 0 = root_keccak.high - start_mmr_snapshot.keccak_root.high;

    let (local previous_peaks_dict_poseidon) = default_dict_new(default_value=0);
    let (local previous_peaks_dict_keccak) = default_dict_new(default_value=0);
    tempvar dict_start_poseidon = previous_peaks_dict_poseidon;
    tempvar dict_start_keccak = previous_peaks_dict_keccak;
    initialize_peaks_dicts{
        dict_end_poseidon=previous_peaks_dict_poseidon, dict_end_keccak=previous_peaks_dict_keccak
    }(
        start_peaks_positions_len - 1,
        start_peaks_positions,
        start_mmr_snapshot.poseidon_peaks,
        start_mmr_snapshot.keccak_peaks,
    );

    let (mmr_array_keccak: Uint256*) = alloc();
    let (mmr_array_poseidon: felt*) = alloc();
    let mmr_array_len = 0;
    let mmr_offset = start_mmr_snapshot.size;

    with poseidon_leafs, keccak_leafs, mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, mmr_offset, previous_peaks_dict_poseidon, previous_peaks_dict_keccak {
        construct_mmr(index=0, n_leaves=n_headers);
    }

    with mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, previous_peaks_dict_poseidon, previous_peaks_dict_keccak, mmr_offset {
        let (new_mmr_root_poseidon: felt, new_mmr_root_keccak: Uint256) = get_roots();
    }

    print_felt_hex(new_mmr_root_poseidon);
    print_uint256(new_mmr_root_keccak);
    print_felt(mmr_array_len + mmr_offset);

    default_dict_finalize(dict_start_poseidon, previous_peaks_dict_poseidon, 0);
    default_dict_finalize(dict_start_keccak, previous_peaks_dict_keccak, 0);



    return ();
}

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
// - previous_peaks_dict_poseidon: DictAccess* - previous peaks of the Poseidon MMR
// - previous_peaks_dict_keccak: DictAccess* - previous peaks of the Keccak MMR
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
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
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
// - previous_peaks_dict_poseidon: DictAccess* - previous peaks of the Poseidon MMR
// - previous_peaks_dict_keccak: DictAccess* - previous peaks of the Keccak MMR
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
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(height: felt) {
    alloc_locals;

    tempvar next_pos: felt = mmr_array_len + mmr_offset + 1;
    let height_next_pos = compute_height{pow2_array=pow2_array}(next_pos);

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