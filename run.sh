docker run \
    --group-add="$(getent group docker | cut -d: -f3)" \
    --rm -it -v /var/run/docker.sock:/var/run/docker.sock \
    -e USER=$USER \
    -e XDG_CONFIG_HOME=$HOME/.config \
    -v $HOME:$HOME \
    -w $PWD \
    yifongau/nvim -S
