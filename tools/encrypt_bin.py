'''
This script will encrypt a .bin file given encryption key stored in a separate file.
Encryption will use XORing each 32-bit value (instruction) by the key and by the 
instruction address (byte offset within the file). So the 1st instruction is at address 0,
and the 2nd instruction is at address 4.

Example command:
python3 encrypt_bin.py main.bin key_file encrypted_main.bin
'''

import sys
import pathlib
import os
import argparse
import struct

def encrypt_bin_file(bin_file_path, key, output_file_path, verbose=False):
    # # Read the encryption key
    # with open(key_file_path, "rb") as key_file:
    #     key = key_file.read()
    #     if verbose:
    #         print(f"Using encryption key: {key.hex()}")

    # Read the binary file
    with open(bin_file_path, "rb") as bin_file:
        bin_data = bin_file.read()

    # Encrypt the binary data
    encrypted_data = bytearray()
    for i in range(0, len(bin_data), 4):
        # Read a 32-bit instruction
        instruction = struct.unpack("<I", bin_data[i:i+4])[0]
        # Encrypt the instruction
        # encrypted_instruction = instruction ^ struct.unpack("<I", key)[0] ^ i
        mask = (1 << 32) - 1
        encrypted_instruction = (instruction ^ int.from_bytes(key, byteorder='big') ^ i) & mask
        encrypted_data.extend(struct.pack("<I", encrypted_instruction))
        # import pdb; pdb.set_trace()

        if verbose:
            print(f"Encrypting instruction at offset {i}: {instruction:#010x} -> {encrypted_instruction:#010x}")

    # Write the encrypted data to the output file
    with open(output_file_path, "wb") as output_file:
        output_file.write(encrypted_data)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Encrypt a binary file.")
    parser.add_argument("bin_file", help="Path to the binary file to encrypt.")
    parser.add_argument("key", help="Hexadecimal key")
    parser.add_argument("output_file", help="Path to the output file for the encrypted data.")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output.")
    args = parser.parse_args()

    key = args.key.split('x')[-1] if 'x' in args.key else args.key
    encrypt_bin_file(args.bin_file, bytes.fromhex(key), args.output_file, args.verbose)