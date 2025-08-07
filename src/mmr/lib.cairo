from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.mmr.utils import assert_mmr_size_is_valid, compute_peaks_positions, bag_peaks
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from src.mmr.types import MmrSnapshot

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

    return ();
}