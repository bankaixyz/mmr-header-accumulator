%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon range_check96 add_mod mul_mod
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin, HashBuiltin, ModBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.alloc import alloc
from src.beacon.lib import run_beacon_mmr_update
from src.core.sha import SHA256
from src.core.utils import pow2alloc128
from src.core.keccak import USE_BUILTIN_KECCAK

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr: felt*,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr: felt*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    alloc_locals;
    with_attr error_message("USE_BUILTIN_KECCAK must be 0 in stwo mode") {
        assert USE_BUILTIN_KECCAK = 0;
    }

    let pow2_array: felt* = pow2alloc128();
    let (sha256_ptr, sha256_ptr_start) = SHA256.init();

    let (keccak_felt_ptr: felt*) = alloc();
    let start_keccak_felt_ptr = keccak_felt_ptr;

    run_beacon_mmr_update{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_felt_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        sha256_ptr=sha256_ptr,
    }();

    SHA256.finalize(sha256_start_ptr=sha256_ptr_start, sha256_end_ptr=sha256_ptr);
    finalize_keccak(keccak_ptr_start=start_keccak_felt_ptr, keccak_ptr_end=keccak_felt_ptr);

    return ();
}