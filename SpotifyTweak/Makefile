TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Spotify

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LyriCarSpotify

LyriCarSpotify_FILES = LyriCarSpotify.m
LyriCarSpotify_CFLAGS = -fobjc-arc -Osize
LyriCarSpotify_FRAMEWORKS = Foundation UIKit CarPlay MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk
