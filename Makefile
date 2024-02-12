CORE := iob_soc_sut
BOARD ?= AES-KU040-DB-G

# Disable Linter while rules are not finished
DISABLE_LINT:=1

ifeq ($(TESTER),1)
TOP_MODULE_NAME :=iob_soc_tester
endif
ifneq ($(USE_EXTMEM),1)
$(info NOTE: USE_EXTMEM must be set to support iob-soc-opencryptolinux and ethernet with DMA. Auto-adding USE_EXTMEM=1...)
USE_EXTMEM:=1
endif

LIB_DIR:=submodules/IOBSOC/submodules/LIB
include $(LIB_DIR)/setup.mk

INIT_MEM ?= 1
RUN_LINUX ?= 0

ifeq ($(INIT_MEM),1)
SETUP_ARGS += INIT_MEM
endif

ifeq ($(USE_EXTMEM),1)
SETUP_ARGS += USE_EXTMEM
endif

ifeq ($(TESTER_ONLY),1)
SETUP_ARGS += TESTER_ONLY
endif

ifeq ($(RUN_LINUX),1)
SETUP_ARGS += RUN_LINUX
endif

ifeq ($(NO_ILA),1)
SETUP_ARGS += NO_ILA
endif

setup:
	make build-setup SETUP_ARGS="$(SETUP_ARGS)"

pc-emul-run: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ pc-emul-run

sim-run: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ sim-run

fpga-run: build_dir_name
ifeq ($(USE_EXTMEM),1)
	echo "WARNING: INIT_MEM must be set to zero run on the FPGA with USE_EXTMEM=1. Auto-setting INIT_MEM=0..."
	nix-shell --run "make clean setup INIT_MEM=0"
else
	nix-shell --run "make clean setup"
endif
	make fpga-connect

fpga-connect: build_dir_name
	nix-shell --run 'make -C $(BUILD_DIR)/ fpga-fw-build BOARD=$(BOARD) RUN_LINUX=$(RUN_LINUX)'
	make -C $(BUILD_DIR)/ fpga-run BOARD=$(BOARD) RUN_LINUX=$(RUN_LINUX) 

test-linux-fpga-connect: build_dir_name
	-rm $(BUILD_DIR)/hardware/fpga/test.log
	-ln -s minicom_test1.txt $(BUILD_DIR)/hardware/fpga/minicom_linux_script.txt
	make fpga-connect TESTER=1 RUN_LINUX=1

.PHONY: pc-emul-run sim-run fpga-run fpga-connect test-linux-fpga-connect

test-all: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ pc-emul-test
	#make sim-run SIMULATOR=icarus
	make sim-run SIMULATOR=verilator
	make fpga-run BOARD=CYCLONEV-GT-DK
	make fpga-run BOARD=AES-KU040-DB-G
	make clean setup && make -C $(BUILD_DIR)/ doc-test

.PHONY: test-all

build-sut-netlist: build_dir_name
	make clean && make setup 
	# Rename constraint files
	#FPGA_DIR=`ls -d $(BUILD_DIR)/hardware/fpga/quartus/CYCLONEV-GT-DK` &&\
	#mv $$FPGA_DIR/iob_soc_sut_fpga_wrapper_dev.sdc $$FPGA_DIR/iob_soc_sut_dev.sdc
	#FPGA_DIR=`ls -d $(BUILD_DIR)/hardware/fpga/vivado/AES-KU040-DB-G` &&\
	#mv $$FPGA_DIR/iob_soc_sut_fpga_wrapper_dev.sdc $$FPGA_DIR/iob_soc_sut_dev.sdc
	# Build netlist 
	make -C $(BUILD_DIR)/ fpga-build BOARD=$(BOARD) IS_FPGA=0

tester-sut-netlist: build-sut-netlist
	#Build tester without sut sources, but with netlist instead
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	rm -fr ../iob_soc_tester_V* && make setup TESTER_ONLY=1 BUILD_DIR="../iob_soc_tester_$$TESTER_VER" &&\
	cp ../iob_soc_sut_V*/hardware/fpga/iob_soc_sut_fpga_wrapper_netlist.v ../iob_soc_tester_$$TESTER_VER/hardware/fpga/iob_soc_sut.v &&\
	cp ../iob_soc_sut_V*/hardware/fpga/iob_soc_sut_firmware.* ../iob_soc_tester_$$TESTER_VER/hardware/fpga/ &&\
	if [ -f ../iob_soc_sut_V*/hardware/fpga/iob_soc_sut_stub.v ]; then cp ../iob_soc_sut_V*/hardware/fpga/iob_soc_sut_stub.v ../iob_soc_tester_$$TESTER_VER/hardware/src/; fi &&\
	echo -e "\nIP+=iob_soc_sut.v" >> ../iob_soc_tester_$$TESTER_VER/hardware/fpga/fpga_build.mk &&\
	cp software/firmware/iob_soc_tester_firmware.c ../iob_soc_tester_$$TESTER_VER/software/firmware
	# Copy and modify iob_soc_sut_params.vh (needed for stub) and modify *_stub.v to insert the SUT parameters 
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	if [ -f ../iob_soc_sut_V*/hardware/fpga/iob_soc_sut_stub.v ]; then\
		cp ../iob_soc_sut_V0.70/hardware/src/iob_soc_sut_params.vh ../iob_soc_tester_$$TESTER_VER/hardware/src/;\
		sed -i -E 's/=[^,]*(,?)$$/=0\1/g' ../iob_soc_tester_$$TESTER_VER/hardware/src/iob_soc_sut_params.vh;\
		sed -i 's/_sut(/_sut#(\n`include "iob_soc_sut_params.vh"\n)(/g' ../iob_soc_tester_$$TESTER_VER/hardware/src/iob_soc_sut_stub.v;\
	fi
	# Run Tester on fpga
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	make -C ../iob_soc_tester_V*/ fpga-run BOARD=$(BOARD) | tee ../iob_soc_tester_$$TESTER_VER/test.log && grep "Verification successful!" ../iob_soc_tester_$$TESTER_VER/test.log > /dev/null

.PHONY: build-sut-netlist test-sut-netlist

# Target to create vcd file based on ila_data.bin generated by the ILA Tester peripheral
ila-vcd: build_dir_name
	# Copy simulation ila data from remote machine (currently set to verilator)
	scp $(VSIM_USER)@$(VSIM_SERVER):$(USER)/`basename $(BUILD_DIR)`/hardware/simulation/ila_data.bin $(BUILD_DIR)/hardware/simulation 2> /dev/null | true
	# Create VCD file from simulation ila data
	if [ -f $(BUILD_DIR)/hardware/simulation/ila_data.bin ]; then \
		./$(BUILD_DIR)/./scripts/ilaDataToVCD.py ILA0 $(BUILD_DIR)/hardware/simulation/ila_data.bin ila_sim.vcd; fi
	# Copy fpga ila data from remote machine (currently set to ku040)
	scp $(KU40_USER)@$(KU40_SERVER):$(USER)/`basename $(BUILD_DIR)`/hardware/fpga/ila_data.bin $(BUILD_DIR)/hardware/fpga 2> /dev/null | true
	# Create VCD file from fpga ila data
	if [ -f $(BUILD_DIR)/hardware/fpga/ila_data.bin ]; then \
		./$(BUILD_DIR)/./scripts/ilaDataToVCD.py ILA0 $(BUILD_DIR)/hardware/fpga/ila_data.bin ila_fpga.vcd; fi
	#gtkwave ./ila_sim.vcd
.PHONY: ila-vcd

### Linux targets

LINUX_OS_DIR ?= submodules/TESTER/submodules/OPENCRYPTOLINUX/submodules/OS
TESTER_DIR ?= submodules/TESTER
REL_OS2TESTER :=`realpath $(TESTER_DIR) --relative-to=$(LINUX_OS_DIR)`
REL_OS2SUT :=`realpath $(CURDIR) --relative-to=$(LINUX_OS_DIR)`

build-linux-dts:
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-dts MACROS_FILE=$(REL_OS2TESTER)/hardware/simulation/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/simulation OS_SOFTWARE_DIR=$(REL_OS2TESTER)/software'
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-dts MACROS_FILE=$(REL_OS2TESTER)/hardware/fpga/vivado/AES-KU040-DB-G/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/fpga/vivado/AES-KU040-DB-G OS_SOFTWARE_DIR=$(REL_OS2TESTER)/software'
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-dts MACROS_FILE=$(REL_OS2TESTER)/hardware/fpga/quartus/CYCLONEV-GT-DK/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/fpga/quartus/CYCLONEV-GT-DK OS_SOFTWARE_DIR=$(REL_OS2TESTER)/software'

build-linux-opensbi:
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-opensbi MACROS_FILE=$(REL_OS2TESTER)/hardware/simulation/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/simulation'
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-opensbi MACROS_FILE=$(REL_OS2TESTER)/hardware/fpga/vivado/AES-KU040-DB-G/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/fpga/vivado/AES-KU040-DB-G'
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-opensbi MACROS_FILE=$(REL_OS2TESTER)/hardware/fpga/quartus/CYCLONEV-GT-DK/linux_build_macros.txt OS_BUILD_DIR=$(REL_OS2TESTER)/hardware/fpga/quartus/CYCLONEV-GT-DK'

build-linux-buildroot:
	make -C $(LINUX_OS_DIR) build-buildroot OS_SUBMODULES_DIR=$(REL_OS2SUT)/.. OS_SOFTWARE_DIR=../`realpath $(TESTER_DIR) --relative-to=..`/software OS_BUILD_DIR=$(REL_OS2TESTER)/software/src

build-linux-kernel:
	-rm ../linux-5.15.98/arch/riscv/boot/Image
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'make -C $(LINUX_OS_DIR) build-linux-kernel OS_SUBMODULES_DIR=$(REL_OS2SUT)/.. OS_SOFTWARE_DIR=../`realpath $(TESTER_DIR) --relative-to=..`/software OS_BUILD_DIR=$(REL_OS2TESTER)/software/src'

build-linux-files:
	make build-linux-dts
	make build-linux-opensbi
	make build-linux-buildroot
	make build-linux-kernel

.PHONY: build-linux-dts build-linux-opensbi build-linux-buildroot build-linux-kernel build-linux-files

INCLUDE = -I.
SRC = *.c
FLAGS = -Wall -O2
#FLAGS += -Werror
FLAGS += -static
FLAGS += -march=rv32imac
FLAGS += -mabi=ilp32
BIN = run_verification
CC = riscv64-unknown-linux-gnu-gcc
build-linux-tester-verification:
	nix-shell $(LINUX_OS_DIR)/default.nix --run 'cd $(TESTER_DIR)/software/buildroot/board/IObundle/iob-soc/rootfs-overlay/root/tester_verification/ && \
	$(CC) $(FLAGS) $(INCLUDE) -o $(BIN) $(SRC)'

.PHONY: build-linux-tester-verification
