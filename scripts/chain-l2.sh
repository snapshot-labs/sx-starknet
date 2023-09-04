#!/bin/bash
starknet-devnet --seed 42 --verbose --sierra-compiler-path "${STARKNET_SIERRA_COMPILE_PATH}" --compiler-args '--allowed-libfuncs-list-file ./audited_cairo_libfuncs.json --add-pythonic-hints' --lite-mode
exit 0 
