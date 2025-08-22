# MMR Header Accumulator

This Cairo program is a core component of Bankai. It is used to provably grow a Merkle Mountain Range (MMR) with new headers. The code in this repository is designed to be imported and used within the main Bankai Cairo project.

## How to run

### 1. Setup

First, run the setup script. This only needs to be done once.

```bash
make setup
```

### 2. Activate Environment

Before running the programs, you must activate the virtual environment.

```bash
source scripts/activate.sh
```

### 3. Compile the Cairo Program

Compile the main Cairo program to produce a JSON artifact that the hint processor can execute.

```bash
make build-cairo
```
This will compile `src/beacon/main.cairo` and create `build/main.json`.

### 4. Run the Hint Processor

Finally, run the Rust hint processor to execute the compiled Cairo program with a given input file. The following command runs the processor with `input.json` from the project root. The output PIE file will be saved in the `output/` directory.

```bash
cargo run -- --input-path example_input.json
```

### 5. Format the Cairo Code

Format the Cairo code to ensure consistency.

```bash
make format
```

### 6. Get the Program Hash

Get the hash of the compiled program.

```bash
make get-program-hash
```

## How it Works: Adding Headers to the MMR

The core of this repository is a Cairo program that provably adds a batch of new block headers to a Merkle Mountain Range (MMR). This process ensures that the headers form a valid and continuous chain, and that they are correctly appended to the MMR without any gaps. The process can be broken down into the following steps:

1.  **Initialization**: The process begins with the snapshot of a previous, valid MMR state. The Cairo program loads the peaks of this MMR into memory. To ensure we are starting from a correct state, the program re-computes the MMR root from these peaks and matches it against the root provided in the snapshot.

2.  **Gap-Free Growth with Last Leaf Verification**: A key challenge in growing an MMR is to ensure that new leaves are appended directly after the existing ones, without any gaps. To solve this, the program requires a Merkle proof for the last leaf of the starting MMR. It verifies this proof to confirm that the leaf is indeed the last element of the MMR. This step is crucial for guaranteeing a contiguous history of block headers.

3.  **Header Chain Verification**: The first new header to be added must be a direct child of the verified last leaf (i.e., its `parent_root` must match the last leaf's hash). The program then walks through the batch of new headers, ensuring they are correctly linked together in a chain. During this process, it computes both the Poseidon and Keccak256 hashes of each new header. These hashes will serve as the new leaves for the two MMRs.

4.  **MMR Growth**: With the new leaf hashes computed, the program appends them to the MMR. It creates new parent nodes and peaks as necessary, following the MMR construction logic. This is done for both the Poseidon and Keccak256 MMRs.

5.  **Finalization and Verification**: Finally, after adding all new leaves, the program computes the new roots of the grown MMRs. These new roots, along with the new size of the MMR, are compared against an expected end-state snapshot. This final assertion guarantees that the entire off-chain computation of growing the MMR was performed correctly and according to the rules of the protocol.

## Supported Headers

Currently, this accumulator supports block headers from the following chains:

-   **Ethereum Beacon Chain**: Fully supported.

### Upcoming Support

Work is in progress to extend support to the following chains:

-   **Ethereum Execution Chain**: In progress.
-   **Major L2s**: Planned for future releases.

## Acknowledgements

This repository is a fork of the original work by the team at Herodotus. We want to extend a heartfelt thank you for their excellent and foundational work on Merkle Mountain Ranges. They are good friends, and their implementation has been an invaluable resource for us.

The original repository can be found here: [https://github.com/herodotusdev/mmr-header-accumulator](https://github.com/herodotusdev/mmr-header-accumulator).

The original project is licensed under the Apache 2.0 License. We have made modifications to the original software in this fork.
