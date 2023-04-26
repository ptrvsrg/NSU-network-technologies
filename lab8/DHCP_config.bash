#!/bin/bash

sudo ip addr flush wlp2s0
sudo dhclient -r
sudo dhclient wlp2s0
