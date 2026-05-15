FROM alpine:3.20 AS build

ARG V_REPO=https://github.com/vlang/v.git
ARG V_REF=master

ENV VROOT=/opt/v
ENV PATH="/opt/v:${PATH}"

WORKDIR /src

RUN apk add --no-cache build-base git libpq-dev sassc sqlite-dev openssl-dev linux-headers \
    && git clone --depth 1 --branch "${V_REF}" "${V_REPO}" "${VROOT}" \
    && make -C "${VROOT}" \
    && v symlink

COPY . /src/

RUN v install markdown \
    && v build.vsh \
    && cp ./src ./gitly

FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache git libpq sqlite-libs ca-certificates \
    && addgroup -S gitly \
    && adduser -S -G gitly gitly

COPY --from=build /src/gitly /app/gitly
COPY --from=build /src/config.json /app/config.json
COPY --from=build /src/static /app/static
COPY --from=build /src/translations /app/translations

RUN mkdir -p /app/repos /app/archives /app/avatars /app/logs \
    && chown -R gitly:gitly /app

USER gitly

ENV GITLY_PORT=8080
EXPOSE 8080

VOLUME ["/app/repos", "/app/archives", "/app/avatars", "/app/logs"]

CMD ["./gitly"]
