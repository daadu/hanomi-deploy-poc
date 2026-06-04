#!/usr/bin/env bash
####
## Deploy script for frontend module.
## 
## This script will be executed on the target VM to deploy the frontend, once the release artifacts are copied and extracted.
## Read the deploy flow documented in README.md for more information.
## 
## Usage:
##   ./deploy.sh <release-id>
####

set -euo pipefail

# TODO