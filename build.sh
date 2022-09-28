#!/bin/bash

docker build -t nvim-01:0.0.1 --build-arg USER_NAME=$USER --build-arg UID=$(id -u) --build-arg GID=$(id -g) .
