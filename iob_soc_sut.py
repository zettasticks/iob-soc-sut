#!/usr/bin/env python3
import os
import copy

from iob_soc import iob_soc
from iob_regfileif import iob_regfileif
from iob_gpio import iob_gpio
from iob_axistream_in import iob_axistream_in
from iob_axistream_out import iob_axistream_out
from iob_eth import iob_eth
from iob_ram_2p_be import iob_ram_2p_be

sut_regs = [
    {
        "name": "regfileif",
        "descr": "REGFILEIF software accessible registers.",
        "regs": [
            {
                "name": "REG1",
                "type": "W",
                "n_bits": 8,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Write register: 8 bit",
            },
            {
                "name": "REG2",
                "type": "W",
                "n_bits": 16,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Write register: 16 bit",
            },
            {
                "name": "REG3",
                "type": "R",
                "n_bits": 8,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Read register: 8 bit",
            },
            {
                "name": "REG4",
                "type": "R",
                "n_bits": 16,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Read register 16 bit",
            },
            {
                "name": "REG5",
                "type": "R",
                "n_bits": 32,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Read register 32 bit. In this example, we use this to pass the sutMemoryMessage address.",
            },
        ],
    }
]


class iob_soc_sut(iob_soc):
    name = "iob_soc_sut"
    version = "V0.70"
    flows = "pc-emul emb sim doc fpga"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        """Create submodules list with dependencies of this module"""
        super()._create_submodules_list(
            [
                iob_regfileif_custom,
                iob_gpio,
                iob_axistream_in,
                iob_axistream_out,
                # iob_eth,
                # Modules required for AXISTREAM
                (iob_ram_2p_be, {"purpose": "simulation"}),
                (iob_ram_2p_be, {"purpose": "fpga"}),
            ]
        )

    @classmethod
    def _specific_setup(cls):
        """Method that runs the setup process of this class"""
        # Instantiate SUT peripherals
        cls.peripherals.append(
            iob_regfileif_custom("REGFILEIF0", "Register file interface")
        )
        cls.peripherals.append(iob_gpio("GPIO0", "GPIO interface"))
        cls.peripherals.append(
            iob_axistream_in(
                "AXISTREAMIN0",
                "SUT AXI input stream interface",
                parameters={"TDATA_W": "32"},
            )
        )
        cls.peripherals.append(
            iob_axistream_out(
                "AXISTREAMOUT0",
                "SUT AXI output stream interface",
                parameters={"TDATA_W": "32"},
            )
        )
        # cls.peripherals.append(iob_eth("ETH0", "Ethernet interface"))

        cls.peripheral_portmap += [
            (  # Map REGFILEIF0 to external interface
                {
                    "corename": "REGFILEIF0",
                    "if_name": "external_iob_s_port",
                    "port": "",
                    "bits": [],
                },
                {
                    "corename": "external",
                    "if_name": "REGFILEIF0",
                    "port": "",
                    "bits": [],
                    "ios_table_prefix": False,  # Don't add interface table prefix (REGFILEIF0) to the signal names
                    "remove_string_from_port_names": "external_",  # Remove this string from the port names of the external IO
                },
            ),
        ]

        # Run IOb-SoC setup
        super()._specific_setup()

    @classmethod
    def _generate_files(cls):
        super()._generate_files()
        # Remove iob_soc_sut_swreg_gen.v as it is not used
        os.remove(os.path.join(cls.build_dir, "hardware/src/iob_soc_sut_swreg_gen.v"))

    @classmethod
    def _init_attributes(cls):
        super()._init_attributes()
        cls.regs = sut_regs

    @classmethod
    def _setup_confs(cls):
        # Append confs or override them if they exist
        super()._setup_confs(
            [
                # {'name':'BOOTROM_ADDR_W','type':'P', 'val':'13', 'min':'1', 'max':'32', 'descr':"Boot ROM address width"},
                {
                    "name": "SRAM_ADDR_W",
                    "type": "P",
                    "val": "16",
                    "min": "1",
                    "max": "32",
                    "descr": "SRAM address width",
                },
            ]
        )


# Custom iob_regfileif subclass for use in SUT system
class iob_regfileif_custom(iob_regfileif):
    @classmethod
    def _init_attributes(cls):
        super()._init_attributes()
        cls.regs = copy.deepcopy(sut_regs)