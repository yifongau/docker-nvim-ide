FROM alpine:3 as build

WORKDIR /tmp
RUN apk add --update git
RUN git clone https://github.com/neovim/neovim.git
RUN apk add --update alpine-sdk build-base \
    libtool \
    automake \
    m4 \
    autoconf \
    linux-headers \
    ncurses ncurses-dev ncurses-libs ncurses-terminfo \
    make \
    cmake \
    unzip \
    xz \
    libintl \
    curl \
    icu-dev \
    gettext-dev \
    gettext

RUN cd neovim && \
  https_proxy= HTTPS_PROXY= make && \
  make install && \
  cd ../ && rm -rf nvim

FROM mileschou/lua:5.4-alpine as lualsp

# git clone lsp
RUN apk add git
WORKDIR /build
RUN git clone https://github.com/sumneko/lua-language-server
WORKDIR /build/lua-language-server
RUN git submodule update --init --recursive


# build lsp with ninja and C++17 
WORKDIR /build/lua-language-server/3rd/luamake
RUN apk add ninja build-base
RUN ninja -f compile/ninja/linux.ninja

# luamake
WORKDIR /build/lua-language-server
RUN ./3rd/luamake/luamake rebuild

FROM alpine:3 as main

COPY --from=build /usr /usr

RUN apk add bash 
# Install python/pip
ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools lookatme

RUN https_proxy= curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh
RUN helm version

RUN apk add --update docker \
    ripgrep \
    fd \
    yq \
    jq \
    openssh \
    bind-tools \
    lua5.3

RUN apk add fzy remake-make valgrind kubectl kubectl-krew k9s --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

ARG USER_NAME=user
ARG UID=1337
ARG GID=1337

RUN apk add shadow
RUN /usr/sbin/groupadd --gid $GID $USER_NAME
RUN /usr/sbin/useradd -l -K MAIL_DIR=/dev/null -u $UID -g $GID $USER_NAME

COPY --from=lualsp /build/lua-language-server /lsp
RUN chown -R $UID:$GID /lsp
# ENTRYPOINT ["/lsp/bin/lua-language-server", "/lsp/main.lua"]

USER $USER_NAME
ENTRYPOINT ["/usr/local/bin/nvim"]
