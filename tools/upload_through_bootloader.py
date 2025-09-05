import serial
import argparse
import time
import os

parser = argparse.ArgumentParser(description='Upload through bootloader')
parser.add_argument('--port', type=str, default='/dev/ttyUSB0', help='Serial port to use')
parser.add_argument('--baudrate', type=int, default=19200, help='Baud rate')
parser.add_argument('file', type=str, help='File to upload')
args = parser.parse_args()

if not os.path.isfile(args.file):
    print(f"File {args.file} does not exist.")
    exit(1)

with open(args.file, 'rb') as f:
    file_data = f.read()


# after sending "h" serial should deliver:
# CMD:> h
# Available CMDs:
#  h: Help
#  r: Restart
#  u: Upload via UART
#  s: Store to SPI flash
#  l: Load from SPI flash
#  e: Start executable
# CMD:>

def read_serial_and_print(ser, block=False, timeout=0):
    received = False
    start_time = time.time()
    last_line = ''
    while ser.in_waiting or (block and not received):
        while (block and not received and not ser.in_waiting):
            time.sleep(0.1)
            if timeout and (time.time() - start_time) > timeout:
                print("Timeout waiting for serial data")
                return
        line = ser.readline()
        # UnicodeDecodeError: 'utf-8' codec can't decode byte 0xcd in position 0: invalid continuation byte
        try:
            last_line = line.decode().strip()
            print(last_line)
        except UnicodeDecodeError as e:
            print(f"Error decoding serial data: {e}")
            print('Line:')
            print(line)
            print('Line (errors="ignore"):')
            last_line = line.decode(errors="ignore").strip()
            print(last_line)
            print()
        received = True
    return last_line


with serial.Serial(args.port, args.baudrate, timeout=1) as ser:
    # read whatever is available
    print("Reading initial serial data...")
    read_serial_and_print(ser, block=True, timeout=5)

    print("Sending help command...")
    ser.write(b'h')
    read_serial_and_print(ser, block=True, timeout=5)

    print("Sending upload command...")
    ser.write(b'u')
    read_serial_and_print(ser, block=True, timeout=5)

    print("Sending file data...")
    ser.write(file_data)

    print("Reading output until 'OK' or 'CMD:>' is received...")
    last_line = ''
    while last_line not in ['CMD:>', 'OK']:
        last_line = read_serial_and_print(ser)

    print("Sending 'start executable' command")
    ser.write(b'e')

    print("Reading output continuously...")
    while True:
        read_serial_and_print(ser)
