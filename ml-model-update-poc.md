# IoT Reference Integration for Arm -- ML Model update

## Introduction

The *IoT Reference Integration for Arm* does a great job demonstrating how to
develop a feature-rich IoT device. Building on top of it, this proof of concept
shows how to configure the project to extend the Over the Air (OTA) firmware
update feature to allow an ML-model-only update.

## Details

The PSA Firmware Update API already uses the concept of a firmware component,
and the reference implementation integrated into the FRI, the Trusted
Firmware-M, operates on either two-component configuration (Secure and
Non-Secure images), or a single-component config (where the Secure and
Non-Secure images are merged). To enable the ML model OTA update, it was
necessary to update the default configuration to support a 3-component setup,
and to lift any limitations specific to a 2-component implementation.

For details, please see the feature branch hosted [here][poc-branch]. Please
note that commit messages for the submodules are part of the respective patch
files in the repo.

### Summary of changes

#### ML Model extraction

The ML model was moved from the DDR memory into a separate binary loaded into
flash. This enabled the MCUBoot bootloader to handle the model in the same way
as the other firmware components that are stored in their dedicated flash
partitions. Now, MCUBoot can successfully validate or update the ML model image.

#### Partition resizing

To keep the changes minimal, the ML model partitions were created at the cost of
the Non-Secure partitions. These were re-sized from `0x340000 B` to
`0x240000 B`, and the remaining `0x100000 B` were used for the ML model. As a
result, addresses of the Secure, Non-Secure and Scratch partitions are
unchanged. Also the sizes of the Secure and Scratch partitions remain unchanged.

#### Runtime copy

Since the Ethos NPU is not allowed to access flash, the model is copied to DDR
at runtime (during the ML task init). This is why the model is still kept in the
DDR memory region in the linker script.

#### OTA PAL version handling & file path

The OTA PAL (precisely, the `OtaPalInterface_t` interface) had to be extended
with `getPlatformImageVersion` to enable independent version handling for each
component in a multi-component setup.

#### Image processing

Also the build environment required a number of updates to correctly process the
additional ML model image. Provisioning data and signing layout were configured
for the ML model image based on the Non-Secure image config. Currently, the ML
model image is signed with the same key as the Non-Secure image, but this can be
easily changed in the CMake config.

## Build instructions

Fetch the code hosted in [the `model-only-update` feature branch][poc-branch].

Currently, the ML model update is supported for the Keyword-Detection example
application built with the `GNU` toolchain for the `corstone300` platform.
Please follow [the application-specific build instructions](docs/applications/keyword_detection.md).
Please note that like the original Keyword-Detection example, this ML model
update PoC also requires:

- a certificate,
- a private key,
- and AWS credentials.

## Run instructions

Please follow [the application-specific run instructions](docs/applications/keyword_detection.md).

If you prefer to run the FVP manually, and explicitly set all the arguments
(e.g. when debugging), run the following command:

```bash
FVP_Corstone_SSE-300_Ethos-U55 \
-C mps3_board.visualisation.disable-visualisation=1 \
-C core_clk.mul=200000000 \
-C mps3_board.smsc_91c111.enabled=1 \
-C mps3_board.hostbridge.userNetworking=1 \
-C mps3_board.telnetterminal0.start_telnet=0 \
-C mps3_board.uart0.out_file=- \
-C mps3_board.uart0.unbuffered_output=1 \
-C ethosu.extra_args=--fast \
-C mps3_board.DISABLE_GATING=1 \
-a /workspaces/iot-reference-arm-corstone3xx/build/iot_reference_arm_corstone3xx/components/security/trusted_firmware-m/integration/trusted_firmware-m-build-prefix/src/trusted_firmware-m-build-build/bin/bl2.axf \
--data build/iot_reference_arm_corstone3xx/components/security/trusted_firmware-m/integration/trusted_firmware-m-build-prefix/src/trusted_firmware-m-build-build/api_ns/bin/encrypted_provisioning_bundle.bin@0x10022000 \
--data build/keyword-detection_signed.bin@0x28040000 \
--data build/iot_reference_arm_corstone3xx/components/security/trusted_firmware-m/integration/trusted_firmware-m-build-prefix/src/trusted_firmware-m-build-build/api_ns/bin/tfm_s_signed.bin@0x38000000 \
--data build/helpers/provisioning/provisioning_data.bin@0x211ff000 \
--data build/application_sectors/ddr.bin@0x60100000 \
--data build/keyword-detection-model_signed.bin@0x28280000
```

### ML Model update with AWS

As for the usual Non-Secure OTA update demo, the updated ML model firmware image
is created during the application build process. The updated image will only
differ in version number. That is enough to demonstrate the OTA process using a
newly created image.

With the application **not running**, deploy an AWS update job as described in the
[Firmware update with AWS](docs/applications/aws_iot/aws_iot_cloud_connection.md)
section. The flow for the ML model is very similar to the one for the Non-Secure
image; the only differences are:

- use `ml_model image` for **Path name of file on device**,
- upload the signed update binary, `build/keyword-detection-model-update_signed.bin`
- use the signature string from `build/model-update-signature.txt`.

Now, start the Keyword-Detection example, and observe the ML model update.

## Known Issues

1. The keyword-detection application crashes at boot when the ML Model update is
started when the application has already been running.

    In other words, when the AWS update job for the ML model is deployed when
    the FVP is already running, MCUBoot fails to find a valid image after the
    reboot. This scenario requires a fix. As a workaround sufficient for the PoC
    demo, deploy the ML model AWS update job only when the FVP is not running.
1. Toolchain support is limited to `GNU`.
1. Platform support is limited to `corstone300`.
1. Example application support is limited to `Keyword-Detection`.

[poc-branch]: https://gitlab.oss.arm.com/engineering/iot-m-sw/dev/freertos-staging/iot-reference-arm-corstone3xx/-/tree/dev/filjag01/model-only-update
