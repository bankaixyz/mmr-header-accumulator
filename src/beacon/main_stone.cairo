%builtins output range_check bitwise keccak poseidon
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.beacon.lib import run_beacon_mmr_update
from src.core.sha import SHA256
from src.core.utils import pow2alloc128

func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let keccak_felt_ptr = cast(keccak_ptr, felt*);

    let pow2_array: felt* = pow2alloc128();
    let (sha256_ptr, sha256_ptr_start) = SHA256.init();

    run_beacon_mmr_update{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_felt_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        sha256_ptr=sha256_ptr,
    }();

    SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
    tempvar keccak_ptr = cast(keccak_felt_ptr, KeccakBuiltin*);

    return ();
}

func keccak_wrap{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_felt_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let keccak_ptr = keccak_felt_ptr;

    let pow2_array: felt* = pow2alloc128();
    let (sha256_ptr, sha256_ptr_start) = SHA256.init();

    with sha256_ptr, pow2_array, keccak_ptr {
        run_beacon_mmr_update();
    }

    SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);

    return ();
}