
#############################
### stage: build (neovim) ###
#############################

FROM alpine:3.16 as build
WORKDIR /tmp
RUN apk add --update git

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

# Build nvim
RUN git clone https://github.com/neovim/neovim.git
RUN cd neovim && \
  https_proxy= HTTPS_PROXY= make && \
  make install && \
  cd ../ && rm -rf nvim

# Build npm
ENV NODE_VERSION 19.0.0

RUN addgroup -g 1001 node \
    && adduser -u 1001 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        curl \
    && ARCH= && alpineArch="$(apk --print-arch)" \
      && case "${alpineArch##*-}" in \
        x86_64) \
          ARCH='x64' \
          CHECKSUM="80744232bb6ebe38967a827c05cab3d0a4b8cf75d2c7963d806f074e193d05ee" \
          ;; \
        *) ;; \
      esac \
  && if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
      && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
      && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
  else \
    echo "Building from source" \
    # backup build
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        python3 \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && for key in \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      141F07595B7B3FFE74309A937405533BE57C7D57 \
      74F12602B6F1C4E913FAA37AD3A89613643B6201 \
      61FC681DFB92A079F1685E77973F295594EC4689 \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
      108F52B48DB57BB0CC439B2997B01419BD92F80A \
    ; do \
      gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
      gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
  && apk del .build-deps \
  # smoke tests
  && node --version \
  && npm --version

#####################
### stage: lualsp ### 
#####################

FROM mileschou/lua:5.4-alpine as lualsp

# git clone lsp
RUN apk add git
WORKDIR /build
RUN git clone https://github.com/sumneko/lua-language-server
WORKDIR /build/lua-language-server
RUN git submodule update --init --recursive

# Build lsp with ninja and C++17 
WORKDIR /build/lua-language-server/3rd/luamake
RUN apk add ninja build-base
RUN ninja -f compile/ninja/linux.ninja

# Luamake
WORKDIR /build/lua-language-server
RUN ./3rd/luamake/luamake rebuild

##################
### main stage ###
##################

FROM alpine:3.16 as main

# Import build stage (neovim)
COPY --from=build /usr /usr

RUN apk add bash curl

# Install python/pip
ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools lookatme

# install desired npm packages
RUN npm install -g @angular/cli
RUN npm install -g typescript

# Install helm
RUN https_proxy= curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh
RUN helm version

# Install useful tools
RUN apk add --update docker \
    ripgrep \
    fd \
    yq \
    jq \
    openssh \
    bind-tools \
    lua5.3

# Install misc. tools
RUN apk add fzy remake-make valgrind kubectl kubectl-krew k9s --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

# User configuration
ARG USER_NAME=user
ARG UID=1337
ARG GID=1337
RUN apk add shadow
RUN /usr/sbin/groupadd --gid $GID $USER_NAME
RUN /usr/sbin/useradd -l -K MAIL_DIR=/dev/null -u $UID -g $GID $USER_NAME

# Import lualsp stage 
COPY --from=lualsp /build/lua-language-server /lsp
RUN chown -R $UID:$GID /lsp
# ENTRYPOINT ["/lsp/bin/lua-language-server", "/lsp/main.lua"]

# Entrypoint stuff
USER $USER_NAME
ENTRYPOINT ["/usr/local/bin/nvim"]
