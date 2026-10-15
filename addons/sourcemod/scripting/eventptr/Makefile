# Build against the external SourceMod 1.12.0.7253 source SDK.
ifndef SM_SDK
$(error SM_SDK must point to the external SourceMod source tree)
endif

CXX ?= g++
OUTPUT ?= ../../extensions/eventptr.ext.so
CPPFLAGS += -isystem $(SM_SDK)/public -isystem $(SM_SDK)/public/amtl \
            -isystem $(SM_SDK)/public/amtl/amtl \
            -isystem $(SM_SDK)/sourcepawn/include
CXXFLAGS += -m32 -std=c++17 -fPIC -fvisibility=hidden -fno-rtti \
            -fno-exceptions -Wall -Wextra -Werror
LDFLAGS += -m32 -shared -Wl,--no-undefined

$(OUTPUT): extension.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< $(LDFLAGS) -o $@
