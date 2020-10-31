# nRF5 Example Makefile Project

This is a generic starting point for a project made with the nRF5 SDK. It extends Nordic's example build system:

* Builds using Docker environment
* Allows use of multiple sub-projects (for example, application and bootloader) within one repository
* Multiple PCB variants supported
* Continuous integration supported

## Getting Started

You will need the following software:

* Git
* Make
* Docker
* nrfutil
* Segger RTT viewer
* An IDE of your choice
* Some example nRF5 code from the [nRF5 SDK found here](https://developer.nordicsemi.com/nRF5_SDK/nRF5_SDK_v15.x.x/nRF5_SDK_15.2.0_9412b96.zip) - this example project assumes nRF52 SDK 15.2.0 with S132 SoftDevice in various places, but most should work with minor changes.

You will need to:

1. Copy nRF5 example(s) from the nRF5 SDK into the project:
    * `examples/ble_peripheral/ble_app_uart` -> `app`
    * `examples/dfu/secure_bootloader` -> `boot`
    * `examples/dtm/direct_test_mode` -> `dtm`
2. Update example project Makefile(s):
	- `-DNRF_DFU_HW_VERSION=$(COMBINED_PRODUCT_HARDWARE_VERSION)` added to CFLAGS / ASMFLAGS in the bootloader Makefile (and `COMBINED_PRODUCT_HARDWARE_VERSION` may need to be passed to the Makefile - TODO: Confirm this)
3. Configure the `project.mk` Makefile to build the example apps
4. Set up app-specific changes (eg DFU private key setup):
`
nrfutil keys generate private.pem
nrfutil keys display --key pk --format code private.pem --out_file boot/dfu_public_key.c
`

5. Configure `products.mk` based on the current range of products and PCB versions

To build the firmware, run `make`. Each sub-project will be built, and then `project.mk` will build the relevant artefacts (App DFU package and combined hex). 

To flash the hex using a JLink (external or on development board), run `make flash`.

To flash the app package to a remote development board via DFU, run `make flash_dfu`. You will need an nRF5 dongle or development board with the correct connectivity firmware flashed.

## Notes

Overrides default Makefile values with the following:
* SDK_ROOT - set to match the location of the nRF5 SDK in the Docker image. If you need to patch a bug in the SDK, you will need to copy this in to your project and update the path(s).
* OUTPUT_DIRECTORY - this is overridden to be specific to a Product and PCB version (ensures correct results even if building for different products/variants without running `make clean` inbetween.

## Continuous Integration

If your build server is capable of launching new Docker instances (eg Travis) you can do something similar to the following:

```
env:
  matrix:
    - PRODUCT_ID=1 PCBVER=1
    - PRODUCT_ID=1 PCBVER=2
    - PRODUCT_ID=2 PCBVER=1
    - PRODUCT_ID=2 PCBVER=2

script: 
  - make PRODUCT_ID=$PRODUCT_ID PCBVER=$PCBVER clean
  - make PRODUCT_ID=$PRODUCT_ID PCBVER=$PCBVER
```

For Github Actions, a similar syntax can be used, however the matrix strategy isn't as flexible. This can be worked around using `cut`:

``` build.yml

build:
  name: Build
  runs-on: ubuntu-latest
  strategy:
    matrix:
      combined_ver: ["1.1", "1.2", "2.1", "2.2"]
  steps:
  - name: Check out code
    uses: actions/checkout@v2     
  - name: Set up environment variables
    env:
      COMBINED_VER: ${{ matrix.combined_ver }}
    run: |
      echo "::set-env name=PRODUCT_ID::$(cut -d'.' -f1 <<<$COMBINED_VER)"
      echo "::set-env name=PCBVER::$(cut -d'.' -f2 <<<$COMBINED_VER)"
  - name: Build (Hardware ${{ matrix.combined_ver }})
    run: |
      echo "Building firmware $VERSION for product $PRODUCT_ID - PCB $PCBVER"
      make clean
      make
```
