#!/usr/bin/env bash

#https://help.ubuntu.com/community/Privoxy
sudo apt-get update
sudo apt-get install privoxy -y

sudo ip=$(ec2metadata --local-ipv4)
sudo sed -i "s/192.168.0.1/$ip/g" /etc/privoxy/config
sudo /etc/init.d/privoxy restart