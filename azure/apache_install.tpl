#!/bin/bash
echo 'test' > output.txt
curl 10.20.4.10:9000/archive.tar.gz -o file.tar.gz
tar zxvf file.tar.gz
cd ./web
sudo dpkg -i *.deb