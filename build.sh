#!/bin/bash

docker build -t yifongau/nvim-ide:0.0.2 \
	--build-arg USER_NAME=$USER \
	--build-arg UID=$(id -u) \
	--build-arg GID=$(id -g) .
