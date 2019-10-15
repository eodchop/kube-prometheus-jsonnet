#!/usr/bin/env bash

# This command sometimes may need to be done twice (to workaround a race condition)
kubectl apply -f manifests/
