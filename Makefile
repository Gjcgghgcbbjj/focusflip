# FocusFlip - theos build configuration
# Build a TrollStore-installable IPA for iOS 15+

TARGET := iphone:clang:15.6:15.0
INSTALL_PATH := /Applications

PROJECT_NAME := FocusFlip
BUNDLE_NAME := FocusFlip
BUNDLE_ID := com.focusflip.app

THEOS_PROJECT_DIR := $(CURDIR)

# Source files
FocusFlip_FILES = \
	Sources/Theme/DesignSystem.swift \
	Sources/Theme/Compatibility.swift \
	Sources/App/FocusFlipApp.swift \
	Sources/Models/FocusSession.swift \
	Sources/Models/TaskItem.swift \
	Sources/Models/AppSettings.swift \
	Sources/Models/PersistenceController.swift \
	Sources/Engine/PomodoroEngine.swift \
	Sources/Engine/TimerService.swift \
	Sources/Engine/NotificationService.swift \
	Sources/Features/FlipClock/FlipClockView.swift \
	Sources/Features/FlipClock/FlipDigitView.swift \
	Sources/Features/FlipClock/FlipTransition.swift \
	Sources/Features/Timer/TimerView.swift \
	Sources/Features/Tasks/TasksView.swift \
	Sources/Features/Stats/StatsView.swift \
	Sources/Features/Sound/SoundPlayer.swift \
	Sources/Features/Settings/SettingsView.swift \
	Sources/FocusShield/FocusShieldManager.swift \
	Sources/Utils/HapticManager.swift \
	Sources/Utils/DateUtils.swift \
	Widget/LiveActivityAttributes.swift \
	Widget/FocusFlipWidget.swift \
	Widget/LockScreenWidget.swift \
	Widget/FocusFlipWidgetBundle.swift

# Frameworks
FocusFlip_FRAMEWORKS = SwiftUI CoreData AVFoundation AudioToolbox ActivityKit WidgetKit Charts
FocusFlip_PRIVATE_FRAMEWORKS = FrontBoard FrontBoardServices

# C flags for Swift
FocusFlip_SWIFTFLAGS = -I $(THEOS_PROJECT_DIR)/Headers
SWIFT_VERSION := 5.0

# Code signing: use ldid for TrollStore-style fake-sign
FAKE_SIGN := 1

# Entitlements for TrollStore platform app
FocusFlip_ENTITLEMENTS = FocusFlip.entitlements

include $(THEOS_MAKE_PATH)/application.mk
