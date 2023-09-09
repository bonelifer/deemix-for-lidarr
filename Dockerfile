FROM docker.io/library/node:16-alpine as deemix
ARG TARGETPLATFORM=linux/amd64

RUN apk add --no-cache git jq python3 make gcc musl-dev g++ && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --recurse-submodules https://gitlab.com/RemixDev/deemix-gui.git
WORKDIR deemix-gui
RUN case "$TARGETPLATFORM" in \
        "linux/amd64") \
            jq '.pkg.targets = ["node16-alpine-x64"]' ./server/package.json > tmp-json ;; \
        "linux/arm64") \
            jq '.pkg.targets = ["node16-alpine-arm64"]' ./server/package.json > tmp-json ;; \
        *) \
            echo "Platform not supported" && exit 1 ;; \
    esac && \
    mv tmp-json /deemix-gui/server/package.json
RUN yarn install-all
# Patching deemix: see issue https://github.com/youegraillot/lidarr-on-steroids/issues/63
RUN sed -i 's/const channelData = await dz.gw.get_page(channelName)/let channelData; try { channelData = await dz.gw.get_page(channelName); } catch (error) { console.error(`Caught error ${error}`); return [];}/' ./server/src/routes/api/get/newReleases.ts
RUN yarn dist-server
RUN mv /deemix-gui/dist/deemix-server /deemix-server


FROM cr.hotio.dev/hotio/lidarr:pr-plugins-1.4.1.3564

LABEL maintainer="youegraillot"

ENV DEEMIX_SINGLE_USER=true
ENV AUTOCONFIG=true
ENV PUID=1000
ENV PGID=1000

# flac2mp3
RUN apk add --no-cache ffmpeg && \
    rm -rf /var/lib/apt/lists/*
COPY lidarr-flac2mp3/root/usr /usr

# deemix
COPY --from=deemix /deemix-server /deemix-server
RUN chmod +x /deemix-server
VOLUME ["/config_deemix", "/downloads"]
EXPOSE 6595

COPY root /
RUN chmod +x /etc/services.d/*/run
VOLUME ["/config", "/music"]
EXPOSE 6595 8686
