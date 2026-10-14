THEOS ?= $(HOME)/theos

TARGET := iphone:clang:9.3:6.0
ARCHS = armv7

THEOS_DEVICE_IP = iphone4
THEOS_DEVICE_USER = root

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = RetroStore
RetroStore_FILES = $(wildcard Sources/*.m)
RetroStore_CFLAGS = -marm -fobjc-arc -ISources \
	-Wno-deprecated-module-dot-map -Wno-deprecated-declarations -Wunguarded-availability
RetroStore_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
RetroStore_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "su mobile -c uicache"

ipa: stage
	rm -rf .theos/ipa
	mkdir -p .theos/ipa/Payload packages
	cp -R .theos/_/Applications/RetroStore.app .theos/ipa/Payload/
	rm -f packages/RetroStore-$(shell grep '^Version:' control | cut -d' ' -f2).ipa
	cd .theos/ipa && COPYFILE_DISABLE=1 zip -qrX ../../packages/RetroStore-$(shell grep '^Version:' control | cut -d' ' -f2).ipa Payload
