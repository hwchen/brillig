TARGET_EXEC := cbril
TEST_EXEC := testrun
BUILD_DIR := ./build

SRCS := $(shell find . -name '*.c3')
TURNT_SRCS := $(shell find test -name '*.bril')

$(BUILD_DIR)/$(TARGET_EXEC): $(SRCS)
	c3c compile $(SRCS) -o $@ $(CFLAGS)

$(BUILD_DIR)/$(TEST_EXEC): $(SRCS)
	c3c compile-test --suppress-run $(SRCS) -o $@ $(CFLAGS)

.PHONY: clean
clean:
	rm -r ./build

.PHONY: test
test: $(BUILD_DIR)/$(TEST_EXEC)
	$(BUILD_DIR)/$(TEST_EXEC)

# `make turnt TURNT_FLAGS=-v`
# --save
# --diff
.PHONY: turnt
turnt: $(BUILD_DIR)/$(TARGET_EXEC)
	turnt $(TURNT_FLAGS) -j $(TURNT_SRCS)
