%builtins output range_check bitwise
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.beacon.types import BeaconHeader
from src.core.ssz import SSZ
from src.core.sha import SHA256
from src.core.utils import pow2alloc128
from src.debug.lib import print_uint256, print_string

func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc128();
    let (sha256_ptr, sha256_ptr_start) = SHA256.init();

    let (inputs: BeaconHeader*) = alloc();
    local n_headers: felt;

    let previous_root = Uint256(low=0xf6d9d72d80c8164799a194d0f42f7b31, high=0x99ac6306231527b6d62a6590c62e7d2f);

    let header_roots: Uint256* = alloc();

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

        headers = [
            {
                "slot": 8234857,
                "proposer_index": 1828,
                "parent_root": split_128("0x99ac6306231527b6d62a6590c62e7d2ff6d9d72d80c8164799a194d0f42f7b31"),
                "state_root": split_128("0xae5aa2417e93e05c43fcd9133500eae3dc59ab2634a83e67a31de342f4574a5b"),
                "body_root": split_128("0x8d674e4b9933b9871fede87f422b5e6271e4a87ae8045c3d45a7f69a5afa7479"),
            },
            {
                "slot": 8234858,
                "proposer_index": 438,
                "parent_root": split_128("0xbe7dd19c0ff66355d2472f13af1cf99b2fce765ef545e4f3bc01e0a2688da1b7"),
                "state_root": split_128("0x80b63d29a5dc81ee0027ee21ee9cff27eab9fde362a839c5eba3fa0bbe622bde"),
                "body_root": split_128("0x64fc3386a282d78d6c81c89ad6f6ff16c96f741b7349503044680e26b3d158a1"),
            },
            {
                "slot": 8234859,
                "proposer_index": 52,
                "parent_root": split_128("0x8ff54dd4bf87a6575ee00f881628e67a1fa2d54aafe474eabae1573c0a587034"),
                "state_root": split_128("0x485e6afd0597c583d3407ab3c07950e08dc0b6e07cdc344dfacd1928a60126a4"),
                "body_root": split_128("0xd97138e510216f7942fc57efc530525026b1ef287edd410e794c1a6f31c0e260"),
            }
        ]

        counter = 0
        for i, header in enumerate(headers):
            memory[ids.inputs._reference_value + i * 8] = header['slot']
            memory[ids.inputs._reference_value + i * 8 + 1] = header['proposer_index']
            memory[ids.inputs._reference_value + i * 8 + 2] = header['parent_root'][0]
            memory[ids.inputs._reference_value + i * 8 + 3] = header['parent_root'][1]
            memory[ids.inputs._reference_value + i * 8 + 4] = header['state_root'][0]
            memory[ids.inputs._reference_value + i * 8 + 5] = header['state_root'][1]
            memory[ids.inputs._reference_value + i * 8 + 6] = header['body_root'][0]
            memory[ids.inputs._reference_value + i * 8 + 7] = header['body_root'][1]

        ids.n_headers = len(headers)
        print(f"n_headers: {ids.n_headers}")
    %}
    with pow2_array, sha256_ptr {
        assert_header_linkage(
            previous_root=previous_root,
            headers=inputs,
            count=n_headers,
            roots=header_roots,
        );
    }


    // SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
    return ();
}


func assert_header_linkage{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    sha256_ptr: felt*,
}(
    previous_root: Uint256,
    headers: BeaconHeader*,
    count: felt,
    roots: Uint256*,
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

    assert roots[0].low = root.low;
    assert roots[0].high = root.high;

    return assert_header_linkage(
        previous_root=root,
        headers=headers + BeaconHeader.SIZE,
        count=count - 1,
        roots=roots + Uint256.SIZE,
    );
}