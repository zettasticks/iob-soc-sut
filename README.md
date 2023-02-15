# IOb-SoC-SUT

IOb-SoC-SUT is a generic RISC-V SoC, based on [IOb-SoC](https://github.com/IObundle/iob-soc), used to verify the [IOb-SoC-Tester](https://github.com/IObundle/iob-soc-tester).
This repository is a System Under Test (SUT) example, demonstrating the Tester's abilities for verification purposes.

This system runs on bare metal and has UART and IOb-native interfaces.

## Dependencies

Before building the system, install the following tools:
- GNU Bash >=5.1.16
- GNU Make >=4.3
- RISC-V GNU Compiler Toolchain =2022.06.10  (Instructions at the end of this README)
- Python3 >=3.10.6
- Python3-Parse >=1.19.0

Optional tools, depending on desired run strategy:
- Icarus Verilog >=10.3
- Verilator >=5.002
- gtkwave >=3.3.113
- Vivado >=2020.2
- Quartus >=20.1

Older versions of the dependencies above may work but were not tested.

## Nix environment

Instead of manually installing the dependencies above, you can use
[nix-shell](https://nixos.org/download.html#nix-install-linux) to run
IOb-SoC-SUT in a [Nix](https://nixos.org/) environment with all dependencies
available except for Vivado and Quartus.

- Run `nix-shell` from the IOb-SoC-SUT root directory to install and start the environment with all the required dependencies.

## Setup the SUT

This system's setup, build and run steps are similar to the ones used in [IOb-SoC](https://github.com/IObundle/iob-soc).
Check the `README.md` file of that repository for more details on the process of setup, building and running the system without the Tester.

The SUT's main configuration, stored in `iob_soc_sut_setup.py`, sets the UART, REGFILEIF and ETHERNET peripherals. In total, the SUT has one UART, one ETHERNET, and one IOb-native (provided by the REGFILEIF peripheral) interface.

**NOTE**: For the time being, the ETHERNET peripheral is disabled as it has not yet been updated to be compatible with the new python-setup branch.

To set up the system, type:

```Bash
make setup [<control parameters>]
```

`<control parameters>` are system configuration parameters passed in the
command line, overriding those in the `iob_soc_sut_setup.py` file. Example control
parameters are `INIT_MEM=0 USE_EXTMEM=1`. For example,

```Bash
make setup INIT_MEM=0 USE_EXTMEM=1
```

The setup process will create a build directory that contains all the files required for building the system.

The **setup directory** is considered to be the repository folder, as it contains the files needed to set up the system.

The **build directory** is considered to be the folder generated by the setup process, as it contains the files needed to build the system.
The build directory is usually located in `../iob_soc_sut_V*` relative to the setup directory.

The SUT's firmware, stored in `software/firmware/iob_soc_sut_firmware.c` has two modes of operation:
- Without external memory (USE\_EXTMEM=0)
- Running from external memory (USE\_EXTMEM=1)

This firmware currently does not use the ethernet interface.

When running without external memory, the SUT only prints a few `Hello Word!` messages via UART and inserts values into the registers of its IOb-native interface.

When running from the external memory, the system does the same as without external memory. It also allocates and stores a string in memory and writes its pointer to a register in the IOb-native interface.

### Emulate the SUT on the PC

To emulate the SUT's embedded software on a PC, type:

```Bash
make -C ../iob_soc_sut_V* pc-emul
```

### Simulate the SUT

To build and run the SUT in simulation, type:

```Bash
make -C ../iob_soc_sut_V* sim-run [SIMULATOR=<simulator name>]
```

`<simulator name>` is the name of the simulator's Makefile segment.

### Build and run the SUT on the FPGA board

To build the SUT for FPGA, type:

```Bash
make -C ../iob_soc_sut_V* fpga-build [BOARD=<board directory name>]
```

`<board directory name>` is the name of the board's run directory.

To run the SUT in FPGA, type:

```Bash
make -C ../iob_soc_sut_V* fpga-run [BOARD=<board directory name>]
```

## Setup the Tester along with the SUT

The Tester's main configuration is stored in the `tester_options` variable of the `iob_soc_sut_setup.py` file.
It adds the IOBNATIVEBRIDGEIF, two ETHERNET, and another UART instance to the default Tester peripherals.
In total, the Tester has two UART interfaces, two ETHERNET, and one IOb-native (provided by IOBNATIVEBRIDGEIF).

**NOTE**: As mentioned previously, for the time being, the ETHERNET peripheral is disabled as it has not yet been updated to be compatible with the new python-setup branch.

To set up the Tester with the SUT, type:

```Bash
make setup TESTER=1 [<control parameters>]
```

The SUT and Tester's peripheral IO connections, stored in the `peripheral_portmap` variable of the `iob_soc_sut_setup.py` file, have the following configuration:
- Instance 0 of Tester's UART is connected to the PC's console.
- Instance 1 of Tester's UART is connected to the SUT's UART.
- Tester's IOBNATIVEBRIDGEIF is connected to SUT's REGFILEIF. These are the IOb-native interfaces of both systems.
- Instance 0 of Tester's ETHERNET is connected to the PC's console. Currently, this interface is not used.
- Instance 1 of Tester's ETHERNET is connected to the SUT's ETHERNET. Currently, these interfaces are not used.

The Tester's firmware, stored in `software/firmware/iob_soc_tester_firmware.c`, also has two modes of operation:
- Without external memory (USE\_EXTMEM=0)
- Running from external memory (USE\_EXTMEM=1)

This firmware currently does not use ethernet interfaces.

When running without external memory, the Tester only relays messages printed from the SUT to the console and reads values from the IOb-native interface connected to the SUT.

When running from the external memory, the Tester does the same as without external memory.
But it also reads a string pointer from the IOb-native interface.
It inverts the most significant bit of that pointer to access the SUT's address space and then reads the string stored at that location.

More details on configuring, building and running the Tester are available in the `README.md` file of the [IOb-SoC-Tester](https://github.com/IObundle/iob-soc-tester) repository.


### Build and run the Tester along with the SUT

The steps to build and run the Tester along with the SUT, are the same as the ones for the SUT individually.
You just need to make sure that the system was previously setup with the `TESTER=1` argument in the `make setup TESTER=1` command.

To build and run in simulation, type:

```Bash
make -C ../iob_soc_sut_V* sim-run [SIMULATOR=<simulator name>]
```

`<simulator name>` is the name of the simulator's Makefile segment.

To build for FPGA, type:

```Bash
make -C ../iob_soc_sut_V* fpga-build [BOARD=<board name>]
```

`<board name>` is the name of the board's run directory.

To run in FPGA, type:

```Bash
make -C ../iob_soc_sut_V* fpga-run [BOARD=<board name>]
```

## Cleaning

The following command will clean the selected simulation, board and document
directories, locally and in the remote servers:

```Bash
make -C ../iob_soc_sut_V* clean
```

The following command will delete the build directory:

```Bash
make clean
```

## Instructions for Installing the RISC-V GNU Compiler Toolchain

### Get sources and checkout the supported stable version

```Bash
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
git checkout 2022.06.10
```

### Prerequisites

For the Ubuntu OS and its variants:

```Bash
sudo apt install autoconf automake autotools-dev curl python3 python2 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
```

For CentOS and its variants:

```Bash
sudo yum install autoconf automake python3 python2 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel
```

### Installation

```Bash
./configure --prefix=/path/to/riscv --enable-multilib
sudo make -j$(nproc)
```

This will take a while. After it is done, type:

```Bash
export PATH=$PATH:/path/to/riscv/bin
```

The above command should be added to your `~/.bashrc` file, so that
you do not have to type it on every session.

# Acknowledgement
The [OpenCryptoTester](https://nlnet.nl/project/OpenCryptoTester#ack) project is funded through the NGI Assure Fund, a fund established by NLnet
with financial support from the European Commission's Next Generation Internet
programme, under the aegis of DG Communications Networks, Content and Technology
under grant agreement No 957073.

<table>
    <tr>
        <td align="center" width="50%"><img src="https://nlnet.nl/logo/banner.svg" alt="NLnet foundation logo" style="width:90%"></td>
        <td align="center"><img src="https://nlnet.nl/image/logos/NGIAssure_tag.svg" alt="NGI Assure logo" style="width:90%"></td>
    </tr>
</table>
