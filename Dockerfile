# bro
#
# VERSION               0.1

# Checkout and build Zeek
FROM debian:buster as builder
MAINTAINER Justin Azoff <justin.azoff@gmail.com>

ENV WD /scratch

RUN mkdir ${WD}
WORKDIR /scratch

RUN apt-get update && apt-get upgrade -y && echo 2010-05-15
RUN apt-get -y install build-essential git bison flex gawk cmake swig libssl-dev libmaxminddb-dev libpcap-dev python3.7-dev libcurl4-openssl-dev wget libncurses5-dev ca-certificates zlib1g-dev --no-install-recommends

ARG ZEEK_VER=3.0.0
ARG BUILD_TYPE=Release
ENV VER ${ZEEK_VER}
ADD ./common/buildbro ${WD}/common/buildbro
RUN ${WD}/common/buildbro zeek ${VER} ${BUILD_TYPE}

# For testing
ADD ./common/getmmdb.sh /usr/local/getmmdb.sh
ADD ./common/bro_profile.sh /usr/local/bro_profile.sh

# Get geoip data
FROM debian:buster as geogetter
ARG MAXMIND_LICENSE_KEY
RUN apt-get update && apt-get -y install wget ca-certificates --no-install-recommends

# For testing
#ADD ./common/getmmdb.sh /usr/local/bin/getmmdb.sh
COPY --from=builder /usr/local/getmmdb.sh /usr/local/bin/getmmdb.sh
RUN mkdir -p /usr/share/GeoIP
RUN /usr/local/bin/getmmdb.sh ${MAXMIND_LICENSE_KEY}
# This is a workaround for the case where getmmdb.sh does not create any files.
RUN touch /usr/share/GeoIP/.notempty

# Make final image
FROM debian:buster
ARG ZEEK_VER=3.0.0
ENV VER ${ZEEK_VER}
#install runtime dependencies
RUN apt-get update \
    && apt-get -y install --no-install-recommends libpcap0.8 libssl1.1 libmaxminddb0 python3.7-minimal \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/zeek-${VER} /usr/local/zeek-${VER}
COPY --from=geogetter /usr/share/GeoIP/* /usr/share/GeoIP/
RUN rm -f /usr/share/GeoIP/.notempty
RUN ln -s /usr/local/zeek-${VER} /bro
RUN ln -s /usr/local/zeek-${VER} /zeek

# install zsh and net-tools vim
RUN apt-get update \
    && apt-get -y install zsh git net-tools vim neovim uml-utilities wget tcpreplay tcpdump whois\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh &&\
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc &&\
    chsh -s /bin/zsh && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.zsh-syntax-highlighting" --depth 1 && \
    echo "source $HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$HOME/.zshrc"

# install vim 
RUN echo ":set nu" >> ~/.vimrc
RUN echo ":syntax on" >> ~/.vimrc


# For testing
#ADD ./common/bro_profile.sh /etc/profile.d/zeek.sh
COPY --from=builder /usr/local/bro_profile.sh /etc/profile.d/zeek.sh

env PATH /zeek/bin/:$PATH
CMD /bin/zsh -l
