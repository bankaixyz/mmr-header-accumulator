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

    let previous_root = Uint256(low=0xf6d9d72d80c8164799a194d0f42f7b31, high=0x99ac6306231527b6d62a6590c62e7d2f);

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
            },
            {
                "slot": 8234860,
                "proposer_index": 749,
                "parent_root": split_128("0xff0c8d65b5779bc06497a673cff65c5b07c2b8c9c5ea91d1f183d706f50ff323"),
                "state_root": split_128("0x36ba66eb697bfd5426ca5204ded2c4a779aa3640b0e38d5317589c1e181b77e6"),
                "body_root": split_128("0x1d3deff62c2862cc092489d4fa48fd0bc286d7edd5172a23feb4518f4ca492b6"),
            },
            {
                "slot": 8234861,
                "proposer_index": 212,
                "parent_root": split_128("0xde41eec57545c2a0e9d7bdba10d3dc54cbf8402e24136f34662e9ee61bbea047"),
                "state_root": split_128("0x36080445deb4f43a98abe1f7fa75ec11e84a9e11109b9c1081aa7acf2816b13f"),
                "body_root": split_128("0x642f9dc3e4af89aadab30538bfe29c550fc113a047916310d9e61e55a28c34d5"),
            },
            {
                "slot": 8234862,
                "proposer_index": 553,
                "parent_root": split_128("0x40bbb0f491db5ec455aad016c30d5712448471e61354aa732a534b0e4df8f053"),
                "state_root": split_128("0xcb3258f11a3063332a388b21f35e7e5958c63eb7801375741242e66b5398af4e"),
                "body_root": split_128("0xc564908d585f03a193a9e167b1a29d832dc03cba632e6726ecc66bdbe2e9ff53"),
            },
            {
                "slot": 8234863,
                "proposer_index": 813,
                "parent_root": split_128("0x12e8f195787b74f5e9efe2ad08672699da65fec8d1616be70cd67e180cd78a1b"),
                "state_root": split_128("0x008aea2bca70c58a86c6c71faa7502d1ac09e0fcd51d5d7f11fedd4574613e0c"),
                "body_root": split_128("0x4a7d86fbf8769ea54a65898903e50504456d4092481f649687b7638ababf606f"),
            },
            {
                "slot": 8234864,
                "proposer_index": 1361,
                "parent_root": split_128("0xe502a7ce276a4d73b05c3e1bb3dd908579830a1f93295ed094517bcefd525215"),
                "state_root": split_128("0xf4e7601a987c87cb2902c5b363dc74244ff4284f0d486e0a1ae45a306456e52b"),
                "body_root": split_128("0x5d297c4a7573b7d2f1463e6b6f415abe7a9cac919519193d047e4efa6fd9f9c8"),
            },
            {
                "slot": 8234865,
                "proposer_index": 1448,
                "parent_root": split_128("0x274e08f8e6eda7aa347896aa5b92bde565d817ce5da624dd32621f8064e613f5"),
                "state_root": split_128("0xa6c4cd72d93d08bc4e3f20c38b4f3b39f9421a0debbfe8a1f3d140d3d256179c"),
                "body_root": split_128("0x5ec189e0aa2a7c5ca92c9f423f211c41c27e7566300a8147c4d1eafc1abcced6"),
            },
            {
                "slot": 8234866,
                "proposer_index": 1195,
                "parent_root": split_128("0x8de0b0f76497ff576c561052015e1d6627ec3dc92d1b8a0e5bdc744f8c3b3548"),
                "state_root": split_128("0x21bf98eaad3524bc4325e7f5af51133f9b0dd14cb9f860cba154534e9c636ec2"),
                "body_root": split_128("0xccf37956091d5e634a3ec90d9fcdb7a0b931491bd7373cd477bc63d85a5db7d7"),
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
            poseidon_hashes=poseidon_hashes,
            keccak_hashes=keccak_hashes,
        );
    }

    SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
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