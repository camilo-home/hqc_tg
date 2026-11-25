#!/usr/bin/env bash
sudo killall -q jtagd || true
sudo "$(which jtagd)"
jtagconfig