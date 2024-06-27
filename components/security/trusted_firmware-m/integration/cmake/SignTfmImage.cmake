# Copyright 2023-2024 Arm Limited and/or its affiliates
# <open-source-office@arm.com>
# SPDX-License-Identifier: MIT

list(APPEND CMAKE_MODULE_PATH ${IOT_REFERENCE_ARM_CORSTONE3XX_SOURCE_DIR}/tools/cmake)
include(ConvertElfToBin)
include(ExternalProject)

ExternalProject_Get_Property(trusted_firmware-m-build BINARY_DIR)

function(iot_reference_arm_corstone3xx_tf_m_sign_images target signed_ns_bin_name ns_bin_version signed_ns_ml_model_bin_name ns_ml_model_bin_version pad)
    if(${pad})
        set(pad_option "--pad")
    else()
        set(pad_option "")
    endif()

    set(LINKER_SECTION_NAMES  "ddr.bin" "model.bin")
    set(OUTPUT_BINARY_NAME    "flash")

    extract_sections_from_axf(
        ${target}
        SECTIONS_NAMES   "${LINKER_SECTION_NAMES}"
        OUTPUT_BIN_NAME  "${OUTPUT_BINARY_NAME}"
    )

    add_custom_command(
        TARGET
            ${target}
        POST_BUILD
        DEPENDS
            $<TARGET_FILE_DIR:${target}>/${target}.bin
        COMMAND
            # Sign the non-secure (application) image for TF-M bootloader (BL2)
            python3 ${BINARY_DIR}/api_ns/image_signing/scripts/wrapper/wrapper.py
                -v ${ns_bin_version}
                --layout ${BINARY_DIR}/api_ns/image_signing/layout_files/signing_layout_ns.o
                -k ${BINARY_DIR}/api_ns/image_signing/keys/image_ns_signing_private_key.pem
                --public-key-format full
                --align 1 --pad-header ${pad_option} -H 0x400 -s auto
                --measured-boot-record
                --confirm
                ${SECTORS_BIN_DIR}/${OUTPUT_BINARY_NAME}.bin
                $<TARGET_FILE_DIR:${target}>/${signed_ns_bin_name}.bin
        COMMAND
            ${CMAKE_COMMAND} -E echo "-- signed: $<TARGET_FILE_DIR:${target}>/${signed_ns_bin_name}.bin"
        VERBATIM
    )

    add_custom_command(
        TARGET
            ${target}
        POST_BUILD
        DEPENDS
            $<TARGET_FILE_DIR:${target}>/${target}.bin
        COMMAND
            # Sign the non-secure (ML model) image for TF-M bootloader (BL2)
            python3 ${BINARY_DIR}/api_ns/image_signing/scripts/wrapper/wrapper.py
                -v ${ns_ml_model_bin_version}
                --layout ${BINARY_DIR}/api_ns/image_signing/layout_files/signing_layout_ns_ml_model.o
                -k ${BINARY_DIR}/api_ns/image_signing/keys/image_ns_signing_private_key.pem # Reuse the NS key.
                --public-key-format full
                --align 1 --pad-header ${pad_option} -H 0x400 -s auto
                --measured-boot-record
                --confirm
                ${SECTORS_BIN_DIR}/model.bin
                $<TARGET_FILE_DIR:${target}>/${signed_ns_ml_model_bin_name}.bin
        COMMAND
            ${CMAKE_COMMAND} -E echo "-- signed: $<TARGET_FILE_DIR:${target}>/${signed_ns_ml_model_bin_name}.bin"
        VERBATIM
    )
endfunction()
