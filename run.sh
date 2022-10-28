# note that simply copies the $PATH of the host as a quick fix to give
# container access to user binaries. But if host $PATH does not include
# directories of the system binaries the container uses, it will throw errors.
# Ensure host $PATH has at least the following:
# /bin and /sbin
# /usr/bin and /usr/sbin
# /usr/local/bin and /usr/local/sbin


tag=yifongau/nvim-ide:0.0.2

if [[ -f Session.vim ]]
then
    session_arg='-S'
else
    session_arg=
fi

docker run \
    --group-add="$(getent group docker | cut -d: -f3)" \
    --rm -it -v /var/run/docker.sock:/var/run/docker.sock \
    -e USER=$USER \
    -e XDG_CONFIG_HOME=$HOME/.config \
    -e PATH=$PATH \
    -v $HOME:$HOME \
    -w $PWD \
    --expose=4200 \
    -p 4200:4200 \
    $tag $session_arg

