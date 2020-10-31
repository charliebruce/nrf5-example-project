# This Makefile is called within the Docker environment
# It should be used for building the firmware binaries

# Configure as required here
CHIP=nrf52832_xxaa
BOARD=pca10040
SD_TYPE=s132
SD_VERSION=6.1.0
SD_VERSION_HEX=0xAF # Run `nrfutil pkg generate --help` for a list 
SDK_ROOT=/nrf5/nRF5_SDK_15.2.0

# Directories used to store files
TEMP_DIR = tmp
ARTEFACTS_DIR = artefacts

# Files generated as part of the build process
APPLICATION = app/src/$(BOARD)/$(SD_TYPE)/armgcc/_build_$(COMBINED_PRODUCT_HARDWARE_VERSION)/$(CHIP).hex
BOOTLOADER = boot/bootloader_secure/$(BOARD)_ble/armgcc/_build_$(COMBINED_PRODUCT_HARDWARE_VERSION)/$(CHIP)_$(SD_TYPE).hex
SOFTDEVICE = $(SDK_ROOT)/components/softdevice/$(SD_TYPE)/hex/$(SD_TYPE)_nrf52_$(SD_VERSION)_softdevice.hex
BL_SETTINGS = $(TEMP_DIR)/bootloadersettings.hex

# Human-readable identifier for artefacts
VERSION_IDENTIFIER = $(PRODUCT_NAME)-$(PRODUCT_ID).$(PCBVER)

# Combined version is a single number which combines both the Product ID and PCB revision. Useful for bootloader hardware version number...
A = $(PRODUCT_ID)
B = $(PCBVER)
COMBINED_PRODUCT_HARDWARE_VERSION=$(shell echo $$(($A*256+$B)))

# Identify the number of processors present on the build machine. Use this to set the number of jobs for best performance.
NUMPROC := $(shell grep -c "processor" /proc/cpuinfo)
ifeq ($(NUMPROC),0)
        NUMPROC = 1
endif
NUMJOBS := $(shell echo $$(($(NUMPROC)*2)))


.PHONY: all clean
all:
	mkdir -p $(TEMP_DIR)/
	@echo "project.mk is building for $(PRODUCT_NAME) with PRODUCT_ID=$(PRODUCT_ID), PCBVER=$(PCBVER)"
	
	# Build the sub-projects
	make -j$(NUMJOBS) PASS_LINKER_INPUT_VIA_FILE=0 SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C app/src/$(BOARD)/$(SD_TYPE)/armgcc
	make -j$(NUMJOBS) PASS_LINKER_INPUT_VIA_FILE=0 SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C dtm/src/$(BOARD)/blank/armgcc
	make -j$(NUMJOBS) PASS_LINKER_INPUT_VIA_FILE=0 SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C boot/bootloader_secure/$(BOARD)_ble/armgcc
	
	# Make the artefacts directory if it does not exist
	mkdir -p artefacts
	
	# Build the DFU package from the app
	nrfutil pkg generate --hw-version $(COMBINED_PRODUCT_HARDWARE_VERSION) --application-version 1 --application $(APPLICATION) --sd-req $(SD_VERSION_HEX) --key-file private.pem $(ARTEFACTS_DIR)/dfu-$(VERSION_IDENTIFIER).zip
	
	# Merge hex files to form a complete package
	# In order to boot into the app immediately after flashing, the bootloader's settings page needs to be written
	nrfutil settings generate --family NRF52 --application $(APPLICATION) --application-version 0 --bootloader-version 0 --bl-settings-version 1 $(BL_SETTINGS)
	srec_cat $(SOFTDEVICE) -intel $(APPLICATION) -intel $(BOOTLOADER) -intel $(BL_SETTINGS) -intel -o $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex -intel -address-length=4
	
	# For convenience, store this hex file as our latest successful build
	cp $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex latest.hex

clean:
	@echo "project.mk is cleaning for $(PRODUCT_NAME) with PRODUCT_ID=$(PRODUCT_ID), PCBVER=$(PCBVER)"
	rm -rf hex/
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C app/src/$(BOARD)/$(SD_TYPE)/armgcc clean
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C dtm/src/$(BOARD)/blank/armgcc clean
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C boot/bootloader_secure/$(BOARD)_ble/armgcc clean
	rm $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex
	rm $(ARTEFACTS_DIR)/dfu-$(VERSION_IDENTIFIER).zip
