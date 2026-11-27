# Verification Firmware Build Makefile (SOC_VB_001)
# Requires a bare-metal RV32I GNU toolchain (not currently installed on host).

CROSS_COMPILE ?= riscv64-unknown-elf-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump
PYTHON  := python3

ARCH_FLAGS := -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles -fno-builtin -mcmodel=medlow
WARN_FLAGS := -Wall -Wextra -Werror
ASM_FLAGS  := $(ARCH_FLAGS) $(WARN_FLAGS) -O2 -g -x assembler-with-cpp -Iinclude
C_FLAGS    := $(ARCH_FLAGS) $(WARN_FLAGS) -O2 -g -Iinclude
LD_FLAGS   := $(ARCH_FLAGS) -T link.ld -Wl,--gc-sections

BUILD_DIR := build

CORE_ASM_TESTS := VER_CORE_001 VER_CORE_002 VER_CORE_003
C_TESTS        := VER_CORE_004

# Fault tests and their subcase counts (0..N-1)
FAULT_001_SUBS := 0 1 2
FAULT_002_SUBS := 0 1
FAULT_003_SUBS := 0 1 2 3 4 5
FAULT_004_SUBS := 0
FAULT_005_SUBS := 0
FAULT_006_SUBS := 0 1 2 3 4 5
FAULT_007_SUBS := 0 1 2
FAULT_008_SUBS := 0 1 2 3 4 5
FAULT_009_SUBS := 0 1 2 3 4 5 6
FAULT_010_SUBS := 0 1
FAULT_011_SUBS := 0 1 2 3 4

.PHONY: all clean check-toolchain

all: check-toolchain $(addprefix $(BUILD_DIR)/,$(addsuffix .mem,$(CORE_ASM_TESTS) $(C_TESTS))) \
     fault-images

check-toolchain:
	@command -v $(CC) >/dev/null 2>&1 || { echo "ERROR: $(CC) not found. See TOOLCHAIN_AND_BUILD.md."; exit 1; }
	@$(CC) --version | head -n 1

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Core assembly tests
$(BUILD_DIR)/%.elf: src/%.S link.ld include/verif_mailbox.inc | $(BUILD_DIR)
	$(CC) $(ASM_FLAGS) $(LD_FLAGS) -Wl,-Map=$(BUILD_DIR)/$*.map $< -o $@

# Bare-metal C test (VER_CORE_004)
$(BUILD_DIR)/VER_CORE_004.elf: src/crt0.S src/VER_CORE_004.c link.ld include/verif_mailbox.inc | $(BUILD_DIR)
	$(CC) $(C_FLAGS) $(LD_FLAGS) -Wl,-Map=$(BUILD_DIR)/VER_CORE_004.map src/crt0.S src/VER_CORE_004.c -o $@

# Parameterized fault subcase template
define BUILD_FAULT_RULE
$(BUILD_DIR)/$(1)_sub$(2).elf: src/$(1).S link.ld include/verif_mailbox.inc | $(BUILD_DIR)
	$(CC) $(ASM_FLAGS) -DSUBCASE=$(2) $(LD_FLAGS) -Wl,-Map=$(BUILD_DIR)/$(1)_sub$(2).map $$< -o $$@
endef

$(foreach s,$(FAULT_001_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_001,$(s))))
$(foreach s,$(FAULT_002_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_002,$(s))))
$(foreach s,$(FAULT_003_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_003,$(s))))
$(foreach s,$(FAULT_004_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_004,$(s))))
$(foreach s,$(FAULT_005_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_005,$(s))))
$(foreach s,$(FAULT_006_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_006,$(s))))
$(foreach s,$(FAULT_007_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_007,$(s))))
$(foreach s,$(FAULT_008_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_008,$(s))))
$(foreach s,$(FAULT_009_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_009,$(s))))
$(foreach s,$(FAULT_010_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_010,$(s))))
$(foreach s,$(FAULT_011_SUBS),$(eval $(call BUILD_FAULT_RULE,VER_FAULT_011,$(s))))

FAULT_MEMS := \
  $(foreach s,$(FAULT_001_SUBS),$(BUILD_DIR)/VER_FAULT_001_sub$(s).mem) \
  $(foreach s,$(FAULT_002_SUBS),$(BUILD_DIR)/VER_FAULT_002_sub$(s).mem) \
  $(foreach s,$(FAULT_003_SUBS),$(BUILD_DIR)/VER_FAULT_003_sub$(s).mem) \
  $(foreach s,$(FAULT_004_SUBS),$(BUILD_DIR)/VER_FAULT_004_sub$(s).mem) \
  $(foreach s,$(FAULT_005_SUBS),$(BUILD_DIR)/VER_FAULT_005_sub$(s).mem) \
  $(foreach s,$(FAULT_006_SUBS),$(BUILD_DIR)/VER_FAULT_006_sub$(s).mem) \
  $(foreach s,$(FAULT_007_SUBS),$(BUILD_DIR)/VER_FAULT_007_sub$(s).mem) \
  $(foreach s,$(FAULT_008_SUBS),$(BUILD_DIR)/VER_FAULT_008_sub$(s).mem) \
  $(foreach s,$(FAULT_009_SUBS),$(BUILD_DIR)/VER_FAULT_009_sub$(s).mem) \
  $(foreach s,$(FAULT_010_SUBS),$(BUILD_DIR)/VER_FAULT_010_sub$(s).mem) \
  $(foreach s,$(FAULT_011_SUBS),$(BUILD_DIR)/VER_FAULT_011_sub$(s).mem)

fault-images: $(FAULT_MEMS)

$(BUILD_DIR)/%.mem: $(BUILD_DIR)/%.elf bin2mem.py
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/$*.bin
	$(OBJDUMP) -d -S $< > $(BUILD_DIR)/$*.dis
	$(PYTHON) bin2mem.py $(BUILD_DIR)/$*.bin $@ --max-bytes 32768
	sha256sum $< $(BUILD_DIR)/$*.bin $@ > $(BUILD_DIR)/$*.sha256

clean:
	rm -rf $(BUILD_DIR)
