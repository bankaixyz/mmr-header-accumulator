%builtins output range_check bitwise keccak poseidon
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.beacon.types import BeaconHeader
from src.core.ssz import SSZ
from src.core.sha import SHA256
from src.core.utils import pow2alloc128
from src.debug.lib import print_uint256, print_string
from src.mmr.leaf_hash import poseidon_uint256, keccak_uint256

from src.mmr.lib import init_mmr

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

    let previous_root = Uint256(low=0xa57e66a87a2e77d6c22675607e621c39, high=0xfad68dc38d7685970d9ba89a0cc32790);

    let poseidon_hashes: felt* = alloc();
    let keccak_hashes: Uint256* = alloc();

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
    %}
    with pow2_array, sha256_ptr {
        assert_header_linkage(
            previous_root=previous_root,
            headers=inputs,
            count=n_headers,
            poseidon_hashes=poseidon_hashes,
            keccak_hashes=keccak_hashes,
        );
    }
    with pow2_array {
        init_mmr(keccak_leafs=keccak_hashes, poseidon_leafs=poseidon_hashes, n_headers=n_headers);
    }

    // SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
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