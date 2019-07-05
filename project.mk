# This Makefile is called within the Docker environment
# It should be used for building the firmware binaries

TEMP_DIR = tmp
ARTEFACTS_DIR = artefacts

SDK_ROOT=/nrf5/nRF5_SDK_15.2.0
APPLICATION = app/src/pca10040/s132/armgcc/_build_$(COMBINED_PRODUCT_HARDWARE_VERSION)/nrf52832_xxaa.hex
BOOTLOADER = boot_nrf52/bootloader_secure/pca10040_ble/armgcc/_build_$(COMBINED_PRODUCT_HARDWARE_VERSION)/nrf52832_xxaa_s132.hex
SOFTDEVICE = $(SDK_ROOT)/components/softdevice/s132/hex/s132_nrf52_6.1.0_softdevice.hex
BL_SETTINGS = $(TEMP_DIR)/bootloadersettings.hex

VERSION_IDENTIFIER = $(PRODUCT_NAME)-$(PRODUCT_ID).$(PCBVER)

# Combined version is a single number which combines both the Product ID and PCB revision. Useful for bootloader hardware version number...
A = $(PRODUCT_ID)
B = $(PCBVER)
COMBINED_PRODUCT_HARDWARE_VERSION=$(shell echo $$(($A*256+$B)))


.PHONY: all clean
all:
	mkdir -p $(TEMP_DIR)/
	@echo "project.mk is building for $(PRODUCT_NAME) with PRODUCT_ID=$(PRODUCT_ID), PCBVER=$(PCBVER)"
	
	# Build the sub-projects
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C app/src/pca10040/s132/armgcc
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C boot_nrf52/bootloader_secure/pca10040_ble/armgcc
	
	# Build the DFU package from the app
	nrfutil pkg generate --hw-version $(COMBINED_PRODUCT_HARDWARE_VERSION) --application-version 1 --application $(OUTPUT_DIRECTORY)/nrf52832_xxaa.hex --sd-req 0xAF --key-file $(PROJ_DIR)/private.pem $(ARTEFACTS_DIR)/dfu-$(VERSION_IDENTIFIER).zip
	
	# Merge hex files to form a complete package
	# In order to boot into the app immediately after flashing, the bootloader's settings page needs to be written
	nrfutil settings generate --family NRF52 --application $(APPLICATION) --application-version 0 --bootloader-version 0 --bl-settings-version 1 $(BL_SETTINGS)
	srec_cat $(SOFTDEVICE) -intel $(APPLICATION) -intel $(BOOTLOADER) -intel $(BL_SETTINGS) -intel -o $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex -intel -address-length=4
	
	# For convenience, store this hex file as our latest successful build
	cp $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex latest.hex

clean:
	@echo "project.mk is cleaning for $(PRODUCT_NAME) with PRODUCT_ID=$(PRODUCT_ID), PCBVER=$(PCBVER)"
	rm -rf hex/
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C app/src/pca10040/s132/armgcc clean
	make SDK_ROOT=$(SDK_ROOT) OUTPUT_DIRECTORY=_build_$(COMBINED_PRODUCT_HARDWARE_VERSION) -C boot_nrf52/bootloader_secure/pca10040_ble/armgcc clean
	rm $(ARTEFACTS_DIR)/img-$(VERSION_IDENTIFIER).hex
	rm $(ARTEFACTS_DIR)/dfu-$(VERSION_IDENTIFIER).zip
