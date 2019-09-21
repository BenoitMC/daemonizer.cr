#!/bin/bash
crystal build --release --no-debug daemonizer.cr
rm -f daemonizer.dwarf
