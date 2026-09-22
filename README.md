# FPGA-Based HQC Post-Quantum Cryptographic Accelerator

## Overview

This project is a Capstone Project focused on the hardware implementation and acceleration of the **Hamming Quasi-Cyclic (HQC)** post-quantum key encapsulation mechanism (KEM) using **Verilog HDL** and FPGA technology.
<img width="1159" height="592" alt="Image" src="https://github.com/user-attachments/assets/6e244624-2673-4157-9b20-1270e138490a" />

The main objective is to implement the major cryptographic operations of HQC in hardware and investigate the performance benefits of FPGA-based acceleration compared with a microcontroller-based implementation.

The project implements the complete HQC cryptographic flow, including:
<img width="1576" height="730" alt="Image" src="https://github.com/user-attachments/assets/8b94cab7-4e50-4241-9781-03a146538ee1" />

- Key Generation
- Encapsulation
- Decapsulation
- Reed–Solomon (RS) encoding and decoding
- Reed–Muller (RM) encoding and decoding
- Polynomial multiplication
- GF(2^8) arithmetic
- Keccak / SHAKE-based hashing
- Error correction and decoding operations

The FPGA implementation achieves **up to 200× speedup** compared with the IoT Nucleo implementation under the evaluated conditions.
