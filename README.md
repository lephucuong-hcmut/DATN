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
- Polynomial multiplication
- Keccak / SHAKE-based hashing

KeyGen Block Design
<img width="864" height="773" alt="Image" src="https://github.com/user-attachments/assets/9d3091b0-ffa8-4cb3-aa89-c95c32b62d06" />

Encap Block Design
<img width="976" height="606" alt="Image" src="https://github.com/user-attachments/assets/49686108-4d10-4a11-88ee-7d9fdc9e6bc1" />

Decap Block Design
<img width="1079" height="780" alt="Image" src="https://github.com/user-attachments/assets/25bb238f-2069-4aae-b8cd-6ca59d5e3433" />

Polynomial multiplacation Block Design
<img width="1084" height="468" alt="Image" src="https://github.com/user-attachments/assets/d4441c6b-1177-4ba2-8431-46cad5c6316b" />


Keccak 1600 bit refer from Keccak TEAM
<img width="544" height="481" alt="Image" src="https://github.com/user-attachments/assets/4f009c1a-cf50-49e7-83a2-4c8e900ea4fa" />

It is also have many sub modules to help the design.  See at DATN/project_1
/src/

The FPGA implementation achieves **up to 200× speedup** compared with the IoT Nucleo implementation under the evaluated conditions.
