# Various ways of flashing the complete image(s) to the nRF5 hardware

flash: 
	nrfjprog --program $(COMPLETE_HEX) --sectorerase --verify --reset
	
flash_dfu:
	#"-f" flag will write the connectivity firmware to the nRF52 development board or dongle.
	nrfutil dfu ble -ic NRF52 -pkg $(APP_ZIP) -p COM3 -n "DfuTarg"

erase:
	nrfjprog --eraseall

