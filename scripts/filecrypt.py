#!/usr/bin/env python
"""
Name: filecrypt.py
Description: Encrypt or decrypt a file.
Version: 0.1.3
Author: partner
Last Updated: 20180725
"""
import os 
import argparse
from sys import exit

ForeRED = "\033[01;31m{0}\033[00m"


def encryptfile(FILE, PASS):
    os.system("openssl aes-256-cbc -a -salt -in " + FILE + " -out " + FILE + ".enc -k '"  + PASS  + "'")


def decryptfile(FILE, PASS):
    os.system("openssl aes-256-cbc -d -a -in " + FILE + " -out " + FILE[:-4] + " -k '"  + PASS  + "'")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    required = parser.add_argument_group('required argument')
    required.add_argument(
        '-f',
        '--file',
        help='File to process',
        type=str,
        metavar='/path/to/file',
        required=True,
    )
    required.add_argument(
        '-p',
        '--passphrase',
        help='passphrase for encrypt/decrypt',
        type=str,
        metavar='<Pashphrase>',
        required=True,
    )
    requiredgroup = parser.add_mutually_exclusive_group(required=True,)
    requiredgroup.add_argument(
        '-e',
        '--encrypt',
        help='Encrypt a file',
        action="store_true",
    )
    requiredgroup.add_argument(
        '-d',
        '--decrypt',
        help='Decrypt a file',
        action="store_true",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print ForeRED.format("File does not exist!")
        exit(1)

    if args.encrypt:
        if args.file[-4:] == '.enc':
            print ForeRED.format("Encrypt option selected and file extension is .enc")
            exit(1)
        else:
            encryptfile(args.file, args.passphrase)

    if args.decrypt:
        if args.file[-4:] != '.enc':
            print ForeRED.format("Decrypt option selected and file extension is not .enc")
            exit(1)
        else:
            decryptfile(args.file, args.passphrase)

