FROM dart:stable AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.pub-cache/bin:${PATH}"

RUN dart pub global activate jaspr_cli 0.22.3

WORKDIR /workspace

COPY packages ./packages
COPY apps/echogram_web ./apps/echogram_web

WORKDIR /workspace/apps/echogram_web

RUN dart pub get
RUN npm ci
RUN npm run build:css
RUN jaspr build

FROM nginx:1.27-alpine

COPY apps/echogram_web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/apps/echogram_web/build/jaspr /usr/share/nginx/html

EXPOSE 80
