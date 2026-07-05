# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2](https://github.com/lucid-softworks/lumen/compare/v0.1.1...v0.1.2) - 2026-07-05

### Added

- *(lumen)* interactive REPL — persistent realm, real multi-line continuation
- *(lumen)* bytecode execution tier v0 — opt-in, oracle-checked, 247 on v8-v7
- *(lumen)* wasm playground — engine compiled to WebAssembly + GitHub Pages site

### Fixed

- *(lumen)* [Symbol.asyncDispose] calls return() with no arguments

### Other

- *(lumen)* dense array elements + in-place local updates — 186 on v8-v7 (from 167)
- *(lumen)* +44% on the classic V8 suite — string fast paths, cached hoisting, leaner hot loops

## [0.1.1](https://github.com/lucid-softworks/lumen/compare/v0.1.0...v0.1.1) - 2026-07-05

### Other

- update Cargo.lock dependencies
