#!/usr/bin/env bash

# Copyright 2025 Neudesic, an IBM Company
#
# This program is confidential and proprietary to Neudesic, an IBM Company,
# and may not be reproduced, published, or disclosed to others without company
# authorization.

set -e

# Configure the /workspace directory as a safe directory for Git.
git config --global --add safe.directory /workspace