#!/usr/bin/env bash

#https://help.ubuntu.com/community/Privoxy
sudo apt-get update
sudo apt-get install privoxy -y

#bind proxy listen-address to all IPs
sudo sed -i "s/127.0.0.1//g" /etc/privoxy/config
sudo /etc/init.d/privoxy restart