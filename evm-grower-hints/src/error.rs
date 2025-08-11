use rust_vm_hints::vm::cairo_vm::{
    cairo_run::EncodeTraceError,
    types::errors::program_errors::ProgramError,
    vm::errors::{
        cairo_run_errors::CairoRunError, runner_errors::RunnerError, trace_errors::TraceError,
        vm_errors::VirtualMachineError,
    },
};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("Failed to interact with the file system")]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
    #[error("{0}")]
    Parse(String),
    #[error(transparent)]
    EncodeTrace(#[from] EncodeTraceError),
    #[error(transparent)]
    VirtualMachine(#[from] VirtualMachineError),
    #[error(transparent)]
    Trace(#[from] TraceError),
    #[error(transparent)]
    Program(#[from] ProgramError),
    #[error(transparent)]
    CairoRun(#[from] CairoRunError),
    #[error(transparent)]
    Runner(#[from] RunnerError),
}
