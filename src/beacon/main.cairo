%builtins output range_check bitwise keccak poseidon
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from src.beacon.types import BeaconHeader
from src.core.ssz import SSZ
from src.core.sha import SHA256
from src.core.utils import pow2alloc128
from src.debug.lib import print_uint256, print_string
from src.mmr.leaf_hash import poseidon_uint256, keccak_uint256
from src.mmr.types import MmrSnapshot, LastLeafProof
from src.mmr.lib import initialize_peaks, finalize_mmr, grow_mmr
from src.mmr.utils import assert_is_last_leaf_in_mmr
from src.mmr.core import hash_subtree_path_poseidon, hash_subtree_path_keccak

func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc128();
    let (sha256_ptr, sha256_ptr_start) = SHA256.init();

    let (inputs: BeaconHeader*) = alloc();
    local n_headers: felt;

    local start_mmr_snapshot: MmrSnapshot;
    local end_mmr_snapshot: MmrSnapshot;
    local last_leaf_proof: LastLeafProof;

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

        # Write headers
        headers = program_input["chain_integrations"][0]["headers"]
        counter = 0
        for i, header in enumerate(headers):

            memory[ids.inputs._reference_value + i * 8] = int(header["header"]['slot'], 10)
            memory[ids.inputs._reference_value + i * 8 + 1] = int(header["header"]['proposer_index'], 10)
            memory[ids.inputs._reference_value + i * 8 + 2], memory[ids.inputs._reference_value + i * 8 + 3] = split_128(header["header"]['parent_root'])
            memory[ids.inputs._reference_value + i * 8 + 4], memory[ids.inputs._reference_value + i * 8 + 5] = split_128(header["header"]['state_root'])
            memory[ids.inputs._reference_value + i * 8 + 6], memory[ids.inputs._reference_value + i * 8 + 7] = split_128(header["header"]['body_root'])

        ids.n_headers = len(headers)
        print(f"n_headers: {ids.n_headers}")

        start_mmr_data = program_input['chain_integrations'][0]['start_mmr']
        end_mmr_data = program_input['chain_integrations'][0]['end_mmr']

        # Write MMR Data
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

        # Write last leaf proof
        last_leaf = program_input['chain_integrations'][0]['last_leaf_proof']

        # Header root as Uint256
        header_root_split = split_128(last_leaf['header_root'])
        ids.last_leaf_proof.header_root.low = header_root_split[0]
        ids.last_leaf_proof.header_root.high = header_root_split[1]

        # Scalars
        ids.last_leaf_proof.header_position = int(last_leaf['header_position'])
        ids.last_leaf_proof.path_len = int(last_leaf['path_len'])

        # Poseidon path (felt*)
        poseidon_path_ptr = segments.add()
        ids.last_leaf_proof.poseidon_path = poseidon_path_ptr
        poseidon_path_data = [int(p, 16) for p in last_leaf['poseidon_path']]
        segments.write_arg(poseidon_path_ptr, poseidon_path_data)

        # Keccak path (Uint256*)
        keccak_path_ptr = segments.add()
        ids.last_leaf_proof.keccak_path = keccak_path_ptr
        keccak_path_data = []
        for k in last_leaf['keccak_path']:
            keccak_path_data.extend(split_128(k))
        segments.write_arg(keccak_path_ptr, keccak_path_data)

        print("Start MMR size: ", ids.start_mmr_snapshot.size)
        print("End MMR size: ", ids.end_mmr_snapshot.size)
    %}

    with pow2_array {
        let (
            start_peaks_dict_poseidon,
            start_peaks_dict_keccak,
            peaks_dict_poseidon,
            peaks_dict_keccak,
        ) = initialize_peaks(start_mmr_snapshot=start_mmr_snapshot, end_mmr_snapshot=end_mmr_snapshot);
    }

    with pow2_array, peaks_dict_poseidon, peaks_dict_keccak {
        verify_last_leaf(proof=last_leaf_proof, start_mmr=start_mmr_snapshot);
    }

    let (poseidon_hashes: felt*) = alloc();
    let (keccak_hashes: Uint256*) = alloc();

    with pow2_array, sha256_ptr {
        assert_header_linkage(
            previous_root=last_leaf_proof.header_root,
            headers=inputs,
            count=n_headers,
            poseidon_hashes=poseidon_hashes,
            keccak_hashes=keccak_hashes,
        );
    }
    with pow2_array, peaks_dict_poseidon, peaks_dict_keccak {
        let (new_mmr_root_poseidon, new_mmr_root_keccak, new_mmr_size) = grow_mmr(mmr_size=start_mmr_snapshot.size, keccak_leafs=keccak_hashes, poseidon_leafs=poseidon_hashes, n_headers=n_headers);
    }

    with pow2_array, peaks_dict_poseidon, peaks_dict_keccak {
        finalize_mmr(
            end_mmr_snapshot=end_mmr_snapshot,
            new_mmr_root_poseidon=new_mmr_root_poseidon,
            new_mmr_root_keccak=new_mmr_root_keccak,
            new_mmr_size=new_mmr_size,
            start_peaks_dict_poseidon=start_peaks_dict_poseidon,
            peaks_dict_poseidon=peaks_dict_poseidon,
            start_peaks_dict_keccak=start_peaks_dict_keccak,
            peaks_dict_keccak=peaks_dict_keccak,
        );
    }

    SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
    return ();
}

// To ensure we dont have any gaps in the MMR, we verify the proof of the last leaf of each MMR
// this should then be the parent_root of the first header we add to the MMR
func verify_last_leaf{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    peaks_dict_poseidon: DictAccess*,
    peaks_dict_keccak: DictAccess*,
    pow2_array: felt*,
}(proof: LastLeafProof, start_mmr: MmrSnapshot) {
    alloc_locals;

    let (poseidon_leaf) = poseidon_uint256(leaf=proof.header_root);

    let (peak_poseidon, peak_poseidon_pos, _) = hash_subtree_path_poseidon(
        element=poseidon_leaf,
        height=0,
        position=proof.header_position,
        inclusion_proof=proof.poseidon_path,
        inclusion_proof_len=proof.path_len,
    );

    let (peak_poseidon_value) = dict_read{dict_ptr=peaks_dict_poseidon}(key=peak_poseidon_pos);
    assert peak_poseidon_value = peak_poseidon;

    let (keccak_leaf) = keccak_uint256(leaf=proof.header_root);
    let (peak_keccak, peak_keccak_pos, _) = hash_subtree_path_keccak(
        element=keccak_leaf,
        height=0,
        position=proof.header_position,
        inclusion_proof=proof.keccak_path,
        inclusion_proof_len=proof.path_len,
    );

    let (peak_keccak_ptr: Uint256*) = dict_read{dict_ptr=peaks_dict_keccak}(
        key=peak_keccak_pos
    );
    assert peak_keccak.low = peak_keccak_ptr.low;
    assert peak_keccak.high = peak_keccak_ptr.high;

    assert_is_last_leaf_in_mmr(mmr_size=start_mmr.size, position=proof.header_position);

    return ();
}

func assert_header_linkage{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    sha256_ptr: felt*,
}(
    previous_root: Uint256,
    headers: BeaconHeader*,
    count: felt,
    poseidon_hashes: felt*,
    keccak_hashes: Uint256*,
) {
    alloc_locals;
    if (count == 0) {
        return ();
    }

    // Ensure the linkage works
    assert headers.parent_root.high = previous_root.high;
    assert headers.parent_root.low = previous_root.low;

    let parent = headers.parent_root;
    let state = headers.state_root;
    let body = headers.body_root;

    // Compute next root
    let root = SSZ.hash_header_root(
        slot=Uint256(low=headers.slot, high=0),
        proposer_index=Uint256(low=headers.proposer_index, high=0),
        parent_root=parent,
        state_root=state,
        body_root=body,
    );

    print_uint256(root);

    let (poseidon_hash) = poseidon_uint256(root);
    let (keccak_hash) = keccak_uint256(root);

    assert poseidon_hashes[0] = poseidon_hash;
    assert keccak_hashes[0].low = keccak_hash.low;
    assert keccak_hashes[0].high = keccak_hash.high;

    return assert_header_linkage(
        previous_root=root,
        headers=headers + BeaconHeader.SIZE,
        count=count - 1,
        poseidon_hashes=poseidon_hashes + 1,
        keccak_hashes=keccak_hashes + Uint256.SIZE,
    );
}