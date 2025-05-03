# Copyright 2025 Neudesic, an IBM Company
#
# This program is confidential and proprietary to Neudesic, an IBM Company,
# and may not be reproduced, published, or disclosed to others without company
# authorization.

FROM mcr.microsoft.com/devcontainers/base:1.2.5-ubuntu-24.04

# gnupg2 is needed for Git commit signing to work from the development
# container.
RUN apt-get update && apt-get install -y gnupg2